SET NOCOUNT ON;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_generate_process', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_process
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @p_period varchar(30)=NULL, @p_store_id varchar(30)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'process accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_generate_nasional_process', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_nasional_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_nasional_process
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @p_period varchar(30)=NULL, @p_store_id varchar(30)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'process accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_generate_store_process', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_store_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_generate_store_process
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @p_period varchar(30)=NULL, @p_store_id varchar(30)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'process accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_eom_process', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_eom_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_eom_process
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @p_period varchar(30)=NULL, @p_store_id varchar(30)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'process accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_monthly_payroll_process', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_monthly_payroll_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_monthly_payroll_process
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @p_period varchar(30)=NULL, @p_store_id varchar(30)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'process accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_adhoc_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_adhoc_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_adhoc_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_alfa_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_alfa_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_alfa_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_dinas_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_dinas_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_dinas_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_izin_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_izin_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_izin_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payment_request_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payment_request_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payment_request_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_benefit_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_deduction_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_formula_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_variable_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sakit_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sakit_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sakit_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_salary_entry_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_insert ( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'insert accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_adhoc_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_adhoc_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_adhoc_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_alfa_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_alfa_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_alfa_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_dinas_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_dinas_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_dinas_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_izin_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_izin_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_izin_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payment_request_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payment_request_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payment_request_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_benefit_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_deduction_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_formula_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_variable_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sakit_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sakit_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sakit_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_salary_entry_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_update ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'update accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_adhoc_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_adhoc_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_adhoc_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_alfa_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_alfa_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_alfa_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_dinas_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_dinas_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_dinas_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_izin_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_izin_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_izin_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payment_request_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payment_request_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payment_request_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_benefit_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_deduction_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_formula_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_variable_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sakit_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sakit_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sakit_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_salary_entry_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_delete ( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'delete accepted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_adhoc_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_adhoc_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_adhoc_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_alfa_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_alfa_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_alfa_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_cuti_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_cuti_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_cuti_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_dinas_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_dinas_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_dinas_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_izin_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_izin_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_izin_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payment_request_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payment_request_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payment_request_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_benefit_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_benefit_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_deduction_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_deduction_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_formula_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_formula_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_payroll_variable_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_payroll_variable_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sakit_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sakit_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sakit_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_salary_entry_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_salary_entry_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_getrow ( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT ) AS BEGIN SET NOCOUNT ON; SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY((SELECT @p_id id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END
GO
