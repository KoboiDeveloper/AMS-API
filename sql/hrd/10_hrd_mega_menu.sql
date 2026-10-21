/*
  HRD mega menu — group folders under root HRD (idempotent).
  Admin can rearrange anytime via Security → Module (parent_module_code + sort_no).
  Empty / '#' endpoint_path = menu folder / mega column (not a page).
*/
USE RBACESS;
GO

SET NOCOUNT ON;

/* ------------------------------------------------------------------ Root + group folders */
DECLARE @folders TABLE (
      module_code          varchar(80)  NOT NULL PRIMARY KEY
    , module_name          varchar(150) NOT NULL
    , parent_module_code   varchar(80)  NULL
    , endpoint_path        varchar(250) NULL
    , sort_no              int          NOT NULL
);

INSERT INTO @folders (module_code, module_name, parent_module_code, endpoint_path, sort_no) VALUES
    ('HRD',                  'HRD',            NULL,  '#', 90),
    ('HRD_GRP_ATTENDANCE',   'ATTENDANCE',     'HRD', '#', 10),
    ('HRD_GRP_PERSONEL',     'PERSONEL',       'HRD', '#', 20),
    ('HRD_GRP_GENERATE',     'GENERATE',       'HRD', '#', 30),
    ('HRD_GRP_PAYROLL',      'Payroll',        'HRD', '#', 40),
    ('HRD_GRP_PROCESS',      'Process',        'HRD', '#', 50),
    ('HRD_GRP_REPORT',       'REPORT',         'HRD', '#', 60),
    ('HRD_GRP_SYS_PARAM',    'System Param',   'HRD', '#', 70),
    ('HRD_GRP_MASTER',       'MASTER',         'HRD', '#', 80),
    ('HRD_GRP_EOM',          'End Of Month',   'HRD', '#', 90);

INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT f.module_code, f.module_name, f.parent_module_code, f.endpoint_path, f.sort_no, 1, 'MIGRATION'
FROM @folders AS f
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = f.module_code);

/* Keep folder names / parents / sort in sync on re-run */
UPDATE m
SET
    m.module_name = f.module_name,
    m.parent_module_code = f.parent_module_code,
    m.endpoint_path = f.endpoint_path,
    m.sort_no = f.sort_no,
    m.is_active = 1,
    m.updated_by = 'MIGRATION',
    m.updated_at = SYSUTCDATETIME()
FROM dbo.RBAC_Module AS m
INNER JOIN @folders AS f ON f.module_code = m.module_code;
GO

/* ------------------------------------------------------------------ Reparent leaves + titles */
DECLARE @leaves TABLE (
      module_code          varchar(80)  NOT NULL PRIMARY KEY
    , module_name          varchar(150) NOT NULL
    , parent_module_code   varchar(80)  NOT NULL
    , sort_no              int          NOT NULL
);

INSERT INTO @leaves (module_code, module_name, parent_module_code, sort_no) VALUES
    /* ATTENDANCE */
    ('HRD_ABS_ONLINE_LIST',       'ONLINE ATTENDANCE LIST', 'HRD_GRP_ATTENDANCE', 10),
    ('HRD_ABS_ALL_ATTENDANCE',    'ALL ATTENDANCE',         'HRD_GRP_ATTENDANCE', 20),
    /* PERSONEL */
    ('HRD_ABS_PERSONEL',          'PERSONEL INFO',          'HRD_GRP_PERSONEL',   10),
    ('HRD_ABS_KONTRAK',           'KONTRAK',                'HRD_GRP_PERSONEL',   20),
    ('HRD_ABS_STATUS',            'STATUS',                 'HRD_GRP_PERSONEL',   30),
    ('HRD_ABS_PROMOSI',           'PROMOSI',                'HRD_GRP_PERSONEL',   40),
    ('HRD_ABS_MUTASI',            'MUTASI',                 'HRD_GRP_PERSONEL',   50),
    ('HRD_ABS_RESIGN',            'PENGUNDURAN DIRI',       'HRD_GRP_PERSONEL',   60),
    /* GENERATE */
    ('HRD_ABS_GENERATE_STORE',    'ABSEN STORE',            'HRD_GRP_GENERATE',   10),
    ('HRD_ABS_GENERATE_NASIONAL', 'ABSEN NASIONAL',         'HRD_GRP_GENERATE',   20),
    /* Payroll */
    ('HRD_CAB_VARIABLE',          'Payroll Variable',       'HRD_GRP_PAYROLL',    10),
    ('HRD_CAB_FORMULA',           'Payroll Formula',        'HRD_GRP_PAYROLL',    20),
    ('HRD_CAB_BENEFIT',           'Benefit',                'HRD_GRP_PAYROLL',    30),
    ('HRD_CAB_DEDUCTION',         'Deduction',              'HRD_GRP_PAYROLL',    40),
    ('HRD_CAB_SALARY_ENTRY',      'Payroll Salary Entry',   'HRD_GRP_PAYROLL',    50),
    ('HRD_CAB_SALARY_INQUIRY',    'Payroll Inquery',        'HRD_GRP_PAYROLL',    60),
    ('HRD_CAB_SALARY_REPORT',     'Salary Report',          'HRD_GRP_PAYROLL',    70),
    ('HRD_CAB_THR',               'THR Generate',           'HRD_GRP_PAYROLL',    80),
    /* Process */
    ('HRD_CAB_MONTHLY',           'Monthly Payroll',        'HRD_GRP_PROCESS',    10),
    ('HRD_CAB_PAYMENT',           'Payment Request',        'HRD_GRP_PROCESS',    20),
    /* REPORT */
    ('HRD_RPT_ABSEN_WFH',         'ABSEN WFH',              'HRD_GRP_REPORT',     10),
    ('HRD_RPT_ABSEN_TOTAL',       'ABSEN REPORT',           'HRD_GRP_REPORT',     20),
    ('HRD_RPT_ABSEN_NASIONAL',    'ABSEN NASIONAL',         'HRD_GRP_REPORT',     30),
    ('HRD_RPT_CUTI',              'INFO CUTI',              'HRD_GRP_REPORT',     40),
    ('HRD_RPT_LEMBUR',            'LEMBUR',                 'HRD_GRP_REPORT',     50),
    ('HRD_RPT_SLIP_GAJI',         'SLIP GAJI',              'HRD_GRP_REPORT',     60),
    ('HRD_RPT_EXPORT_EMP',        'EXPORT DATA KARYAWAN',   'HRD_GRP_REPORT',     70),
    ('HRD_RPT_DETAIL_HADIR',      'DETAIL KEHADIRAN',       'HRD_GRP_REPORT',     80),
    ('HRD_RPT_KPI',               'KPI - KARYAWAN',         'HRD_GRP_REPORT',     90),
    /* System Param */
    ('HRD_PAR_ADHOC',             'SPECIAL ACTIVITY',       'HRD_GRP_SYS_PARAM',  10),
    ('HRD_PAR_DINAS',             'DINAS',                  'HRD_GRP_SYS_PARAM',  20),
    ('HRD_PAR_IZIN',              'IZIN',                   'HRD_GRP_SYS_PARAM',  30),
    ('HRD_PAR_CUTI',              'CUTI',                   'HRD_GRP_SYS_PARAM',  40),
    ('HRD_PAR_SAKIT',             'SAKIT',                  'HRD_GRP_SYS_PARAM',  50),
    ('HRD_PAR_OVERTIME',          'OVERTIME',               'HRD_GRP_SYS_PARAM',  60),
    ('HRD_PAR_ALFA',              'ALFA',                   'HRD_GRP_SYS_PARAM',  70),
    ('HRD_PAR_HOLIDAY',           'MASTER HOLIDAY',         'HRD_GRP_SYS_PARAM',  80),
    ('HRD_PAR_OT_AMOUNT',         'MASTER OVERTIME AMOUNT', 'HRD_GRP_SYS_PARAM',  90),
    ('HRD_PAR_POLICY',            'POLICY',                 'HRD_GRP_SYS_PARAM', 100),
    /* MASTER */
    ('HRD_PAR_PERUSAHAAN',        'PERUSAHAAN',             'HRD_GRP_MASTER',     10),
    ('HRD_PAR_CABANG',            'CABANG',                 'HRD_GRP_MASTER',     20),
    ('HRD_PAR_DIVISI',            'DIVISI',                 'HRD_GRP_MASTER',     30),
    ('HRD_PAR_DEPARTEMEN',        'DEPARTEMEN',             'HRD_GRP_MASTER',     40),
    ('HRD_PAR_GOLONGAN',          'GOLONGAN',               'HRD_GRP_MASTER',     50),
    ('HRD_PAR_PANGKAT',           'PANGKAT',                'HRD_GRP_MASTER',     60),
    ('HRD_PAR_JABATAN',           'JABATAN',                'HRD_GRP_MASTER',     70),
    ('HRD_PAR_SM_DEPT',           'SM DEPARTMENT LIST',     'HRD_GRP_MASTER',     80),
    /* End Of Month */
    ('HRD_PAR_EOM',               'End Of Month',           'HRD_GRP_EOM',        10);

UPDATE m
SET
    m.module_name = l.module_name,
    m.parent_module_code = l.parent_module_code,
    m.sort_no = l.sort_no,
    m.is_active = 1,
    m.updated_by = 'MIGRATION',
    m.updated_at = SYSUTCDATETIME()
FROM dbo.RBAC_Module AS m
INNER JOIN @leaves AS l ON l.module_code = m.module_code;
GO

/* ------------------------------------------------------------------ Hide legacy 4-bucket parents from menu */
UPDATE dbo.RBAC_Module
SET
    is_active = 0,
    updated_by = 'MIGRATION',
    updated_at = SYSUTCDATETIME()
WHERE module_code IN ('HRD_ABS', 'HRD_PAR', 'HRD_RPT', 'HRD_CAB')
  AND is_active = 1;
GO

/* ------------------------------------------------------------------ Permissions for new folders */
DECLARE @hrd_role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'HRD');

INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @hrd_role_id, m.module_id, p.permission_id, 1, 'MIGRATION'
FROM dbo.RBAC_Module AS m
CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code IN (
        'HRD',
        'HRD_GRP_ATTENDANCE', 'HRD_GRP_PERSONEL', 'HRD_GRP_GENERATE',
        'HRD_GRP_PAYROLL', 'HRD_GRP_PROCESS', 'HRD_GRP_REPORT',
        'HRD_GRP_SYS_PARAM', 'HRD_GRP_MASTER', 'HRD_GRP_EOM'
    )
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

PRINT '10_hrd_mega_menu.sql completed.';
GO
