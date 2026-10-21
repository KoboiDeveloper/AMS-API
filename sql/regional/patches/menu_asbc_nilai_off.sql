/*
  Deactivate Asbc Nilai from REG Sales menu.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MENU_ASBC_NILAI_OFF',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_RPT_ASBC_NILAI';
GO

SELECT module_code, module_name, is_active, sort_no
FROM dbo.RBAC_Module
WHERE module_code = 'REG_RPT_ASBC_NILAI'
   OR parent_module_code = 'REG_GRP_SALES'
ORDER BY CASE WHEN parent_module_code = 'REG_GRP_SALES' THEN sort_no ELSE 0 END, module_code;
GO
