/*
  Member Info (REG RPT) — module/rpt/member_Info.aspx parity
  Wrappers around pos_server member info / point / detail / chart / update SPs.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.fn_ams_reg_member_date103', N'FN') IS NULL
BEGIN
    EXEC(N'
    CREATE FUNCTION dbo.fn_ams_reg_member_date103 (@v varchar(30), @fallback date)
    RETURNS varchar(10)
    AS
    BEGIN
        DECLARE @s varchar(30) = LTRIM(RTRIM(ISNULL(@v, '''')));
        DECLARE @d date = NULL;
        IF @s LIKE ''[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%''
            SET @d = TRY_CONVERT(date, LEFT(@s, 10), 23);
        ELSE IF @s <> ''''
            SET @d = TRY_CONVERT(date, @s, 103);
        RETURN CONVERT(varchar(10), ISNULL(@d, @fallback), 103);
    END');
END
GO

/* ---------- profile ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_info_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_getrow
(
      @p_id varchar(80) = NULL
    , @p_id_member varchar(80) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id varchar(80) = NULLIF(LTRIM(RTRIM(COALESCE(@p_id_member, @p_id))), '');
        IF @id IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'mem wajib' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #i
        (
              member_id varchar(20) NULL
            , Nama varchar(max) NULL
            , alamat varchar(max) NULL
            , provinsi int NULL
            , kota int NULL
            , TglLahir nvarchar(4000) NULL
            , NoTelpon varchar(max) NULL
            , email varchar(max) NULL
            , Password varchar(max) NULL
            , TglMember nvarchar(4000) NULL
            , Store_ID varchar(max) NULL
            , Jenis_kelamin varchar(1) NULL
            , TIER varchar(331) NULL
        );
        INSERT INTO #i
        EXEC pos_server.dbo.xsp_app_dashboard_member_Info_getrow @id;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL((
                       SELECT TOP 1
                              @id AS id_member,
                              member_id, Nama AS nama, alamat,
                              CAST(provinsi AS varchar(20)) AS provinsi,
                              CAST(kota AS varchar(20)) AS kota,
                              TglLahir AS tgl_lahir, NoTelpon AS no_telpon,
                              email, Password AS password, TglMember AS tgl_member,
                              Store_ID AS store_id, Jenis_kelamin AS jenis_kelamin, TIER AS tier
                       FROM #i
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                   ), '{}')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- points ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_info_points_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_points_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_points_getrow
(
      @p_id varchar(80) = NULL
    , @p_id_member varchar(80) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id varchar(80) = NULLIF(LTRIM(RTRIM(COALESCE(@p_id_member, @p_id))), '');
        IF @id IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'mem wajib' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #p
        (
              TOTAL_POINT nvarchar(50) NULL
            , Point_used nvarchar(50) NULL
            , Sisa_point nvarchar(50) NULL
        );
        INSERT INTO #p
        EXEC pos_server.dbo.xsp_app_dashboard_member_info_total_point_getrow @id;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL((
                       SELECT TOP 1 TOTAL_POINT AS total_point, Point_used AS point_used, Sisa_point AS sisa_point
                       FROM #p
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                   ), '{}')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- point mutation grid ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_info_tx_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_tx_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_tx_getrows
(
      @p_id varchar(80) = NULL
    , @p_id_member varchar(80) = NULL
    , @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @today date = CAST(GETDATE() AS date);
        DECLARE @id varchar(80) = NULLIF(LTRIM(RTRIM(COALESCE(@p_id_member, @p_id))), '');
        DECLARE @fd varchar(10) = dbo.fn_ams_reg_member_date103(@p_from_date, DATEFROMPARTS(YEAR(@today), MONTH(@today), 1));
        DECLARE @td varchar(10) = dbo.fn_ams_reg_member_date103(@p_to_date, @today);
        IF @id IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'mem wajib' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #t
        (
              CATEGORY varchar(100) NULL
            , TANGGAL nvarchar(4000) NULL
            , A decimal(18, 0) NULL
            , REDEEM decimal(18, 0) NULL
            , REWARD decimal(18, 0) NULL
            , BIRTHDAY decimal(18, 0) NULL
            , BIGDAY decimal(18, 0) NULL
            , Z decimal(18, 0) NULL
            , ID_STORE varchar(50) NULL
        );
        INSERT INTO #t
        EXEC pos_server.dbo.xsp_get_member_detail_ver2_getrows @id, @fd, @td;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL((
                       SELECT CATEGORY AS category, TANGGAL AS tanggal,
                              A AS awal, REDEEM AS redeem, REWARD AS reward,
                              BIRTHDAY AS birthday, BIGDAY AS bigday, Z AS akhir,
                              ID_STORE AS id_store
                       FROM #t
                       FOR JSON PATH, INCLUDE_NULL_VALUES
                   ), '[]')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- charts (JSON string from legacy) ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_info_chart_freq_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_chart_freq_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_chart_freq_getrow
(
      @p_id varchar(80) = NULL
    , @p_id_member varchar(80) = NULL
    , @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @today date = CAST(GETDATE() AS date);
        DECLARE @id varchar(80) = NULLIF(LTRIM(RTRIM(COALESCE(@p_id_member, @p_id))), '');
        DECLARE @fd varchar(10) = dbo.fn_ams_reg_member_date103(@p_from_date, DATEFROMPARTS(YEAR(@today), MONTH(@today), 1));
        DECLARE @td varchar(10) = dbo.fn_ams_reg_member_date103(@p_to_date, @today);
        IF @id IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'mem wajib' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #c (member_activity_frequency nvarchar(max) NULL);
        INSERT INTO #c
        EXEC pos_server.dbo.xsp_app_dashboard_member_Activity_frequency_chart_getrow @fd, @td, @id;

        DECLARE @raw nvarchar(max) = (SELECT TOP 1 member_activity_frequency FROM #c);
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(CASE WHEN ISJSON(@raw) = 1 THEN @raw ELSE '[]' END) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_info_chart_brand_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_chart_brand_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_chart_brand_getrow
(
      @p_id varchar(80) = NULL
    , @p_id_member varchar(80) = NULL
    , @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @today date = CAST(GETDATE() AS date);
        DECLARE @id varchar(80) = NULLIF(LTRIM(RTRIM(COALESCE(@p_id_member, @p_id))), '');
        DECLARE @fd varchar(10) = dbo.fn_ams_reg_member_date103(@p_from_date, DATEFROMPARTS(YEAR(@today), MONTH(@today), 1));
        DECLARE @td varchar(10) = dbo.fn_ams_reg_member_date103(@p_to_date, @today);
        IF @id IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'mem wajib' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #c (member_activity_all_brand nvarchar(max) NULL);
        INSERT INTO #c
        EXEC pos_server.dbo.xsp_app_dashboard_member_Activity_all_brand_chart_getrow @fd, @td, @id;

        DECLARE @raw nvarchar(max) = (SELECT TOP 1 member_activity_all_brand FROM #c);
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(CASE WHEN ISJSON(@raw) = 1 THEN @raw ELSE '[]' END) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- update profile ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_info_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_info_update
(
      @p_id varchar(80) = NULL
    , @p_payload varchar(max) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id varchar(80) = NULLIF(LTRIM(RTRIM(COALESCE(
            JSON_VALUE(@p_payload, '$.id_member'),
            @p_id
        ))), '');
        IF @id IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'mem wajib' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @nama varchar(50) = LEFT(LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.nama'), ''))), 50);
        DECLARE @tglRaw varchar(30) = LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.tgl_lahir'), '')));
        DECLARE @tgl datetime = COALESCE(
            TRY_CONVERT(datetime, @tglRaw, 111),
            TRY_CONVERT(datetime, @tglRaw, 23),
            TRY_CONVERT(datetime, @tglRaw, 103)
        );
        DECLARE @jk varchar(4) = LEFT(UPPER(LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.jenis_kelamin'), '')))), 4);
        DECLARE @tlp varchar(50) = LEFT(LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.no_telpon'), ''))), 50);
        DECLARE @alamat varchar(200) = LEFT(LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.alamat'), ''))), 200);
        DECLARE @prov varchar(50) = LEFT(LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.provinsi'), ''))), 50);
        DECLARE @kota varchar(50) = LEFT(LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.kota'), ''))), 50);
        DECLARE @email varchar(50) = LEFT(LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.email'), ''))), 50);
        DECLARE @pwd varchar(50) = LEFT(LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.password'), ''))), 50);

        EXEC pos_server.dbo.xsp_data_member_update
              @p_id_member = @id
            , @p_nama = @nama
            , @p_tanggal_lahir = @tgl
            , @p_jenis_kelamin = @jk
            , @p_no_tlp = @tlp
            , @p_alamat = @alamat
            , @p_provinsi = @prov
            , @p_kota = @kota
            , @p_email = @email
            , @p_password = @pwd;

        SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* Hide Member Info from Commerce → Member menu (page remains for drill-down) */
UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MEMBER_INFO_MENU_OFF',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_RPT_MEMBER_INFO';
GO
