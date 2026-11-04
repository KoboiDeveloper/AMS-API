/*
  DigitalSales Retur — role DIGITAL_SALES_RETUR, menu Dashboard / Retur / Gudang Retur,
  user DigitalSalesRetur1.
  Jalankan di RBACESS:
    sqlcmd ... -d RBACESS -v DSR_PASSWORD="KacangPanjang" DSR_RESET_PASSWORD="0" -i digitalsales_retur_rbac_seed.sql
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Role WHERE role_code = 'DIGITAL_SALES_RETUR')
BEGIN
    INSERT INTO dbo.RBAC_Role (role_code, role_name, scope_level, description, is_system, is_active, created_by)
    VALUES ('DIGITAL_SALES_RETUR', 'Digital Sales Retur', 'AREA',
            'Retur marketplace saja — dashboard retur, list retur per store, gudang retur', 0, 1, 'DGS_RETUR_SEED');
END;
GO

DECLARE @mods TABLE (
      module_code varchar(80) NOT NULL PRIMARY KEY
    , module_name varchar(150) NOT NULL
    , parent_module_code varchar(80) NULL
    , endpoint_path varchar(250) NULL
    , sort_no int NOT NULL
);
INSERT INTO @mods (module_code, module_name, parent_module_code, endpoint_path, sort_no) VALUES
    ('DGS_RETUR_DASH',   'Dashboard',     NULL, '/dgs/retur-dashboard', 10),
    ('DGS_RETUR_LIST',   'Retur',         NULL, '/dgs/retur-list',      20),
    ('DGS_RETUR_GUDANG', 'Gudang Retur',  NULL, '/dgs/retur',           30);

INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT m.module_code, m.module_name, m.parent_module_code, m.endpoint_path, m.sort_no, 1, 'DGS_RETUR_SEED'
FROM @mods AS m
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = m.module_code);

UPDATE x SET x.module_name = m.module_name, x.parent_module_code = m.parent_module_code,
    x.endpoint_path = m.endpoint_path, x.sort_no = m.sort_no, x.is_active = 1,
    x.updated_by = 'DGS_RETUR_SEED', x.updated_at = SYSUTCDATETIME()
FROM dbo.RBAC_Module AS x INNER JOIN @mods AS m ON m.module_code = x.module_code;

-- Rename existing Gudang Retur label for full DigitalSales (path tetap /dgs/retur)
UPDATE dbo.RBAC_Module SET module_name = 'Gudang Retur', updated_by = 'DGS_RETUR_SEED', updated_at = SYSUTCDATETIME()
WHERE module_code = 'DGS_RETUR' AND module_name <> 'Gudang Retur';
GO

DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'DIGITAL_SALES_RETUR');
INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @role_id, m.module_id, p.permission_id, 1, 'DGS_RETUR_SEED'
FROM dbo.RBAC_Module AS m CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code IN ('DGS_RETUR_DASH','DGS_RETUR_LIST','DGS_RETUR_GUDANG')
  AND p.permission_code IN ('VIEW','CREATE','UPDATE','DELETE','EXPORT','APPROVE')
  AND @role_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RBAC_RolePermission rp
      WHERE rp.role_id = @role_id AND rp.module_id = m.module_id AND rp.permission_id = p.permission_id
  );
GO

DECLARE @nik varchar(30) = 'DIGITALSALESRETUR1';
DECLARE @pwd varchar(200) = '$(DSR_PASSWORD)';
DECLARE @reset varchar(5) = '$(DSR_RESET_PASSWORD)';
DECLARE @salt varchar(80) = REPLACE(CONVERT(varchar(36), NEWID()), '-', '') + REPLACE(CONVERT(varchar(36), NEWID()), '-', '');
DECLARE @hash varchar(64) = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @salt + @pwd)), 2);

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Employee WHERE nik = @nik)
    INSERT INTO dbo.RBAC_Employee (nik, employee_name, employee_type, job_title, is_active, created_by)
    VALUES (@nik, 'Yeni', 'OFFICE', 'DIGITAL_SALES_RETUR', 1, 'DGS_RETUR_SEED');
ELSE
    UPDATE dbo.RBAC_Employee
       SET employee_name = 'Yeni',
           job_title = COALESCE(NULLIF(job_title, ''), 'DIGITAL_SALES_RETUR'),
           is_active = 1,
           updated_by = 'DGS_RETUR_SEED',
           updated_at = SYSUTCDATETIME()
     WHERE nik = @nik;

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_AuthUser WHERE nik = @nik OR username IN ('DigitalSalesRetur1','digitalsalesretur1'))
    INSERT INTO dbo.RBAC_AuthUser (username, nik, password_salt, password_hash, is_active, failed_login_count, force_change_password, created_by)
    VALUES ('DigitalSalesRetur1', @nik, @salt, @hash, 1, 0, 0, 'DGS_RETUR_SEED');
ELSE IF @reset = '1'
    UPDATE dbo.RBAC_AuthUser
       SET password_salt = @salt, password_hash = @hash, is_active = 1, failed_login_count = 0,
           username = 'DigitalSalesRetur1'
     WHERE nik = @nik OR username IN ('DigitalSalesRetur1','digitalsalesretur1');

DECLARE @rid int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'DIGITAL_SALES_RETUR');
IF @rid IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM dbo.RBAC_UserRole ur WHERE ur.nik = @nik AND ur.role_id = @rid AND ur.is_active = 1
)
    INSERT INTO dbo.RBAC_UserRole (nik, role_id, start_date, is_active, created_by)
    VALUES (@nik, @rid, CAST(GETDATE() AS date), 1, 'DGS_RETUR_SEED');
GO

PRINT 'digitalsales_retur_rbac_seed.sql completed.';
GO
