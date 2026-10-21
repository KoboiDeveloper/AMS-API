/*
  HRD menu labels — Title Case (no ALL CAPS). Idempotent.
*/
USE RBACESS;
GO

SET NOCOUNT ON;

DECLARE @names TABLE (
      module_code   varchar(80)  NOT NULL PRIMARY KEY
    , module_name   varchar(150) NOT NULL
);

INSERT INTO @names (module_code, module_name) VALUES
    ('HRD_ABS', 'Absensi'),
    ('HRD_CAB', 'Benefit'),
    ('HRD_RPT', 'Laporan'),
    ('HRD_PAR', 'Utility'),

    ('HRD_GRP_ATTENDANCE', 'Attendance'),
    ('HRD_GRP_PERSONEL', 'Personel'),
    ('HRD_GRP_GENERATE', 'Generate'),
    ('HRD_GRP_PAYROLL', 'Payroll'),
    ('HRD_GRP_PROCESS', 'Process'),
    ('HRD_GRP_REPORT', 'Report'),
    ('HRD_GRP_SYS_PARAM', 'System Param'),
    ('HRD_GRP_MASTER', 'Master'),
    ('HRD_GRP_EOM', 'End Of Month'),

    ('HRD_ABS_ONLINE_LIST', 'Online Attendance List'),
    ('HRD_ABS_ALL_ATTENDANCE', 'All Attendance'),
    ('HRD_ABS_PERSONEL', 'Personel Info'),
    ('HRD_ABS_KONTRAK', 'Kontrak'),
    ('HRD_ABS_STATUS', 'Status'),
    ('HRD_ABS_PROMOSI', 'Promosi'),
    ('HRD_ABS_MUTASI', 'Mutasi'),
    ('HRD_ABS_RESIGN', 'Pengunduran Diri'),
    ('HRD_ABS_GENERATE_STORE', 'Absen Store'),
    ('HRD_ABS_GENERATE_NASIONAL', 'Absen Nasional'),

    ('HRD_CAB_VARIABLE', 'Payroll Variable'),
    ('HRD_CAB_FORMULA', 'Payroll Formula'),
    ('HRD_CAB_BENEFIT', 'Benefit'),
    ('HRD_CAB_DEDUCTION', 'Deduction'),
    ('HRD_CAB_SALARY_ENTRY', 'Payroll Salary Entry'),
    ('HRD_CAB_SALARY_INQUIRY', 'Payroll Inquiry'),
    ('HRD_CAB_SALARY_REPORT', 'Salary Report'),
    ('HRD_CAB_THR', 'THR Generate'),
    ('HRD_CAB_MONTHLY', 'Monthly Payroll'),
    ('HRD_CAB_PAYMENT', 'Payment Request'),

    ('HRD_RPT_ABSEN_WFH', 'Absen WFH'),
    ('HRD_RPT_ABSEN_TOTAL', 'Absen Report'),
    ('HRD_RPT_ABSEN_NASIONAL', 'Absen Nasional'),
    ('HRD_RPT_CUTI', 'Info Cuti'),
    ('HRD_RPT_LEMBUR', 'Lembur'),
    ('HRD_RPT_SLIP_GAJI', 'Slip Gaji'),
    ('HRD_RPT_EXPORT_EMP', 'Export Data Karyawan'),
    ('HRD_RPT_DETAIL_HADIR', 'Detail Kehadiran'),
    ('HRD_RPT_KPI', 'KPI - Karyawan'),

    ('HRD_PAR_ADHOC', 'Special Activity'),
    ('HRD_PAR_DINAS', 'Dinas'),
    ('HRD_PAR_IZIN', 'Izin'),
    ('HRD_PAR_CUTI', 'Cuti'),
    ('HRD_PAR_SAKIT', 'Sakit'),
    ('HRD_PAR_OVERTIME', 'Overtime'),
    ('HRD_PAR_ALFA', 'Alfa'),
    ('HRD_PAR_HOLIDAY', 'Master Holiday'),
    ('HRD_PAR_OT_AMOUNT', 'Master Overtime Amount'),
    ('HRD_PAR_POLICY', 'Policy'),
    ('HRD_PAR_PERUSAHAAN', 'Perusahaan'),
    ('HRD_PAR_CABANG', 'Cabang'),
    ('HRD_PAR_DIVISI', 'Divisi'),
    ('HRD_PAR_DEPARTEMEN', 'Departemen'),
    ('HRD_PAR_GOLONGAN', 'Golongan'),
    ('HRD_PAR_PANGKAT', 'Pangkat'),
    ('HRD_PAR_JABATAN', 'Jabatan'),
    ('HRD_PAR_SM_DEPT', 'SM Department List'),
    ('HRD_PAR_EOM', 'End Of Month');

UPDATE m
SET
    m.module_name = n.module_name,
    m.updated_by = 'MIGRATION',
    m.updated_at = SYSUTCDATETIME()
FROM dbo.RBAC_Module AS m
INNER JOIN @names AS n ON n.module_code = m.module_code;
GO

PRINT '12_hrd_menu_title_case.sql completed.';
GO
