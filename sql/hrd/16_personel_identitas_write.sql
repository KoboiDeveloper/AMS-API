USE RBACESS;

GO

/* Real identitas insert/update — wraps POS_SERVER legacy SPs from JSON payload. */

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_update
(
  @p_id varchar(50)=NULL,
  @p_payload nvarchar(max)=NULL,
  @p_updated_by varchar(50)=NULL,
  @p_actor_nik varchar(50)=NULL,
  @bitparam varchar(max) OUTPUT
)
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @pid int = TRY_CAST(@p_id AS int);
  DECLARE @j nvarchar(max)=ISNULL(@p_payload, N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''), NULLIF(LTRIM(RTRIM(@p_actor_nik)),''), 'AMS');
  IF @pid IS NULL THROW 50001, 'invalid pegawai id', 1;

  DECLARE @jv_nik nvarchar(max)=JSON_VALUE(@j,'$.nik'), @jv_employee_name nvarchar(max)=JSON_VALUE(@j,'$.employee_name'), @jv_nama_panggilan nvarchar(max)=JSON_VALUE(@j,'$.nama_panggilan'), @jv_tempat_lahir_id nvarchar(max)=JSON_VALUE(@j,'$.tempat_lahir_id'), @jv_tanggal_lahir nvarchar(max)=JSON_VALUE(@j,'$.tanggal_lahir'), @jv_jenis_kelamin_id nvarchar(max)=JSON_VALUE(@j,'$.jenis_kelamin_id'), @jv_agama_id nvarchar(max)=JSON_VALUE(@j,'$.agama_id'), @jv_warga_negara_id nvarchar(max)=JSON_VALUE(@j,'$.warga_negara_id'), @jv_no_ktp nvarchar(max)=JSON_VALUE(@j,'$.no_ktp'), @jv_masa_berlaku_ktp nvarchar(max)=JSON_VALUE(@j,'$.masa_berlaku_ktp'), @jv_rangkuman nvarchar(max)=JSON_VALUE(@j,'$.rangkuman'), @jv_active_date nvarchar(max)=JSON_VALUE(@j,'$.active_date'), @jv_lokasi_absen_id nvarchar(max)=JSON_VALUE(@j,'$.lokasi_absen_id'), @jv_status_aktif nvarchar(max)=JSON_VALUE(@j,'$.status_aktif');
  EXEC POS_SERVER.dbo.xsp_personel_identitas_update
    @p_pegawai_id=@pid,
    @p_NomorIndukStr=@jv_nik,
    @p_NamaLengkapStr=@jv_employee_name,
    @p_NamaPanggilanStr=@jv_nama_panggilan,
    @p_TempatLahirIDLng=@jv_tempat_lahir_id,
    @p_TanggalLahirDtd=@jv_tanggal_lahir,
    @p_JenisKelaminIDLng=@jv_jenis_kelamin_id,
    @p_AgamaIDLng=@jv_agama_id,
    @p_KebangsaanIDLng=@jv_warga_negara_id,
    @p_NomorKTPStr=@jv_no_ktp,
    @p_KTPBerlakuHinggaDtd=@jv_masa_berlaku_ktp,
    @p_RangkumanStr=@jv_rangkuman,
    @p_TanggalMulaiAktifDtd=@jv_active_date,
    @p_LokasiAbsensiIDLng=@jv_lokasi_absen_id,
    @p_PegawaiNonAktifInt=@jv_status_aktif,
    @p_UserNameStr=@actor;

  SET @bitparam=(SELECT '2002500' responseCode,'Identitas tersimpan' responseMessage, JSON_QUERY((SELECT @pid AS id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_insert;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_insert
(
  @p_payload nvarchar(max)=NULL,
  @p_created_by varchar(50)=NULL,
  @p_actor_nik varchar(50)=NULL,
  @bitparam varchar(max) OUTPUT
)
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload, N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''), NULLIF(LTRIM(RTRIM(@p_actor_nik)),''), 'AMS');
  DECLARE @pid int = NULL;

  DECLARE @jv_nik nvarchar(max)=JSON_VALUE(@j,'$.nik'), @jv_employee_name nvarchar(max)=JSON_VALUE(@j,'$.employee_name'), @jv_nama_panggilan nvarchar(max)=JSON_VALUE(@j,'$.nama_panggilan'), @jv_tempat_lahir_id nvarchar(max)=JSON_VALUE(@j,'$.tempat_lahir_id'), @jv_tanggal_lahir nvarchar(max)=JSON_VALUE(@j,'$.tanggal_lahir'), @jv_jenis_kelamin_id nvarchar(max)=JSON_VALUE(@j,'$.jenis_kelamin_id'), @jv_agama_id nvarchar(max)=JSON_VALUE(@j,'$.agama_id'), @jv_warga_negara_id nvarchar(max)=JSON_VALUE(@j,'$.warga_negara_id'), @jv_no_ktp nvarchar(max)=JSON_VALUE(@j,'$.no_ktp'), @jv_masa_berlaku_ktp nvarchar(max)=JSON_VALUE(@j,'$.masa_berlaku_ktp'), @jv_rangkuman nvarchar(max)=JSON_VALUE(@j,'$.rangkuman'), @jv_active_date nvarchar(max)=JSON_VALUE(@j,'$.active_date'), @jv_lokasi_absen_id nvarchar(max)=JSON_VALUE(@j,'$.lokasi_absen_id'), @jv_status_aktif nvarchar(max)=JSON_VALUE(@j,'$.status_aktif');
  DECLARE @nik varchar(50)=@jv_nik;
  DECLARE @status_aktif varchar(10)=ISNULL(@jv_status_aktif,'0');
  EXEC POS_SERVER.dbo.xsp_personel_identitas_add_insert
    @p_pegawai_id=@pid OUTPUT,
    @p_NomorIndukStr=@nik,
    @p_NamaLengkapStr=@jv_employee_name,
    @p_NamaPanggilanStr=@jv_nama_panggilan,
    @p_TempatLahirIDLng=@jv_tempat_lahir_id,
    @p_TanggalLahirDtd=@jv_tanggal_lahir,
    @p_JenisKelaminIDLng=@jv_jenis_kelamin_id,
    @p_AgamaIDLng=@jv_agama_id,
    @p_KebangsaanIDLng=@jv_warga_negara_id,
    @p_NomorKTPStr=@jv_no_ktp,
    @p_KTPBerlakuHinggaDtd=@jv_masa_berlaku_ktp,
    @p_RangkumanStr=@jv_rangkuman,
    @p_TanggalMulaiAktifDtd=@jv_active_date,
    @p_LokasiAbsensiIDLng=@jv_lokasi_absen_id,
    @p_PegawaiNonAktifInt=@status_aktif,
    @p_UserNameStr=@actor,
    @p_web_input_store_awal=@actor;

  IF @pid IS NULL
    SELECT TOP 1 @pid=PegawaiIDLng FROM hris.dbo.tblpegawai WITH (NOLOCK) WHERE NomorIndukStr=@nik ORDER BY PegawaiIDLng DESC;

  SET @bitparam=(SELECT '2002500' responseCode,'Pegawai dibuat' responseMessage, JSON_QUERY((SELECT @pid AS id, @nik AS nik FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END

GO
