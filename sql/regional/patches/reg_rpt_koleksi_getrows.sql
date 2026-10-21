/*
  Koleksi export (REG2) — NEW SP on RBACESS.
  Parity: CocaCola.aspx / xsp_get_koleksi_sales_getrows (no EXEC of legacy SPs).
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_koleksi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_koleksi_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_koleksi_getrows
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
    BEGIN TRY
        DECLARE @from_dt datetime = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date,''))),'') AS datetime);
        DECLARE @to_dt datetime = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date,''))),'') AS datetime);
        DECLARE @tipe varchar(10) = UPPER(LTRIM(RTRIM(ISNULL(@p_tipe,'ARTICLE'))));
        DECLARE @article varchar(80) = LTRIM(RTRIM(ISNULL(@p_article,'')));
        DECLARE @koleksi varchar(80) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_kategori,''), NULLIF(@p_brand_filter,''), @p_keywords), '')));
        DECLARE @v_from_date datetime;
        DECLARE @v_to_date_excl datetime;
        IF @from_dt IS NULL OR @to_dt IS NULL OR @koleksi = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'koleksi (kategori), from_date, to_date wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #out (
            STORE varchar(50) NULL, ARTICLE varchar(80) NULL, PLU varchar(80) NULL,
            DESKRIPSI varchar(200) NULL, QTY float NULL, HARGA float NULL, NET_SALES float NULL
        );

        IF UPPER(@koleksi) = 'COCA COLA'
        BEGIN
            IF @tipe = 'ARTICLE'
                INSERT INTO #out (ARTICLE, PLU, DESKRIPSI, QTY, HARGA, NET_SALES)
                SELECT c.ARTICLE, a.PLU, c.DESKRIPSI, SUM(a.QTY), c.HARGA, SUM(a.Net)
                FROM pos_server.dbo.TR_SALES_DETAIL a WITH (NOLOCK)
                INNER JOIN pos_server.dbo.TR_SALES_HEADER b WITH (NOLOCK) ON a.ID_TR_SALES_HEADER = b.ID_TR_SALES_HEADER
                INNER JOIN pos_server.dbo.DT_PLU c WITH (NOLOCK) ON a.PLU = c.PLU
                WHERE a.ARTICLE IN ('LIN000334C','LIN000336C','LIN000341C','LIN000331C','LIN000337C','LIN000333C','LIN000355C','LIN000338C','LIN000340C','LIN000368C','LIN000342C','LIN000371C','L03000126C','L03000120C','L03000123C','L03000132C','LIN000456C','LIN000457C','LIN000401C','LIN000462C','L03000179C','L03000164C','L03000162C','L03000161C','L03000160C','LIN000458C','LIN000463C','LIN000461C','LIN000467C','L03000182C','LIN000469C','LIN000488C','L03000177C','L03000188C','L03000183C','LIN000479C','LIN000464C','L03000178C','I31000115C','LIN001014C','LIN000846C','L03000394C','LIN001011C','L03000387C')
                  AND (@article = '' OR c.ARTICLE LIKE '%' + @article + '%')
                  AND DATEDIFF(DAY, b.tanggal_transaksi, @from_dt) <= 0 AND DATEDIFF(DAY, b.tanggal_transaksi, @to_dt) >= 0
                  AND a.ID_Store <> '7777'
                GROUP BY c.ARTICLE, a.PLU, c.DESKRIPSI, c.HARGA;
            ELSE
                INSERT INTO #out (STORE, ARTICLE, PLU, DESKRIPSI, QTY, HARGA, NET_SALES)
                SELECT b.ID_Store, c.ARTICLE, a.PLU, c.DESKRIPSI, SUM(a.QTY), c.HARGA, SUM(a.Net)
                FROM pos_server.dbo.TR_SALES_DETAIL a WITH (NOLOCK)
                INNER JOIN pos_server.dbo.TR_SALES_HEADER b WITH (NOLOCK) ON a.ID_TR_SALES_HEADER = b.ID_TR_SALES_HEADER
                INNER JOIN pos_server.dbo.DT_PLU c WITH (NOLOCK) ON a.PLU = c.PLU
                WHERE a.ARTICLE IN ('LIN000334C','LIN000336C','LIN000341C','LIN000331C','LIN000337C','LIN000333C','LIN000355C','LIN000338C','LIN000340C','LIN000368C','LIN000342C','LIN000371C','L03000126C','L03000120C','L03000123C','L03000132C','LIN000456C','LIN000457C','LIN000401C','LIN000462C','L03000179C','L03000164C','L03000162C','L03000161C','L03000160C','LIN000458C','LIN000463C','LIN000461C','LIN000467C','L03000182C','LIN000469C','LIN000488C','L03000177C','L03000188C','L03000183C','LIN000479C','LIN000464C','L03000178C','I31000115C','LIN001014C','LIN000846C','L03000394C','LIN001011C','L03000387C')
                  AND (@article = '' OR c.ARTICLE LIKE '%' + @article + '%')
                  AND DATEDIFF(DAY, b.tanggal_transaksi, @from_dt) <= 0 AND DATEDIFF(DAY, b.tanggal_transaksi, @to_dt) >= 0
                  AND a.ID_Store <> '7777'
                GROUP BY b.ID_Store, c.ARTICLE, a.PLU, c.DESKRIPSI, c.HARGA;
        END
        ELSE
        BEGIN
            IF @to_dt < @from_dt
            BEGIN
                SET @bitparam = (SELECT '4002500' AS responseCode, 'to_date tidak boleh lebih kecil dari from_date.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
                RETURN;
            END;
            SET @v_from_date = DATEADD(DAY, DATEDIFF(DAY, 0, @from_dt), 0);
            SET @v_to_date_excl = DATEADD(DAY, DATEDIFF(DAY, 0, @to_dt) + 1, 0);
            IF OBJECT_ID('tempdb..#koleksi_net') IS NOT NULL DROP TABLE #koleksi_net;

            ;WITH MARKETPLACE_STATUS AS
(
    SELECT
         mar.ID_TR_SALES_HEADER
        ,MAX(mar.TGL_REALISASI) AS TGL_REALISASI
        ,MAX
         (
             CASE
                 WHEN mar.TGL_REALISASI IS NULL THEN 1
                 ELSE 0
             END
         ) AS ADA_BELUM_REALISASI
    FROM pos_server.dbo.MARKETPLACE_AR mar
    GROUP BY
        mar.ID_TR_SALES_HEADER
),

VALID_ARTICLE AS
(
    SELECT DISTINCT
        ta.NO_ARTICLE COLLATE DATABASE_DEFAULT AS ARTICLE
    FROM SISPRO_SCM.dbo.TR_ARTICLE ta
    INNER JOIN SISPRO_SCM.dbo.DT_BRAND db
        ON db.ID_BRAND = ta.ID_BRAND
    WHERE ta.THEME = @koleksi
      
),

MUTASI_SALES AS
(
    /* =====================================================
       SALES POSITIF

       OFFLINE:
       - Tidak memiliki referensi pos_server.dbo.MARKETPLACE_AR
       - Periode memakai TANGGAL_TRANSAKSI

       ONLINE:
       - Memiliki referensi pos_server.dbo.MARKETPLACE_AR
       - Sudah direalisasi
       - Periode memakai TGL_REALISASI
       ===================================================== */
    SELECT
         b.ID_STORE AS STORE
        ,c.ARTICLE
        ,a.PLU
        ,c.DESKRIPSI
        ,SUM(ISNULL(a.QTY, 0)) AS QTY
        ,c.HARGA
        ,SUM(ISNULL(a.NET, 0)) AS NET_SALES
    FROM pos_server.dbo.TR_SALES_DETAIL a
    INNER JOIN pos_server.dbo.TR_SALES_HEADER b
        ON b.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER
    INNER JOIN pos_server.dbo.DT_PLU c
        ON c.PLU = a.PLU
    INNER JOIN VALID_ARTICLE va
        ON va.ARTICLE =
           a.ARTICLE COLLATE DATABASE_DEFAULT
    LEFT JOIN MARKETPLACE_STATUS mp
        ON mp.ID_TR_SALES_HEADER = b.ID_TR_SALES_HEADER
    WHERE b.ID_STORE <> '7777'
      AND b.ID_STORE NOT LIKE 'DS%'

      AND
      (
          @article = ''
          OR c.ARTICLE LIKE '%' + @article + '%'
      )

      AND
      (
          /* Offline memakai tanggal transaksi */
          (
              mp.ID_TR_SALES_HEADER IS NULL
              AND b.TANGGAL_TRANSAKSI >= @v_from_date
              AND b.TANGGAL_TRANSAKSI <  @v_to_date_excl
          )

          OR

          /* Online memakai tanggal realisasi */
          (
              mp.ID_TR_SALES_HEADER IS NOT NULL
              AND mp.ADA_BELUM_REALISASI = 0
              AND mp.TGL_REALISASI >= @v_from_date
              AND mp.TGL_REALISASI <  @v_to_date_excl
          )
      )

    GROUP BY
         b.ID_STORE
        ,c.ARTICLE
        ,a.PLU
        ,c.DESKRIPSI
        ,c.HARGA


    UNION ALL


    /* =====================================================
       REFUND NEGATIF

       Refund masuk ke periode berdasarkan TGL_REFUND.
       QTY dan NET dibuat negatif agar mengurangi sales.
       ===================================================== */
    SELECT
         rh.ID_STORE AS STORE
        ,c.ARTICLE
        ,rd.PLU
        ,c.DESKRIPSI
        ,-SUM(ISNULL(rd.QTY, 0)) AS QTY
        ,c.HARGA
        ,-SUM(ISNULL(rd.NET, 0)) AS NET_SALES
    FROM pos_server.dbo.TR_SALES_REFUND rh
    INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL rd
        ON rd.ID_TR_SALES_REFUND = rh.ID_TR_SALES_REFUND
       AND rd.ID_TR_SALES_HEADER = rh.ID_TR_SALES_HEADER
    INNER JOIN pos_server.dbo.DT_PLU c
        ON c.PLU = rd.PLU
    INNER JOIN VALID_ARTICLE va
        ON va.ARTICLE =
           rd.ARTICLE COLLATE DATABASE_DEFAULT
    WHERE rh.TGL_REFUND >= @v_from_date
      AND rh.TGL_REFUND <  @v_to_date_excl

      AND rh.ID_STORE <> '7777'
      AND rh.ID_STORE NOT LIKE 'DS%'

      AND
      (
          @article = ''
          OR c.ARTICLE LIKE '%' + @article + '%'
      )

      /*
        Refund online yang transaksi asalnya belum
        direalisasi tidak ikut mengurangi sales.
      */
      AND NOT EXISTS
      (
          SELECT 1
          FROM pos_server.dbo.MARKETPLACE_AR mar
          WHERE mar.ID_TR_SALES_HEADER =
                rh.ID_TR_SALES_HEADER
            AND mar.TGL_REALISASI IS NULL
      )

    GROUP BY
         rh.ID_STORE
        ,c.ARTICLE
        ,rd.PLU
        ,c.DESKRIPSI
        ,c.HARGA
)

SELECT
     STORE
    ,ARTICLE
    ,PLU
    ,DESKRIPSI
    ,QTY
    ,HARGA
    ,NET_SALES
INTO #koleksi_net
FROM MUTASI_SALES;


/* =========================================================
   OUTPUT BERDASARKAN ARTICLE
   ========================================================= */
            IF @tipe = 'ARTICLE'
                INSERT INTO #out (STORE, ARTICLE, PLU, DESKRIPSI, QTY, HARGA, NET_SALES)
                SELECT STORE, ARTICLE, PLU, DESKRIPSI, SUM(QTY), HARGA, SUM(NET_SALES)
                FROM #koleksi_net
                GROUP BY STORE, ARTICLE, PLU, DESKRIPSI, HARGA
                HAVING SUM(QTY) <> 0 OR SUM(NET_SALES) <> 0;
            ELSE
                INSERT INTO #out (STORE, ARTICLE, PLU, DESKRIPSI, QTY, HARGA, NET_SALES)
                SELECT STORE, ARTICLE, PLU, DESKRIPSI, SUM(QTY), HARGA, SUM(NET_SALES)
                FROM #koleksi_net
                GROUP BY STORE, ARTICLE, PLU, DESKRIPSI, HARGA
                HAVING SUM(QTY) <> 0 OR SUM(NET_SALES) <> 0;

            DROP TABLE #koleksi_net;
        END

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((SELECT * FROM #out FOR JSON PATH)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        DROP TABLE #out;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#out') IS NOT NULL DROP TABLE #out;
        IF OBJECT_ID('tempdb..#koleksi_net') IS NOT NULL DROP TABLE #koleksi_net;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
