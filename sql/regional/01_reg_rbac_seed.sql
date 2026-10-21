USE RBACESS;
GO
SET NOCOUNT ON;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL')
BEGIN
    INSERT INTO dbo.RBAC_Role (role_code, role_name, scope_level, description, is_system, is_active, created_by)
    VALUES ('REGIONAL', 'Regional', 'AREA', 'Migrated from WEB_USER_MAIN roll_code 5', 0, 1, 'REG_MIGRATION');
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
    ('REG_DASHBOARD', 'Dashboard', NULL, '/admin/regional/dashboard', 1),
    ('REG_RPT', 'Laporan', NULL, '#', 100),
    ('REG_COMMERCE', 'Commerce', NULL, '#', 150),
    ('REG_MP', 'Marketplace', 'REG_COMMERCE', '#', 10),
    ('REG_MP_AR_LIST', 'Ar List', 'REG_MP', '/admin/regional/mp/ar-list', 10),
    ('REG_MP_AR_REALISASI', 'Ar Realisasi', 'REG_MP', '/admin/regional/mp/ar-realisasi', 20),
    ('REG_MP_RETUR', 'Retur', 'REG_MP', '/admin/regional/mp/retur', 30),
    ('REG_GRP_OFFICE', 'Office', 'REG_RPT', '#', 10),
    ('REG_GRP_SALES', 'Sales', 'REG_RPT', '#', 20),
    ('REG_GRP_INV', 'Inventory', 'REG_RPT', '#', 30),
    ('REG_GRP_SO', 'Stock Opname', 'REG_RPT', '#', 35),
    ('REG_GRP_VOUCHER', 'Voucher', 'REG_COMMERCE', '#', 20),
    ('REG_GRP_OMNI', 'Omnichannel', 'REG_COMMERCE', '#', 30),
    ('REG_GRP_MEMBER', 'Member', 'REG_COMMERCE', '#', 40),
    ('REG_ABSEN_LIST', 'Absen List', 'REG_GRP_OFFICE', '/admin/regional/absen/list', 5),
    ('REG_SLIP_DCR', 'Slip Setoran Bank', 'REG_GRP_OFFICE', '/admin/regional/slip/dcr', 30),
    ('REG_MOBILE_TOT_SALES', 'Total Sales', 'REG_GRP_SALES', '/admin/regional/rpt/sales/total-sales', 5),
    ('REG_RPT_SALES_ARTICLE', 'Sales By Article', 'REG_GRP_SALES', '/admin/regional/rpt/sales/sales-article', 6),
    ('REG_RPT_SALES_ISLAND', 'Sales By Island', 'REG_GRP_SALES', '/admin/regional/rpt/sales/sales-island', 7),
    ('REG_RPT_GROSS_MARGIN', 'Gross Margin', 'REG_GRP_SALES', '/admin/regional/rpt/sales/gross-margin', 8),
    ('REG_RPT_DAILY_SALES', 'Daily Sales Summary', 'REG_GRP_SALES', '/admin/regional/rpt/sales/daily-sales', 20),
    ('REG_RPT_DCR', 'Daily Collection Report', 'REG_GRP_SALES', '/admin/regional/rpt/sales/dcr', 25),
    ('REG_RPT_SALES_DETAIL', 'Sales Detail', 'REG_GRP_SALES', '/admin/regional/rpt/sales/sales-detail', 35),
    ('REG_RPT_PAYMENT', 'Payment Detail', 'REG_GRP_SALES', '/admin/regional/rpt/sales/payment-detail', 40),
    ('REG_RPT_AR_DETAIL', 'Ar Detail', 'REG_GRP_SALES', '/admin/regional/rpt/sales/ar-detail', 45),
    ('REG_RPT_PROMOSI', 'Promosi', 'REG_GRP_SALES', '/admin/regional/rpt/sales/promosi', 50),
    ('REG_RPT_SALES_KOL', 'Sales By Kol', 'REG_GRP_SALES', '/admin/regional/rpt/sales/sales-kol', 55),
    ('REG_RPT_STORE_DISKON', 'Store Diskon', 'REG_GRP_SALES', '/admin/regional/rpt/sales/store-diskon', 60),
    ('REG_RPT_ASBC_QTY', 'Asbc Qty', 'REG_GRP_SALES', '/admin/regional/rpt/sales/asbc-qty', 65),
    ('REG_RPT_KOLEKSI', 'Koleksi', 'REG_GRP_SALES', '/admin/regional/rpt/sales/koleksi', 75),
    ('REG_RPT_SALES_MANPOWER', 'Sales By Man Power', 'REG_GRP_SALES', '/admin/regional/rpt/sales/sales-manpower', 80),
    ('REG_RPT_TR_ST_IN', 'Tr St In', 'REG_GRP_INV', '/admin/regional/rpt/inv/tr-st-in', 10),
    ('REG_RPT_OUTSTANDING', 'Outstanding Stock', 'REG_GRP_INV', '/admin/regional/rpt/inv/outstanding', 20),
    ('REG_RPT_TR_ST_OUT', 'Tr St Out', 'REG_GRP_INV', '/admin/regional/rpt/inv/tr-st-out', 60),
    ('REG_RPT_ST_LIST', 'St List', 'REG_GRP_INV', '/admin/regional/rpt/inv/st-list', 70),
    ('REG_RPT_LBPP_BRAND', 'Lbpp By Brand', 'REG_GRP_INV', '/admin/regional/rpt/inv/lbpp-brand', 100),
    ('REG_RPT_LAST_STOCK', 'Last Stock', 'REG_GRP_INV', '/admin/regional/rpt/inv/last-stock', 110),
    ('REG_RPT_LAST_STOCK_ALL', 'Last Stock All Store', 'REG_GRP_INV', '/admin/regional/rpt/inv/last-stock-all', 140),
    ('REG_RPT_DAILY_STOCK', 'Daily Stock Summary', 'REG_GRP_INV', '/admin/regional/rpt/inv/daily-stock', 150),
    ('REG_RPT_CEK_MUTASI', 'Cek Mutasi', 'REG_GRP_INV', '/admin/regional/rpt/inv/cek-mutasi', 170),
    ('REG_RPT_MUTASI_HARIAN', 'Mutasi Harian', 'REG_GRP_INV', '/admin/regional/rpt/inv/mutasi-harian', 180),
    ('REG_RPT_CEK_QTY0', 'Cek Qty 0', 'REG_GRP_INV', '/admin/regional/rpt/inv/cek-qty0', 190),
    ('REG_RPT_TR_SO', 'Tr So', 'REG_GRP_SO', '/admin/regional/rpt/so/tr-so', 10),
    ('REG_RPT_SO_DIFF', 'So Different', 'REG_GRP_SO', '/admin/regional/rpt/so/so-diff', 20),
    ('REG_RPT_SO_ADJ', 'So Adjustment', 'REG_GRP_SO', '/admin/regional/rpt/so/so-adj', 30),
    ('REG_RPT_TR_SO_PARTIAL', 'Tr So Partial', 'REG_GRP_SO', '/admin/regional/rpt/so/tr-so-partial', 40),
    ('REG_RPT_SO_DIFF_PARTIAL', 'So Different Partial', 'REG_GRP_SO', '/admin/regional/rpt/so/so-diff-partial', 50),
    ('REG_RPT_SO_ADJ_PARTIAL', 'So Adjustment Partial', 'REG_GRP_SO', '/admin/regional/rpt/so/so-adj-partial', 60),
    ('REG_RPT_VOUCHER_FISIK', 'Voucher Fisik', 'REG_GRP_VOUCHER', '/admin/regional/rpt/voucher/fisik', 10),
    ('REG_RPT_VOUCHER_IMLEK', 'Voucher Imlek', 'REG_GRP_VOUCHER', '/admin/regional/rpt/voucher/imlek', 20),
    ('REG_RPT_OMNI_RT', 'Realtime Stock', 'REG_GRP_OMNI', '/admin/regional/rpt/omni/realtime-stock', 10),
    ('REG_RPT_OMNI_VARIAN', 'Varian Stock', 'REG_GRP_OMNI', '/admin/regional/rpt/omni/varian-stock', 20),
    ('REG_RPT_OMNI_ORDER', 'Order Online', 'REG_GRP_OMNI', '/admin/regional/rpt/omni/order-online', 30),
    ('REG_RPT_MEMBER', 'Member', 'REG_GRP_MEMBER', '/admin/regional/rpt/member/list', 10),
    ('REG_RPT_MEMBER_INFO', 'Member Info', 'REG_GRP_MEMBER', '/admin/regional/rpt/member/info', 20),
    ('REG_UTIL', 'Utility', NULL, '#', 400),
    ('REG_GRP_SCAN', 'Scan Selisih Harga', 'REG_UTIL', '#', 10),
    ('REG_GRP_TOOLS', 'Tools', 'REG_UTIL', '#', 20),
    ('REG_GRP_PRINT', 'Print', 'REG_UTIL', '#', 30),
    ('REG_SCAN_SELISIH', 'Tools Scan Selisih', 'REG_GRP_SCAN', '/admin/regional/util/scan-selisih', 10),
    ('REG_PLU_SCAN', 'Scan Plu', 'REG_GRP_TOOLS', '/admin/regional/util/scan-plu', 5),
    ('REG_TOOLS_ADJ_SO', 'Adj So Parsial', 'REG_GRP_TOOLS', '/admin/regional/util/adj-so-partial', 10),
    ('REG_TOOLS_GH', 'Group Head', 'REG_GRP_TOOLS', '/admin/regional/util/group-head', 20),
    ('REG_TOOLS_STORE', 'Store List', 'REG_GRP_TOOLS', '/admin/regional/util/store-list', 30),
    ('REG_PRINT_OUTSTANDING', 'Outstanding Stock Print', 'REG_GRP_PRINT', '/admin/regional/util/print-outstanding', 10);
INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT m.module_code, m.module_name, m.parent_module_code, m.endpoint_path, m.sort_no, 1, 'REG_MIGRATION'
FROM @mods AS m
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = m.module_code);
UPDATE m SET m.module_name = t.module_name, m.parent_module_code = t.parent_module_code,
    m.endpoint_path = t.endpoint_path, m.sort_no = t.sort_no, m.is_active = 1,
    m.updated_by = 'REG_MIGRATION', m.updated_at = SYSUTCDATETIME()
FROM dbo.RBAC_Module AS m INNER JOIN @mods AS t ON t.module_code = m.module_code;
GO
DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL');
INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @role_id, m.module_id, p.permission_id, 1, 'REG_MIGRATION'
FROM dbo.RBAC_Module AS m CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code LIKE 'REG[_]%'
  AND p.permission_code IN ('VIEW','CREATE','UPDATE','DELETE','EXPORT')
  AND @role_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.RBAC_RolePermission rp WHERE rp.role_id=@role_id AND rp.module_id=m.module_id AND rp.permission_id=p.permission_id);
GO
DECLARE @users TABLE (nik varchar(30) NOT NULL PRIMARY KEY, nama varchar(150));
INSERT INTO @users (nik, nama) VALUES
    ('REG2','REG 2'),('REG1','REG 1'),('REGX','REG X'),('ARIS','ARIS'),
    ('BARMAN','BARMAN'),('BASKORO','BASKORO'),('JEFRI','JEFRI');
IF OBJECT_ID(N'pos_server.dbo.WEB_USER_MAIN', N'U') IS NOT NULL
BEGIN
    INSERT INTO @users (nik, nama)
    SELECT DISTINCT u.ID_USER, ISNULL(NULLIF(LTRIM(RTRIM(u.FULL_NAME)), ''), u.ID_USER)
    FROM pos_server.dbo.WEB_USER_MAIN AS u
    WHERE CONVERT(varchar(20), u.ROLL_CODE) = '5'
      AND NOT EXISTS (SELECT 1 FROM @users x WHERE x.nik = u.ID_USER);
END;
DECLARE @salt varchar(80) = 'b2c3d4e5f6478990ab12cd34ef567890a1';
DECLARE @pwd varchar(200) = 'Reg@2026!';
DECLARE @hash varchar(64) = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @salt + @pwd)), 2);
INSERT INTO dbo.RBAC_Employee (nik, employee_name, employee_type, job_title, is_active, created_by)
SELECT u.nik, u.nama, 'OFFICE', 'REGIONAL', 1, 'REG_MIGRATION' FROM @users u
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Employee e WHERE e.nik = u.nik);
INSERT INTO dbo.RBAC_AuthUser (username, nik, password_salt, password_hash, is_active, failed_login_count, force_change_password, created_by)
SELECT LOWER(u.nik), u.nik, @salt, @hash, 1, 0, 0, 'REG_MIGRATION' FROM @users u
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_AuthUser a WHERE a.nik = u.nik OR a.username = LOWER(u.nik));
DECLARE @rid int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL');
INSERT INTO dbo.RBAC_UserRole (nik, role_id, start_date, is_active, created_by)
SELECT u.nik, @rid, CAST(GETDATE() AS date), 1, 'REG_MIGRATION' FROM @users u
WHERE @rid IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM dbo.RBAC_UserRole ur WHERE ur.nik = u.nik AND ur.role_id = @rid AND ur.is_active = 1
);
GO
PRINT '01_reg_rbac_seed.sql completed.';
GO