/* Hide Alfa from Utility > System Param (not needed). */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET
    is_active = 0,
    updated_by = 'MIGRATION',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'HRD_PAR_ALFA'
  AND is_active = 1;
GO
