/*
  Last Stock (REG2) — ASP parity Rpt_Last_stock.aspx
  Dual grids via @p_tipe TOTAL | DETAIL
  Calls legacy POS SPs (open batch day = live txs, not only DT_STOCK_SUMMARY):
    xsp_rpt_last_stock_p_last_batch_total_getrows
    xsp_rpt_last_stock_p_last_batch_getrows
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_last_stock_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_last_stock_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_last_stock_getrows
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
        DECLARE @tgl date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_from_date,''), @p_tgl),''))),'') AS date);
        IF @tgl IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'date (from_date / last date) wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), ''))));
        IF @store IN ('','0','ALL')
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'Store wajib dipilih.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), ''))));
        IF @brand <> '' AND @brand NOT IN ('0','ALL')
           AND NOT EXISTS (
               SELECT 1 FROM pos_server.dbo.DT_STORE ds WITH (NOLOCK)
               WHERE ds.Store_ID = @store AND ds.Store_Brand_ID = @brand
           )
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'Store tidak cocok dengan Brand.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @article varchar(80) = LTRIM(RTRIM(ISNULL(@p_article, '')));
        DECLARE @mode varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(@p_tipe, 'TOTAL'))));
        IF @mode IN ('','0','1') SET @mode = 'TOTAL';
        IF @mode IN ('2','SALES','DETAIL') SET @mode = 'DETAIL';

        DECLARE @batch varchar(32) = CONVERT(varchar(10), @tgl, 23);

        IF @mode = 'TOTAL'
        BEGIN
            CREATE TABLE #tot (
                Store_ID varchar(50) NULL,
                A decimal(19,4) NULL, ST_IN decimal(19,4) NULL, TRADE_IN decimal(19,4) NULL,
                ST_OUT decimal(19,4) NULL, TRADE_OUT decimal(19,4) NULL, SALES decimal(19,4) NULL,
                ADJ decimal(19,4) NULL, Z decimal(19,4) NULL,
                mA decimal(19,4) NULL, mST_IN decimal(19,4) NULL, mTRADE_IN decimal(19,4) NULL,
                mST_OUT decimal(19,4) NULL, mTRADE_OUT decimal(19,4) NULL, mSales decimal(19,4) NULL,
                mADJ decimal(19,4) NULL, mZ decimal(19,4) NULL,
                xA decimal(19,4) NULL, xST_IN decimal(19,4) NULL, xTRADE_IN decimal(19,4) NULL,
                xST_OUT decimal(19,4) NULL, xTRADE_OUT decimal(19,4) NULL, xSALES decimal(19,4) NULL,
                xADJ decimal(19,4) NULL, xZ decimal(19,4) NULL
            );

            INSERT INTO #tot
            EXEC pos_server.dbo.xsp_rpt_last_stock_p_last_batch_total_getrows
                @p_xidstore = @store,
                @p_xbatch = @batch;

            SELECT @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT
                               t.Store_ID AS STORE_ID,
                               ISNULL(t.A,0) AS A,
                               ISNULL(t.xA,0) AS XA,
                               ISNULL(t.ST_IN,0) AS ST_IN,
                               ISNULL(t.xST_IN,0) AS XST_IN,
                               ISNULL(t.TRADE_IN,0) AS TRADE_IN,
                               ISNULL(t.xTRADE_IN,0) AS XTRADE_IN,
                               ISNULL(t.ST_OUT,0) AS ST_OUT,
                               ISNULL(t.xST_OUT,0) AS XST_OUT,
                               ISNULL(t.SALES,0) AS SALES,
                               ISNULL(t.xSALES,0) AS XSALES,
                               ISNULL(t.ADJ,0) AS ADJ,
                               ISNULL(t.xADJ,0) AS XADJ,
                               ISNULL(t.Z,0) AS Z,
                               ISNULL(t.xZ,0) AS XZ
                           FROM #tot t
                           ORDER BY t.Store_ID
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            DROP TABLE #tot;
        END
        ELSE
        BEGIN
            CREATE TABLE #det (
                Waktu_Urut datetime NULL,
                TANGGAL varchar(32) NULL,
                Store_ID varchar(50) NULL,
                PLU varchar(50) NULL,
                PRICE decimal(19,4) NULL,
                HPP decimal(19,4) NULL,
                A decimal(19,4) NULL, ST_IN decimal(19,4) NULL, TRADE_IN decimal(19,4) NULL,
                ST_OUT decimal(19,4) NULL, TRADE_OUT decimal(19,4) NULL, SALES decimal(19,4) NULL,
                ADJ decimal(19,4) NULL, Z decimal(19,4) NULL,
                mA decimal(19,4) NULL, mST_IN decimal(19,4) NULL, mTRADE_IN decimal(19,4) NULL,
                mST_OUT decimal(19,4) NULL, mTRADE_OUT decimal(19,4) NULL, mSales decimal(19,4) NULL,
                mADJ decimal(19,4) NULL, mZ decimal(19,4) NULL,
                xA decimal(19,4) NULL, xST_IN decimal(19,4) NULL, xTRADE_IN decimal(19,4) NULL,
                xST_OUT decimal(19,4) NULL, xTRADE_OUT decimal(19,4) NULL, xSALES decimal(19,4) NULL,
                xADJ decimal(19,4) NULL, xZ decimal(19,4) NULL
            );

            INSERT INTO #det
            EXEC pos_server.dbo.xsp_rpt_last_stock_p_last_batch_getrows
                @p_xidstore = @store,
                @p_xbatch = @batch,
                @p_article = @article;

            SELECT @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT
                               CONVERT(varchar(10), TRY_CAST(d.TANGGAL AS date), 23) AS TANGGAL,
                               d.Store_ID AS STORE_ID,
                               d.PLU,
                               ISNULL(d.PRICE,0) AS PRICE,
                               ISNULL(d.HPP,0) AS HPP,
                               ISNULL(d.A,0) AS A,
                               ISNULL(d.mA,0) AS MA,
                               ISNULL(d.xA,0) AS XA,
                               ISNULL(d.ST_IN,0) AS ST_IN,
                               ISNULL(d.mST_IN,0) AS MST_IN,
                               ISNULL(d.xST_IN,0) AS XST_IN,
                               ISNULL(d.TRADE_IN,0) AS TRADE_IN,
                               ISNULL(d.mTRADE_IN,0) AS MTRADE_IN,
                               ISNULL(d.xTRADE_IN,0) AS XTRADE_IN,
                               ISNULL(d.ST_OUT,0) AS ST_OUT,
                               ISNULL(d.mST_OUT,0) AS MST_OUT,
                               ISNULL(d.xST_OUT,0) AS XST_OUT,
                               ISNULL(d.TRADE_OUT,0) AS TRADE_OUT,
                               ISNULL(d.mTRADE_OUT,0) AS MTRADE_OUT,
                               ISNULL(d.xTRADE_OUT,0) AS XTRADE_OUT,
                               ISNULL(d.SALES,0) AS SALES,
                               ISNULL(d.mSales,0) AS MSALES,
                               ISNULL(d.xSALES,0) AS XSALES,
                               ISNULL(d.ADJ,0) AS ADJ,
                               ISNULL(d.mADJ,0) AS MADJ,
                               ISNULL(d.xADJ,0) AS XADJ,
                               ISNULL(d.Z,0) AS Z,
                               ISNULL(d.mZ,0) AS MZ,
                               ISNULL(d.xZ,0) AS XZ
                           FROM #det d
                           WHERE ISNULL(d.A,0) <> 0 OR ISNULL(d.ST_IN,0) <> 0 OR ISNULL(d.TRADE_IN,0) <> 0
                              OR ISNULL(d.ST_OUT,0) <> 0 OR ISNULL(d.TRADE_OUT,0) <> 0 OR ISNULL(d.SALES,0) <> 0
                              OR ISNULL(d.ADJ,0) <> 0 OR ISNULL(d.Z,0) <> 0
                           ORDER BY d.PLU
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            DROP TABLE #det;
        END;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#tot') IS NOT NULL DROP TABLE #tot;
        IF OBJECT_ID('tempdb..#det') IS NOT NULL DROP TABLE #det;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* last-stock-date removed — use change date on Last Stock; last-stock-all → reg_rpt_last_stock_all_getrows.sql */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_last_stock_date_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_last_stock_date_getrows;
GO
