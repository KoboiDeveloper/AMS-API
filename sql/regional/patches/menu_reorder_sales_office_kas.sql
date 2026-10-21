/* Reorder REG menu:
   - Total Sales → Laporan / Sales (atas), path tanpa mobile
   - Absen List → Laporan / Office
   - Kas Kecil → Laporan (sebelah Inventory)
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* Folder Kas Kecil pindah ke Laporan, di sebelah Inventory */
UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_RPT',
    sort_no = 35,
    module_name = 'Kas Kecil',
    updated_by = 'REG_MENU_REORDER',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_GRP_KAS';

/* Total Sales → Sales group, paling atas, path baru */
UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_GRP_SALES',
    endpoint_path = '/admin/regional/rpt/sales/total-sales',
    sort_no = 5,
    module_name = 'Total Sales',
    is_active = 1,
    updated_by = 'REG_MENU_REORDER',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_MOBILE_TOT_SALES';

/* Absen List → Office */
UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_GRP_OFFICE',
    sort_no = 5,
    module_name = 'Absen List',
    is_active = 1,
    updated_by = 'REG_MENU_REORDER',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_ABSEN_LIST';

/* Geser Absensi / Store Info setelah Absen List */
UPDATE dbo.RBAC_Module SET sort_no = 10, updated_by = 'REG_MENU_REORDER', updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_RPT_ABSENSI';
UPDATE dbo.RBAC_Module SET sort_no = 20, updated_by = 'REG_MENU_REORDER', updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_RPT_STORE_INFO';

/* Sales reports tetap setelah Total Sales */
UPDATE dbo.RBAC_Module SET sort_no = 10, updated_by = 'REG_MENU_REORDER', updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_RPT_BATCH' AND sort_no < 10;

/* Matikan folder Ops kosong: Mobile & Absen Store */
UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MENU_REORDER',
    updated_at = SYSUTCDATETIME()
WHERE module_code IN ('REG_GRP_MOBILE', 'REG_GRP_ABSEN');

PRINT 'menu_reorder_sales_office_kas.sql ok';
GO
