/*
  Promosi (REG2) — xsp_promosi_view_rahmat_getrows
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_promosi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_promosi_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_promosi_getrows
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
        DECLARE @brand_id varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand_id IN ('','0') SET @brand_id = 'ALL';
        DECLARE @store_id varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store_id IN ('','0') SET @store_id = 'ALL';
        DECLARE @plu varchar(20) = ISNULL(NULLIF(LTRIM(RTRIM(@p_plu)),''), '');

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           dp.NO_URUT,
                           dp.ID_DT_PROMOSI,
                           dp.ID_STORE,
                           dp.PLU,
                           dp.KETERANGAN,
                           dp.QTY,
                           dp.POT_HRG,
                           dp.KELIPATAN,
                           FORMAT(dp.START_DATE, 'yyyy-MM-dd') AS START_DATE,
                           FORMAT(dp.END_DATE, 'yyyy-MM-dd') AS END_DATE,
                           dp.Status_Kirim AS STATUS_KIRIM
                       FROM pos_server.dbo.DT_PROMOSI AS dp WITH (NOLOCK)
                       INNER JOIN pos_server.dbo.DT_Store AS ds WITH (NOLOCK)
                           ON ds.Store_ID = dp.ID_STORE
                       WHERE (@plu = '' OR dp.PLU LIKE '%' + @plu + '%')
                         AND DATEDIFF(DAY, dp.START_DATE, @from) <= 0
                         AND DATEDIFF(DAY, dp.START_DATE, @to) >= 0
                         AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
                         AND (@store_id = 'ALL' OR dp.ID_STORE = @store_id)
                       ORDER BY dp.ID_STORE, dp.PLU, dp.START_DATE DESC
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
