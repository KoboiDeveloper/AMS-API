/* Slip Setoran Bank → Laporan / Office, di bawah Store Info */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_GRP_OFFICE',
    sort_no = 30,
    module_name = 'Slip Setoran Bank',
    is_active = 1,
    updated_by = 'REG_MENU_REORDER',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_SLIP_DCR';

UPDATE dbo.RBAC_Module
SET is_active = 0,
    updated_by = 'REG_MENU_REORDER',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_GRP_SLIP';

/* Ops kosong → nonaktifkan */
IF NOT EXISTS (
    SELECT 1 FROM dbo.RBAC_Module
    WHERE parent_module_code IN (
        SELECT module_code FROM dbo.RBAC_Module WHERE parent_module_code = 'REG_OPS' AND is_active = 1
    ) AND is_active = 1
)
BEGIN
    UPDATE dbo.RBAC_Module
    SET is_active = 0, updated_by = 'REG_MENU_REORDER', updated_at = SYSUTCDATETIME()
    WHERE module_code = 'REG_OPS'
      AND NOT EXISTS (
          SELECT 1 FROM dbo.RBAC_Module c
          WHERE c.parent_module_code = 'REG_OPS' AND c.is_active = 1
      );
END;

PRINT 'menu_slip_to_office.sql ok';
GO
