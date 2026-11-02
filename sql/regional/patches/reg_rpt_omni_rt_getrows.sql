/*
  Realtime Stock (REG2) — parity module/omni/realtime_stock.aspx UI
  Route: GET /regional/rpt/omni/realtime-stock

  Params:
    @p_store_id / @p_id_store  wajib
    @p_article                 opsional (LIKE)

  qty = Z closing terakhir (DT_STOCK_SUMMARY)
        + ST in + adj + refund
        - ST out - sales
  Same formula as Varian Stock. SQL only — no Redis.
*/
USE RBACESS;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_omni_rt_getrows', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_omni_rt_getrows AS BEGIN SET NOCOUNT ON; END');
GO

ALTER PROCEDURE dbo.xsp_ams_new_reg_rpt_omni_rt_getrows
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
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(NULLIF(@p_store_id, ''), @p_id_store)));
        DECLARE @article varchar(80) = LTRIM(RTRIM(ISNULL(@p_article, '')));

        IF @store IS NULL OR @store = '' OR UPPER(@store) IN ('0', 'PILIH STORE', 'ALL', '*')
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY('[]') AS data,
                       CAST(0 AS decimal(18, 4)) AS total_qty,
                       CAST(NULL AS varchar(10)) AS close_date,
                       CAST(NULL AS varchar(10)) AS movement_from
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
                  AND d.Store_ID = @store
                  AND LEFT(d.PLU, 2) <> '01'
            ) AS x
            WHERE x.rn = 1;
        END;

        /* Optional article filter via DT_PLU before movement calc */
        IF @article <> ''
        BEGIN
            DELETE b
            FROM @base AS b
            WHERE NOT EXISTS (
                SELECT 1
                FROM pos_server.dbo.DT_PLU AS p WITH (NOLOCK)
                WHERE p.PLU = b.PLU
                  AND UPPER(LTRIM(RTRIM(ISNULL(p.ARTICLE, '')))) LIKE '%' + UPPER(@article) + '%'
            );
        END;

        DECLARE @st_in TABLE (Store_ID varchar(50) NOT NULL, PLU varchar(40) NOT NULL, qty decimal(19, 4) NOT NULL, PRIMARY KEY (Store_ID, PLU));
        DECLARE @st_out TABLE (Store_ID varchar(50) NOT NULL, PLU varchar(40) NOT NULL, qty decimal(19, 4) NOT NULL, PRIMARY KEY (Store_ID, PLU));
        DECLARE @adj TABLE (Store_ID varchar(50) NOT NULL, PLU varchar(40) NOT NULL, qty decimal(19, 4) NOT NULL, PRIMARY KEY (Store_ID, PLU));
        DECLARE @sales TABLE (Store_ID varchar(50) NOT NULL, PLU varchar(40) NOT NULL, qty decimal(19, 4) NOT NULL, PRIMARY KEY (Store_ID, PLU));
        DECLARE @refund TABLE (Store_ID varchar(50) NOT NULL, PLU varchar(40) NOT NULL, qty decimal(19, 4) NOT NULL, PRIMARY KEY (Store_ID, PLU));

        IF @floor IS NOT NULL AND EXISTS (SELECT 1 FROM @base)
        BEGIN
            INSERT INTO @st_in (Store_ID, PLU, qty)
            SELECT h.ID_Store_IN, d.PLU, SUM(CAST(ISNULL(d.QTY_REAL, 0) AS decimal(19, 4)))
            FROM pos_server.dbo.TR_ST_DETAIL AS d WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_ST_HEADER AS h WITH (NOLOCK)
                ON h.NO_TR_ST_HEADER = d.NO_TR_ST_HEADER
            INNER JOIN @base AS b ON b.Store_ID = h.ID_Store_IN AND b.PLU = d.PLU
            WHERE h.Tgl_Closed_Real >= @floor
              AND LEFT(d.PLU, 2) <> '01'
            GROUP BY h.ID_Store_IN, d.PLU;

            INSERT INTO @st_out (Store_ID, PLU, qty)
            SELECT h.ID_Store_OUT, d.PLU, SUM(CAST(ISNULL(d.QTY_OUT, 0) AS decimal(19, 4)))
            FROM pos_server.dbo.TR_ST_DETAIL AS d WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_ST_HEADER AS h WITH (NOLOCK)
                ON h.NO_TR_ST_HEADER = d.NO_TR_ST_HEADER
            INNER JOIN @base AS b ON b.Store_ID = h.ID_Store_OUT AND b.PLU = d.PLU
            WHERE h.Tgl_Out >= @floor
              AND LEFT(d.PLU, 2) <> '01'
            GROUP BY h.ID_Store_OUT, d.PLU;

            INSERT INTO @adj (Store_ID, PLU, qty)
            SELECT a.STORE_ID, a.PLU, SUM(CAST(ISNULL(a.QTY, 0) AS decimal(19, 4)))
            FROM pos_server.dbo.TR_ST_ADJUSMENT AS a WITH (NOLOCK)
            INNER JOIN @base AS b ON b.Store_ID = a.STORE_ID AND b.PLU = a.PLU
            WHERE a.TGL_ADJUST >= @floor
            GROUP BY a.STORE_ID, a.PLU;

            INSERT INTO @sales (Store_ID, PLU, qty)
            SELECT h.ID_Store, d.PLU, SUM(CAST(ISNULL(d.QTY, 0) AS decimal(19, 4)))
            FROM pos_server.dbo.TR_SALES_DETAIL AS d WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_HEADER AS h WITH (NOLOCK)
                ON h.ID_TR_SALES_HEADER = d.ID_TR_SALES_HEADER
            INNER JOIN @base AS b ON b.Store_ID = h.ID_Store AND b.PLU = d.PLU
            WHERE h.Status_Transaksi = 1
              AND h.Tanggal_Transaksi >= @floor
              AND LEFT(d.PLU, 2) <> '01'
            GROUP BY h.ID_Store, d.PLU;

            INSERT INTO @refund (Store_ID, PLU, qty)
            SELECT rh.ID_STORE, rd.PLU, SUM(CAST(ISNULL(rd.QTY, 0) AS decimal(19, 4)))
            FROM pos_server.dbo.TR_SALES_REFUND AS rh WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL AS rd WITH (NOLOCK)
                ON rd.ID_TR_SALES_REFUND = rh.ID_TR_SALES_REFUND
            INNER JOIN @base AS b ON b.Store_ID = rh.ID_STORE AND b.PLU = rd.PLU
            WHERE rh.TGL_REFUND >= @floor
              AND LEFT(rd.PLU, 2) <> '01'
            GROUP BY rh.ID_STORE, rd.PLU;
        END;

        ;WITH calc AS (
            SELECT
                s.Store_Brand_ID AS brand,
                b.Store_ID AS store_id,
                ISNULL(s.STORE_KOTA, '') AS kota,
                LTRIM(RTRIM(ISNULL(s.STORE_PROVINSI, ''))) AS provinsi,
                ISNULL(s.STORE_PULAU, '') AS pulau,
                ISNULL(p.ARTICLE, '') AS article,
                b.PLU AS plu,
                CAST(
                    b.Z
                    + ISNULL(i.qty, 0)
                    + ISNULL(j.qty, 0)
                    + ISNULL(rf.qty, 0)
                    - ISNULL(o.qty, 0)
                    - ISNULL(sl.qty, 0)
                AS decimal(18, 4)) AS qty,
                LTRIM(RTRIM(ISNULL(p.UKURAN, ''))) AS size,
                LTRIM(RTRIM(ISNULL(p.WARNA, ''))) AS color
            FROM @base AS b
            LEFT JOIN pos_server.dbo.DT_Store AS s WITH (NOLOCK) ON s.Store_ID = b.Store_ID
            LEFT JOIN pos_server.dbo.DT_PLU AS p WITH (NOLOCK) ON p.PLU = b.PLU
            LEFT JOIN @st_in AS i ON i.Store_ID = b.Store_ID AND i.PLU = b.PLU
            LEFT JOIN @st_out AS o ON o.Store_ID = b.Store_ID AND o.PLU = b.PLU
            LEFT JOIN @adj AS j ON j.Store_ID = b.Store_ID AND j.PLU = b.PLU
            LEFT JOIN @sales AS sl ON sl.Store_ID = b.Store_ID AND sl.PLU = b.PLU
            LEFT JOIN @refund AS rf ON rf.Store_ID = b.Store_ID AND rf.PLU = b.PLU
        )
        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL((
                       SELECT brand, store_id, kota, provinsi, pulau, article, plu, qty, size, color
                       FROM calc
                       ORDER BY brand, article, plu
                       FOR JSON PATH
                   ), '[]')) AS data,
                   ISNULL((SELECT SUM(qty) FROM calc), 0) AS total_qty,
                   CONVERT(varchar(10), @close, 23) AS close_date,
                   CONVERT(varchar(10), @floor, 23) AS movement_from
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
