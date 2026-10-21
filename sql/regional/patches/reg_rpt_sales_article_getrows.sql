/*
  Sales By Article (REG2) — NEW SP on RBACESS (HRD-style @bitparam JSON).
  Parity with legacy xsp_get_sales_qty_by_article_getrows logic,
  but does NOT EXEC that SP — queries pos_server tables from RBACESS.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_sales_article_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_article_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_article_getrows
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
        DECLARE @from date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date, ''))), '') AS date);
        DECLARE @to date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date, ''))), '') AS date);
        IF @from IS NULL SET @from = CAST(GETDATE() AS date);
        IF @to IS NULL SET @to = @from;
        IF @from > @to
        BEGIN
            DECLARE @swap date = @from;
            SET @from = @to;
            SET @to = @swap;
        END;

        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand, ''), @p_brand), 'ALL'))));
        IF @brand IN ('', '0', 'ALL') SET @brand = 'ALL';

        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store, ''), @p_store_id), 'ALL')));
        IF @store IN ('', '0', 'all', 'ALL') SET @store = 'ALL';

        DECLARE @article varchar(80) = LTRIM(RTRIM(ISNULL(@p_article, '')));
        IF @article = '' SET @article = LTRIM(RTRIM(ISNULL(@p_keywords, '')));

        IF OBJECT_ID(N'pos_server.dbo.tr_sales_header', N'U') IS NULL
           OR OBJECT_ID(N'pos_server.dbo.TR_SALES_DETAIL', N'U') IS NULL
           OR OBJECT_ID(N'pos_server.dbo.dt_store', N'U') IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'pos_server sales tables not reachable from RBACESS' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* Same result shape as legacy: SOURCE | ARTICLE | qty */
        CREATE TABLE #out (
            SOURCE varchar(50) NOT NULL,
            ARTICLE varchar(80) NOT NULL,
            qty decimal(18, 2) NOT NULL
        );

        INSERT INTO #out (SOURCE, ARTICLE, qty)
        SELECT
              CASE WHEN @store = 'ALL' THEN @brand ELSE a.ID_Store END,
              b.ARTICLE,
              SUM(b.QTY)
        FROM pos_server.dbo.tr_sales_header AS a WITH (NOLOCK)
        INNER JOIN pos_server.dbo.TR_SALES_DETAIL AS b WITH (NOLOCK)
            ON b.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER
        INNER JOIN pos_server.dbo.dt_store AS c WITH (NOLOCK)
            ON c.Store_ID = a.ID_Store
        WHERE DATEDIFF(DAY, a.Tanggal_Transaksi, @from) <= 0
          AND DATEDIFF(DAY, a.Tanggal_Transaksi, @to) >= 0
          AND (CASE WHEN @brand = 'ALL' THEN c.Store_Brand_ID ELSE @brand END) = c.Store_Brand_ID
          AND (CASE WHEN @store = 'ALL' THEN a.ID_Store ELSE @store END) = a.ID_Store
          AND (CASE WHEN @article = '' THEN b.ARTICLE ELSE @article END) = b.ARTICLE
          AND b.QTY > 0
        GROUP BY
              CASE WHEN @store = 'ALL' THEN @brand ELSE a.ID_Store END,
              b.ARTICLE;

        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT o.SOURCE, o.ARTICLE, o.qty
                       FROM #out AS o
                       ORDER BY o.SOURCE, o.ARTICLE
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        DROP TABLE #out;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#out') IS NOT NULL DROP TABLE #out;
        SET @bitparam = (
            SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH
END
GO
