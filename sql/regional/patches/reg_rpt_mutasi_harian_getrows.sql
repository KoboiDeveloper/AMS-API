/*
  Mutasi Harian (REG2) — port xsp_get_mutasi_harian_getrows (mutasi_harian_REG.aspx).
  NEW SP only on RBACESS; queries pos_server.dbo.*; never EXEC legacy.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_mutasi_harian_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_mutasi_harian_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_mutasi_harian_getrows
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
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), ''))));
        IF @from IS NULL OR @to IS NULL OR @store IN ('','0','ALL')
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'store, from_date, to_date wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           Store_ID,
                           CONVERT(varchar(10), TANGGAL, 23) AS TANGGAL,
                           SUM(A) AS A,
                           SUM(ST_IN) AS ST_IN,
                           SUM(TRADE_IN) AS TRADE_IN,
                           SUM(ST_OUT) AS ST_OUT,
                           SUM(TRADE_OUT) AS TRADE_OUT,
                           SUM(SALES) AS SALES,
                           SUM(ADJ) AS ADJ,
                           SUM(Z) AS Z,
                           SUM(AA) AS AA,
                           SUM(Z) - SUM(AA) AS SELISIH
                       FROM (
                           SELECT Store_ID, TANGGAL,
                                  SUM(A) AS A, SUM(ST_IN) AS ST_IN, SUM(TRADE_IN) AS TRADE_IN,
                                  SUM(ST_OUT) AS ST_OUT, SUM(TRADE_OUT) AS TRADE_OUT,
                                  SUM(SALES) AS SALES, SUM(ADJ) AS ADJ, SUM(Z) AS Z, 0 AS AA
                           FROM pos_server.dbo.DT_STOCK_SUMMARY WITH (NOLOCK)
                           WHERE Store_ID = @store
                             AND TANGGAL >= @from AND TANGGAL < DATEADD(DAY, 1, @to)
                           GROUP BY Store_ID, TANGGAL
                           UNION ALL
                           SELECT Store_ID, DATEADD(DAY, -1, TANGGAL) AS TANGGAL,
                                  0, 0, 0, 0, 0, 0, 0, 0, SUM(A) AS AA
                           FROM pos_server.dbo.DT_STOCK_SUMMARY WITH (NOLOCK)
                           WHERE Store_ID = @store
                             AND TANGGAL >= DATEADD(DAY, 1, @from) AND TANGGAL < DATEADD(DAY, 2, @to)
                           GROUP BY Store_ID, TANGGAL
                       ) AS X
                       GROUP BY Store_ID, TANGGAL
                       ORDER BY TANGGAL
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
