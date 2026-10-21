/* Remove Batch + Slip Setoran from Laporan → Sales (not needed). */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MENU_BATCH_SLIP_OFF',
    updated_at = SYSUTCDATETIME()
WHERE module_code IN ('REG_RPT_BATCH', 'REG_RPT_SLIP_SETORAN');
GO

SELECT module_code, module_name, is_active, sort_no
FROM dbo.RBAC_Module
WHERE module_code IN ('REG_RPT_BATCH', 'REG_RPT_SLIP_SETORAN')
   OR parent_module_code = 'REG_GRP_SALES'
ORDER BY CASE WHEN parent_module_code = 'REG_GRP_SALES' THEN sort_no ELSE 0 END, module_code;
GO
