/*
  Voucher Imlek (REG2) — ASP parity module/Tools/voucher_imlek_rpt.aspx
  Rewritten with brand/store/year push-down (legacy xsp_get_voucher_imlek_header no filters).
  Detail: patches/reg_rpt_voucher_imlek_detail_getrows.sql
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_voucher_imlek_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_voucher_imlek_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_voucher_imlek_getrows
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
        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand IN ('', '0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id, NULLIF(@p_id_cabang,''), @p_cabang), 'ALL'))));
        IF @store IN ('', '0') SET @store = 'ALL';
        DECLARE @year varchar(10) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_year,''), NULLIF(@p_tahun,'')), 'ALL')));
        IF @year IN ('', '0') SET @year = 'ALL';
        DECLARE @yr int = TRY_CAST(@year AS int);

        IF @brand = 'ALL' AND @store = 'ALL' AND @year = 'ALL'
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'Pilih Brand, Store, dan/atau Tahun dulu.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           a.ID_PROMO AS ID_PROMO,
                           a.STORE_ID AS STORE_ID,
                           (a.TIPE_PROMO + ' - ' + a.NAMA_PROMO) AS TIPE,
                           CAST(ISNULL(a.NOMINAL, 0) AS float) AS NOMINAL
                       FROM pos_server.dbo.DT_PROMOSI_STORE a
                       LEFT JOIN pos_server.dbo.DT_Store s ON s.Store_ID = a.STORE_ID
                       WHERE (@brand = 'ALL' OR UPPER(LTRIM(RTRIM(ISNULL(s.Store_Brand_ID, '')))) = @brand)
                         AND (@store = 'ALL' OR UPPER(LTRIM(RTRIM(ISNULL(a.STORE_ID, '')))) = @store)
                         AND (@year = 'ALL' OR (@yr IS NOT NULL AND YEAR(a.START_DATE) = @yr))
                       ORDER BY a.STORE_ID, a.ID_PROMO
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
