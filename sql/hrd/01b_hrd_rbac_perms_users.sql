/*
  HRD role-permissions + users (fix after modules/role exist)
*/
SET NOCOUNT ON;
GO

DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'HRD');

INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_at, created_by)
SELECT @role_id, m.module_id, p.permission_id, 1, GETDATE(), 'MIGRATION'
FROM dbo.RBAC_Module m
CROSS JOIN dbo.RBAC_Permission p
WHERE m.module_code LIKE 'HRD%'
  AND p.permission_code IN ('VIEW','CREATE','UPDATE','DELETE','EXPORT')
  AND p.is_active = 1
  AND @role_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RBAC_RolePermission rp
      WHERE rp.role_id = @role_id AND rp.module_id = m.module_id AND rp.permission_id = p.permission_id
  );
GO

DECLARE @users TABLE (uid varchar(50), full_name varchar(100));
INSERT INTO @users VALUES
('DAMARHRD','DAMAR'),('DELLAHRD','HRD DELLA'),('DHIKAHRD','DHIKA'),('FEBBYHRD','HRD FEBBY'),
('LAURAHRD','ANNA'),('LINAHRD','HRD LINA'),('LINDAHRD','LINDA HRD'),('LUSIHRD','HRD LUSI'),
('NADIAHRD','HRD NADIA'),('REGITAHRD','REGITA'),('RIFKIHRD2','RIFKI'),('RIOHRD','HRD RIO'),('SUCIHRD','SUCI');

DECLARE @uid varchar(50), @fname varchar(100), @salt varchar(80), @hash varchar(64), @pwd varchar(50) = 'Hrd@12345';
DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'HRD');

DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT uid, full_name FROM @users;
OPEN c;
FETCH NEXT FROM c INTO @uid, @fname;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Employee WHERE nik = @uid)
    BEGIN
        INSERT INTO dbo.RBAC_Employee (nik, employee_name, employee_type, job_title, is_active, created_at, created_by)
        VALUES (@uid, @fname, 'HRD', 'HRD Staff', 1, GETDATE(), 'MIGRATION');
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_AuthUser WHERE LOWER(username) = LOWER(@uid))
    BEGIN
        SET @salt = LOWER(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''));
        SET @hash = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @salt + @pwd)), 2);
        INSERT INTO dbo.RBAC_AuthUser (username, nik, password_salt, password_hash, is_active, failed_login_count, force_change_password, created_at, created_by)
        VALUES (@uid, @uid, @salt, @hash, 1, 0, 1, GETDATE(), 'MIGRATION');
    END

    IF @role_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM dbo.RBAC_UserRole ur WHERE ur.nik = @uid AND ur.role_id = @role_id AND ur.is_active = 1
    )
    BEGIN
        INSERT INTO dbo.RBAC_UserRole (nik, role_id, start_date, is_active, created_at, created_by)
        VALUES (@uid, @role_id, CONVERT(date, GETDATE()), 1, GETDATE(), 'MIGRATION');
    END

    FETCH NEXT FROM c INTO @uid, @fname;
END
CLOSE c; DEALLOCATE c;
GO
