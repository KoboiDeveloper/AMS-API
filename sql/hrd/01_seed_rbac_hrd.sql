/*
  HRD RBAC seed — INSERT only. Never DELETE legacy data.
  DB: RBACESS
  Default HRD login password: Hrd@2026!
  username = lowercase(ID_USER), nik = ID_USER
*/
SET NOCOUNT ON;
GO

/* Role HRD */
IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Role WHERE role_code = 'HRD')
BEGIN
    INSERT INTO dbo.RBAC_Role(role_code, role_name, scope_level, description, is_active, created_by)
    VALUES ('HRD', 'HRD Head Office', 'GLOBAL', 'Migrated from WEB_USER_MAIN roll_code 76', 1, 'HRD_MIGRATION');
END
GO

/* Parent modules */
DECLARE @parents TABLE(code varchar(80), name varchar(150), path varchar(250), sort_no int);
INSERT INTO @parents VALUES
 ('HRD_ABS','HRD Absensi & Personel','/admin/hrd/abs',100),
 ('HRD_PAR','HRD Parameter & Master','/admin/hrd/par',200),
 ('HRD_RPT','HRD Laporan','/admin/hrd/rpt',300),
 ('HRD_CAB','HRD Compensation & Benefit','/admin/hrd/cab',400);

INSERT INTO dbo.RBAC_Module(module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT p.code, p.name, NULL, p.path, p.sort_no, 1, 'HRD_MIGRATION'
FROM @parents p
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module m WHERE m.module_code = p.code);
GO

/* Child modules — 48 pages */
DECLARE @mods TABLE(code varchar(80), name varchar(150), parent varchar(80), path varchar(250), sort_no int);
INSERT INTO @mods VALUES
-- ABS (10)
('HRD_ABS_ONLINE_LIST','Online Attendance List','HRD_ABS','/admin/hrd/abs/online-attendance',101),
('HRD_ABS_ALL_ATTENDANCE','All Attendance','HRD_ABS','/admin/hrd/abs/all-attendance',102),
('HRD_ABS_GENERATE_STORE','Generate Absen Store','HRD_ABS','/admin/hrd/abs/generate-store',103),
('HRD_ABS_GENERATE_NASIONAL','Generate Absen Nasional','HRD_ABS','/admin/hrd/abs/generate-nasional',104),
('HRD_ABS_PERSONEL','Personel Info','HRD_ABS','/admin/hrd/abs/personel',105),
('HRD_ABS_KONTRAK','Personel Kontrak','HRD_ABS','/admin/hrd/abs/kontrak',106),
('HRD_ABS_STATUS','Personel Status','HRD_ABS','/admin/hrd/abs/status',107),
('HRD_ABS_PROMOSI','Personel Promosi','HRD_ABS','/admin/hrd/abs/promosi',108),
('HRD_ABS_MUTASI','Personel Mutasi','HRD_ABS','/admin/hrd/abs/mutasi',109),
('HRD_ABS_RESIGN','Pengunduran Diri','HRD_ABS','/admin/hrd/abs/resign',110),
-- PAR System (10)
('HRD_PAR_ADHOC','Special Activity','HRD_PAR','/admin/hrd/par/adhoc',201),
('HRD_PAR_DINAS','Dinas','HRD_PAR','/admin/hrd/par/dinas',202),
('HRD_PAR_IZIN','Izin','HRD_PAR','/admin/hrd/par/izin',203),
('HRD_PAR_CUTI','Cuti','HRD_PAR','/admin/hrd/par/cuti',204),
('HRD_PAR_SAKIT','Sakit','HRD_PAR','/admin/hrd/par/sakit',205),
('HRD_PAR_OVERTIME','Overtime','HRD_PAR','/admin/hrd/par/overtime',206),
('HRD_PAR_ALFA','Alfa','HRD_PAR','/admin/hrd/par/alfa',207),
('HRD_PAR_HOLIDAY','Master Holiday','HRD_PAR','/admin/hrd/par/holiday',208),
('HRD_PAR_OT_AMOUNT','Overtime Amount','HRD_PAR','/admin/hrd/par/overtime-amount',209),
('HRD_PAR_POLICY','Policy','HRD_PAR','/admin/hrd/par/policy',210),
-- PAR Master (8)
('HRD_PAR_PERUSAHAAN','Master Perusahaan','HRD_PAR','/admin/hrd/par/perusahaan',211),
('HRD_PAR_CABANG','Master Cabang','HRD_PAR','/admin/hrd/par/cabang',212),
('HRD_PAR_DIVISI','Master Divisi','HRD_PAR','/admin/hrd/par/divisi',213),
('HRD_PAR_DEPARTEMEN','Master Departemen','HRD_PAR','/admin/hrd/par/departemen',214),
('HRD_PAR_GOLONGAN','Master Golongan','HRD_PAR','/admin/hrd/par/golongan',215),
('HRD_PAR_PANGKAT','Master Pangkat','HRD_PAR','/admin/hrd/par/pangkat',216),
('HRD_PAR_JABATAN','Master Jabatan','HRD_PAR','/admin/hrd/par/jabatan',217),
('HRD_PAR_SM_DEPT','SM Department','HRD_PAR','/admin/hrd/par/sm-dept',218),
('HRD_PAR_EOM','End Of Month','HRD_PAR','/admin/hrd/par/eom',219),
-- RPT (9)
('HRD_RPT_ABSEN_TOTAL','Absen Report','HRD_RPT','/admin/hrd/rpt/absen-total',301),
('HRD_RPT_ABSEN_NASIONAL','Absen Nasional','HRD_RPT','/admin/hrd/rpt/absen-nasional',302),
('HRD_RPT_ABSEN_WFH','Absen WFH','HRD_RPT','/admin/hrd/rpt/absen-wfh',303),
('HRD_RPT_DETAIL_KEHADIRAN','Detail Kehadiran','HRD_RPT','/admin/hrd/rpt/detail-kehadiran',304),
('HRD_RPT_EXPORT_KARYAWAN','Export Data Karyawan','HRD_RPT','/admin/hrd/rpt/export-karyawan',305),
('HRD_RPT_CUTI','Info Cuti','HRD_RPT','/admin/hrd/rpt/cuti',306),
('HRD_RPT_LEMBUR','Lembur','HRD_RPT','/admin/hrd/rpt/lembur',307),
('HRD_RPT_SLIP_GAJI','Slip Gaji','HRD_RPT','/admin/hrd/rpt/slip-gaji',308),
('HRD_RPT_KPI','KPI Karyawan','HRD_RPT','/admin/hrd/rpt/kpi',309),
-- CAB (10)
('HRD_CAB_VARIABLE','Payroll Variable','HRD_CAB','/admin/hrd/cab/variable',401),
('HRD_CAB_FORMULA','Payroll Formula','HRD_CAB','/admin/hrd/cab/formula',402),
('HRD_CAB_BENEFIT','Benefit','HRD_CAB','/admin/hrd/cab/benefit',403),
('HRD_CAB_DEDUCTION','Deduction','HRD_CAB','/admin/hrd/cab/deduction',404),
('HRD_CAB_SALARY_ENTRY','Payroll Salary Entry','HRD_CAB','/admin/hrd/cab/salary-entry',405),
('HRD_CAB_SALARY_INQUIRY','Payroll Inquiry','HRD_CAB','/admin/hrd/cab/salary-inquiry',406),
('HRD_CAB_SALARY_REPORT','Salary Report','HRD_CAB','/admin/hrd/cab/salary-report',407),
('HRD_CAB_THR','THR Generate','HRD_CAB','/admin/hrd/cab/thr',408),
('HRD_CAB_MONTHLY','Monthly Payroll','HRD_CAB','/admin/hrd/cab/monthly-process',409),
('HRD_CAB_PAYMENT_REQ','Payment Request','HRD_CAB','/admin/hrd/cab/payment-request',410);

INSERT INTO dbo.RBAC_Module(module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)
SELECT x.code, x.name, x.parent, x.path, x.sort_no, 1, 'HRD_MIGRATION'
FROM @mods x
WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module m WHERE m.module_code = x.code);
GO

/* Role permissions VIEW/CREATE/UPDATE/DELETE (+EXPORT for reports) */
DECLARE @perms TABLE(code varchar(80));
INSERT INTO @perms VALUES ('VIEW'),('CREATE'),('UPDATE'),('DELETE'),('EXPORT');

INSERT INTO dbo.RBAC_RolePermission(role_id, module_id, permission_id, is_active, created_by)
SELECT r.role_id, m.module_id, p.permission_id, 1, 'HRD_MIGRATION'
FROM dbo.RBAC_Role r
CROSS JOIN dbo.RBAC_Module m
CROSS JOIN dbo.RBAC_Permission p
INNER JOIN @perms x ON x.code = p.permission_code
WHERE r.role_code = 'HRD'
  AND (m.module_code LIKE 'HRD_%')
  AND NOT EXISTS (
      SELECT 1 FROM dbo.RBAC_RolePermission rp
      WHERE rp.role_id = r.role_id AND rp.module_id = m.module_id AND rp.permission_id = p.permission_id
  );
GO

/* Employees + AuthUser + UserRole for HRD usernames */
DECLARE @users TABLE(id_user varchar(30), nama varchar(150));
INSERT INTO @users VALUES
('DAMARHRD','DAMAR'),('DELLAHRD','HRD DELLA'),('DHIKAHRD','DHIKA'),('FEBBYHRD','FEBBY HRD'),
('LAURAHRD','LAURA'),('LINAHRD','HRD LINA'),('LINDAHRD','LINDA HRD'),('LUSIHRD','HRD LUSI'),
('NADIAHRD','HRD NADIA'),('REGITAHRD','REGITA'),('RIFKIHRD2','RIFKI HRD'),('RIOHRD','HRD RIO'),('SUCIHRD','SUCI');

DECLARE @pwd varchar(50) = 'Hrd@2026!';
DECLARE @id_user varchar(30), @nama varchar(150), @username varchar(80), @salt varchar(80), @hash varchar(64);

DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT id_user, nama FROM @users;
OPEN c;
FETCH NEXT FROM c INTO @id_user, @nama;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Employee WHERE nik = @id_user)
    BEGIN
        INSERT INTO dbo.RBAC_Employee(nik, employee_name, employee_type, job_title, is_active, created_by)
        VALUES (@id_user, @nama, 'OFFICE', 'HRD', 1, 'HRD_MIGRATION');
    END

    SET @username = LOWER(@id_user);
    IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_AuthUser WHERE nik = @id_user OR username = @username)
    BEGIN
        SET @salt = REPLACE(CONVERT(varchar(36), NEWID()), '-', '');
        SET @hash = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @salt + @pwd)), 2);
        INSERT INTO dbo.RBAC_AuthUser(username, nik, password_salt, password_hash, is_active, failed_login_count, force_change_password, created_by)
        VALUES (@username, @id_user, @salt, @hash, 1, 0, 0, 'HRD_MIGRATION');
    END

    IF NOT EXISTS (
        SELECT 1 FROM dbo.RBAC_UserRole ur
        INNER JOIN dbo.RBAC_Role r ON r.role_id = ur.role_id
        WHERE ur.nik = @id_user AND r.role_code = 'HRD' AND ur.is_active = 1
    )
    BEGIN
        INSERT INTO dbo.RBAC_UserRole(nik, role_id, start_date, is_active, created_by)
        SELECT @id_user, role_id, CONVERT(date, GETDATE()), 1, 'HRD_MIGRATION'
        FROM dbo.RBAC_Role WHERE role_code = 'HRD';
    END

    FETCH NEXT FROM c INTO @id_user, @nama;
END
CLOSE c; DEALLOCATE c;
GO
