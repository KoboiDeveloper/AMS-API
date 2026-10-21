/* Disable Dr.Woro; nest Stock Opname under Kas Kecil (same mega column). */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET is_active = 0, updated_by = 'REG_MENU_WORO_OFF', updated_at = SYSUTCDATETIME()
WHERE module_code IN ('REG_GRP_WORO', 'REG_RPT_WORO1', 'REG_RPT_WORO2');
GO

UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_GRP_KAS',
    sort_no = 100,
    is_active = 1,
    updated_by = 'REG_MENU_SO_UNDER_KAS',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_GRP_SO';
GO
