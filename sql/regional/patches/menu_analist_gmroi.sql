/* Analist (beside Laporan) → Dashboard → Analisa GMROI */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

DECLARE @mods TABLE (
      module_code varchar(80) NOT NULL PRIMARY KEY
    , module_name varchar(150) NOT NULL
    , parent_module_code varchar(80) NULL
    , endpoint_path varchar(250) NULL
    , sort_no int NOT NULL
);
INSERT INTO @mods (module_code, module_name, parent_module_code, endpoint_path, sort_no) VALUES
    ('REG_ANALIST', 'Analist', NULL, '#', 120),
    ('REG_GRP_ANALIST_DASH', 'Dashboard', 'REG_ANALIST', '#', 10),
    ('REG_ANALIST_GMROI', 'Analisa GMROI', 'REG_GRP_ANALIST_DASH', '/admin/regional/analist/dashboard/gmroi', 10);

MERGE dbo.RBAC_Module AS t
USING @mods AS s
ON t.module_code = s.module_code
WHEN MATCHED THEN
    UPDATE SET
        t.module_name = s.module_name,
        t.parent_module_code = s.parent_module_code,
        t.endpoint_path = s.endpoint_path,
        t.sort_no = s.sort_no,
        t.is_active = 1,
        t.updated_by = 'REG_ANALIST',
        t.updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
    VALUES (s.module_code, s.module_name, s.parent_module_code, s.endpoint_path, s.sort_no, 1, 'REG_ANALIST');
GO

DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL');
INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT @role_id, m.module_id, p.permission_id, 1, 'REG_ANALIST'
FROM dbo.RBAC_Module AS m
CROSS JOIN dbo.RBAC_Permission AS p
WHERE m.module_code IN ('REG_ANALIST', 'REG_GRP_ANALIST_DASH', 'REG_ANALIST_GMROI')
  AND p.permission_code IN ('VIEW', 'CREATE', 'UPDATE', 'DELETE', 'EXPORT')
  AND @role_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM dbo.RBAC_RolePermission rp
    WHERE rp.role_id = @role_id
      AND rp.module_id = m.module_id
      AND rp.permission_id = p.permission_id
  );
GO
