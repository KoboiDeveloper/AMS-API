USE RBACESS;
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_lookup_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_lookup_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_lookup_getrows
(
      @p_type varchar(50)
    , @p_keywords varchar(200) = NULL
    , @p_parent_id varchar(80) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @t varchar(50) = LOWER(LTRIM(RTRIM(ISNULL(@p_type,''))));
        DECLARE @kw varchar(200) = NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'');
        DECLARE @parent varchar(80) = NULLIF(LTRIM(RTRIM(ISNULL(@p_parent_id,''))),'');
        DECLARE @gh varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_actor_nik,''))),'');

        /* Legacy Shared.BindidbrandAll2 → xsp_brand_filter_all_getrows */
        IF @t IN ('brand_all','brand-all','brands_all') AND OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT DISTINCT a.Store_Brand_ID AS value, a.Store_Brand_ID AS label
                           FROM pos_server.dbo.DT_Store AS a WITH (NOLOCK)
                           WHERE a.Store_Brand_ID IS NOT NULL
                             AND a.Store_Brand_ID NOT IN (
                                 'AEESHA','ART VISUAL','CELCIUS KIDS','DC','DC OLD','GA',
                                 'MINISTORE','POS TES','KW2','WOL','TEST'
                             )
                             AND (@kw IS NULL OR a.Store_Brand_ID LIKE '%'+@kw+'%')
                           ORDER BY 1
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* Legacy Shared.BindRegbrand → xsp_brand_filter_REG_getrows(@p_gh_id) */
        IF @t IN ('brand','brands') AND OBJECT_ID(N'pos_server.dbo.xsp_brand_filter_REG_getrows', N'P') IS NOT NULL
        BEGIN
            CREATE TABLE #brand (brand varchar(100));
            INSERT INTO #brand (brand)
            EXEC pos_server.dbo.xsp_brand_filter_REG_getrows @p_gh_id = @gh;

            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT DISTINCT b.brand AS value, b.brand AS label
                           FROM #brand AS b
                           WHERE b.brand IS NOT NULL
                             AND (@kw IS NULL OR b.brand LIKE '%'+@kw+'%')
                           ORDER BY 1
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            DROP TABLE #brand;
            RETURN;
        END;

        /* Legacy Shared.BindRegStore → xsp_brand_reg_filter_getrows(@p_gh_id) */
        IF @t IN ('store','stores') AND OBJECT_ID(N'pos_server.dbo.xsp_brand_reg_filter_getrows', N'P') IS NOT NULL
        BEGIN
            CREATE TABLE #store (Store_desc varchar(200), Store varchar(50));
            INSERT INTO #store (Store_desc, Store)
            EXEC pos_server.dbo.xsp_brand_reg_filter_getrows @p_gh_id = @gh;

            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (800)
                                  s.Store AS value,
                                  ISNULL(s.Store_desc, s.Store) AS label
                           FROM #store AS s
                           WHERE s.Store IS NOT NULL
                             AND (@kw IS NULL OR s.Store LIKE '%'+@kw+'%' OR s.Store_desc LIKE '%'+@kw+'%')
                             AND (
                                   @parent IS NULL
                                OR EXISTS (
                                       SELECT 1 FROM pos_server.dbo.DT_Store ds WITH (NOLOCK)
                                       WHERE ds.Store_ID = s.Store
                                         AND (
                                              ds.Store_Brand_ID = @parent
                                           OR (@parent = 'CELCIUS' AND ds.Store_Brand_ID IN ('CELCIUS','CELCIUS KIDS'))
                                         )
                                   )
                             )
                           ORDER BY s.Store
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            DROP TABLE #store;
            RETURN;
        END;

        IF @t IN ('cabang','branch') AND OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT DISTINCT ISNULL(s.STORE_PULAU, s.STORE_KOTA) AS value,
                                  ISNULL(s.STORE_PULAU, s.STORE_KOTA) AS label
                           FROM pos_server.dbo.DT_Store AS s WITH (NOLOCK)
                           WHERE s.Status_Active = 1
                             AND ISNULL(s.STORE_PULAU, s.STORE_KOTA) IS NOT NULL
                           ORDER BY 1
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* Legacy Shared.BindManPowerSalesGH → XSP_SALES_BY_MAN_POWER_GETROWS (@p_store_id) */
        IF @t IN ('manpower','man_power','sales_manpower','manpower_sales')
           AND OBJECT_ID(N'pos_server.dbo.DT_User', N'U') IS NOT NULL
        BEGIN
            IF @parent IS NULL OR UPPER(@parent) IN ('ALL','0','PILIH','')
            BEGIN
                SET @bitparam = (
                    SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                           JSON_QUERY((SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0 FOR JSON PATH)) AS data
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                );
                RETURN;
            END;

            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT DISTINCT
                                  UPPER(u.User_NIK) AS value,
                                  UPPER(u.USER_NAME) + ' - ' + UPPER(u.User_NIK) AS label
                           FROM pos_server.dbo.DT_User AS u WITH (NOLOCK)
                           WHERE u.STORE_ID = @parent
                             AND u.Status_Active = 1
                             AND u.User_NIK IS NOT NULL
                             AND (
                                   @kw IS NULL
                                OR u.User_NIK LIKE '%' + @kw + '%'
                                OR u.USER_NAME LIKE '%' + @kw + '%'
                             )
                           ORDER BY 2
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
/* Dashboard body maintained in patches/reg_dashboard_full.sql — keep signature here for gens */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_dashboard_summary_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_dashboard_summary_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_dashboard_summary_getrow
(
      @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @p_id_brand varchar(50) = NULL
    , @p_id_cabang varchar(50) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    /* Full implementation applied via patches/reg_dashboard_full.sql */
    SET @bitparam = (
        SELECT '2002500' AS responseCode, 'success' AS responseMessage,
               JSON_QUERY((
                   SELECT CONVERT(varchar(10), CAST(GETDATE() AS date), 23) AS as_of,
                          0 AS active_store_count,
                          CAST(0 AS money) AS sales_today
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
               )) AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO
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
        /* Legacy: module/rpt/rpt_attendance.aspx → xsp_rpt_dt_absensi_ghreg_getrows
           Columns: STORE | USER NIK | EMPLOYEE | DATE | TIME IN | TIME OUT */
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
                                 /* Legacy: when store set, filter store only (BRAND_ID often NULL). */
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_store_list_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_store_list_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_store_list_getrows
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
        DECLARE @kw varchar(200) = NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'');
        DECLARE @brand varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(NULLIF(@p_id_brand,''), NULLIF(@p_brand,'')))), '');
        IF OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (1000)
                                  s.Store_ID AS id,
                                  s.Store_ID AS store_id,
                                  s.Store_Brand_ID AS brand_id,
                                  s.STORE_KOTA AS kota,
                                  s.STORE_PULAU AS pulau,
                                  s.Status_Active AS is_active
                           FROM pos_server.dbo.DT_Store AS s WITH (NOLOCK)
                           WHERE (@brand IS NULL OR s.Store_Brand_ID = @brand OR (@brand='CELCIUS' AND s.Store_Brand_ID IN ('CELCIUS','CELCIUS KIDS')))
                             AND (@kw IS NULL OR s.Store_ID LIKE '%'+@kw+'%' OR s.STORE_KOTA LIKE '%'+@kw+'%')
                           ORDER BY s.Store_ID
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_total_sales_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_total_sales_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_total_sales_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_plu_scan_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_plu_scan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_plu_scan_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_slip_dcr_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_slip_dcr_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_slip_dcr_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_list_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_list_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_list_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_list_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_list_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_list_getrow
( @p_id varchar(80), @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_list_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_list_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_list_insert
( @p_payload varchar(max), @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_list_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_list_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_list_update
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_list_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_list_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_list_delete
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_realisasi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_realisasi_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_getrow
( @p_id varchar(80), @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_realisasi_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_insert
( @p_payload varchar(max), @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_realisasi_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_update
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_realisasi_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_delete
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_mp_retur_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_mp_retur_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_mp_retur_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_mp_retur_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_mp_retur_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_mp_retur_getrow
( @p_id varchar(80), @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_mp_retur_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_mp_retur_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_mp_retur_insert
( @p_payload varchar(max), @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_mp_retur_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_mp_retur_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_mp_retur_update
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_mp_retur_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_mp_retur_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_mp_retur_delete
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_absensi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_absensi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_absensi_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_store_info_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_store_info_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_store_info_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_batch_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_batch_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_batch_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_slip_setoran_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_slip_setoran_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_slip_setoran_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_daily_sales_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_daily_sales_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_daily_sales_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_dcr_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_dcr_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_dcr_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_sales_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_detail_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_detail_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_payment_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_payment_detail_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_payment_detail_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_ar_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_ar_detail_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_ar_detail_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_sales_kol_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_kol_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_kol_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_store_diskon_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_store_diskon_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_store_diskon_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_asbc_qty_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_asbc_qty_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_asbc_qty_getrows
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
/* Asbc Nilai removed — DROP only (see patches/drop_asbc_nilai.sql) */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_asbc_nilai_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_asbc_nilai_getrows;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_st_in_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_st_in_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_st_in_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_outstanding_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_outstanding_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_outstanding_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_stock_diff_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_stock_diff_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_stock_diff_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_stock_diff_adj_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_stock_diff_adj_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_stock_diff_adj_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_stock_adj_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_stock_adj_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_stock_adj_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_st_out_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_st_out_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_st_out_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_st_list_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_st_list_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_st_list_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_last_stock_date_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_last_stock_date_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_last_stock_date_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_last_stock_all_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_last_stock_all_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_last_stock_all_getrows
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
        /* stockALlS.aspx → xsp_get_stock_all_store_getrows */
        CREATE TABLE #all (
            Store_ID varchar(200) NULL,
            tglbatch varchar(32) NULL,
            A decimal(19,4) NULL,
            HPP decimal(19,4) NULL,
            PRICE decimal(19,4) NULL
        );

        INSERT INTO #all (Store_ID, tglbatch, A, HPP, PRICE)
        EXEC pos_server.dbo.xsp_get_stock_all_store_getrows;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           a.Store_ID AS STORE_ID,
                           a.tglbatch AS TGLBATCH,
                           CAST(ISNULL(a.A, 0) AS float) AS A,
                           CAST(ISNULL(a.HPP, 0) AS float) AS HPP,
                           CAST(ISNULL(a.PRICE, 0) AS float) AS PRICE
                       FROM #all a
                       ORDER BY a.Store_ID
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_cek_mutasi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_cek_mutasi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_cek_mutasi_getrows
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
        DECLARE @plu varchar(80) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_plu,''), @p_article), '')));
        DECLARE @user varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_actor_nik,''), NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,'')), '')));

        IF @from IS NULL OR @to IS NULL OR @store IN ('','0','ALL') OR @plu = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'Store, PLU, from_date, to_date wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        IF @user = '' SET @user = 'REG2';

        DECLARE @fromS varchar(20) = CONVERT(varchar(10), @from, 111);
        DECLARE @toS varchar(20) = CONVERT(varchar(10), @to, 111);

        /* Final SELECT of XSP_Z_GETROWS */
        CREATE TABLE #r (
            ID int NULL,
            ID_STORE varchar(50) NULL,
            KODE varchar(50) NULL,
            IDNYA varchar(50) NULL,
            tanggal nvarchar(50) NULL,
            PLU varchar(20) NULL,
            A int NULL,
            TRANSAKSI int NULL,
            Z int NULL,
            status varchar(50) NULL,
            color varchar(50) NULL,
            P_USER_ID varchar(50) NULL
        );

        INSERT INTO #r (ID, ID_STORE, KODE, IDNYA, tanggal, PLU, A, TRANSAKSI, Z, status, color, P_USER_ID)
        EXEC pos_server.dbo.XSP_Z_GETROWS
            @p_store_id = @store,
            @p_from_date = @fromS,
            @p_to_date = @toS,
            @p_plu = @plu,
            @p_user_id = @user;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           r.IDNYA AS IDNYA,
                           r.KODE AS KODE,
                           r.tanggal AS TANGGAL,
                           r.PLU AS PLU,
                           CAST(ISNULL(r.A, 0) AS float) AS A,
                           CAST(ISNULL(r.TRANSAKSI, 0) AS float) AS TRANSAKSI,
                           CAST(ISNULL(r.Z, 0) AS float) AS Z,
                           ISNULL(r.status, '') AS STATUS,
                           ISNULL(r.color, '') AS COLOR,
                           r.ID_STORE AS STORE_ID
                       FROM #r r
                       ORDER BY r.ID
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_cek_qty0_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_cek_qty0_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_cek_qty0_getrows
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
/* Tr So list — implemented in patches/reg_rpt_tr_so_getrows.sql (wrap xsp_rpt_tr_so_header_detail_getrows).
   Action modals — patches/reg_rpt_tr_so_actions.sql. */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_so_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_getrows
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

        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand IN ('','0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store IN ('','0') SET @store = 'ALL';
        DECLARE @gh varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,''), NULLIF(@p_actor_nik,'')), '0')));
        IF @gh = '' SET @gh = '0';

        DECLARE @fromS varchar(20) = CONVERT(varchar(10), @from, 111);
        DECLARE @toS varchar(20) = CONVERT(varchar(10), @to, 111);

        CREATE TABLE #h (
            NO_URUT bigint NULL,
            WAKTU_URUT datetime NULL,
            NO_TR_SO_HEADER varchar(32) NULL,
            tgl_so nvarchar(4000) NULL,
            Brand_SO varchar(max) NULL,
            ID_Store_SO varchar(max) NULL,
            Class_SO varchar(3) NULL,
            Grade_SO varchar(1) NULL,
            Distinct_A int NULL,
            Qty_A int NULL,
            HPP_A money NULL,
            Price_A money NULL,
            Distinct_REAL int NULL,
            QTY_REAL int NULL,
            HPP_REAL money NULL,
            Price_REAL money NULL,
            tgl_status_so nvarchar(4000) NULL,
            Status_SO bit NULL,
            tgl_closing nvarchar(4000) NULL,
            Status_Closing bit NULL,
            qty_selisih int NULL,
            HPP_SELISIH money NULL,
            price_selisih money NULL,
            tgl_download nvarchar(4000) NULL,
            Status_Download bit NULL
        );

        INSERT INTO #h
        EXEC pos_server.dbo.xsp_rpt_tr_so_header_detail_getrows
            @p_from_date = @fromS,
            @p_to_date = @toS,
            @p_brand_id = @brand,
            @p_store_id = @store,
            @p_id_gh = @gh;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           h.NO_URUT AS NO_URUT,
                           h.NO_TR_SO_HEADER AS NO_TR_SO_HEADER,
                           h.tgl_so AS TGL_SO,
                           h.Brand_SO AS BRAND_SO,
                           h.ID_Store_SO AS ID_STORE_SO,
                           h.Class_SO AS CLASS_SO,
                           h.Grade_SO AS GRADE_SO,
                           CAST(ISNULL(h.Qty_A, 0) AS float) AS QTY_A,
                           CAST(ISNULL(h.HPP_A, 0) AS float) AS HPP_A,
                           CAST(ISNULL(h.Price_A, 0) AS float) AS PRICE_A,
                           CAST(ISNULL(h.QTY_REAL, 0) AS float) AS QTY_REAL,
                           CAST(ISNULL(h.HPP_REAL, 0) AS float) AS HPP_REAL,
                           CAST(ISNULL(h.Price_REAL, 0) AS float) AS PRICE_REAL,
                           h.tgl_status_so AS TGL_STATUS_SO,
                           CAST(ISNULL(h.Status_SO, 0) AS int) AS STATUS_SO,
                           h.tgl_closing AS TGL_CLOSING,
                           CAST(ISNULL(h.Status_Closing, 0) AS int) AS STATUS_CLOSING,
                           CAST(ISNULL(h.qty_selisih, 0) AS float) AS QTY_SELISIH,
                           CAST(ISNULL(h.HPP_SELISIH, 0) AS float) AS HPP_SELISIH,
                           CAST(ISNULL(h.price_selisih, 0) AS float) AS PRICE_SELISIH
                       FROM #h h
                       ORDER BY h.WAKTU_URUT DESC, h.NO_URUT DESC
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_so_diff_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_so_diff_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_so_diff_getrows
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
/* So Adjustment — implemented in patches/reg_rpt_so_adj_getrows.sql
   (wrap xsp_rpt_tr_so_adjust_getrows / xsp_rpt_tr_so_adjust_CLASS_getrows). */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_so_adj_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_so_adj_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_so_adj_getrows
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

        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand IN ('','0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store IN ('','0') SET @store = 'ALL';
        DECLARE @gh varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,''), NULLIF(@p_actor_nik,'')), '0')));
        IF @gh = '' SET @gh = '0';
        DECLARE @tipe varchar(20) = LOWER(LTRIM(RTRIM(ISNULL(@p_tipe, 'plu'))));
        IF @tipe IN ('','full','all','1') SET @tipe = 'plu';
        IF @tipe IN ('3','cls') SET @tipe = 'class';
        DECLARE @fromS varchar(20) = CONVERT(varchar(10), @from, 111);
        DECLARE @toS varchar(20) = CONVERT(varchar(10), @to, 111);

        IF @tipe = 'class'
        BEGIN
            CREATE TABLE #c (PLU varchar(13) NULL, QTY int NULL, TOTAL_PRICE money NULL);
            INSERT INTO #c EXEC pos_server.dbo.xsp_rpt_tr_so_adjust_CLASS_getrows
                @p_from_date=@fromS, @p_to_date=@toS, @p_brand_id=@brand, @p_store_id=@store, @p_id_gh=@gh;
            SELECT @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((SELECT c.PLU AS PLU, CAST(ISNULL(c.QTY,0) AS float) AS QTY,
                                          CAST(ISNULL(c.TOTAL_PRICE,0) AS float) AS TOTAL_PRICE
                                   FROM #c c ORDER BY c.PLU FOR JSON PATH)) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        CREATE TABLE #p (
            NO_URUT bigint NULL, WAKTU_URUT datetime NULL, ID_TR_SO_ADJUST varchar(32) NULL,
            ID_TR_SO_SELISIH varchar(32) NULL, NO_TR_SO_HEADER varchar(32) NULL, STORE_ID varchar(50) NULL,
            PLU varchar(13) NULL, QTY int NULL, HPP money NULL, PRICE money NULL, TOTAL_HPP money NULL,
            TOTAL_PRICE money NULL, TGL_REAL nvarchar(4000) NULL, TGL_ADJUST nvarchar(4000) NULL
        );
        INSERT INTO #p EXEC pos_server.dbo.xsp_rpt_tr_so_adjust_getrows
            @p_from_date=@fromS, @p_to_date=@toS, @p_brand_id=@brand, @p_store_id=@store, @p_id_gh=@gh;
        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT p.STORE_ID AS STORE_ID, p.PLU AS PLU, CAST(ISNULL(p.QTY,0) AS float) AS QTY,
                              CAST(ISNULL(p.HPP,0) AS float) AS HPP, CAST(ISNULL(p.PRICE,0) AS float) AS PRICE,
                              CAST(ISNULL(p.TOTAL_HPP,0) AS float) AS TOTAL_HPP,
                              CAST(ISNULL(p.TOTAL_PRICE,0) AS float) AS TOTAL_PRICE,
                              p.TGL_ADJUST AS TGL_ADJUST, p.NO_TR_SO_HEADER AS NO_TR_SO_HEADER,
                              p.ID_TR_SO_ADJUST AS ID_TR_SO_ADJUST
                       FROM #p p ORDER BY p.WAKTU_URUT DESC, p.NO_URUT DESC FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_so_partial_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_partial_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_partial_getrows
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

        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand IN ('','0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store IN ('','0') SET @store = 'ALL';
        DECLARE @gh varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,''), NULLIF(@p_actor_nik,'')), '0')));
        IF @gh = '' SET @gh = '0';

        CREATE TABLE #h (
            NO_URUT bigint NULL,
            WAKTU_URUT datetime NULL,
            NO_TR_SO_HEADER varchar(32) NULL,
            Tgl_SO nvarchar(4000) NULL,
            Brand_SO varchar(max) NULL,
            ID_Store_SO varchar(max) NULL,
            Class_SO varchar(3) NULL,
            Grade_SO varchar(1) NULL,
            Distinct_A int NULL,
            Qty_A int NULL,
            HPP_A money NULL,
            Price_A money NULL,
            Distinct_REAL int NULL,
            QTY_REAL int NULL,
            HPP_REAL money NULL,
            Price_REAL money NULL,
            Tgl_Status_SO nvarchar(4000) NULL,
            jam_open_so nvarchar(4000) NULL,
            Status_SO bit NULL,
            Tgl_Closing nvarchar(4000) NULL,
            jam_tutup_so nvarchar(4000) NULL,
            Status_Closing bit NULL,
            QTY_SELISIH int NULL,
            HPP_SELISIH money NULL,
            PRICE_SELISIH money NULL,
            Tgl_Download datetime NULL,
            Status_Download bit NULL
        );

        INSERT INTO #h
        EXEC pos_server.dbo.xsp_tr_so_header_partial_getrows
            @p_store_id = @store,
            @p_brand_id = @brand,
            @p_id_gh = @gh,
            @p_from_date = @from,
            @p_to_date = @to;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           h.NO_URUT AS NO_URUT,
                           h.NO_TR_SO_HEADER AS NO_TR_SO_HEADER,
                           h.Tgl_SO AS TGL_SO,
                           h.Brand_SO AS BRAND_SO,
                           h.ID_Store_SO AS ID_STORE_SO,
                           h.Class_SO AS CLASS_SO,
                           h.Grade_SO AS GRADE_SO,
                           h.jam_open_so AS JAM_OPEN_SO,
                           h.jam_tutup_so AS JAM_TUTUP_SO,
                           CAST(ISNULL(h.Qty_A, 0) AS float) AS QTY_A,
                           CAST(ISNULL(h.HPP_A, 0) AS float) AS HPP_A,
                           CAST(ISNULL(h.Price_A, 0) AS float) AS PRICE_A,
                           CAST(ISNULL(h.QTY_REAL, 0) AS float) AS QTY_REAL,
                           CAST(ISNULL(h.HPP_REAL, 0) AS float) AS HPP_REAL,
                           CAST(ISNULL(h.Price_REAL, 0) AS float) AS PRICE_REAL,
                           CAST(ISNULL(h.Status_SO, 0) AS int) AS STATUS_SO,
                           CAST(ISNULL(h.Status_Closing, 0) AS int) AS STATUS_CLOSING,
                           CAST(ISNULL(h.QTY_SELISIH, 0) AS float) AS QTY_SELISIH,
                           CAST(ISNULL(h.HPP_SELISIH, 0) AS float) AS HPP_SELISIH,
                           CAST(ISNULL(h.PRICE_SELISIH, 0) AS float) AS PRICE_SELISIH
                       FROM #h h
                       ORDER BY h.WAKTU_URUT DESC, h.NO_URUT DESC
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_so_diff_partial_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_so_diff_partial_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_so_diff_partial_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_so_adj_partial_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_so_adj_partial_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_so_adj_partial_getrows
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

        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand IN ('','0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store IN ('','0') SET @store = 'ALL';
        DECLARE @gh varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,''), NULLIF(@p_actor_nik,'')), '0')));
        IF @gh = '' SET @gh = '0';

        DECLARE @fromS varchar(20) = CONVERT(varchar(10), @from, 111);
        DECLARE @toS varchar(20) = CONVERT(varchar(10), @to, 111);

        CREATE TABLE #p (
            NO_URUT bigint NULL,
            WAKTU_URUT datetime NULL,
            ID_TR_SO_ADJUST varchar(32) NULL,
            ID_TR_SO_SELISIH varchar(32) NULL,
            NO_TR_SO_HEADER varchar(32) NULL,
            STORE_ID varchar(max) NULL,
            PLU varchar(max) NULL,
            QTY int NULL,
            HPP money NULL,
            PRICE money NULL,
            TOTAL_HPP money NULL,
            TOTAL_PRICE money NULL,
            TGL_REAL nvarchar(4000) NULL,
            TGL_ADJUST nvarchar(4000) NULL
        );

        INSERT INTO #p
        EXEC pos_server.dbo.xsp_rpt_tr_so_adjust_partial_getrows
            @p_from_date = @fromS,
            @p_to_date = @toS,
            @p_brand_id = @brand,
            @p_store_id = @store,
            @p_id_gh = @gh;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           p.STORE_ID AS STORE_ID,
                           p.PLU AS PLU,
                           CAST(ISNULL(p.QTY, 0) AS float) AS QTY,
                           CAST(ISNULL(p.HPP, 0) AS float) AS HPP,
                           CAST(ISNULL(p.PRICE, 0) AS float) AS PRICE,
                           CAST(ISNULL(p.TOTAL_HPP, 0) AS float) AS TOTAL_HPP,
                           CAST(ISNULL(p.TOTAL_PRICE, 0) AS float) AS TOTAL_PRICE,
                           p.TGL_ADJUST AS TGL_ADJUST,
                           p.NO_TR_SO_HEADER AS NO_TR_SO_HEADER,
                           p.ID_TR_SO_ADJUST AS ID_TR_SO_ADJUST
                       FROM #p p
                       ORDER BY p.WAKTU_URUT DESC, p.NO_URUT DESC
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
/* Voucher Fisik/Imlek — full bodies live in patches/reg_rpt_voucher_*_getrows.sql (applied to RBACESS). */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_voucher_fisik_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_voucher_fisik_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_voucher_fisik_getrows
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
        DECLARE @st varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_status, 'ALL'))));
        IF @st = '' SET @st = 'ALL';
        IF @st NOT IN ('ALL', 'TERPAKAI', 'BELUM TERPAKAI', 'EXPIRED') SET @st = 'ALL';
        DECLARE @kw varchar(100) = LTRIM(RTRIM(ISNULL(@p_keywords, '')));
        CREATE TABLE #h (
            ID_VOUCHER nvarchar(32) NULL, TIPE_VOUCHER nvarchar(20) NULL, qty nchar(10) NULL,
            MAXNOMINAL int NULL, CRE_DATE datetime NULL, qty_z int NULL,
            NOMINAL nvarchar(4000) NULL, BRAND nvarchar(50) NULL, KETERANGAN varchar(max) NULL
        );
        INSERT INTO #h EXEC pos_server.dbo.xsp_header_vouchermarcomm_rpt_getrows @p_status=@st, @p_keywords=@kw;
        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT h.ID_VOUCHER AS ID_VOUCHER, h.TIPE_VOUCHER AS TIPE_VOUCHER,
                              LTRIM(RTRIM(ISNULL(h.qty,''))) AS QTY, CAST(ISNULL(h.MAXNOMINAL,0) AS float) AS MAXNOMINAL,
                              CONVERT(varchar(19), h.CRE_DATE, 120) AS CRE_DATE, CAST(ISNULL(h.qty_z,0) AS float) AS QTY_Z,
                              h.NOMINAL AS NOMINAL, h.BRAND AS BRAND, h.KETERANGAN AS KETERANGAN
                       FROM #h h ORDER BY h.CRE_DATE DESC FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
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
        CREATE TABLE #h (ID_PROMO varchar(32) NULL, STORE_ID varchar(20) NULL, tipe varchar(200) NULL, nominal money NULL);
        INSERT INTO #h EXEC pos_server.dbo.xsp_get_voucher_imlek_header;
        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT h.ID_PROMO AS ID_PROMO, h.STORE_ID AS STORE_ID, h.tipe AS TIPE, CAST(ISNULL(h.nominal,0) AS float) AS NOMINAL
                       FROM #h h ORDER BY h.STORE_ID, h.ID_PROMO FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_woro1_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_woro1_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_woro1_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_woro2_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_woro2_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_woro2_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_omni_rt_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_omni_rt_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_omni_rt_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_omni_varian_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_omni_varian_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_omni_varian_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_omni_order_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_omni_order_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_omni_order_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_info_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_scan_selisih_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_scan_selisih_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_scan_selisih_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_scan_selisih_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_scan_selisih_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_scan_selisih_getrow
( @p_id varchar(80), @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_scan_selisih_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_scan_selisih_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_scan_selisih_insert
( @p_payload varchar(max), @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_scan_selisih_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_scan_selisih_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_scan_selisih_update
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_scan_selisih_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_scan_selisih_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_scan_selisih_delete
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_adj_so_partial_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_adj_so_partial_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_adj_so_partial_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_adj_so_partial_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_adj_so_partial_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_adj_so_partial_getrow
( @p_id varchar(80), @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_adj_so_partial_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_adj_so_partial_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_adj_so_partial_insert
( @p_payload varchar(max), @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_adj_so_partial_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_adj_so_partial_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_adj_so_partial_update
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_adj_so_partial_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_adj_so_partial_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_adj_so_partial_delete
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_getrows
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_getrow
( @p_id varchar(80), @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_insert
( @p_payload varchar(max), @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_update
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_delete
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_print_outstanding_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_print_outstanding_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_print_outstanding_getrows
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