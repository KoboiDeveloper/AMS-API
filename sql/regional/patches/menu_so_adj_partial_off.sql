/* Hide So Adjustment Partial from Regional SO menu (temporarily). */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MENU_SO_ADJ_PARTIAL_OFF',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_RPT_SO_ADJ_PARTIAL';
GO
