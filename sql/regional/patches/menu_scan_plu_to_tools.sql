/* Scan Plu → Utility / Tools (tanpa folder Plu) */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_GRP_TOOLS',
    endpoint_path = '/admin/regional/util/scan-plu',
    sort_no = 5,
    module_name = 'Scan Plu',
    is_active = 1,
    updated_by = 'REG_MENU_REORDER',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_PLU_SCAN';

UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MENU_REORDER',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_GRP_PLU';

PRINT 'menu_scan_plu_to_tools.sql ok';
GO
