/*
  Daily Stock Summary 2 (REG2) — ASP parity Daily_s_stock2.aspx (REG / roll 5|888)
  Digit (@p_plu): FULL | 3 | 1
  Mode  (@p_tipe): 1 DETAIL | 2 TOTAL | 3 GRAND TOTAL
  Article filter: @p_article (FULL DETAIL) / @p_article as p_plu on some TOTAL SPs
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_daily_stock_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_daily_stock_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_daily_stock_getrows
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
        DECLARE @from date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date,''))),'') AS date);
        DECLARE @to date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date,''))),'') AS date);
        IF @from IS NULL OR @to IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'from_date dan to_date wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        /* Legacy SPs expect yyyy/MM/dd */
        DECLARE @fromS varchar(20) = CONVERT(varchar(10), @from, 111);
        DECLARE @toS varchar(20) = CONVERT(varchar(10), @to, 111);

        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand IN ('','0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store IN ('','0') SET @store = 'ALL';

        DECLARE @digit varchar(10) = UPPER(LTRIM(RTRIM(ISNULL(@p_plu, 'FULL'))));
        IF @digit IN ('','0','PLU') SET @digit = 'FULL';
        DECLARE @mode varchar(10) = LTRIM(RTRIM(ISNULL(@p_tipe, '1')));
        IF @mode IN ('','0','DETAIL') SET @mode = '1';
        IF @mode IN ('TOTAL') SET @mode = '2';
        IF @mode IN ('GRAND','GRAND TOTAL') SET @mode = '3';

        DECLARE @gh varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,''), NULLIF(@p_actor_nik,'')),''))),'');
        DECLARE @article varchar(80) = LTRIM(RTRIM(ISNULL(@p_article, '')));

        CREATE TABLE #r (
            tanggal nvarchar(50) NULL,
            Store_ID varchar(50) NULL,
            PLU varchar(50) NULL,
            Price decimal(19,4) NULL,
            HPP decimal(19,4) NULL,
            A decimal(19,4) NULL,
            st_in decimal(19,4) NULL,
            trade_in decimal(19,4) NULL,
            st_out decimal(19,4) NULL,
            trade_out decimal(19,4) NULL,
            sales decimal(19,4) NULL,
            adj decimal(19,4) NULL,
            z decimal(19,4) NULL,
            ma decimal(19,4) NULL,
            mst_in decimal(19,4) NULL,
            mtrade_in decimal(19,4) NULL,
            mst_out decimal(19,4) NULL,
            mtrade_out decimal(19,4) NULL,
            msales decimal(19,4) NULL,
            madj decimal(19,4) NULL,
            mz decimal(19,4) NULL,
            xa decimal(19,4) NULL,
            xst_in decimal(19,4) NULL,
            xtrade_in decimal(19,4) NULL,
            xst_out decimal(19,4) NULL,
            xtrade_out decimal(19,4) NULL,
            xsales decimal(19,4) NULL,
            xadj decimal(19,4) NULL,
            xz decimal(19,4) NULL
        );

        /* REG routing — Daily_s_stock2.aspx.cs btnFilter_Click (roll 5|888) */
        IF @digit = 'FULL' AND @mode = '1'
        BEGIN
            INSERT INTO #r
            EXEC pos_server.dbo.XSP_RPT_DAILY_S_STOCK_S_b_GETROWS
                @p_from_date = @fromS, @p_to_date = @toS,
                @p_brand_id = @brand, @p_store_id = @store,
                @p_id_gh = @gh, @p_article = @article;
        END
        ELSE IF @digit = 'FULL' AND @mode = '2'
        BEGIN
            INSERT INTO #r
            EXEC pos_server.dbo.XSP_RPT_DAILY_S_STOCK_S_TOTAL_B_GETROWS
                @p_from_date = @fromS, @p_to_date = @toS,
                @p_brand_id = @brand, @p_store_id = @store,
                @p_s_brand_id = NULL, @p_s_store_id = NULL,
                @p_id_gh = @gh;
        END
        ELSE IF @digit = '3' AND @mode = '1'
        BEGIN
            INSERT INTO #r
            EXEC pos_server.dbo.XSP_RPT_DAILY_S_STOCK_S_PLU3_B_GETROWS
                @p_from_date = @fromS, @p_to_date = @toS,
                @p_brand_id = @brand, @p_store_id = @store,
                @p_s_brand_id = NULL, @p_s_store_id = NULL,
                @p_id_gh = @gh;
        END
        ELSE IF @digit = '3' AND @mode = '2'
        BEGIN
            INSERT INTO #r
            EXEC pos_server.dbo.XSP_RPT_DAILY_S_STOCK_S_PLU3_TOTAL_B_GETROWS
                @p_from_date = @fromS, @p_to_date = @toS,
                @p_brand_id = @brand, @p_store_id = @store,
                @p_s_brand_id = NULL, @p_s_store_id = NULL,
                @p_id_gh = @gh, @p_plu = @article;
        END
        ELSE IF @digit = '1' AND @mode = '1'
        BEGIN
            INSERT INTO #r
            EXEC pos_server.dbo.XSP_RPT_DAILY_S_STOCK_S_PLU1_B_GETROWS
                @p_from_date = @fromS, @p_to_date = @toS,
                @p_brand_id = @brand, @p_store_id = @store,
                @p_s_brand_id = NULL, @p_s_store_id = NULL,
                @p_id_gh = @gh;
        END
        ELSE IF @digit = '1' AND @mode = '2'
        BEGIN
            INSERT INTO #r
            EXEC pos_server.dbo.XSP_RPT_DAILY_S_STOCK_S_PLU1_reg_TOTAL_GETROWS
                @p_from_date = @fromS, @p_to_date = @toS,
                @p_brand_id = @brand, @p_store_id = @store,
                @p_s_brand_id = NULL, @p_s_store_id = NULL,
                @p_id_gh = @gh, @p_plu = @article;
        END
        ELSE /* mode 3 GRAND TOTAL (any digit) */
        BEGIN
            INSERT INTO #r
            EXEC pos_server.dbo.XSP_RPT_DAILY_S_STOCK_S_PLU1_GRAND_TOTAL_B_GETROWS
                @p_from_date = @fromS, @p_to_date = @toS,
                @p_brand_id = @brand, @p_store_id = @store,
                @p_s_brand_id = NULL, @p_s_store_id = NULL,
                @p_id_gh = @gh;
        END;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           r.Store_ID AS STORE_ID,
                           r.tanggal AS TANGGAL,
                           r.PLU AS PLU,
                           CAST(ISNULL(r.Price, 0) AS float) AS PRICE,
                           CAST(ISNULL(r.HPP, 0) AS float) AS HPP,
                           CAST(ISNULL(r.A, 0) AS float) AS A,
                           CAST(ISNULL(r.ma, 0) AS float) AS MA,
                           CAST(ISNULL(r.xa, 0) AS float) AS XA,
                           CAST(ISNULL(r.st_in, 0) AS float) AS ST_IN,
                           CAST(ISNULL(r.mst_in, 0) AS float) AS MST_IN,
                           CAST(ISNULL(r.xst_in, 0) AS float) AS XST_IN,
                           CAST(ISNULL(r.trade_in, 0) AS float) AS TRADE_IN,
                           CAST(ISNULL(r.mtrade_in, 0) AS float) AS MTRADE_IN,
                           CAST(ISNULL(r.xtrade_in, 0) AS float) AS XTRADE_IN,
                           CAST(ISNULL(r.st_out, 0) AS float) AS ST_OUT,
                           CAST(ISNULL(r.mst_out, 0) AS float) AS MST_OUT,
                           CAST(ISNULL(r.xst_out, 0) AS float) AS XST_OUT,
                           CAST(ISNULL(r.trade_out, 0) AS float) AS TRADE_OUT,
                           CAST(ISNULL(r.mtrade_out, 0) AS float) AS MTRADE_OUT,
                           CAST(ISNULL(r.xtrade_out, 0) AS float) AS XTRADE_OUT,
                           CAST(ISNULL(r.sales, 0) AS float) AS SALES,
                           CAST(ISNULL(r.msales, 0) AS float) AS MSALES,
                           CAST(ISNULL(r.xsales, 0) AS float) AS XSALES,
                           CAST(ISNULL(r.adj, 0) AS float) AS ADJ,
                           CAST(ISNULL(r.madj, 0) AS float) AS MADJ,
                           CAST(ISNULL(r.xadj, 0) AS float) AS XADJ,
                           CAST(ISNULL(r.z, 0) AS float) AS Z,
                           CAST(ISNULL(r.mz, 0) AS float) AS MZ,
                           CAST(ISNULL(r.xz, 0) AS float) AS XZ
                       FROM #r r
                       ORDER BY r.Store_ID, r.PLU, r.Price, r.HPP
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
