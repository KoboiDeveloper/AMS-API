/*
  Taxi — role TAXI, limited menus: Payment Dashboard (placeholder),
  AR Detail, DCR, Sales Detail, Last Stock.
  Jalankan di RBACESS:
    sqlcmd ... -d RBACESS -v TAXI_PASSWORD="ManisManja" TAXI_RESET_PASSWORD="1" -i taxi_rbac_seed.sql
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* ---- Role ---- */
IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Role WHERE role_code = 'TAXI')
BEGIN
    INSERT INTO dbo.RBAC_Role (role_code, role_name, scope_level, description, is_system, is_active, created_by)
    VALUES ('TAXI', 'Taxi AR / Sales Lite', 'AREA',
            'Limited: analisa payment dash, AR detail, DCR, sales detail, last stock', 0, 1, 'TAXI_SEED');
END;
GO

/* ---- Ensure / re-enable modules ---- */
DECLARE @mods TABLE (
      module_code varchar(80) NOT NULL PRIMARY KEY
    , module_name varchar(150) NOT NULL
    , parent_module_code varchar(80) NULL
    , endpoint_path varchar(250) NULL
    , sort_no int NOT NULL
);
INSERT INTO @mods (module_code, module_name, parent_module_code, endpoint_path, sort_no) VALUES
    ('TAXI_PAYMENT_DASH',    'Analisa Payment',           NULL,            '/admin/regional/taxi/payment-dashboard',  1),
    ('REG_RPT',              'Laporan',                   NULL,            '#',                                       50),
    ('REG_GRP_SALES',        'Sales',                     'REG_RPT',       '#',                                       20),
    ('REG_GRP_INV',          'Inventory',                 'REG_RPT',       '#',                                       30),
    ('REG_RPT_AR_DETAIL',    'AR Detail',                 'REG_GRP_SALES', '/admin/regional/rpt/sales/ar-detail',     30),
    ('REG_RPT_KAS_KECIL',    'Report Kas Kecil',          'REG_GRP_SALES', '/admin/regional/rpt/sales/kas-kecil-report', 31),
    ('REG_RPT_DCR',          'Daily Collection Report',   'REG_GRP_SALES', '/admin/regional/rpt/sales/dcr',           25),
    ('REG_RPT_SALES_DETAIL', 'Sales Detail',              'REG_GRP_SALES', '/admin/regional/rpt/sales/sales-detail',  35),
    ('REG_RPT_LAST_STOCK',   'Last Stock By Date',        'REG_GRP_INV',   '/admin/regional/rpt/inv/last-stock',      110);

INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT m.module_code, m.module_name, m.parent_module_code, m.endpoint_path, m.sort_no, 1, 'TAXI_SEED'
FROM @mods AS m
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = m.module_code);

UPDATE x
   SET x.module_name = CASE
           WHEN x.module_code IN ('TAXI_PAYMENT_DASH','REG_RPT_AR_DETAIL','REG_RPT_KAS_KECIL','REG_RPT_LAST_STOCK') THEN m.module_name
           ELSE x.module_name
       END,
       x.parent_module_code = CASE
           WHEN x.module_code IN ('TAXI_PAYMENT_DASH','REG_RPT_AR_DETAIL','REG_RPT_KAS_KECIL') THEN m.parent_module_code
           ELSE x.parent_module_code
       END,
       x.endpoint_path = CASE
           WHEN x.module_code IN ('TAXI_PAYMENT_DASH','REG_RPT_AR_DETAIL','REG_RPT_KAS_KECIL') THEN m.endpoint_path
           ELSE x.endpoint_path
       END,
       x.sort_no = CASE
           WHEN x.module_code = 'REG_RPT_KAS_KECIL' THEN m.sort_no
           ELSE x.sort_no
       END,
       x.is_active = 1,
       x.updated_by = 'TAXI_SEED',
       x.updated_at = SYSUTCDATETIME()
FROM dbo.RBAC_Module AS x
INNER JOIN @mods AS m ON m.module_code = x.module_code
WHERE x.module_code IN (
    'TAXI_PAYMENT_DASH','REG_RPT_AR_DETAIL','REG_RPT_KAS_KECIL','REG_RPT_DCR','REG_RPT_SALES_DETAIL','REG_RPT_LAST_STOCK',
    'REG_RPT','REG_GRP_SALES','REG_GRP_INV'
);
GO

/* ---- Role permissions (VIEW + EXPORT) ---- */
DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'TAXI');
INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @role_id, m.module_id, p.permission_id, 1, 'TAXI_SEED'
FROM dbo.RBAC_Module AS m
CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code IN (
      'TAXI_PAYMENT_DASH'
    , 'REG_RPT'
    , 'REG_GRP_SALES'
    , 'REG_GRP_INV'
    , 'REG_RPT_AR_DETAIL'
    , 'REG_RPT_KAS_KECIL'
    , 'REG_RPT_DCR'
    , 'REG_RPT_SALES_DETAIL'
    , 'REG_RPT_LAST_STOCK'
)
  AND p.permission_code IN ('VIEW','EXPORT')
  AND @role_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RBAC_RolePermission rp
      WHERE rp.role_id = @role_id AND rp.module_id = m.module_id AND rp.permission_id = p.permission_id
  );
GO

/* ---- User taxi / ManisManja ---- */
DECLARE @nik varchar(30) = 'TAXI';
DECLARE @pwd varchar(200) = N'$(TAXI_PASSWORD)';
DECLARE @reset varchar(5) = N'$(TAXI_RESET_PASSWORD)';
DECLARE @salt varchar(80) = REPLACE(CONVERT(varchar(36), NEWID()), '-', '') + REPLACE(CONVERT(varchar(36), NEWID()), '-', '');
DECLARE @hash varchar(64);

/* sqlcmd leaves $(VAR) literal when -v not passed; avoid LIKE with % (sqlcmd expands %) */
IF @pwd IS NULL OR @pwd = '' OR CHARINDEX(N'TAXI_PASSWORD', @pwd) > 0
    SET @pwd = N'ManisManja';

IF @reset IS NULL OR @reset = '' OR CHARINDEX(N'TAXI_RESET_PASSWORD', @reset) > 0
    SET @reset = N'1';

SET @hash = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @salt + @pwd)), 2);

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Employee WHERE nik = @nik)
    INSERT INTO dbo.RBAC_Employee (nik, employee_name, employee_type, job_title, is_active, created_by)
    VALUES (@nik, 'Taxi', 'OFFICE', 'TAXI', 1, 'TAXI_SEED');
ELSE
    UPDATE dbo.RBAC_Employee
       SET employee_name = 'Taxi',
           job_title = COALESCE(NULLIF(job_title, ''), 'TAXI'),
           is_active = 1,
           updated_by = 'TAXI_SEED',
           updated_at = SYSUTCDATETIME()
     WHERE nik = @nik;

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_AuthUser WHERE nik = @nik OR LOWER(username) = 'taxi')
    INSERT INTO dbo.RBAC_AuthUser (username, nik, password_salt, password_hash, is_active, failed_login_count, force_change_password, created_by)
    VALUES ('taxi', @nik, @salt, @hash, 1, 0, 0, 'TAXI_SEED');
ELSE IF @reset = '1'
    UPDATE dbo.RBAC_AuthUser
       SET password_salt = @salt,
           password_hash = @hash,
           is_active = 1,
           failed_login_count = 0,
           username = 'taxi',
           updated_by = 'TAXI_SEED',
           updated_at = SYSUTCDATETIME()
     WHERE nik = @nik OR LOWER(username) = 'taxi';

DECLARE @rid int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'TAXI');
IF @rid IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM dbo.RBAC_UserRole ur WHERE ur.nik = @nik AND ur.role_id = @rid AND ur.is_active = 1
)
    INSERT INTO dbo.RBAC_UserRole (nik, role_id, start_date, is_active, created_by)
    VALUES (@nik, @rid, CAST(GETDATE() AS date), 1, 'TAXI_SEED');
GO

PRINT 'taxi_rbac_seed.sql completed.';
GO
