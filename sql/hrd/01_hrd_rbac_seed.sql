/*
  HRD RBAC seed — RBACESS only (idempotent INSERT / IF NOT EXISTS).
  Default password for new HRD auth users: Hrd@12345
  Hash: SHA2_256 hex of (password_salt + plaintext), same as xsp_ams_new_auth_login / reset_password.
  Shared migration salt below (36 chars, no dashes) so re-seed does not rotate hashes for existing rows.
*/
USE RBACESS;
GO

SET NOCOUNT ON;

/* ------------------------------------------------------------------ Role */
IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Role WHERE role_code = 'HRD')
BEGIN
    INSERT INTO dbo.RBAC_Role (role_code, role_name, scope_level, description, is_system, is_active, created_by)
    VALUES ('HRD', 'HRD Head Office', 'GLOBAL', NULL, 0, 1, 'MIGRATION');
END;
GO

/* ------------------------------------------------------------------ Modules */
DECLARE @mods TABLE (
      module_code          varchar(80)  NOT NULL PRIMARY KEY
    , module_name          varchar(150) NOT NULL
    , parent_module_code   varchar(80)  NULL
    , endpoint_path        varchar(250) NULL
    , sort_no              int          NOT NULL
);

INSERT INTO @mods (module_code, module_name, parent_module_code, endpoint_path, sort_no) VALUES
    /* Top menus + mega columns (endpoint # = folder) */
    ('HRD_ABS', 'Absensi', NULL, '#', 100),
    ('HRD_CAB', 'Benefit', NULL, '#', 200),
    ('HRD_RPT', 'Laporan', NULL, '#', 300),
    ('HRD_PAR', 'Utility', NULL, '#', 400),
    ('HRD_GRP_ATTENDANCE', 'Attendance', 'HRD_ABS', '#', 10),
    ('HRD_GRP_PERSONEL', 'Personel', 'HRD_ABS', '#', 20),
    ('HRD_GRP_GENERATE', 'Generate', 'HRD_ABS', '#', 30),
    ('HRD_GRP_PAYROLL', 'Payroll', 'HRD_CAB', '#', 10),
    ('HRD_GRP_PROCESS', 'Process', 'HRD_CAB', '#', 20),
    ('HRD_GRP_REPORT', 'Report', 'HRD_RPT', '#', 10),
    ('HRD_GRP_SYS_PARAM', 'System Param', 'HRD_PAR', '#', 10),
    ('HRD_GRP_MASTER', 'Master', 'HRD_PAR', '#', 20),
    ('HRD_GRP_EOM', 'End Of Month', 'HRD_PAR', '#', 30),

    /* ATTENDANCE */
    ('HRD_ABS_ONLINE_LIST', 'Online Attendance List', 'HRD_GRP_ATTENDANCE', '/admin/hrd/abs/online-attendance', 10),
    ('HRD_ABS_ALL_ATTENDANCE', 'All Attendance', 'HRD_GRP_ATTENDANCE', '/admin/hrd/abs/all-attendance', 20),
    /* PERSONEL */
    ('HRD_ABS_PERSONEL', 'Personel Info', 'HRD_GRP_PERSONEL', '/admin/hrd/abs/personel', 10),
    ('HRD_ABS_KONTRAK', 'Kontrak', 'HRD_GRP_PERSONEL', '/admin/hrd/abs/personel-kontrak', 20),
    ('HRD_ABS_STATUS', 'Status', 'HRD_GRP_PERSONEL', '/admin/hrd/abs/personel-status', 30),
    ('HRD_ABS_PROMOSI', 'Promosi', 'HRD_GRP_PERSONEL', '/admin/hrd/abs/personel-promosi', 40),
    ('HRD_ABS_MUTASI', 'Mutasi', 'HRD_GRP_PERSONEL', '/admin/hrd/abs/personel-mutasi', 50),
    ('HRD_ABS_RESIGN', 'Pengunduran Diri', 'HRD_GRP_PERSONEL', '/admin/hrd/abs/personel-resign', 60),
    /* GENERATE */
    ('HRD_ABS_GENERATE_STORE', 'Absen Store', 'HRD_GRP_GENERATE', '/admin/hrd/abs/generate-store', 10),
    ('HRD_ABS_GENERATE_NASIONAL', 'Absen Nasional', 'HRD_GRP_GENERATE', '/admin/hrd/abs/generate-nasional', 20),
    /* System Param */
    ('HRD_PAR_ADHOC', 'Special Activity', 'HRD_GRP_SYS_PARAM', '/admin/hrd/par/adhoc', 10),
    ('HRD_PAR_DINAS', 'Dinas', 'HRD_GRP_SYS_PARAM', '/admin/hrd/par/dinas', 20),
    ('HRD_PAR_IZIN', 'Izin', 'HRD_GRP_SYS_PARAM', '/admin/hrd/par/izin', 30),
    ('HRD_PAR_CUTI', 'Cuti', 'HRD_GRP_SYS_PARAM', '/admin/hrd/par/cuti', 40),
    ('HRD_PAR_SAKIT', 'Sakit', 'HRD_GRP_SYS_PARAM', '/admin/hrd/par/sakit', 50),
    ('HRD_PAR_OVERTIME', 'Overtime', 'HRD_GRP_SYS_PARAM', '/admin/hrd/par/overtime', 60),
    ('HRD_PAR_ALFA', 'Alfa', 'HRD_GRP_SYS_PARAM', '/admin/hrd/par/alfa', 70),
    ('HRD_PAR_HOLIDAY', 'Master Holiday', 'HRD_GRP_SYS_PARAM', '/admin/hrd/par/holiday', 80),
    ('HRD_PAR_OT_AMOUNT', 'Master Overtime Amount', 'HRD_GRP_SYS_PARAM', '/admin/hrd/par/overtime-amount', 90),
    ('HRD_PAR_POLICY', 'Policy', 'HRD_GRP_SYS_PARAM', '/admin/hrd/par/policy', 100),
    /* MASTER */
    ('HRD_PAR_PERUSAHAAN', 'Perusahaan', 'HRD_GRP_MASTER', '/admin/hrd/par/perusahaan', 10),
    ('HRD_PAR_CABANG', 'Cabang', 'HRD_GRP_MASTER', '/admin/hrd/par/cabang', 20),
    ('HRD_PAR_DIVISI', 'Divisi', 'HRD_GRP_MASTER', '/admin/hrd/par/divisi', 30),
    ('HRD_PAR_DEPARTEMEN', 'Departemen', 'HRD_GRP_MASTER', '/admin/hrd/par/departemen', 40),
    ('HRD_PAR_GOLONGAN', 'Golongan', 'HRD_GRP_MASTER', '/admin/hrd/par/golongan', 50),
    ('HRD_PAR_PANGKAT', 'Pangkat', 'HRD_GRP_MASTER', '/admin/hrd/par/pangkat', 60),
    ('HRD_PAR_JABATAN', 'Jabatan', 'HRD_GRP_MASTER', '/admin/hrd/par/jabatan', 70),
    ('HRD_PAR_SM_DEPT', 'SM Department List', 'HRD_GRP_MASTER', '/admin/hrd/par/sm-dept', 80),
    /* End Of Month */
    ('HRD_PAR_EOM', 'End Of Month', 'HRD_GRP_EOM', '/admin/hrd/par/eom', 10),
    /* REPORT */
    ('HRD_RPT_ABSEN_WFH', 'Absen WFH', 'HRD_GRP_REPORT', '/admin/hrd/rpt/absen-wfh', 10),
    ('HRD_RPT_ABSEN_TOTAL', 'Absen Report', 'HRD_GRP_REPORT', '/admin/hrd/rpt/absen-total', 20),
    ('HRD_RPT_ABSEN_NASIONAL', 'Absen Nasional', 'HRD_GRP_REPORT', '/admin/hrd/rpt/absen-nasional', 30),
    ('HRD_RPT_CUTI', 'Info Cuti', 'HRD_GRP_REPORT', '/admin/hrd/rpt/cuti', 40),
    ('HRD_RPT_LEMBUR', 'Lembur', 'HRD_GRP_REPORT', '/admin/hrd/rpt/lembur', 50),
    ('HRD_RPT_SLIP_GAJI', 'Slip Gaji', 'HRD_GRP_REPORT', '/admin/hrd/rpt/slip-gaji', 60),
    ('HRD_RPT_EXPORT_EMP', 'Export Data Karyawan', 'HRD_GRP_REPORT', '/admin/hrd/rpt/export-employee', 70),
    ('HRD_RPT_DETAIL_HADIR', 'Detail Kehadiran', 'HRD_GRP_REPORT', '/admin/hrd/rpt/detail-kehadiran', 80),
    ('HRD_RPT_KPI', 'KPI - Karyawan', 'HRD_GRP_REPORT', '/admin/hrd/rpt/kpi', 90),
    /* Payroll */
    ('HRD_CAB_VARIABLE', 'Payroll Variable', 'HRD_GRP_PAYROLL', '/admin/hrd/cab/variable', 10),
    ('HRD_CAB_FORMULA', 'Payroll Formula', 'HRD_GRP_PAYROLL', '/admin/hrd/cab/formula', 20),
    ('HRD_CAB_BENEFIT', 'Benefit', 'HRD_GRP_PAYROLL', '/admin/hrd/cab/benefit', 30),
    ('HRD_CAB_DEDUCTION', 'Deduction', 'HRD_GRP_PAYROLL', '/admin/hrd/cab/deduction', 40),
    ('HRD_CAB_SALARY_ENTRY', 'Payroll Salary Entry', 'HRD_GRP_PAYROLL', '/admin/hrd/cab/salary-entry', 50),
    ('HRD_CAB_SALARY_INQUIRY', 'Payroll Inquiry', 'HRD_GRP_PAYROLL', '/admin/hrd/cab/salary-inquiry', 60),
    ('HRD_CAB_SALARY_REPORT', 'Salary Report', 'HRD_GRP_PAYROLL', '/admin/hrd/cab/salary-report', 70),
    ('HRD_CAB_THR', 'THR Generate', 'HRD_GRP_PAYROLL', '/admin/hrd/cab/thr', 80),
    /* Process */
    ('HRD_CAB_MONTHLY', 'Monthly Payroll', 'HRD_GRP_PROCESS', '/admin/hrd/cab/monthly-process', 10),
    ('HRD_CAB_PAYMENT', 'Payment Request', 'HRD_GRP_PROCESS', '/admin/hrd/cab/payment-request', 20);

INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT m.module_code, m.module_name, m.parent_module_code, m.endpoint_path, m.sort_no, 1, 'MIGRATION'
FROM @mods AS m
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = m.module_code);
GO

/* ------------------------------------------------------------------ Role permissions (HRD role × all HRD_* modules × VIEW,CREATE,UPDATE,DELETE,EXPORT) */
DECLARE @hrd_role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'HRD');

INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @hrd_role_id, m.module_id, p.permission_id, 1, 'MIGRATION'
FROM dbo.RBAC_Module AS m
CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code LIKE 'HRD[_]%'
  AND p.permission_code IN ('VIEW', 'CREATE', 'UPDATE', 'DELETE', 'EXPORT')
  AND @hrd_role_id IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.RBAC_RolePermission AS rp
        WHERE rp.role_id = @hrd_role_id
          AND rp.module_id = m.module_id
          AND rp.permission_id = p.permission_id
    );
GO

/* ------------------------------------------------------------------ HRD users */
DECLARE @users TABLE (nik varchar(30) NOT NULL PRIMARY KEY);
INSERT INTO @users (nik) VALUES
    ('DAMARHRD'), ('DELLAHRD'), ('DHIKAHRD'), ('FEBBYHRD'), ('LAURAHRD'), ('LINAHRD'),
    ('LINDAHRD'), ('LUSIHRD'), ('NADIAHRD'), ('REGITAHRD'), ('RIFKIHRD2'), ('RIOHRD'), ('SUCIHRD');

DECLARE @migration_salt varchar(80) = 'a1b2c3d4e5f6478990ab12cd34ef567890';
DECLARE @migration_pwd  varchar(200) = 'Hrd@12345';
DECLARE @migration_hash varchar(64) = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @migration_salt + @migration_pwd)), 2);

INSERT INTO dbo.RBAC_Employee (nik, employee_name, employee_type, is_active, created_by)
SELECT u.nik, u.nik, 'HRD', 1, 'MIGRATION'
FROM @users AS u
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Employee AS e WHERE e.nik = u.nik);

INSERT INTO dbo.RBAC_AuthUser (username, nik, password_salt, password_hash, is_active, failed_login_count, locked_until, force_change_password, created_by)
SELECT u.nik, u.nik, @migration_salt, @migration_hash, 1, 0, NULL, 1, 'MIGRATION'
FROM @users AS u
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_AuthUser AS a WHERE a.nik = u.nik);

DECLARE @hrd_role_id2 int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'HRD');

INSERT INTO dbo.RBAC_UserRole (nik, role_id, branch_id, store_id, is_active, created_by)
SELECT u.nik, @hrd_role_id2, NULL, NULL, 1, 'MIGRATION'
FROM @users AS u
WHERE @hrd_role_id2 IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.RBAC_UserRole AS ur
        WHERE ur.nik = u.nik
          AND ur.role_id = @hrd_role_id2
          AND ur.branch_id IS NULL
          AND ur.store_id IS NULL
    );
GO

PRINT '01_hrd_rbac_seed.sql completed.';
GO
