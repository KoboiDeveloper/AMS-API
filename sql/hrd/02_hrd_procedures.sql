/*
  HRD stored procedures - RBACESS only (DROP+CREATE; SQL Server 2016 RTM).
  JSON @bitparam pattern matches xsp_ams_new_rbac_branch_getrows.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @kw varchar(300) = NULLIF(LTRIM(RTRIM(CONCAT(ISNULL(@p_search, ''), ' ', ISNULL(@p_keywords, '')))), '');

        IF OBJECT_ID(N'pos_server.dbo.WEB_USER_MAIN', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (100)
                                  u.ID_USER AS idUser,
                                  u.FULL_NAME AS fullName,
                                  u.NAMA_NICK AS nickName,
                                  u.EMAIL AS email,
                                  u.PHONE_NUMBER AS phone,
                                  u.ID_STORE AS storeId,
                                  u.IS_ACTIVE AS isActive
                           FROM pos_server.dbo.WEB_USER_MAIN AS u
                           WHERE (@kw IS NULL OR u.ID_USER LIKE '%' + @kw + '%' OR u.FULL_NAME LIKE '%' + @kw + '%' OR u.NAMA_NICK LIKE '%' + @kw + '%')
                           ORDER BY u.ID_USER
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_list_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_list_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_list_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @p_date_from date = NULL
    , @p_date_to date = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @kw varchar(300) = NULLIF(LTRIM(RTRIM(CONCAT(ISNULL(@p_search, ''), ' ', ISNULL(@p_keywords, '')))), '');

        IF OBJECT_ID(N'pos_server.dbo.DT_ABSENSI', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (100)
                                  a.ID_ABSENSI AS idAbsensi,
                                  a.User_NIK AS userNik,
                                  a.Store_ID AS storeId,
                                  a.BRAND_ID AS brandId,
                                  a.Jenis AS jenis,
                                  a.Waktu AS waktu,
                                  a.Status_Approve AS statusApprove,
                                  a.Absen_Online AS absenOnline
                           FROM pos_server.dbo.DT_ABSENSI AS a
                           WHERE (@kw IS NULL OR a.User_NIK LIKE '%' + @kw + '%' OR a.Store_ID LIKE '%' + @kw + '%' OR CAST(a.ID_ABSENSI AS varchar(30)) LIKE '%' + @kw + '%')
                             AND (@p_date_from IS NULL OR CONVERT(date, a.Waktu) >= @p_date_from)
                             AND (@p_date_to IS NULL OR CONVERT(date, a.Waktu) <= @p_date_to)
                             
                           ORDER BY a.Waktu DESC
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_all_attendance_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_all_attendance_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_all_attendance_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @p_date_from date = NULL
    , @p_date_to date = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @kw varchar(300) = NULLIF(LTRIM(RTRIM(CONCAT(ISNULL(@p_search, ''), ' ', ISNULL(@p_keywords, '')))), '');

        IF OBJECT_ID(N'pos_server.dbo.DT_ABSENSI', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (100)
                                  a.ID_ABSENSI AS idAbsensi,
                                  a.User_NIK AS userNik,
                                  a.Store_ID AS storeId,
                                  a.BRAND_ID AS brandId,
                                  a.Jenis AS jenis,
                                  a.Waktu AS waktu,
                                  a.Status_Approve AS statusApprove,
                                  a.Absen_Online AS absenOnline
                           FROM pos_server.dbo.DT_ABSENSI AS a
                           WHERE (@kw IS NULL OR a.User_NIK LIKE '%' + @kw + '%' OR a.Store_ID LIKE '%' + @kw + '%' OR CAST(a.ID_ABSENSI AS varchar(30)) LIKE '%' + @kw + '%')
                             AND (@p_date_from IS NULL OR CONVERT(date, a.Waktu) >= @p_date_from)
                             AND (@p_date_to IS NULL OR CONVERT(date, a.Waktu) <= @p_date_to)
                             
                           ORDER BY a.Waktu DESC
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_online_attendance_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_online_attendance_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_online_attendance_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @p_date_from date = NULL
    , @p_date_to date = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @kw varchar(300) = NULLIF(LTRIM(RTRIM(CONCAT(ISNULL(@p_search, ''), ' ', ISNULL(@p_keywords, '')))), '');

        IF OBJECT_ID(N'pos_server.dbo.DT_ABSENSI', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (100)
                                  a.ID_ABSENSI AS idAbsensi,
                                  a.User_NIK AS userNik,
                                  a.Store_ID AS storeId,
                                  a.BRAND_ID AS brandId,
                                  a.Jenis AS jenis,
                                  a.Waktu AS waktu,
                                  a.Status_Approve AS statusApprove,
                                  a.Absen_Online AS absenOnline
                           FROM pos_server.dbo.DT_ABSENSI AS a
                           WHERE (@kw IS NULL OR a.User_NIK LIKE '%' + @kw + '%' OR a.Store_ID LIKE '%' + @kw + '%' OR CAST(a.ID_ABSENSI AS varchar(30)) LIKE '%' + @kw + '%')
                             AND (@p_date_from IS NULL OR CONVERT(date, a.Waktu) >= @p_date_from)
                             AND (@p_date_to IS NULL OR CONVERT(date, a.Waktu) <= @p_date_to)
                             AND ISNULL(a.Absen_Online, 0) = 1
                           ORDER BY a.Waktu DESC
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kontrak_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_status_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_status_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_status_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_promosi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_mutasi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_resign_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_resign_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_resign_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_izin_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_izin_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_izin_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sakit_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_sakit_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sakit_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_alfa_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_alfa_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_alfa_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_dinas_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_dinas_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_dinas_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_adhoc_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_adhoc_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_adhoc_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_report_total_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_report_total_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_report_total_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_report_nasional_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_wfh_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_wfh_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_wfh_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_detail_kehadiran_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_detail_kehadiran_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_detail_kehadiran_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_export_employee_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_export_employee_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_export_employee_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_report_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_report_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_report_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_lembur_report_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_lembur_report_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_lembur_report_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_kpi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_kpi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_kpi_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_variable_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_formula_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_benefit_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_deduction_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_salary_entry_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_salary_inquiry_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_salary_inquiry_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_salary_inquiry_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_salary_report_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_salary_report_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_salary_report_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_thr_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_thr_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_thr_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payment_request_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_payment_request_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payment_request_getrows
(
      @p_search varchar(150) = ''
    , @p_keywords varchar(200) = ''
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0
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
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_generate_process', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_process
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'process accepted (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT ISNULL(@p_actor_nik, '') AS actorNik,
                              ISNULL(@p_payload, '') AS payloadReceived
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_generate_store_process', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_store_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_store_process
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'process accepted (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT ISNULL(@p_actor_nik, '') AS actorNik,
                              ISNULL(@p_payload, '') AS payloadReceived
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_generate_nasional_process', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_nasional_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_nasional_process
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'process accepted (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT ISNULL(@p_actor_nik, '') AS actorNik,
                              ISNULL(@p_payload, '') AS payloadReceived
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_eom_process', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_eom_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_eom_process
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'process accepted (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT ISNULL(@p_actor_nik, '') AS actorNik,
                              ISNULL(@p_payload, '') AS payloadReceived
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_monthly_payroll_process', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_monthly_payroll_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_monthly_payroll_process
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'process accepted (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT ISNULL(@p_actor_nik, '') AS actorNik,
                              ISNULL(@p_payload, '') AS payloadReceived
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'personel' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'personel' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'personel' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_izin_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_izin_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_izin_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'izin' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_izin_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_izin_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_izin_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'izin' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_izin_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_izin_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_izin_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'izin' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'cuti' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'cuti' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'cuti' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'holiday' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'holiday' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'holiday' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_perusahaan' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_perusahaan' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_perusahaan' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_cabang' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_cabang' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_cabang' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_divisi' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_divisi' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_divisi' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_departemen' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_departemen' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_departemen' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_golongan' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_golongan' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_golongan' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_pangkat' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_pangkat' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_pangkat' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_insert
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_jabatan' AS entity, 'insert' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_update
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_jabatan' AS entity, 'update' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_delete
(
      @p_payload varchar(max) = NULL
    , @p_actor_nik varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success (stub - no legacy write)' AS responseMessage,
                   JSON_QUERY((
                       SELECT 'master_jabatan' AS entity, 'delete' AS action
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_slip_gaji_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_slip_gaji_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_slip_gaji_getrows
(
      @p_search varchar(150) = ''
    , @p_period varchar(20) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success - Crystal report stub; use legacy rptslipgaji' AS responseMessage,
                   JSON_QUERY((SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0 FOR JSON PATH)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
