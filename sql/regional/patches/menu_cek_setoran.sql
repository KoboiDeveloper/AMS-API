/* Laporan → Office → Cek Setoran (rekonsiliasireg.aspx) */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module WHERE module_code = 'REG_RPT_CEK_SETORAN')
BEGIN
    INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
    VALUES ('REG_RPT_CEK_SETORAN', 'Cek Setoran', 'REG_GRP_OFFICE', '/admin/regional/office/cek-setoran', 40, 1, 'REG_CEK_SETORAN');
END
ELSE
BEGIN
    UPDATE dbo.RBAC_Module
    SET module_name = 'Cek Setoran',
        parent_module_code = 'REG_GRP_OFFICE',
        endpoint_path = '/admin/regional/office/cek-setoran',
        sort_no = 40,
        is_active = 1,
        updated_by = 'REG_CEK_SETORAN',
        updated_at = SYSUTCDATETIME()
    WHERE module_code = 'REG_RPT_CEK_SETORAN';
END
GO

DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL');
INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @role_id, m.module_id, p.permission_id, 1, 'REG_CEK_SETORAN'
FROM dbo.RBAC_Module AS m
CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code = 'REG_RPT_CEK_SETORAN'
  AND p.permission_code IN ('VIEW', 'CREATE', 'UPDATE', 'DELETE', 'EXPORT')
  AND @role_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM dbo.RBAC_RolePermission rp
    WHERE rp.role_id = @role_id AND rp.module_id = m.module_id AND rp.permission_id = p.permission_id
  );
GO
