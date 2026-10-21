/*
  HRD top menus: Absensi / Benefit / Laporan / Utility (not single HRD).
  Group folders stay as mega columns under each top. Idempotent.
*/
USE RBACESS;
GO

SET NOCOUNT ON;

/* ------------------------------------------------------------------ Top-level menus */
DECLARE @tops TABLE (
      module_code          varchar(80)  NOT NULL PRIMARY KEY
    , module_name          varchar(150) NOT NULL
    , endpoint_path        varchar(250) NULL
    , sort_no              int          NOT NULL
);

INSERT INTO @tops (module_code, module_name, endpoint_path, sort_no) VALUES
    ('HRD_ABS', 'Absensi',  '#', 100),
    ('HRD_CAB', 'Benefit',  '#', 200),
    ('HRD_RPT', 'Laporan',  '#', 300),
    ('HRD_PAR', 'Utility',  '#', 400);

INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT t.module_code, t.module_name, NULL, t.endpoint_path, t.sort_no, 1, 'MIGRATION'
FROM @tops AS t
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = t.module_code);

UPDATE m
SET
    m.module_name = t.module_name,
    m.parent_module_code = NULL,
    m.endpoint_path = t.endpoint_path,
    m.sort_no = t.sort_no,
    m.is_active = 1,
    m.updated_by = 'MIGRATION',
    m.updated_at = SYSUTCDATETIME()
FROM dbo.RBAC_Module AS m
INNER JOIN @tops AS t ON t.module_code = m.module_code;
GO

/* ------------------------------------------------------------------ Hide old single-root HRD */
UPDATE dbo.RBAC_Module
SET
    is_active = 0,
    updated_by = 'MIGRATION',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'HRD'
  AND is_active = 1;
GO

/* ------------------------------------------------------------------ Group folders under the 4 tops */
DECLARE @groups TABLE (
      module_code          varchar(80)  NOT NULL PRIMARY KEY
    , module_name          varchar(150) NOT NULL
    , parent_module_code   varchar(80)  NOT NULL
    , sort_no              int          NOT NULL
);

INSERT INTO @groups (module_code, module_name, parent_module_code, sort_no) VALUES
    /* Absensi */
    ('HRD_GRP_ATTENDANCE', 'ATTENDANCE',   'HRD_ABS', 10),
    ('HRD_GRP_PERSONEL',   'PERSONEL',     'HRD_ABS', 20),
    ('HRD_GRP_GENERATE',   'GENERATE',     'HRD_ABS', 30),
    /* Benefit */
    ('HRD_GRP_PAYROLL',    'Payroll',      'HRD_CAB', 10),
    ('HRD_GRP_PROCESS',    'Process',      'HRD_CAB', 20),
    /* Laporan */
    ('HRD_GRP_REPORT',     'REPORT',       'HRD_RPT', 10),
    /* Utility */
    ('HRD_GRP_SYS_PARAM',  'System Param', 'HRD_PAR', 10),
    ('HRD_GRP_MASTER',     'MASTER',       'HRD_PAR', 20),
    ('HRD_GRP_EOM',        'End Of Month', 'HRD_PAR', 30);

UPDATE m
SET
    m.module_name = g.module_name,
    m.parent_module_code = g.parent_module_code,
    m.endpoint_path = '#',
    m.sort_no = g.sort_no,
    m.is_active = 1,
    m.updated_by = 'MIGRATION',
    m.updated_at = SYSUTCDATETIME()
FROM dbo.RBAC_Module AS m
INNER JOIN @groups AS g ON g.module_code = m.module_code;
GO

/* ------------------------------------------------------------------ Ensure VIEW on top menus for HRD role */
DECLARE @hrd_role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'HRD');

INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @hrd_role_id, m.module_id, p.permission_id, 1, 'MIGRATION'
FROM dbo.RBAC_Module AS m
CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code IN ('HRD_ABS', 'HRD_CAB', 'HRD_RPT', 'HRD_PAR')
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

PRINT '11_hrd_top_menus.sql completed.';
GO
