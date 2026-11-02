/*
  Varian Stock (REG2) â€” parity module/omni/varian_stock.aspx
  Route: GET /regional/rpt/omni/varian-stock

  @p_tipe
    PROVINSI  daftar provinsi store (dropdown)
    ATTR      size + color untuk satu article          (@p_article)
    STOCK     sisa realtime semua store untuk satu varian
              @p_article, @p_kategori = size, @p_group = color, @p_provinsi opsional

  qty = Z pada tanggal closing terakhir yang <= hari ini (DT_STOCK_SUMMARY)
        + penerimaan (TR_ST masuk, Tgl_Closed_Real setelah tanggal closing)
        + adjustment (TR_ST_ADJUSMENT)
        + retur (TR_SALES_REFUND_DETAIL)
        - transfer keluar (TR_ST QTY_OUT, Tgl_Out setelah closing)
        - penjualan Status_Transaksi = 1 setelah closing

  DT_STOCK_SUMMARY ratusan juta baris dan tidak punya key PLU.
  Closing dibaca lewat index TANGGAL_closingulang (key = TANGGAL), satu tanggal saja.
  Mutasi di hari closing sudah masuk ke Z. Yang dihitung ulang hanya tanggal setelah TANGGAL closing.
  Trade antar store ikut TR_ST (masuk / keluar), tidak ada tabel trade terpisah di query ini.
  Hanya SELECT. Tidak ada DELETE, TRUNCATE, DROP, atau ubah data.
  Server ini tidak mendukung CREATE OR ALTER, jadi prosedur di-ALTER (dibuat kosong hanya jika belum ada).
  Tidak membaca dan tidak menghapus key Redis, termasuk Realtime_Stock:All_Store.
*/
USE RBACESS;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_omni_varian_getrows', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_omni_varian_getrows AS BEGIN SET NOCOUNT ON; END');
GO

ALTER PROCEDURE dbo.xsp_ams_new_reg_rpt_omni_varian_getrows
(
      @p_keywords varchar(200) = NULL
    , @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @p_is_active varchar(10) = NULL
    , @p_id_brand varchar(50) = NULL
    , @p_id_store varchar(50) = NULL
    , @p_brand varchar(50) = NULL
    , @p_store_id varchar(50) = NULL
    , @p_status varchar(50) = NULL
    , @p_kategori varchar(50) = NULL
    , @p_group varchar(50) = NULL
    , @p_dept varchar(50) = NULL
    , @p_department varchar(50) = NULL
    , @p_cabang varchar(50) = NULL
    , @p_id_cabang varchar(50) = NULL
    , @p_year varchar(10) = NULL
    , @p_month varchar(10) = NULL
    , @p_period varchar(20) = NULL
    , @p_tipe varchar(50) = NULL
    , @p_is_pajak varchar(10) = NULL
    , @p_id_mesin varchar(50) = NULL
    , @p_currentmonth varchar(10) = NULL
    , @p_tahun varchar(10) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @p_plu varchar(80) = NULL
    , @p_article varchar(80) = NULL
    , @p_voucher varchar(80) = NULL
    , @p_invoice varchar(80) = NULL
    , @p_marketplace varchar(80) = NULL
    , @p_multi_store varchar(max) = NULL
    , @p_brand_filter varchar(80) = NULL
    , @p_brand_to varchar(50) = NULL
    , @p_store_to varchar(50) = NULL
    , @p_tgl varchar(30) = NULL
    , @p_provinsi varchar(80) = NULL
    , @p_kota varchar(80) = NULL
    , @p_id_member varchar(80) = NULL
    , @p_confirm_status varchar(50) = NULL
    , @p_gh_id varchar(50) = NULL
    , @p_id_gh varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    BEGIN TRY
        DECLARE @tipe varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(@p_tipe, ''))));
        DECLARE @article varchar(80) = LTRIM(RTRIM(ISNULL(@p_article, '')));
        /* Regional list params: size â†’ kategori, color â†’ group */
        DECLARE @size varchar(50) = LTRIM(RTRIM(ISNULL(@p_kategori, '')));
        DECLARE @color varchar(50) = LTRIM(RTRIM(ISNULL(@p_group, '')));
        DECLARE @prov varchar(80) = LTRIM(RTRIM(ISNULL(@p_provinsi, '')));
        IF UPPER(@prov) IN ('ALL', '0', '*') SET @prov = '';

        IF @tipe NOT IN ('PROVINSI', 'ATTR', 'STOCK')
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'tipe wajib PROVINSI, ATTR, atau STOCK.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        IF @tipe IN ('ATTR', 'STOCK') AND @article = ''
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'Article wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        IF @tipe = 'STOCK' AND (@size = '' OR @color = '')
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'Size dan Color wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* DT_PLU.UKURAN / WARNA and DT_Store.STORE_PROVINSI are the live column names.
           Static SQL: a single nvarchar literal longer than 4000 is truncated by SQL Server. */

        IF @tipe = 'PROVINSI'
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY(ISNULL((
                           SELECT DISTINCT LTRIM(RTRIM(s.STORE_PROVINSI)) AS provinsi
                           FROM pos_server.dbo.DT_Store AS s WITH (NOLOCK)
                           WHERE LTRIM(RTRIM(ISNULL(s.STORE_PROVINSI, ''))) <> ''
                           ORDER BY LTRIM(RTRIM(s.STORE_PROVINSI))
                           FOR JSON PATH
                       ), '[]')) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        IF @tipe = 'ATTR'
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY(ISNULL((
                           SELECT DISTINCT
                                  LTRIM(RTRIM(p.UKURAN)) AS size,
                                  LTRIM(RTRIM(p.WARNA)) AS color
                           FROM pos_server.dbo.DT_PLU AS p WITH (NOLOCK)
                           WHERE UPPER(LTRIM(RTRIM(p.ARTICLE))) = UPPER(@article)
                             AND LTRIM(RTRIM(ISNULL(p.UKURAN, ''))) <> ''
                             AND LTRIM(RTRIM(ISNULL(p.WARNA, ''))) <> ''
                           ORDER BY LTRIM(RTRIM(p.UKURAN)), LTRIM(RTRIM(p.WARNA))
                           FOR JSON PATH
                       ), '[]')) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @close date;
        DECLARE @floor date;
        SELECT @close = MAX(d.TANGGAL)
        FROM pos_server.dbo.DT_STOCK_SUMMARY AS d WITH (NOLOCK, INDEX(TANGGAL_closingulang))
        WHERE d.TANGGAL <= CAST(GETDATE() AS date);
        SET @floor = DATEADD(DAY, 1, @close);

        DECLARE @plu TABLE (
            PLU varchar(40) NOT NULL PRIMARY KEY,
            ARTICLE varchar(80) NULL,
            size varchar(50) NULL,
            color varchar(50) NULL
        );
        INSERT INTO @plu (PLU, ARTICLE, size, color)
        SELECT
            p.PLU,
            MAX(p.ARTICLE),
            MAX(LTRIM(RTRIM(p.UKURAN))),
            MAX(LTRIM(RTRIM(p.WARNA)))
        FROM pos_server.dbo.DT_PLU AS p WITH (NOLOCK)
        WHERE UPPER(LTRIM(RTRIM(p.ARTICLE))) = UPPER(@article)
          AND UPPER(LTRIM(RTRIM(p.UKURAN))) = UPPER(@size)
          AND UPPER(LTRIM(RTRIM(p.WARNA))) = UPPER(@color)
        GROUP BY p.PLU;

        DECLARE @base TABLE (
            Store_ID varchar(50) NOT NULL,
            PLU varchar(40) NOT NULL,
            Z decimal(19, 4) NOT NULL,
            PRIMARY KEY (Store_ID, PLU)
        );
        IF @close IS NOT NULL
        BEGIN
            INSERT INTO @base (Store_ID, PLU, Z)
            SELECT Store_ID, PLU, Z
            FROM (
                SELECT
                    d.Store_ID,
                    d.PLU,
                    CAST(ISNULL(d.Z, 0) AS decimal(19, 4)) AS Z,
                    ROW_NUMBER() OVER (
                        PARTITION BY d.Store_ID, d.PLU
                        ORDER BY d.NO_URUT DESC
                    ) AS rn
                FROM pos_server.dbo.DT_STOCK_SUMMARY AS d WITH (NOLOCK, INDEX(TANGGAL_closingulang))
                WHERE d.TANGGAL = @close
                  AND d.PLU IN (SELECT PLU FROM @plu)
            ) AS x
            WHERE x.rn = 1;
        END;

        DECLARE @st_in TABLE (Store_ID varchar(50) NOT NULL, PLU varchar(40) NOT NULL, qty decimal(19, 4) NOT NULL, PRIMARY KEY (Store_ID, PLU));
        DECLARE @st_out TABLE (Store_ID varchar(50) NOT NULL, PLU varchar(40) NOT NULL, qty decimal(19, 4) NOT NULL, PRIMARY KEY (Store_ID, PLU));
        DECLARE @adj TABLE (Store_ID varchar(50) NOT NULL, PLU varchar(40) NOT NULL, qty decimal(19, 4) NOT NULL, PRIMARY KEY (Store_ID, PLU));
        DECLARE @sales TABLE (Store_ID varchar(50) NOT NULL, PLU varchar(40) NOT NULL, qty decimal(19, 4) NOT NULL, PRIMARY KEY (Store_ID, PLU));
        DECLARE @refund TABLE (Store_ID varchar(50) NOT NULL, PLU varchar(40) NOT NULL, qty decimal(19, 4) NOT NULL, PRIMARY KEY (Store_ID, PLU));

        IF @floor IS NOT NULL
        BEGIN
            INSERT INTO @st_in (Store_ID, PLU, qty)
            SELECT h.ID_Store_IN, d.PLU, SUM(CAST(ISNULL(d.QTY_REAL, 0) AS decimal(19, 4)))
            FROM pos_server.dbo.TR_ST_DETAIL AS d WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_ST_HEADER AS h WITH (NOLOCK)
                ON h.NO_TR_ST_HEADER = d.NO_TR_ST_HEADER
            INNER JOIN @base AS b ON b.Store_ID = h.ID_Store_IN AND b.PLU = d.PLU
            WHERE d.PLU IN (SELECT PLU FROM @plu)
              AND h.Tgl_Closed_Real >= @floor
              AND LEFT(d.PLU, 2) <> '01'
            GROUP BY h.ID_Store_IN, d.PLU;

            INSERT INTO @st_out (Store_ID, PLU, qty)
            SELECT h.ID_Store_OUT, d.PLU, SUM(CAST(ISNULL(d.QTY_OUT, 0) AS decimal(19, 4)))
            FROM pos_server.dbo.TR_ST_DETAIL AS d WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_ST_HEADER AS h WITH (NOLOCK)
                ON h.NO_TR_ST_HEADER = d.NO_TR_ST_HEADER
            INNER JOIN @base AS b ON b.Store_ID = h.ID_Store_OUT AND b.PLU = d.PLU
            WHERE d.PLU IN (SELECT PLU FROM @plu)
              AND h.Tgl_Out >= @floor
              AND LEFT(d.PLU, 2) <> '01'
            GROUP BY h.ID_Store_OUT, d.PLU;

            INSERT INTO @adj (Store_ID, PLU, qty)
            SELECT a.STORE_ID, a.PLU, SUM(CAST(ISNULL(a.QTY, 0) AS decimal(19, 4)))
            FROM pos_server.dbo.TR_ST_ADJUSMENT AS a WITH (NOLOCK)
            INNER JOIN @base AS b ON b.Store_ID = a.STORE_ID AND b.PLU = a.PLU
            WHERE a.PLU IN (SELECT PLU FROM @plu)
              AND a.TGL_ADJUST >= @floor
            GROUP BY a.STORE_ID, a.PLU;

            INSERT INTO @sales (Store_ID, PLU, qty)
            SELECT h.ID_Store, d.PLU, SUM(CAST(ISNULL(d.QTY, 0) AS decimal(19, 4)))
            FROM pos_server.dbo.TR_SALES_DETAIL AS d WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_HEADER AS h WITH (NOLOCK)
                ON h.ID_TR_SALES_HEADER = d.ID_TR_SALES_HEADER
            INNER JOIN @base AS b ON b.Store_ID = h.ID_Store AND b.PLU = d.PLU
            WHERE d.PLU IN (SELECT PLU FROM @plu)
              AND h.Status_Transaksi = 1
              AND h.Tanggal_Transaksi >= @floor
              AND LEFT(d.PLU, 2) <> '01'
            GROUP BY h.ID_Store, d.PLU;

            INSERT INTO @refund (Store_ID, PLU, qty)
            SELECT rh.ID_STORE, rd.PLU, SUM(CAST(ISNULL(rd.QTY, 0) AS decimal(19, 4)))
            FROM pos_server.dbo.TR_SALES_REFUND AS rh WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL AS rd WITH (NOLOCK)
                ON rd.ID_TR_SALES_REFUND = rh.ID_TR_SALES_REFUND
            INNER JOIN @base AS b ON b.Store_ID = rh.ID_STORE AND b.PLU = rd.PLU
            WHERE rd.PLU IN (SELECT PLU FROM @plu)
              AND rh.TGL_REFUND >= @floor
              AND LEFT(rd.PLU, 2) <> '01'
            GROUP BY rh.ID_STORE, rd.PLU;
        END;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL((
                       SELECT
                           s.Store_Brand_ID AS brand,
                           b.Store_ID AS store_id,
                           ISNULL(s.STORE_KOTA, '') AS kota,
                           LTRIM(RTRIM(ISNULL(s.STORE_PROVINSI, ''))) AS provinsi,
                           ISNULL(s.STORE_PULAU, '') AS pulau,
                           p.ARTICLE AS article,
                           b.PLU AS plu,
                           CAST(
                               b.Z
                               + ISNULL(i.qty, 0)
                               + ISNULL(j.qty, 0)
                               + ISNULL(rf.qty, 0)
                               - ISNULL(o.qty, 0)
                               - ISNULL(sl.qty, 0)
                           AS decimal(18, 4)) AS qty,
                           p.size,
                           p.color
                       FROM @base AS b
                       INNER JOIN @plu AS p ON p.PLU = b.PLU
                       LEFT JOIN pos_server.dbo.DT_Store AS s WITH (NOLOCK) ON s.Store_ID = b.Store_ID
                       LEFT JOIN @st_in AS i ON i.Store_ID = b.Store_ID AND i.PLU = b.PLU
                       LEFT JOIN @st_out AS o ON o.Store_ID = b.Store_ID AND o.PLU = b.PLU
                       LEFT JOIN @adj AS j ON j.Store_ID = b.Store_ID AND j.PLU = b.PLU
                       LEFT JOIN @sales AS sl ON sl.Store_ID = b.Store_ID AND sl.PLU = b.PLU
                       LEFT JOIN @refund AS rf ON rf.Store_ID = b.Store_ID AND rf.PLU = b.PLU
                       WHERE @prov = '' OR UPPER(LTRIM(RTRIM(ISNULL(s.STORE_PROVINSI, '')))) = UPPER(@prov)
                       ORDER BY b.Store_ID, b.PLU
                       FOR JSON PATH
                   ), '[]')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH
END
GO
