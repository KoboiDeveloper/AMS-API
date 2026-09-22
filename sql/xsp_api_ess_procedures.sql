/*
  ESS Stored Procedures - SQL Server
  Pola keluaran JSON via @bitparam (NVARCHAR(MAX) OUTPUT)

  Catatan:
  - Ganti nama database/schema/table sesuai environment (placeholder: dbo.WEB_USER_MAIN, dll).
  - getrow  => WITHOUT_ARRAY_WRAPPER (object)
  - getrows => array JSON (tanpa WITHOUT_ARRAY_WRAPPER)
*/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* =========================================================
   1) AUTH - LOGIN
   SP sudah ada di database: dbo.xsp_api_ess_login
   Parameter: @p_uid, @p_password, @bitparam OUTPUT
   Jangan recreate dari file ini.
   ========================================================= */


/* =========================================================
   1b) AUTH - LOGIN SESSION LOG (Perangkat Terhubung)
   Table + SP di RBACESS
   - 1 device (DEVICE_KEY) = 1 baris: login ulang → UPDATE + rotate ID (jti)
   - Device beda → INSERT baru
   ========================================================= */

IF OBJECT_ID(N'dbo.ESS_USER_LOGIN_SESSION', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ESS_USER_LOGIN_SESSION
    (
         ID               UNIQUEIDENTIFIER NOT NULL
        ,USER_ID          VARCHAR(50)      NOT NULL
        ,DEVICE_KEY       VARCHAR(100)     NULL
        ,DEVICE_TYPE      VARCHAR(20)      NOT NULL
            CONSTRAINT DF_ESS_LOGIN_SESSION_DEVICE_TYPE DEFAULT ('UNKNOWN')
        ,DEVICE_NAME      NVARCHAR(100)    NULL
        ,CLIENT_INFO      NVARCHAR(200)    NULL
        ,USER_AGENT       NVARCHAR(500)    NULL
        ,IP_ADDRESS       VARCHAR(45)      NULL
        ,LOCATION_NAME    NVARCHAR(150)    NULL
        ,LOGIN_AT         DATETIME2(0)     NOT NULL
            CONSTRAINT DF_ESS_LOGIN_SESSION_LOGIN_AT DEFAULT (DATEADD(HOUR, 7, SYSUTCDATETIME()))
        ,LAST_ACTIVE_AT   DATETIME2(0)     NOT NULL
            CONSTRAINT DF_ESS_LOGIN_SESSION_LAST_ACTIVE DEFAULT (DATEADD(HOUR, 7, SYSUTCDATETIME()))
        ,EXPIRES_AT       DATETIME2(0)     NOT NULL
        ,IS_ACTIVE        BIT              NOT NULL
            CONSTRAINT DF_ESS_LOGIN_SESSION_IS_ACTIVE DEFAULT (1)
        ,REVOKED_AT       DATETIME2(0)     NULL
        ,REVOKED_REASON   VARCHAR(50)      NULL
        ,CONSTRAINT PK_ESS_USER_LOGIN_SESSION PRIMARY KEY CLUSTERED (ID)
    );

    CREATE NONCLUSTERED INDEX IX_ESS_USER_LOGIN_SESSION_USER_ACTIVE
        ON dbo.ESS_USER_LOGIN_SESSION (USER_ID, IS_ACTIVE)
        INCLUDE (EXPIRES_AT, LAST_ACTIVE_AT, DEVICE_TYPE, DEVICE_NAME, DEVICE_KEY);

    CREATE NONCLUSTERED INDEX IX_ESS_USER_LOGIN_SESSION_USER_DEVICE
        ON dbo.ESS_USER_LOGIN_SESSION (USER_ID, DEVICE_KEY)
        INCLUDE (IS_ACTIVE, LAST_ACTIVE_AT);
END
GO

-- Migrasi tabel yang sudah ada (tanpa DEVICE_KEY)
IF OBJECT_ID(N'dbo.ESS_USER_LOGIN_SESSION', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.ESS_USER_LOGIN_SESSION', 'DEVICE_KEY') IS NULL
BEGIN
    ALTER TABLE dbo.ESS_USER_LOGIN_SESSION ADD DEVICE_KEY VARCHAR(100) NULL;

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = N'IX_ESS_USER_LOGIN_SESSION_USER_DEVICE'
          AND object_id = OBJECT_ID(N'dbo.ESS_USER_LOGIN_SESSION')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_ESS_USER_LOGIN_SESSION_USER_DEVICE
            ON dbo.ESS_USER_LOGIN_SESSION (USER_ID, DEVICE_KEY)
            INCLUDE (IS_ACTIVE, LAST_ACTIVE_AT);
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_login_session_insert
(
     @p_id             UNIQUEIDENTIFIER
    ,@p_user_id        VARCHAR(50)
    ,@p_device_key     VARCHAR(100)    = NULL
    ,@p_device_type    VARCHAR(20)     = 'UNKNOWN'
    ,@p_device_name    NVARCHAR(100)   = NULL
    ,@p_client_info    NVARCHAR(200)   = NULL
    ,@p_user_agent     NVARCHAR(500)   = NULL
    ,@p_ip_address     VARCHAR(45)     = NULL
    ,@p_location_name  NVARCHAR(150)   = NULL
    ,@p_login_at       DATETIME2(0)    = NULL
    ,@p_expires_at     DATETIME2(0)
    ,@bitparam         VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @p_id IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002701' AS responseCode, 'session id is required' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SET @p_user_id = NULLIF(LTRIM(RTRIM(@p_user_id)), '');
        IF @p_user_id IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002702' AS responseCode, 'user_id is required' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        IF @p_expires_at IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002703' AS responseCode, 'expires_at is required' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        IF @p_login_at IS NULL
            SET @p_login_at = DATEADD(HOUR, 7, SYSUTCDATETIME()); -- WIB (UTC+7)

        SET @p_device_key = NULLIF(LTRIM(RTRIM(@p_device_key)), '');
        SET @p_device_type = UPPER(NULLIF(LTRIM(RTRIM(@p_device_type)), ''));
        IF @p_device_type IS NULL
            SET @p_device_type = 'UNKNOWN';

        DECLARE
             @existing_id UNIQUEIDENTIFIER = NULL
            ,@action      VARCHAR(20) = 'INSERT';

        /* Device sama → nonaktifkan sesi lama, lalu INSERT jti baru (1 aktif per device) */
        IF @p_device_key IS NOT NULL
        BEGIN
            UPDATE dbo.ESS_USER_LOGIN_SESSION
            SET
                 IS_ACTIVE = 0
                ,REVOKED_AT = DATEADD(HOUR, 7, SYSUTCDATETIME())
                ,REVOKED_REASON = 'RELOGIN_SAME_DEVICE'
            WHERE USER_ID = @p_user_id
              AND DEVICE_KEY = @p_device_key
              AND IS_ACTIVE = 1;

            IF @@ROWCOUNT > 0
                SET @action = 'REPLACE';
        END;

        INSERT INTO dbo.ESS_USER_LOGIN_SESSION
        (
             ID
            ,USER_ID
            ,DEVICE_KEY
            ,DEVICE_TYPE
            ,DEVICE_NAME
            ,CLIENT_INFO
            ,USER_AGENT
            ,IP_ADDRESS
            ,LOCATION_NAME
            ,LOGIN_AT
            ,LAST_ACTIVE_AT
            ,EXPIRES_AT
            ,IS_ACTIVE
        )
        VALUES
        (
             @p_id
            ,@p_user_id
            ,@p_device_key
            ,@p_device_type
            ,@p_device_name
            ,@p_client_info
            ,@p_user_agent
            ,@p_ip_address
            ,@p_location_name
            ,@p_login_at
            ,@p_login_at
            ,@p_expires_at
            ,1
        );

        SET @bitparam = (
            SELECT
                 '2002700' AS responseCode
                ,'Login session recorded' AS responseMessage
                ,JSON_QUERY((
                    SELECT
                         CONVERT(VARCHAR(36), @p_id) AS sessionId
                        ,@p_user_id AS userId
                        ,@p_device_key AS deviceKey
                        ,@action AS action
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT
                 '5002700' AS responseCode
                ,'Failed to record login session' AS responseMessage
                ,ERROR_MESSAGE() AS errorDetail
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_login_session_getrows
(
     @p_user_id         VARCHAR(50)
    ,@p_current_session UNIQUEIDENTIFIER = NULL
    ,@bitparam          VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @p_user_id = NULLIF(LTRIM(RTRIM(@p_user_id)), '');
    IF @p_user_id IS NULL
    BEGIN
        SET @bitparam = (
            SELECT '4002702' AS responseCode, 'user_id is required' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END;

    SET @bitparam = (
        SELECT
             '2002701' AS responseCode
            ,'Data perangkat terhubung berhasil ditemukan' AS responseMessage
            ,JSON_QUERY((
                SELECT
                     CONVERT(VARCHAR(36), s.ID) AS sessionId
                    ,s.USER_ID AS userId
                    ,s.DEVICE_KEY AS deviceKey
                    ,s.DEVICE_TYPE AS deviceType
                    ,s.DEVICE_NAME AS deviceName
                    ,s.CLIENT_INFO AS clientInfo
                    ,s.IP_ADDRESS AS ipAddress
                    ,ISNULL(NULLIF(LTRIM(RTRIM(s.LOCATION_NAME)), ''), N'—') AS locationName
                    ,CONVERT(VARCHAR(19), s.LOGIN_AT, 120) AS loginAt
                    ,CONVERT(VARCHAR(19), s.LAST_ACTIVE_AT, 120) AS lastActiveAt
                    ,CONVERT(VARCHAR(19), s.EXPIRES_AT, 120) AS expiresAt
                    ,CAST(CASE
                        WHEN @p_current_session IS NOT NULL AND s.ID = @p_current_session THEN 1
                        ELSE 0
                     END AS BIT) AS isCurrentSession
                FROM dbo.ESS_USER_LOGIN_SESSION s
                WHERE s.USER_ID = @p_user_id
                  AND s.IS_ACTIVE = 1
                  AND s.EXPIRES_AT > DATEADD(HOUR, 7, SYSUTCDATETIME())
                ORDER BY
                     CASE WHEN @p_current_session IS NOT NULL AND s.ID = @p_current_session THEN 0 ELSE 1 END
                    ,s.LAST_ACTIVE_AT DESC
                FOR JSON PATH
            )) AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_login_session_revoke_others
(
     @p_user_id         VARCHAR(50)
    ,@p_current_session UNIQUEIDENTIFIER
    ,@bitparam          VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @p_user_id = NULLIF(LTRIM(RTRIM(@p_user_id)), '');
        IF @p_user_id IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002702' AS responseCode, 'user_id is required' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        IF @p_current_session IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002701' AS responseCode, 'current session id is required' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @revoked INT = 0;

        UPDATE dbo.ESS_USER_LOGIN_SESSION
        SET
             IS_ACTIVE = 0
            ,REVOKED_AT = DATEADD(HOUR, 7, SYSUTCDATETIME())
            ,REVOKED_REASON = 'REVOKE_OTHERS'
        WHERE USER_ID = @p_user_id
          AND IS_ACTIVE = 1
          AND ID <> @p_current_session;

        SET @revoked = @@ROWCOUNT;

        SET @bitparam = (
            SELECT
                 '2002702' AS responseCode
                ,'Berhasil keluar dari perangkat lain' AS responseMessage
                ,JSON_QUERY((
                    SELECT
                         @p_user_id AS userId
                        ,CONVERT(VARCHAR(36), @p_current_session) AS currentSessionId
                        ,@revoked AS revokedCount
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT
                 '5002702' AS responseCode
                ,'Gagal keluar dari perangkat lain' AS responseMessage
                ,ERROR_MESSAGE() AS errorDetail
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH;
END
GO

/* =========================================================
   2) AUTH - RESET PASSWORD (by user id) — JANGAN UBAH
   SP: xsp_api_ess_reset_password
   Params: @p_user_id, @bitparam
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_reset_password
    @p_user_id  NVARCHAR(50),
    @bitparam   NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Stub lokal — implementasi resmi ada di DB RBACESS.
    SET @bitparam = (
        SELECT
            '5010001' AS responseCode,
            'Local stub only — use RBACESS SP' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

/* =========================================================
   2b) AUTH - RESET PASSWORD BY EMAIL (endpoint baru)
   SP: xsp_api_ess_reset_password_by_email
   Params: @p_user_id, @p_email, @bitparam
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_reset_password_by_email
(
     @p_user_id  VARCHAR(100)
    ,@p_email    VARCHAR(20)
    ,@bitparam   VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Stub lokal — implementasi resmi ada di DB RBACESS.
    -- Validasi user_id + email, return data { idUser, email } untuk kirim OTP di API.

    SET @bitparam = (
        SELECT
            '5010001' AS responseCode,
            'Local stub only — use RBACESS SP' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

/* =========================================================
   3) AUTH - CHANGE PASSWORD
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_change_password
    @p_user         NVARCHAR(50),
    @p_old_password NVARCHAR(100),
    @p_new_password NVARCHAR(100),
    @bitparam       NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_USER_MAIN
        WHERE ID_USER = @p_user
          AND UPASS   = @p_old_password
    )
    BEGIN
        SET @bitparam = (
            SELECT
                '4002502' AS responseCode,
                'Old password is incorrect' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END

    UPDATE dbo.WEB_USER_MAIN
    SET UPASS = @p_new_password
    WHERE ID_USER = @p_user;

    SET @bitparam = (
        SELECT
            '2002502' AS responseCode,
            'Password changed successfully' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

/* =========================================================
   4) AUTH - USER CHANGE PASSWORD (sudah login / JWT)
   SP: xsp_api_ess_user_change_password
   Params: @p_user_id, @p_current_password, @p_password, @bitparam

   Format UPASS mengikuti sistem lama (login/validate):
     CONVERT(NVARCHAR(32), HASHBYTES('MD5', @pwd))
   Jangan pakai style 2 / hex — UPASS di WEB_USER_MAIN bukan hex.
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_user_change_password
(
     @p_user_id             NVARCHAR(50)
    ,@p_current_password    NVARCHAR(50)
    ,@p_password            NVARCHAR(50)
    ,@bitparam              VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        DECLARE
             @id_user              NVARCHAR(50)
            ,@stored_password      NVARCHAR(255)
            ,@current_password_md5 NVARCHAR(32)
            ,@new_password_md5     NVARCHAR(32)
            ,@tanggal_update       DATETIME;

        SET @id_user = NULL;
        SET @stored_password = NULL;
        SET @tanggal_update = GETDATE();

        SET @p_user_id = NULLIF(LTRIM(RTRIM(@p_user_id)), '');
        SET @p_current_password = NULLIF(LTRIM(RTRIM(@p_current_password)), '');
        SET @p_password = NULLIF(LTRIM(RTRIM(@p_password)), '');

        IF @p_user_id IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002501' AS responseCode, 'User ID wajib diisi' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        IF @p_current_password IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002502' AS responseCode, 'Current password wajib diisi' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        IF @p_password IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002503' AS responseCode, 'Password baru wajib diisi' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* Samakan password lewat plaintext — jangan andalkan hash legacy */
        IF @p_password = @p_current_password
        BEGIN
            SET @bitparam = (
                SELECT
                     '4002504' AS responseCode
                    ,'Password baru tidak boleh sama dengan password lama' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SELECT TOP 1
             @id_user = A.ID_USER
            ,@stored_password = A.UPASS
        FROM POS_SERVER.dbo.WEB_USER_MAIN A
        WHERE A.ID_USER = @p_user_id
        ORDER BY A.ID_USER;

        IF @id_user IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4042500' AS responseCode, 'Account not found' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* Format hash sama seperti login: CONVERT(NVARCHAR(32), HASHBYTES('MD5', ...)) */
        SET @current_password_md5 =
            CONVERT(NVARCHAR(32), HASHBYTES('MD5', @p_current_password));

        SET @new_password_md5 =
            CONVERT(NVARCHAR(32), HASHBYTES('MD5', @p_password));

        IF @stored_password IS NULL
           OR @stored_password <> @current_password_md5
        BEGIN
            SET @bitparam = (
                SELECT
                     '4012500' AS responseCode
                    ,'Current password tidak sesuai' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        UPDATE POS_SERVER.dbo.WEB_USER_MAIN
        SET
             UPASS = @new_password_md5
            ,LAST_LOGIN_DATE = @tanggal_update
        WHERE ID_USER = @id_user
          AND UPASS = @current_password_md5;

        IF @@ROWCOUNT = 0
        BEGIN
            SET @bitparam = (
                SELECT
                     '4092500' AS responseCode
                    ,'Password gagal diupdate karena data telah berubah' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SET @bitparam = (
            SELECT
                 '2002500' AS responseCode
                ,'Password berhasil diupdate' AS responseMessage
                ,JSON_QUERY((
                    SELECT
                         @id_user AS userId
                        ,CONVERT(VARCHAR(19), @tanggal_update, 120) AS updatedDate
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT
                 '5002500' AS responseCode
                ,'Terjadi kesalahan saat mengubah password' AS responseMessage
                ,ERROR_MESSAGE() AS errorDetail
                ,ERROR_NUMBER() AS errorNumber
                ,ERROR_LINE() AS errorLine
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH;
END
GO

/* =========================================================
   5) DASHBOARD INFO (getrow)
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_dashboard_info_getrow
    @p_user   NVARCHAR(50),
    @bitparam NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'OK' AS responseMessage,
            (
                SELECT
                    a.ID_USER  AS userId,
                    a.NAMA     AS userName,
                    a.NIK      AS nik,
                    a.STORE_ID AS storeId
                    -- TODO: tambah ringkasan absensi/izin/cuti hari ini
                FROM dbo.WEB_USER_MAIN a
                WHERE a.ID_USER = @p_user
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    IF @bitparam IS NULL
    BEGIN
        SET @bitparam = (
            SELECT
                '4040000' AS responseCode,
                'Data not found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END
END
GO

/* =========================================================
   6) ATTENDANCE / ABSENSI (getrows)
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_attendance_getrows
    @p_user      NVARCHAR(50),
    @p_date_from DATE = NULL,
    @p_date_to   DATE = NULL,
    @bitparam    NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'OK' AS responseMessage,
            ISNULL((
                SELECT
                    b.TANGGAL     AS tanggal,
                    b.JAM_MASUK   AS jamMasuk,
                    b.JAM_PULANG  AS jamPulang,
                    b.STATUS      AS statusAbsensi
                FROM dbo.ESS_ABSENSI b   -- TODO: sesuaikan nama tabel
                WHERE b.ID_USER = @p_user
                  AND (@p_date_from IS NULL OR b.TANGGAL >= @p_date_from)
                  AND (@p_date_to   IS NULL OR b.TANGGAL <= @p_date_to)
                ORDER BY b.TANGGAL DESC
                FOR JSON PATH
            ), '[]') AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

/* =========================================================
   7) PROFILE GET (getrow)
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_profile_getrow
    @p_user   NVARCHAR(50),
    @bitparam NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'OK' AS responseMessage,
            (
                SELECT
                    a.ID_USER  AS userId,
                    a.NAMA     AS userName,
                    a.NIK      AS nik,
                    a.EMAIL    AS email,
                    a.PHONE    AS phone,
                    a.STORE_ID AS storeId,
                    a.JABATAN  AS jabatan
                FROM dbo.WEB_USER_MAIN a
                WHERE a.ID_USER = @p_user
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );

    IF @bitparam IS NULL OR JSON_VALUE(@bitparam, '$.data') IS NULL
    BEGIN
        SET @bitparam = (
            SELECT
                '4040000' AS responseCode,
                'Profile not found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END
END
GO

/* =========================================================
   8) PROFILE UPDATE
   SP: xsp_api_update_profile_ess
   Params: @p_nik, @p_nick_name, @p_nama_lengkap, @p_email, @p_phone_number, @bitparam
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_update_profile_ess
(
     @p_nik           NVARCHAR(50)
    ,@p_nick_name     NVARCHAR(100) = NULL
    ,@p_nama_lengkap  NVARCHAR(200) = NULL
    ,@p_email         NVARCHAR(150) = NULL
    ,@p_phone_number  NVARCHAR(30)  = NULL
    ,@bitparam        VARCHAR(MAX) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Stub lokal — implementasi resmi ada di DB RBACESS.
    -- Contoh response:
    --   2002600 Profile berhasil diupdate + data
    --   4092600 Email sudah digunakan oleh account lain

    SET @bitparam = (
        SELECT
            '5010001' AS responseCode,
            'Local stub only — use RBACESS SP' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

/* =========================================================
   9) IZIN
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_izin_getrows
    @p_user   NVARCHAR(50),
    @bitparam NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'OK' AS responseMessage,
            ISNULL((
                SELECT
                    i.ID_IZIN     AS idIzin,
                    i.TANGGAL     AS tanggal,
                    i.ALASAN      AS alasan,
                    i.STATUS      AS status
                FROM dbo.ESS_IZIN i   -- TODO: sesuaikan nama tabel
                WHERE i.ID_USER = @p_user
                ORDER BY i.TANGGAL DESC
                FOR JSON PATH
            ), '[]') AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_izin_insert
    @p_user    NVARCHAR(50),
    @p_tanggal DATE,
    @p_alasan  NVARCHAR(500),
    @bitparam  NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ESS_IZIN (ID_USER, TANGGAL, ALASAN, STATUS, CREATED_AT)
    VALUES (@p_user, @p_tanggal, @p_alasan, 'PENDING', GETDATE());

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'Izin created successfully' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_izin_update
    @p_user    NVARCHAR(50),
    @p_id_izin INT,
    @p_tanggal DATE = NULL,
    @p_alasan  NVARCHAR(500) = NULL,
    @p_status  NVARCHAR(30) = NULL,
    @bitparam  NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.ESS_IZIN WHERE ID_IZIN = @p_id_izin AND ID_USER = @p_user)
    BEGIN
        SET @bitparam = (
            SELECT
                '4040000' AS responseCode,
                'Izin not found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END

    UPDATE dbo.ESS_IZIN
    SET
        TANGGAL = ISNULL(@p_tanggal, TANGGAL),
        ALASAN  = ISNULL(@p_alasan, ALASAN),
        STATUS  = ISNULL(@p_status, STATUS)
    WHERE ID_IZIN = @p_id_izin
      AND ID_USER = @p_user;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'Izin updated successfully' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

/* =========================================================
   10) CUTI
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_cuti_getrows
    @p_user   NVARCHAR(50),
    @bitparam NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'OK' AS responseMessage,
            ISNULL((
                SELECT
                    c.ID_CUTI     AS idCuti,
                    c.TGL_MULAI   AS tglMulai,
                    c.TGL_SELESAI AS tglSelesai,
                    c.ALASAN      AS alasan,
                    c.STATUS      AS status
                FROM dbo.ESS_CUTI c   -- TODO: sesuaikan nama tabel
                WHERE c.ID_USER = @p_user
                ORDER BY c.TGL_MULAI DESC
                FOR JSON PATH
            ), '[]') AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_cuti_insert
    @p_user       NVARCHAR(50),
    @p_tgl_mulai  DATE,
    @p_tgl_selesai DATE,
    @p_alasan     NVARCHAR(500),
    @bitparam     NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ESS_CUTI (ID_USER, TGL_MULAI, TGL_SELESAI, ALASAN, STATUS, CREATED_AT)
    VALUES (@p_user, @p_tgl_mulai, @p_tgl_selesai, @p_alasan, 'PENDING', GETDATE());

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'Cuti created successfully' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_cuti_update
    @p_user        NVARCHAR(50),
    @p_id_cuti     INT,
    @p_tgl_mulai   DATE = NULL,
    @p_tgl_selesai DATE = NULL,
    @p_alasan      NVARCHAR(500) = NULL,
    @p_status      NVARCHAR(30) = NULL,
    @bitparam      NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.ESS_CUTI WHERE ID_CUTI = @p_id_cuti AND ID_USER = @p_user)
    BEGIN
        SET @bitparam = (
            SELECT
                '4040000' AS responseCode,
                'Cuti not found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END

    UPDATE dbo.ESS_CUTI
    SET
        TGL_MULAI   = ISNULL(@p_tgl_mulai, TGL_MULAI),
        TGL_SELESAI = ISNULL(@p_tgl_selesai, TGL_SELESAI),
        ALASAN      = ISNULL(@p_alasan, ALASAN),
        STATUS      = ISNULL(@p_status, STATUS)
    WHERE ID_CUTI = @p_id_cuti
      AND ID_USER = @p_user;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'Cuti updated successfully' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

/* =========================================================
   11) LEMBUR
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_lembur_getrows
    @p_user   NVARCHAR(50),
    @bitparam NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'OK' AS responseMessage,
            ISNULL((
                SELECT
                    l.ID_LEMBUR   AS idLembur,
                    l.TANGGAL     AS tanggal,
                    l.JAM_MULAI   AS jamMulai,
                    l.JAM_SELESAI AS jamSelesai,
                    l.ALASAN      AS alasan,
                    l.STATUS      AS status
                FROM dbo.ESS_LEMBUR l   -- TODO: sesuaikan nama tabel
                WHERE l.ID_USER = @p_user
                ORDER BY l.TANGGAL DESC
                FOR JSON PATH
            ), '[]') AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_lembur_insert
    @p_user        NVARCHAR(50),
    @p_tanggal     DATE,
    @p_jam_mulai   TIME,
    @p_jam_selesai TIME,
    @p_alasan      NVARCHAR(500),
    @bitparam      NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ESS_LEMBUR (ID_USER, TANGGAL, JAM_MULAI, JAM_SELESAI, ALASAN, STATUS, CREATED_AT)
    VALUES (@p_user, @p_tanggal, @p_jam_mulai, @p_jam_selesai, @p_alasan, 'PENDING', GETDATE());

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'Lembur created successfully' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_lembur_update
    @p_user        NVARCHAR(50),
    @p_id_lembur   INT,
    @p_tanggal     DATE = NULL,
    @p_jam_mulai   TIME = NULL,
    @p_jam_selesai TIME = NULL,
    @p_alasan      NVARCHAR(500) = NULL,
    @p_status      NVARCHAR(30) = NULL,
    @bitparam      NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.ESS_LEMBUR WHERE ID_LEMBUR = @p_id_lembur AND ID_USER = @p_user)
    BEGIN
        SET @bitparam = (
            SELECT
                '4040000' AS responseCode,
                'Lembur not found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END

    UPDATE dbo.ESS_LEMBUR
    SET
        TANGGAL     = ISNULL(@p_tanggal, TANGGAL),
        JAM_MULAI   = ISNULL(@p_jam_mulai, JAM_MULAI),
        JAM_SELESAI = ISNULL(@p_jam_selesai, JAM_SELESAI),
        ALASAN      = ISNULL(@p_alasan, ALASAN),
        STATUS      = ISNULL(@p_status, STATUS)
    WHERE ID_LEMBUR = @p_id_lembur
      AND ID_USER = @p_user;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'Lembur updated successfully' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

/* =========================================================
   12) DINAS
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_dinas_getrows
    @p_user   NVARCHAR(50),
    @bitparam NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'OK' AS responseMessage,
            ISNULL((
                SELECT
                    d.ID_DINAS     AS idDinas,
                    d.TGL_MULAI    AS tglMulai,
                    d.TGL_SELESAI  AS tglSelesai,
                    d.TUJUAN       AS tujuan,
                    d.KETERANGAN   AS keterangan,
                    d.STATUS       AS status
                FROM dbo.ESS_DINAS d   -- TODO: sesuaikan nama tabel
                WHERE d.ID_USER = @p_user
                ORDER BY d.TGL_MULAI DESC
                FOR JSON PATH
            ), '[]') AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_dinas_insert
    @p_user        NVARCHAR(50),
    @p_tgl_mulai   DATE,
    @p_tgl_selesai DATE,
    @p_tujuan      NVARCHAR(200),
    @p_keterangan  NVARCHAR(500) = NULL,
    @bitparam      NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ESS_DINAS (ID_USER, TGL_MULAI, TGL_SELESAI, TUJUAN, KETERANGAN, STATUS, CREATED_AT)
    VALUES (@p_user, @p_tgl_mulai, @p_tgl_selesai, @p_tujuan, @p_keterangan, 'PENDING', GETDATE());

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'Dinas created successfully' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_dinas_update
    @p_user        NVARCHAR(50),
    @p_id_dinas    INT,
    @p_tgl_mulai   DATE = NULL,
    @p_tgl_selesai DATE = NULL,
    @p_tujuan      NVARCHAR(200) = NULL,
    @p_keterangan  NVARCHAR(500) = NULL,
    @p_status      NVARCHAR(30) = NULL,
    @bitparam      NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.ESS_DINAS WHERE ID_DINAS = @p_id_dinas AND ID_USER = @p_user)
    BEGIN
        SET @bitparam = (
            SELECT
                '4040000' AS responseCode,
                'Dinas not found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END

    UPDATE dbo.ESS_DINAS
    SET
        TGL_MULAI   = ISNULL(@p_tgl_mulai, TGL_MULAI),
        TGL_SELESAI = ISNULL(@p_tgl_selesai, TGL_SELESAI),
        TUJUAN      = ISNULL(@p_tujuan, TUJUAN),
        KETERANGAN  = ISNULL(@p_keterangan, KETERANGAN),
        STATUS      = ISNULL(@p_status, STATUS)
    WHERE ID_DINAS = @p_id_dinas
      AND ID_USER = @p_user;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'Dinas updated successfully' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

/* =========================================================
   13) REKAP
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_rekap_absensi_getrows
    @p_user      NVARCHAR(50),
    @p_date_from DATE = NULL,
    @p_date_to   DATE = NULL,
    @bitparam    NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'OK' AS responseMessage,
            ISNULL((
                SELECT
                    r.PERIODE       AS periode,
                    r.HADIR         AS hadir,
                    r.IZIN          AS izin,
                    r.SAKIT         AS sakit,
                    r.ALPHA         AS alpha,
                    r.TERLAMBAT     AS terlambat
                FROM dbo.ESS_REKAP_ABSENSI r   -- TODO: sesuaikan nama tabel/view
                WHERE r.ID_USER = @p_user
                  AND (@p_date_from IS NULL OR r.PERIODE >= @p_date_from)
                  AND (@p_date_to   IS NULL OR r.PERIODE <= @p_date_to)
                ORDER BY r.PERIODE DESC
                FOR JSON PATH
            ), '[]') AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_rekap_cuti_getrows
    @p_user   NVARCHAR(50),
    @p_tahun  INT = NULL,
    @bitparam NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'OK' AS responseMessage,
            ISNULL((
                SELECT
                    c.TAHUN         AS tahun,
                    c.JATAH_CUTI    AS jatahCuti,
                    c.TERPAKAI      AS terpakai,
                    c.SISA          AS sisa
                FROM dbo.ESS_REKAP_CUTI c   -- TODO: sesuaikan nama tabel/view
                WHERE c.ID_USER = @p_user
                  AND (@p_tahun IS NULL OR c.TAHUN = @p_tahun)
                ORDER BY c.TAHUN DESC
                FOR JSON PATH
            ), '[]') AS data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

/*
  Contoh test login (SP milik DB, bukan dari file ini):

  DECLARE @out VARCHAR(MAX);
  EXEC dbo.xsp_api_ess_login
      @p_uid = N'00003287',
      @p_password = N'password',
      @bitparam = @out OUTPUT;
  SELECT @out AS json_result;
*/
