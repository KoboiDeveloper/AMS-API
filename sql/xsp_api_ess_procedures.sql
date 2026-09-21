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
   2) AUTH - RESET PASSWORD
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_reset_password
    @p_user     NVARCHAR(50),
    @p_email    NVARCHAR(150) = NULL,
    @bitparam   NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_USER_MAIN WHERE ID_USER = @p_user)
    BEGIN
        SET @bitparam = (
            SELECT
                '4002501' AS responseCode,
                'User not found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END

    -- TODO: generate temporary password / token reset sesuai aturan bisnis
    SET @bitparam = (
        SELECT
            '2002501' AS responseCode,
            'Reset password request success' AS responseMessage,
            @p_user AS userId
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
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_user_change_password
     @p_user_id             NVARCHAR(50)
    ,@p_current_password    NVARCHAR(50)
    ,@p_password            NVARCHAR(50)
    ,@bitparam              VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Stub lokal — implementasi resmi ada di DB RBCA.
    -- Contoh response:
    --   4012500 Current password tidak sesuai
    --   4002504 Password baru tidak boleh sama dengan password lama
    --   2002500 Password berhasil diupdate + data { userId, updatedDate }

    SET @bitparam = (
        SELECT
            '5010001' AS responseCode,
            'Local stub only — use RBCA SP' AS responseMessage
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
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
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.xsp_api_ess_profile_update
    @p_user   NVARCHAR(50),
    @p_email  NVARCHAR(150) = NULL,
    @p_phone  NVARCHAR(30)  = NULL,
    @bitparam NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_USER_MAIN WHERE ID_USER = @p_user)
    BEGIN
        SET @bitparam = (
            SELECT
                '4040000' AS responseCode,
                'User not found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END

    UPDATE dbo.WEB_USER_MAIN
    SET
        EMAIL = ISNULL(@p_email, EMAIL),
        PHONE = ISNULL(@p_phone, PHONE)
    WHERE ID_USER = @p_user;

    SET @bitparam = (
        SELECT
            '2000000' AS responseCode,
            'Profile updated successfully' AS responseMessage
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
