/* Marcomm — menu "Analisa Member" (MAR_MBR_ANALYTICS)

   Database : RBACESS
   Jalankan : _sqlrun.exe -db rbac -f sql/marcomm/04_member_analytics_rbac.sql

   Hanya INSERT bila belum ada. Tidak ada UPDATE atau DELETE: bila modul / izin sudah ada,
   skrip ini tidak mengubah apa pun. Izin yang diberikan ke role MARKETING: VIEW dan EXPORT.
*/
SET NOCOUNT ON;
GO

INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT 'MAR_MBR_ANALYTICS', 'Analisa Member', 'MAR_MEMBER', '/admin/marcomm/member/analytics', 15, 1, 'MARCOMM_ANALYTICS'
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = 'MAR_MBR_ANALYTICS')
  AND EXISTS (SELECT 1 FROM dbo.RBAC_Module AS p WHERE p.module_code = 'MAR_MEMBER');
GO

INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)
SELECT r.role_id, m.module_id, p.permission_id, 1, 'MARCOMM_ANALYTICS'
FROM dbo.RBAC_Role AS r
INNER JOIN dbo.RBAC_Module AS m ON m.module_code = 'MAR_MBR_ANALYTICS'
INNER JOIN dbo.RBAC_Permission AS p ON p.permission_code IN ('VIEW', 'EXPORT')
WHERE r.role_code = 'MARKETING'
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.RBAC_RolePermission AS rp
        WHERE rp.role_id = r.role_id
          AND rp.module_id = m.module_id
          AND rp.permission_id = p.permission_id
      );
GO

SELECT m.module_id, m.module_code, m.module_name, m.parent_module_code, m.endpoint_path, m.sort_no
     , (SELECT COUNT(*) FROM dbo.RBAC_RolePermission AS rp WHERE rp.module_id = m.module_id AND rp.is_active = 1) AS izin_aktif
FROM dbo.RBAC_Module AS m
WHERE m.module_code = 'MAR_MBR_ANALYTICS';
GO
