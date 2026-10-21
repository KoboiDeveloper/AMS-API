/*
  Align Laporan → Sales with REG2 sales menu (Batch + Slip Setoran excluded from Sales).
  Total Sales, Sales By Article, Sales By Island, Gross Margin,
  Daily Sales Summary, Daily Collection Report, DCR Summary, Sales Detail, Payment Detail,
  Ar Detail, Promosi, Sales By Kol, Store Diskon, Asbc Qty, Koleksi, Sales By Man Power
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

DECLARE @mods TABLE (
    module_code varchar(40) NOT NULL PRIMARY KEY,
    module_name varchar(100) NOT NULL,
    parent_module_code varchar(40) NULL,
    endpoint_path varchar(200) NOT NULL,
    sort_no int NOT NULL
);

INSERT INTO @mods (module_code, module_name, parent_module_code, endpoint_path, sort_no) VALUES
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
    ('REG_RPT_SALES_MANPOWER', 'Sales By Man Power', 'REG_GRP_SALES', '/admin/regional/rpt/sales/sales-manpower', 80);

INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT m.module_code, m.module_name, m.parent_module_code, m.endpoint_path, m.sort_no, 1, 'REG_SALES_FULL'
FROM @mods AS m
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = m.module_code);

UPDATE m
SET m.module_name = t.module_name,
    m.parent_module_code = t.parent_module_code,
    m.endpoint_path = t.endpoint_path,
    m.sort_no = t.sort_no,
    m.is_active = 1,
    m.updated_by = 'REG_SALES_FULL',
    m.updated_at = SYSUTCDATETIME()
FROM dbo.RBAC_Module AS m
INNER JOIN @mods AS t ON t.module_code = m.module_code;
GO

DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL');
INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @role_id, m.module_id, p.permission_id, 1, 'REG_SALES_FULL'
FROM dbo.RBAC_Module AS m
CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code IN (
    'REG_RPT_SALES_ARTICLE','REG_RPT_SALES_ISLAND','REG_RPT_GROSS_MARGIN',
    'REG_RPT_KOLEKSI','REG_RPT_SALES_MANPOWER'
)
  AND p.permission_code IN ('VIEW','CREATE','UPDATE','DELETE','EXPORT')
  AND @role_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM dbo.RBAC_RolePermission rp
    WHERE rp.role_id = @role_id AND rp.module_id = m.module_id AND rp.permission_id = p.permission_id
  );
GO

SELECT module_code, module_name, sort_no, is_active
FROM dbo.RBAC_Module
WHERE parent_module_code = 'REG_GRP_SALES'
ORDER BY sort_no, module_code;
GO
