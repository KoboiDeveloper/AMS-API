/*
  HRD Dashboard summary + RBAC menu HRD_DASHBOARD.
  SP: xsp_ams_new_hrd_dashboard_summary_getrow
*/
USE RBACESS;
GO

SET NOCOUNT ON;

/* ------------------------------------------------------------------ RBAC module */
IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module WHERE module_code = 'HRD_DASHBOARD')
BEGIN
    INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
    VALUES ('HRD_DASHBOARD', 'Dashboard', NULL, '/admin/hrd/dashboard', 50, 1, 'MIGRATION');
END
ELSE
BEGIN
    UPDATE dbo.RBAC_Module
    SET module_name = 'Dashboard',
        parent_module_code = NULL,
        endpoint_path = '/admin/hrd/dashboard',
        sort_no = 50,
        is_active = 1,
        updated_by = 'MIGRATION',
        updated_at = SYSUTCDATETIME()
    WHERE module_code = 'HRD_DASHBOARD';
END;
GO

DECLARE @hrd_role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'HRD');

INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @hrd_role_id, m.module_id, p.permission_id, 1, 'MIGRATION'
FROM dbo.RBAC_Module AS m
CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code = 'HRD_DASHBOARD'
  AND p.permission_code IN ('VIEW', 'CREATE', 'UPDATE', 'DELETE', 'EXPORT')
  AND @hrd_role_id IS NOT NULL
  AND NOT EXISTS (
        SELECT 1 FROM dbo.RBAC_RolePermission AS rp
        WHERE rp.role_id = @hrd_role_id AND rp.module_id = m.module_id AND rp.permission_id = p.permission_id
    );
GO

/* ------------------------------------------------------------------ SP */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_dashboard_summary_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_dashboard_summary_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_dashboard_summary_getrow
(
      @p_id_brand varchar(50) = NULL
    , @p_id_cabang varchar(50) = NULL
    , @p_days_kontrak varchar(10) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @today date = CAST(GETDATE() AS date);
        DECLARE @days int = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_days_kontrak, ''))), '') AS int);
        IF @days IS NULL OR @days <= 0 SET @days = 30;
        DECLARE @brand varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_id_brand, ''))), '');
        DECLARE @cabang varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_id_cabang, ''))), '');
        DECLARE @monthStart date = DATEFROMPARTS(YEAR(@today), MONTH(@today), 1);
        DECLARE @monthEnd date = EOMONTH(@today);
        DECLARE @from7 date = DATEADD(day, -6, @today);
        DECLARE @kontrakUntil date = DATEADD(day, @days, @today);

        DECLARE @active_headcount int = 0;
        DECLARE @join_this_month int = 0;
        DECLARE @resign_this_month int = 0;
        DECLARE @present_today int = 0;
        DECLARE @late_today int = 0;
        DECLARE @absent_today int = 0;
        DECLARE @pending_izin int = 0;
        DECLARE @pending_cuti int = 0;
        DECLARE @pending_sakit int = 0;
        DECLARE @pending_dinas int = 0;
        DECLARE @pending_ot int = 0;
        DECLARE @kontrak_count int = 0;
        DECLARE @att7 nvarchar(max) = N'[]';
        DECLARE @kontrak_json nvarchar(max) = N'[]';

        /* Active headcount (+ optional brand/cabang via penempatan) */
        SELECT @active_headcount = COUNT(DISTINCT t1.PegawaiIDLng)
        FROM hris.dbo.tblpegawai t1 WITH (NOLOCK)
        LEFT JOIN hris.dbo.tblpegawaipenempatan t6 WITH (NOLOCK) ON t1.PegawaiIDLng = t6.PegawaiIDLng
        LEFT JOIN hris.dbo.tblkantorcabang t7 WITH (NOLOCK) ON t6.KantorCabangIDLng = t7.KantorCabangIDLng
        LEFT JOIN hris.dbo.tblfixbrand t8 WITH (NOLOCK) ON t7.BrandIDLng = t8.BrandIDLng
        WHERE t1.PegawaiNonAktifInt = 0
          AND (@brand IS NULL OR t8.BrandStr = @brand OR CAST(t8.BrandIDLng AS varchar(50)) = @brand)
          AND (@cabang IS NULL OR CAST(t7.KantorCabangIDLng AS varchar(50)) = @cabang OR t7.NamaKantorCabangStr LIKE '%' + @cabang + '%');

        SELECT @join_this_month = COUNT(*)
        FROM hris.dbo.tblpegawai t1 WITH (NOLOCK)
        WHERE t1.PegawaiNonAktifInt = 0
          AND t1.TanggalMulaiAktifDtd >= @monthStart
          AND t1.TanggalMulaiAktifDtd < DATEADD(day, 1, @monthEnd);

        SELECT @resign_this_month = COUNT(DISTINCT rs.PegawaiIDLng)
        FROM hris.dbo.tblpersonnelresignheader rs WITH (NOLOCK)
        WHERE rs.TanggalEfektifDtd >= @monthStart
          AND rs.TanggalEfektifDtd < DATEADD(day, 1, @monthEnd);

        /* Attendance today: distinct NIK with Masuk (Jenis=M) */
        IF OBJECT_ID(N'pos_server.dbo.DT_ABSENSI', N'U') IS NOT NULL
        BEGIN
            SELECT @present_today = COUNT(DISTINCT a.User_NIK)
            FROM pos_server.dbo.DT_ABSENSI a WITH (NOLOCK)
            WHERE CONVERT(date, a.Waktu) = @today
              AND (a.Jenis = 'M' OR a.Jenis IS NULL OR a.Jenis = '');

            /* Late: first Masuk after 09:00 */
            ;WITH first_in AS (
                SELECT a.User_NIK, MIN(a.Waktu) AS first_waktu
                FROM pos_server.dbo.DT_ABSENSI a WITH (NOLOCK)
                WHERE CONVERT(date, a.Waktu) = @today
                  AND a.Jenis = 'M'
                GROUP BY a.User_NIK
            )
            SELECT @late_today = COUNT(*)
            FROM first_in
            WHERE CAST(first_waktu AS time) > '09:00:00';

            SET @absent_today = CASE WHEN @active_headcount > @present_today THEN @active_headcount - @present_today ELSE 0 END;

            ;WITH days AS (
                SELECT @from7 AS d
                UNION ALL SELECT DATEADD(day, 1, d) FROM days WHERE d < @today
            ),
            counts AS (
                SELECT CONVERT(date, a.Waktu) AS d, COUNT(DISTINCT a.User_NIK) AS present_count
                FROM pos_server.dbo.DT_ABSENSI a WITH (NOLOCK)
                WHERE CONVERT(date, a.Waktu) BETWEEN @from7 AND @today
                  AND (a.Jenis = 'M' OR a.Jenis IS NULL OR a.Jenis = '')
                GROUP BY CONVERT(date, a.Waktu)
            )
            SELECT @att7 = (
                SELECT CONVERT(varchar(10), days.d, 23) AS [date],
                       ISNULL(c.present_count, 0) AS present_count
                FROM days
                LEFT JOIN counts c ON c.d = days.d
                ORDER BY days.d
                FOR JSON PATH
            )
            OPTION (MAXRECURSION 10);
        END;

        /* Pending approvals */
        IF OBJECT_ID(N'hris.dbo.WEB_REKAP_IZIN', N'U') IS NOT NULL
        BEGIN
            SELECT @pending_izin = COUNT(*)
            FROM hris.dbo.WEB_REKAP_IZIN WITH (NOLOCK)
            WHERE (STATUS IS NULL OR STATUS IN ('NEW'))
              AND ISNULL(KATEGORI, '') NOT LIKE '%sakit%';

            SELECT @pending_sakit = COUNT(*)
            FROM hris.dbo.WEB_REKAP_IZIN WITH (NOLOCK)
            WHERE (STATUS IS NULL OR STATUS IN ('NEW'))
              AND ISNULL(KATEGORI, '') LIKE '%sakit%';
        END;

        IF OBJECT_ID(N'hris.dbo.WEB_REKAP_CUTI', N'U') IS NOT NULL
        BEGIN
            SELECT @pending_cuti = COUNT(*)
            FROM hris.dbo.WEB_REKAP_CUTI WITH (NOLOCK)
            WHERE STATUS IS NULL OR STATUS IN ('NEW');
        END;

        IF OBJECT_ID(N'hris.dbo.WEB_REKAP_DINAS', N'U') IS NOT NULL
        BEGIN
            SELECT @pending_dinas = COUNT(*)
            FROM hris.dbo.WEB_REKAP_DINAS WITH (NOLOCK)
            WHERE STATUS IS NULL OR STATUS IN ('NEW', 'NEW TRANSACTION');
        END;

        IF OBJECT_ID(N'hris.dbo.WEB_OVERTIME', N'U') IS NOT NULL
        BEGIN
            SELECT @pending_ot = COUNT(*)
            FROM hris.dbo.WEB_OVERTIME WITH (NOLOCK)
            WHERE STATUS IS NULL OR STATUS IN ('NEW');
        END;

        /* Kontrak expiring */
        ;WITH expiring AS (
            SELECT
                t1.PersonnelKontrakIDLng AS id,
                t2.NomorIndukStr AS nik,
                t2.NamaLengkapStr AS employee_name,
                CONVERT(varchar(10), t1.TanggalBerakhirDtd, 23) AS tanggal_berakhir,
                t8.BrandStr AS brand,
                t7.NamaKantorCabangStr AS branch_name,
                ROW_NUMBER() OVER (ORDER BY t1.TanggalBerakhirDtd, t1.PersonnelKontrakIDLng) AS rn
            FROM hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
            INNER JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng = t2.PegawaiIDLng AND t2.PegawaiNonAktifInt = 0
            LEFT JOIN hris.dbo.tblkantorcabang t7 WITH (NOLOCK) ON t1.KantorCabangIDLng = t7.KantorCabangIDLng
            LEFT JOIN hris.dbo.tblfixbrand t8 WITH (NOLOCK) ON t7.BrandIDLng = t8.BrandIDLng
            WHERE t1.TanggalBerakhirDtd IS NOT NULL
              AND t1.TanggalBerakhirDtd >= @today
              AND t1.TanggalBerakhirDtd <= @kontrakUntil
              AND (@brand IS NULL OR t8.BrandStr = @brand OR CAST(t8.BrandIDLng AS varchar(50)) = @brand)
              AND (@cabang IS NULL OR CAST(t7.KantorCabangIDLng AS varchar(50)) = @cabang)
        )
        SELECT @kontrak_count = COUNT(*) FROM expiring;

        ;WITH expiring AS (
            SELECT
                t1.PersonnelKontrakIDLng AS id,
                t2.NomorIndukStr AS nik,
                t2.NamaLengkapStr AS employee_name,
                CONVERT(varchar(10), t1.TanggalBerakhirDtd, 23) AS tanggal_berakhir,
                t8.BrandStr AS brand,
                t7.NamaKantorCabangStr AS branch_name,
                ROW_NUMBER() OVER (ORDER BY t1.TanggalBerakhirDtd, t1.PersonnelKontrakIDLng) AS rn
            FROM hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
            INNER JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng = t2.PegawaiIDLng AND t2.PegawaiNonAktifInt = 0
            LEFT JOIN hris.dbo.tblkantorcabang t7 WITH (NOLOCK) ON t1.KantorCabangIDLng = t7.KantorCabangIDLng
            LEFT JOIN hris.dbo.tblfixbrand t8 WITH (NOLOCK) ON t7.BrandIDLng = t8.BrandIDLng
            WHERE t1.TanggalBerakhirDtd IS NOT NULL
              AND t1.TanggalBerakhirDtd >= @today
              AND t1.TanggalBerakhirDtd <= @kontrakUntil
              AND (@brand IS NULL OR t8.BrandStr = @brand OR CAST(t8.BrandIDLng AS varchar(50)) = @brand)
              AND (@cabang IS NULL OR CAST(t7.KantorCabangIDLng AS varchar(50)) = @cabang)
        )
        SELECT @kontrak_json = ISNULL((
            SELECT id, nik, employee_name, tanggal_berakhir, brand, branch_name
            FROM expiring WHERE rn <= 10
            ORDER BY rn
            FOR JSON PATH
        ), N'[]');

        SET @bitparam = (
            SELECT
                '2002500' AS responseCode,
                'success' AS responseMessage,
                JSON_QUERY((
                    SELECT
                        CONVERT(varchar(10), @today, 23) AS as_of,
                        @active_headcount AS active_headcount,
                        @join_this_month AS join_this_month,
                        @resign_this_month AS resign_this_month,
                        JSON_QUERY((
                            SELECT
                                @present_today AS present,
                                @late_today AS late,
                                @absent_today AS absent_or_missing
                            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                        )) AS attendance_today,
                        JSON_QUERY(ISNULL(@att7, N'[]')) AS attendance_7d,
                        JSON_QUERY((
                            SELECT
                                @pending_izin AS izin,
                                @pending_cuti AS cuti,
                                @pending_sakit AS sakit,
                                @pending_dinas AS dinas,
                                @pending_ot AS overtime,
                                (@pending_izin + @pending_cuti + @pending_sakit + @pending_dinas + @pending_ot) AS total
                            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                        )) AS pending,
                        @kontrak_count AS kontrak_expiring_count,
                        @days AS kontrak_expiring_days,
                        JSON_QUERY(ISNULL(@kontrak_json, N'[]')) AS kontrak_expiring
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH
END
GO

PRINT '13_hrd_dashboard_summary.sql completed.';
GO
