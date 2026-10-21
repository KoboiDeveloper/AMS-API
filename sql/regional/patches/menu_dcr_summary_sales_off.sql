/* Remove Dcr Summary from Laporan → Sales (not needed). */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MENU_DCR_SUMMARY_OFF',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_RPT_DCR_SUMMARY';
GO
