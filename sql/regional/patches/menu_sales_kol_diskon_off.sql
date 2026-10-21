/*
  Deactivate Sales By Kol + Store Diskon from REG Sales menu.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MENU_SALES_KOL_DISKON_OFF',
    updated_at = SYSUTCDATETIME()
WHERE module_code IN ('REG_RPT_SALES_KOL', 'REG_RPT_STORE_DISKON');

DELETE FROM dbo.RBAC_Role_Module
WHERE module_code IN ('REG_RPT_SALES_KOL', 'REG_RPT_STORE_DISKON');
GO
