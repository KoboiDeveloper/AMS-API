/*
  DigitalSales (marketplace AR / prasales) — role, modul DGS_*, user, audit table.
  Jalankan di database RBACESS dengan variabel password (jangan commit password):
    sqlcmd -S <server> -U <user> -P <pwd> -d RBACESS -v DS_PASSWORD="<password>" -i digitalsales_rbac_seed.sql
  Idempotent: aman dijalankan ulang. Jika user sudah ada, password TIDAK diubah
  kecuali DS_RESET_PASSWORD=1 diberikan (-v DS_RESET_PASSWORD=1).
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.RBAC_DS_ActionLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RBAC_DS_ActionLog (
          log_id     bigint IDENTITY(1,1) NOT NULL PRIMARY KEY
        , nik        varchar(30)    NULL
        , action     varchar(80)    NOT NULL
        , ref_key    varchar(250)   NULL
        , payload    nvarchar(max)  NULL
        , ip_address varchar(64)    NULL
        , created_at datetime2(0)   NOT NULL CONSTRAINT DF_RBAC_DS_ActionLog_created DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_RBAC_DS_ActionLog_created ON dbo.RBAC_DS_ActionLog (created_at DESC);
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Role WHERE role_code = 'DIGITAL_SALES')
BEGIN
    INSERT INTO dbo.RBAC_Role (role_code, role_name, scope_level, description, is_system, is_active, created_by)
    VALUES ('DIGITAL_SALES', 'Digital Sales', 'AREA',
            'AR & transaksi marketplace (Shopee, Tokopedia, TikTok, dll) — area /dgs', 0, 1, 'DGS_SEED');
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
    ('DGS_MP',            'Marketplace',        NULL,     '#',                     10),
    ('DGS_DASH',          'Dashboard Analisa',  'DGS_MP', '/dgs/dashboard',        10),
    ('DGS_ANALISA_BARANG','Analisa Barang',     'DGS_MP', '/dgs/analisa-barang',   15),
    ('DGS_PRASALES',      'Prasales',           'DGS_MP', '/dgs/prasales',         20),
    ('DGS_AR_LIST',       'Ar List',            'DGS_MP', '/dgs/ar-list',          30),
    ('DGS_AR_REALISASI',  'Ar Realisasi',       'DGS_MP', '/dgs/ar-realisasi',     40),
    ('DGS_RETUR',         'Retur',              'DGS_MP', '/dgs/retur',            50),
    ('DGS_KOMISI',        'Setting Komisi',     'DGS_MP', '/dgs/komisi-setting',   60);

INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT m.module_code, m.module_name, m.parent_module_code, m.endpoint_path, m.sort_no, 1, 'DGS_SEED'
FROM @mods AS m
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = m.module_code);

UPDATE x SET x.module_name = m.module_name, x.parent_module_code = m.parent_module_code,
    x.endpoint_path = m.endpoint_path, x.sort_no = m.sort_no, x.is_active = 1,
    x.updated_by = 'DGS_SEED', x.updated_at = SYSUTCDATETIME()
FROM dbo.RBAC_Module AS x INNER JOIN @mods AS m ON m.module_code = x.module_code;
GO

DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'DIGITAL_SALES');
INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @role_id, m.module_id, p.permission_id, 1, 'DGS_SEED'
FROM dbo.RBAC_Module AS m CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code LIKE 'DGS[_]%'
  AND p.permission_code IN ('VIEW','CREATE','UPDATE','DELETE','EXPORT','APPROVE')
  AND @role_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RBAC_RolePermission rp
      WHERE rp.role_id = @role_id AND rp.module_id = m.module_id AND rp.permission_id = p.permission_id
  );
GO

DECLARE @nik varchar(30) = 'DIGITALSALES';
DECLARE @pwd varchar(200) = '$(DS_PASSWORD)';
DECLARE @reset varchar(5) = '$(DS_RESET_PASSWORD)';
DECLARE @salt varchar(80) = REPLACE(CONVERT(varchar(36), NEWID()), '-', '') + REPLACE(CONVERT(varchar(36), NEWID()), '-', '');
DECLARE @hash varchar(64) = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @salt + @pwd)), 2);

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Employee WHERE nik = @nik)
    INSERT INTO dbo.RBAC_Employee (nik, employee_name, employee_type, job_title, is_active, created_by)
    VALUES (@nik, 'Digital Sales', 'OFFICE', 'DIGITAL_SALES', 1, 'DGS_SEED');

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_AuthUser WHERE nik = @nik OR username = 'digitalsales')
    INSERT INTO dbo.RBAC_AuthUser (username, nik, password_salt, password_hash, is_active, failed_login_count, force_change_password, created_by)
    VALUES ('digitalsales', @nik, @salt, @hash, 1, 0, 0, 'DGS_SEED');
ELSE IF @reset = '1'
    UPDATE dbo.RBAC_AuthUser
       SET password_salt = @salt, password_hash = @hash, is_active = 1, failed_login_count = 0
     WHERE nik = @nik OR username = 'digitalsales';

DECLARE @rid int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'DIGITAL_SALES');
IF @rid IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM dbo.RBAC_UserRole ur WHERE ur.nik = @nik AND ur.role_id = @rid AND ur.is_active = 1
)
    INSERT INTO dbo.RBAC_UserRole (nik, role_id, start_date, is_active, created_by)
    VALUES (@nik, @rid, CAST(GETDATE() AS date), 1, 'DGS_SEED');
GO

PRINT 'digitalsales_rbac_seed.sql completed.';
GO
