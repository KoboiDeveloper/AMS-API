SET NOCOUNT ON;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_list_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_list_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_list_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_report_nasional_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_report_total_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_report_total_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_report_total_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_wfh_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_wfh_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_wfh_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_adhoc_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_adhoc_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_adhoc_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_alfa_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_alfa_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_alfa_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_all_attendance_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_all_attendance_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_all_attendance_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_report_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_report_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_report_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_detail_kehadiran_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_detail_kehadiran_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_detail_kehadiran_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_dinas_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_dinas_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_dinas_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_export_employee_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_export_employee_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_export_employee_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_izin_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_izin_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_izin_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_kpi_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_kpi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_kpi_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_lembur_report_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_lembur_report_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_lembur_report_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_online_attendance_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_online_attendance_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_online_attendance_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payment_request_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payment_request_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payment_request_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_benefit_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_deduction_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_formula_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_variable_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
 DECLARE @active varchar(10)=LTRIM(RTRIM(ISNULL(@p_is_active,'')));
 SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
  SELECT TOP 2000 t1.PegawaiIDLng AS id, t1.NomorIndukStr AS nik, t1.NamaLengkapStr AS employee_name,
   t8.BrandStr AS brand, t7.NamaKantorCabangStr AS branch_name, t3.JabatanStr AS job_title,
   t4.DepartemenStr AS department, t5.StatusPegawaiStr AS status,
   CASE WHEN t1.PegawaiNonAktifInt=0 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS is_active
  FROM hris.dbo.tblpegawai t1
  LEFT JOIN hris.dbo.tblpegawaijabatan t2 ON t1.PegawaiIDLng=t2.PegawaiIDLng
  LEFT JOIN hris.dbo.tbljabatan t3 ON t2.JabatanIDLng=t3.JabatanIDLng
  LEFT JOIN hris.dbo.tbldepartemen t4 ON t2.DepartemenIDLng=t4.DepartemenIDLng
  LEFT JOIN hris.dbo.tblstatuspegawai t5 ON t2.StatusPegawaiIDLng=t5.StatusPegawaiIDLng
  LEFT JOIN hris.dbo.tblpegawaipenempatan t6 ON t1.PegawaiIDLng=t6.PegawaiIDLng
  LEFT JOIN hris.dbo.tblkantorcabang t7 ON t6.KantorCabangIDLng=t7.KantorCabangIDLng
  LEFT JOIN hris.dbo.tblformbrand t8 ON t7.BrandIDLng=t8.BrandIDLng
  WHERE ((@active IN ('1','true','TRUE') AND t1.PegawaiNonAktifInt=0) OR (@active IN ('0','false','FALSE') AND t1.PegawaiNonAktifInt=1) OR (@active=''))
    AND (@kw='' OR t1.NomorIndukStr LIKE '%'+@kw+'%' OR t1.NamaLengkapStr LIKE '%'+@kw+'%' OR ISNULL(t3.JabatanStr,'') LIKE '%'+@kw+'%' OR ISNULL(t7.NamaKantorCabangStr,'') LIKE '%'+@kw+'%')
  FOR JSON PATH)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
 SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kontrak_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_mutasi_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_promosi_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_resign_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_resign_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_resign_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_status_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_status_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_status_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sakit_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sakit_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sakit_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_salary_entry_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_salary_inquiry_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_salary_inquiry_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_salary_inquiry_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_salary_report_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_salary_report_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_salary_report_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_slip_gaji_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_slip_gaji_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_slip_gaji_getrows
( @p_keywords varchar(200)=NULL, @p_period varchar(30)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'Export Crystal belum tersedia di web baru' responseMessage, JSON_QUERY('[]') data, CAST(1 as bit) crystal_skipped FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_thr_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_thr_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_thr_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
