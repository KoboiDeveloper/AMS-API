/* Utility → Tools → Password SO (PassSO.aspx) */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module WHERE module_code = 'REG_TOOLS_PASS_SO')
BEGIN
    INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
    VALUES ('REG_TOOLS_PASS_SO', 'Password SO', 'REG_GRP_TOOLS', '/admin/regional/util/pass-so', 40, 1, 'REG_PASS_SO');
END
ELSE
BEGIN
    UPDATE dbo.RBAC_Module
    SET module_name = 'Password SO',
        parent_module_code = 'REG_GRP_TOOLS',
        endpoint_path = '/admin/regional/util/pass-so',
        sort_no = 40,
        is_active = 1,
        updated_by = 'REG_PASS_SO',
        updated_at = SYSUTCDATETIME()
    WHERE module_code = 'REG_TOOLS_PASS_SO';
END
GO

DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL');
INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @role_id, m.module_id, p.permission_id, 1, 'REG_PASS_SO'
FROM dbo.RBAC_Module AS m
CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code = 'REG_TOOLS_PASS_SO'
  AND p.permission_code IN ('VIEW', 'CREATE', 'UPDATE', 'DELETE', 'EXPORT')
  AND @role_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM dbo.RBAC_RolePermission rp
    WHERE rp.role_id = @role_id AND rp.module_id = m.module_id AND rp.permission_id = p.permission_id
  );
GO
