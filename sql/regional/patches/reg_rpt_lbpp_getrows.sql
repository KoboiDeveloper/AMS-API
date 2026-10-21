/*
  LBPP By Brand (REG2) — port xsp_lbtp_by_brand_getrows.
  Lbpp (store total) removed permanently.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_lbpp_brand_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_lbpp_brand_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_lbpp_brand_getrows
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
        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), ''))));
        IF @from IS NULL OR @to IS NULL OR @brand IN ('','0','ALL')
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'brand, from_date, to_date wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        DECLARE @toX date = DATEADD(DAY, 1, @to);

        ;WITH x AS (
            SELECT dss.PLU, dss.Price, dss.HPP, SUM(dss.A) AS A, 0 AS ST_IN, 0 AS TRADE_IN, 0 AS ST_OUT, 0 AS TRADE_OUT, 0 AS SALES, 0 AS ADJ
            FROM pos_server.dbo.DT_STOCK_SUMMARY dss WITH (NOLOCK)
            INNER JOIN pos_server.dbo.DT_STORE ds WITH (NOLOCK) ON ds.Store_ID = dss.Store_ID
            WHERE ds.Store_Brand_ID = @brand AND dss.TANGGAL >= @from AND dss.TANGGAL < DATEADD(DAY, 1, @from)
            GROUP BY dss.PLU, dss.Price, dss.HPP
            UNION ALL
            SELECT dss.PLU, dss.Price, dss.HPP, 0, SUM(dss.ST_IN), SUM(dss.TRADE_IN), SUM(dss.ST_OUT), SUM(dss.TRADE_OUT), SUM(dss.SALES), SUM(dss.ADJ)
            FROM pos_server.dbo.DT_STOCK_SUMMARY dss WITH (NOLOCK)
            INNER JOIN pos_server.dbo.DT_STORE ds WITH (NOLOCK) ON ds.Store_ID = dss.Store_ID
            WHERE ds.Store_Brand_ID = @brand AND dss.TANGGAL >= @from AND dss.TANGGAL < @toX
            GROUP BY dss.PLU, dss.Price, dss.HPP
        )
        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           PLU, MAX(Price) AS Price, MAX(HPP) AS HPP,
                           SUM(A) AS A, SUM(A * HPP) AS HPP_A, SUM(A * Price) AS PRICE_A,
                           SUM(ST_IN) AS ST_IN, SUM(ST_IN * HPP) AS HPP_ST_IN, SUM(ST_IN * Price) AS PRICE_ST_IN,
                           SUM(TRADE_IN) AS TRADE_IN, SUM(TRADE_IN * HPP) AS HPP_TRADE_IN, SUM(TRADE_IN * Price) AS PRICE_TRADE_IN,
                           SUM(ST_OUT) AS ST_OUT, SUM(ST_OUT * HPP) AS HPP_ST_OUT, SUM(ST_OUT * Price) AS PRICE_ST_OUT,
                           SUM(TRADE_OUT) AS TRADE_OUT, SUM(TRADE_OUT * HPP) AS HPP_TRADE_OUT, SUM(TRADE_OUT * Price) AS PRICE_TRADE_OUT,
                           SUM(SALES) AS SALES, SUM(SALES * HPP) AS HPP_SALES, SUM(SALES * Price) AS PRICE_SALES,
                           SUM(ADJ) AS ADJ, SUM(ADJ * HPP) AS HPP_ADJ, SUM(ADJ * Price) AS PRICE_ADJ,
                           SUM(A)+SUM(ST_IN)+SUM(TRADE_IN)-SUM(ST_OUT)-SUM(TRADE_OUT)-SUM(SALES)+SUM(ADJ) AS Z,
                           SUM(A*HPP)+SUM(ST_IN*HPP)+SUM(TRADE_IN*HPP)-SUM(ST_OUT*HPP)-SUM(TRADE_OUT*HPP)-SUM(SALES*HPP)+SUM(ADJ*HPP) AS HPP_Z,
                           SUM(A*Price)+SUM(ST_IN*Price)+SUM(TRADE_IN*Price)-SUM(ST_OUT*Price)-SUM(TRADE_OUT*Price)-SUM(SALES*Price)+SUM(ADJ*Price) AS PRICE_Z
                       FROM x
                       GROUP BY PLU
                       HAVING SUM(A)+SUM(ST_IN)+SUM(TRADE_IN)+SUM(ST_OUT)+SUM(TRADE_OUT)+SUM(SALES)+SUM(ADJ) <> 0
                       ORDER BY PLU
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
