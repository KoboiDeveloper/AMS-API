/*
  Cek Setoran (REG2) — ASP parity module/Rpt/rekonsiliasireg.aspx (REG2 / brand path)
  Legacy: pos_server.dbo.XSP_DT_FN_BATCH_Rekonsil_GETROWS
  Filters: Brand, From/To date
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_cek_setoran_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_cek_setoran_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_cek_setoran_getrows
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

        DECLARE @brand varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), NULLIF(@p_brand,''), NULLIF(@p_brand_filter,'')), 'ALL')));
        IF @brand IN ('','0') SET @brand = 'ALL';

        CREATE TABLE #r (
            No_Urut bigint NULL,
            Store_ID varchar(200) NULL,
            KODE varchar(20) NULL,
            Tgl varchar(30) NULL,
            Status_SYNC varchar(20) NULL,
            pu nvarchar(50) NULL,
            ti money NULL,
            IMAGE_1 varchar(300) NULL,
            IMAGE_2 varchar(300) NULL,
            IMAGE_3 varchar(300) NULL,
            IMAGE_4 varchar(300) NULL,
            NOMINAL_BNI money NULL,
            NOMINAL_MANDIRI money NULL,
            NOMINAL_DIRECTSELLING money NULL,
            important_star_style varchar(80) NULL,
            important_tooltip varchar(80) NULL,
            STATUS_CHECKED varchar(40) NULL,
            btn_type varchar(80) NULL,
            STATUS_PEMBAYARAN varchar(80) NULL,
            TRX_AMOUNT nvarchar(50) NULL,
            va_status_class varchar(80) NULL,
            [font-color] varchar(200) NULL,
            display_adjust varchar(40) NULL,
            kurang_bayar nvarchar(50) NULL
        );

        INSERT INTO #r
        EXEC pos_server.dbo.XSP_DT_FN_BATCH_Rekonsil_GETROWS
            @p_from_date = @from,
            @p_to_date = @to,
            @p_brand = @brand;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           r.No_Urut AS NO_URUT,
                           r.Tgl AS TGL,
                           r.Store_ID AS STORE_ID,
                           r.KODE AS KODE,
                           ISNULL(r.pu, '0') AS PU,
                           ISNULL(r.TRX_AMOUNT, '0') AS TRX_AMOUNT,
                           ISNULL(r.STATUS_PEMBAYARAN, '') AS STATUS_PEMBAYARAN,
                           ISNULL(r.va_status_class, '') AS VA_STATUS_CLASS,
                           ISNULL(r.[font-color], '') AS FONT_COLOR,
                           ISNULL(r.STATUS_CHECKED, '') AS STATUS_CHECKED,
                           ISNULL(r.kurang_bayar, '0') AS KURANG_BAYAR
                       FROM #r r
                       ORDER BY r.Tgl DESC, r.Store_ID
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
