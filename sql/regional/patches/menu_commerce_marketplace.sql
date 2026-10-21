/* Create Commerce top menu beside Laporan; nest Marketplace under it.
   Stock Opname stays under Laporan (REG_RPT). */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module WHERE module_code = 'REG_COMMERCE')
BEGIN
    INSERT INTO dbo.RBAC_Module
        (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
    VALUES
        ('REG_COMMERCE', 'Commerce', NULL, '#', 150, 1, 'REG_MENU_COMMERCE');
END
ELSE
BEGIN
    UPDATE dbo.RBAC_Module
    SET module_name = 'Commerce',
        parent_module_code = NULL,
        endpoint_path = '#',
        sort_no = 150,
        is_active = 1,
        updated_by = 'REG_MENU_COMMERCE',
        updated_at = SYSUTCDATETIME()
    WHERE module_code = 'REG_COMMERCE';
END
GO

/* Marketplace becomes a group under Commerce */
UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_COMMERCE',
    module_name = 'Marketplace',
    endpoint_path = '#',
    sort_no = 10,
    is_active = 1,
    updated_by = 'REG_MENU_COMMERCE',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_MP';
GO

/* Stock Opname stays in Laporan */
UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_RPT',
    sort_no = 40,
    is_active = 1,
    updated_by = 'REG_MENU_COMMERCE',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_GRP_SO';
GO

/* Voucher / Omnichannel / Member → Commerce */
UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_COMMERCE', sort_no = 20, is_active = 1,
    updated_by = 'REG_MENU_COMMERCE', updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_GRP_VOUCHER';
UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_COMMERCE', sort_no = 30, is_active = 1,
    updated_by = 'REG_MENU_COMMERCE', updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_GRP_OMNI';
UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_COMMERCE', sort_no = 40, is_active = 1,
    updated_by = 'REG_MENU_COMMERCE', updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_GRP_MEMBER';
GO

/* Grant REGIONAL (and any role that has REG_MP) permissions on REG_COMMERCE */
DECLARE @commerce_id int = (SELECT module_id FROM dbo.RBAC_Module WHERE module_code = 'REG_COMMERCE');
DECLARE @mp_id int = (SELECT module_id FROM dbo.RBAC_Module WHERE module_code = 'REG_MP');

IF @commerce_id IS NOT NULL
BEGIN
    INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
    SELECT DISTINCT rp.role_id, @commerce_id, rp.permission_id, 1, 'REG_MENU_COMMERCE'
    FROM dbo.RBAC_RolePermission AS rp
    WHERE rp.module_id = @mp_id
      AND rp.is_active = 1
      AND NOT EXISTS (
          SELECT 1 FROM dbo.RBAC_RolePermission x
          WHERE x.role_id = rp.role_id
            AND x.module_id = @commerce_id
            AND x.permission_id = rp.permission_id
      );

    /* Fallback: REGIONAL role gets VIEW/EXPORT at least */
    DECLARE @rid int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL');
    IF @rid IS NOT NULL
    BEGIN
        INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
        SELECT @rid, @commerce_id, p.permission_id, 1, 'REG_MENU_COMMERCE'
        FROM dbo.RBAC_Permission AS p
        WHERE p.permission_code IN ('VIEW', 'EXPORT', 'CREATE', 'UPDATE', 'DELETE')
          AND NOT EXISTS (
              SELECT 1 FROM dbo.RBAC_RolePermission x
              WHERE x.role_id = @rid AND x.module_id = @commerce_id AND x.permission_id = p.permission_id
          );
    END
END
GO

SELECT module_code, module_name, parent_module_code, sort_no, is_active
FROM dbo.RBAC_Module
WHERE module_code IN ('REG_DASHBOARD','REG_RPT','REG_COMMERCE','REG_MP','REG_UTIL','REG_GRP_SO')
   OR parent_module_code IN ('REG_COMMERCE','REG_MP')
ORDER BY CASE WHEN parent_module_code IS NULL THEN 0 ELSE 1 END, sort_no, module_code;
GO
