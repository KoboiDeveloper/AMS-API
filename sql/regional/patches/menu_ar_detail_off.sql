/* Remove Ar Detail from Laporan → Sales (not needed). */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MENU_AR_DETAIL_OFF',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_RPT_AR_DETAIL';
GO
