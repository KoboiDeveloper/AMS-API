/*
  Marcomm (Marketing) — role MARKETING, modul MAR_*, user marcomm.
  Jalankan di database RBACESS:
    sqlcmd -S <server> -U <user> -P <pwd> -d RBACESS -i 02_marcomm_rbac_seed.sql
  Password default baru: Merdeka123! (SHA2_256 hex of password_salt + plaintext).
  Override password saat seed:
    sqlcmd ... -v MC_PASSWORD="<password>" -i 02_marcomm_rbac_seed.sql
  Reset password user yang sudah ada:
    sqlcmd ... -v MC_RESET_PASSWORD=1 -i 02_marcomm_rbac_seed.sql
  Idempotent: aman dijalankan ulang. Jika user sudah ada, password TIDAK diubah
  kecuali MC_RESET_PASSWORD=1.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Role WHERE role_code = 'MARKETING')
BEGIN
    INSERT INTO dbo.RBAC_Role (role_code, role_name, scope_level, description, is_system, is_active, created_by)
    VALUES ('MARKETING', 'Marketing / Marcomm', 'GLOBAL',
            'Marcomm — member, voucher, laporan, master /admin/marcomm', 0, 1, 'MARCOMM_SEED');
END;
ELSE
BEGIN
    UPDATE dbo.RBAC_Role
       SET role_name = 'Marketing / Marcomm',
           scope_level = 'GLOBAL',
           description = 'Marcomm — member, voucher, laporan, master /admin/marcomm',
           is_active = 1,
           updated_by = 'MARCOMM_SEED',
           updated_at = SYSUTCDATETIME()
     WHERE role_code = 'MARKETING';
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
    /* Top menus */
    ('MAR_DASHBOARD', 'Dashboard',              NULL,          '/admin/marcomm/dashboard', 10),
    ('MAR_MEMBER',    'Member',                 NULL,          '#',                        20),
    ('MAR_VOUCHER',   'Voucher',                NULL,          '#',                        30),
    ('MAR_REPORT',    'Laporan',                NULL,          '#',                        40),
    ('MAR_MASTER',    'Master',                 NULL,          '#',                        50),

    /* MEMBER */
    ('MAR_MBR_LIST',    'Member',                 'MAR_MEMBER', '/admin/marcomm/member/list',         10),
    ('MAR_MBR_TX',      'Transaction',            'MAR_MEMBER', '/admin/marcomm/member/transaction',  20),
    ('MAR_MBR_INFO',    'Member Info',            'MAR_MEMBER', '/admin/marcomm/member/info',         30),
    ('MAR_MBR_PROMO',   'Promo',                  'MAR_MEMBER', '/admin/marcomm/member/promo',        40),
    ('MAR_MBR_VOUCHER', 'Voucher',                'MAR_MEMBER', '/admin/marcomm/member/voucher',      50),
    ('MAR_MBR_REWARDS', 'Rewards',                'MAR_MEMBER', '/admin/marcomm/member/rewards',      60),
    ('MAR_MBR_MISSION', 'Mission',                'MAR_MEMBER', '/admin/marcomm/member/mission',      70),
    ('MAR_MBR_NOTIF',   'Notification',           'MAR_MEMBER', '/admin/marcomm/member/notification', 80),
    ('MAR_MBR_EXPORT',  'Export Data Member',     'MAR_MEMBER', '/admin/marcomm/member/export',       90),

    /* VOUCHER */
    ('MAR_VCR_GENERATED', 'Generated',            'MAR_VOUCHER', '/admin/marcomm/voucher/generated', 10),
    ('MAR_VCR_REPORT',    'Report',               'MAR_VOUCHER', '/admin/marcomm/voucher/report',    20),
    ('MAR_VCR_USED',      'Used',                 'MAR_VOUCHER', '/admin/marcomm/voucher/used',      30),

    /* REPORT (Laporan) */
    ('MAR_RPT_GIFT',   'Gift',                    'MAR_REPORT', '/admin/marcomm/report/gift',             10),
    ('MAR_RPT_REDEEM', 'Redemption',              'MAR_REPORT', '/admin/marcomm/report/redemption',       20),
    ('MAR_RPT_BDAY',   'Birthday Voucher',        'MAR_REPORT', '/admin/marcomm/report/birthday-voucher', 30),

    /* MASTER */
    ('MAR_MST_POINT',    'Point Register',        'MAR_MASTER', '/admin/marcomm/master/point-register',     10),
    ('MAR_MST_STORE',    'Store Location',        'MAR_MASTER', '/admin/marcomm/master/store-location',     20),
    ('MAR_MST_FAQ',      'FAQ',                   'MAR_MASTER', '/admin/marcomm/master/faq',                30),
    ('MAR_MST_VCR_CAT',  'Voucher Category',      'MAR_MASTER', '/admin/marcomm/master/voucher-category',   40),
    ('MAR_MST_GIFT_CAT', 'Gift Category',         'MAR_MASTER', '/admin/marcomm/master/gift-category',      50),
    ('MAR_MST_TNC',      'Syarat Ketentuan',      'MAR_MASTER', '/admin/marcomm/master/syarat-ketentuan',   60),
    ('MAR_MST_FAQ_CAT',  'FAQ Category',          'MAR_MASTER', '/admin/marcomm/master/faq-category',       70),
    ('MAR_MST_HOLIDAY',  'Special Holiday',       'MAR_MASTER', '/admin/marcomm/master/special-holiday',    80),
    ('MAR_MST_TIER',     'Tier',                  'MAR_MASTER', '/admin/marcomm/master/tier',               90);

INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT m.module_code, m.module_name, m.parent_module_code, m.endpoint_path, m.sort_no, 1, 'MARCOMM_SEED'
FROM @mods AS m
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = m.module_code);

UPDATE x
   SET x.module_name = m.module_name,
       x.parent_module_code = m.parent_module_code,
       x.endpoint_path = m.endpoint_path,
       x.sort_no = m.sort_no,
       x.is_active = 1,
       x.updated_by = 'MARCOMM_SEED',
       x.updated_at = SYSUTCDATETIME()
  FROM dbo.RBAC_Module AS x
 INNER JOIN @mods AS m ON m.module_code = x.module_code;
GO

DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'MARKETING');

INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @role_id, m.module_id, p.permission_id, 1, 'MARCOMM_SEED'
FROM dbo.RBAC_Module AS m
CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code LIKE 'MAR[_]%'
  AND p.permission_code IN ('VIEW', 'CREATE', 'UPDATE', 'DELETE', 'EXPORT', 'APPROVE')
  AND @role_id IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.RBAC_RolePermission AS rp
        WHERE rp.role_id = @role_id
          AND rp.module_id = m.module_id
          AND rp.permission_id = p.permission_id
    );
GO

DECLARE @nik varchar(30) = 'MARCOMM';
DECLARE @pwd_in varchar(200) = '$(MC_PASSWORD)';
DECLARE @pwd varchar(200) = 'Merdeka123!';
IF @pwd_in IS NOT NULL AND @pwd_in <> '' AND @pwd_in NOT LIKE '%$(MC_PASSWORD)%'
    SET @pwd = @pwd_in;

DECLARE @reset varchar(5) = '$(MC_RESET_PASSWORD)';
DECLARE @salt varchar(80) = REPLACE(CONVERT(varchar(36), NEWID()), '-', '') + REPLACE(CONVERT(varchar(36), NEWID()), '-', '');
DECLARE @hash varchar(64) = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @salt + @pwd)), 2);

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Employee WHERE nik = @nik)
    INSERT INTO dbo.RBAC_Employee (nik, employee_name, employee_type, job_title, is_active, created_by)
    VALUES (@nik, 'Marketing / Marcomm', 'OFFICE', 'MARKETING', 1, 'MARCOMM_SEED');

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_AuthUser WHERE nik = @nik OR username = 'marcomm')
    INSERT INTO dbo.RBAC_AuthUser (username, nik, password_salt, password_hash, is_active, failed_login_count, force_change_password, created_by)
    VALUES ('marcomm', @nik, @salt, @hash, 1, 0, 0, 'MARCOMM_SEED');
ELSE IF @reset = '1'
    UPDATE dbo.RBAC_AuthUser
       SET password_salt = @salt,
           password_hash = @hash,
           is_active = 1,
           failed_login_count = 0
     WHERE nik = @nik OR username = 'marcomm';

DECLARE @rid int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'MARKETING');
IF @rid IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM dbo.RBAC_UserRole AS ur
    WHERE ur.nik = @nik AND ur.role_id = @rid AND ur.is_active = 1
)
    INSERT INTO dbo.RBAC_UserRole (nik, role_id, start_date, is_active, created_by)
    VALUES (@nik, @rid, CAST(GETDATE() AS date), 1, 'MARCOMM_SEED');
GO

PRINT '02_marcomm_rbac_seed.sql completed.';
GO