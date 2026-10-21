/* Absen List — parity with module/rpt/rpt_attendance.aspx / xsp_rpt_dt_absensi_ghreg_getrows */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_absen_list_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_absen_list_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_absen_list_getrows
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
        /* Legacy columns: STORE | USER NIK | EMPLOYEE | DATE | TIME IN | TIME OUT */
        DECLARE @kw varchar(200) = NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'');
        DECLARE @store varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(NULLIF(@p_id_store,''), NULLIF(@p_store_id,'')))), '');
        DECLARE @brand varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(NULLIF(@p_id_brand,''), NULLIF(@p_brand,'')))), '');
        IF @store IN ('ALL','all','0') SET @store = NULL;
        IF @brand IN ('ALL','all','0') SET @brand = NULL;
        DECLARE @from date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date,''))),'') AS date);
        DECLARE @to date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date,''))),'') AS date);
        IF @from IS NULL SET @from = DATEADD(day, -7, CAST(GETDATE() AS date));
        IF @to IS NULL SET @to = CAST(GETDATE() AS date);

        DECLARE @from_str varchar(20) = CONVERT(varchar(10), @from, 111);
        DECLARE @to_str varchar(20) = CONVERT(varchar(10), @to, 111);

        IF OBJECT_ID(N'pos_server.dbo.DT_ABSENSI', N'U') IS NOT NULL
           AND OBJECT_ID(N'pos_server.dbo.DT_User', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (2000)
                                  CONCAT(agg.Store_ID, '|', agg.User_NIK, '|', agg.Tanggal) AS id,
                                  agg.Store_ID AS store,
                                  agg.User_NIK AS nik,
                                  agg.USER_NAME AS employee_name,
                                  agg.Tanggal AS tanggal,
                                  agg.Masuk AS jam_masuk,
                                  agg.keluar AS jam_keluar
                           FROM (
                               SELECT
                                      DA.Store_ID,
                                      DA.User_NIK,
                                      DS.USER_NAME,
                                      CONVERT(varchar(10), DA.Waktu, 23) AS Tanggal,
                                      CONVERT(nvarchar(8), CAST(MIN(DA.Waktu) AS time), 108) AS Masuk,
                                      CONVERT(nvarchar(8), CAST(MAX(DA.Waktu) AS time), 108) AS keluar
                               FROM pos_server.dbo.DT_ABSENSI AS DA WITH (NOLOCK)
                               INNER JOIN pos_server.dbo.DT_User AS DS WITH (NOLOCK)
                                   ON DS.User_NIK = DA.User_NIK
                               WHERE DATEDIFF(DAY, DA.Waktu, @from_str) <= 0
                                 AND DATEDIFF(DAY, DA.Waktu, @to_str) >= 0
                                 /* Legacy xsp_rpt_dt_absensi_ghreg_getrows: when store set, filter store only
                                    (DT_ABSENSI.BRAND_ID often NULL/empty — brand filter would wipe rows). */
                                 AND (@store IS NULL OR DA.Store_ID = @store)
                                 AND (
                                      @brand IS NULL
                                      OR @store IS NOT NULL
                                      OR EXISTS (
                                          SELECT 1
                                          FROM pos_server.dbo.DT_Store AS st WITH (NOLOCK)
                                          WHERE st.Store_ID = DA.Store_ID
                                            AND (
                                                 st.Store_Brand_ID = @brand
                                                 OR (@brand = 'CELCIUS' AND st.Store_Brand_ID IN ('CELCIUS','CELCIUS KIDS'))
                                            )
                                      )
                                 )
                                 AND (
                                      @kw IS NULL
                                      OR DA.User_NIK LIKE '%'+@kw+'%'
                                      OR DS.USER_NAME LIKE '%'+@kw+'%'
                                      OR DA.Store_ID LIKE '%'+@kw+'%'
                                 )
                               GROUP BY
                                      DA.Store_ID,
                                      DA.User_NIK,
                                      DS.USER_NAME,
                                      CONVERT(varchar(10), DA.Waktu, 23)
                           ) AS agg
                           ORDER BY agg.Store_ID, agg.Tanggal, agg.User_NIK
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0 FOR JSON PATH)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
