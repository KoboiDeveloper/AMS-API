/* Remove Slip Setoran from Laporan → Sales (not needed; DCR stays under Office). */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MENU_SLIP_OFF',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_RPT_SLIP_SETORAN';
GO
