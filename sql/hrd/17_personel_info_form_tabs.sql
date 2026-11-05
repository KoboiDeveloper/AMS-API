USE RBACESS;

GO

/* Form tabs: alamat, kesehatan, bank, sipil, pendidikan-terakhir, kondisi-kerja, aktifitas — getrow from hris, update via POS. */

/* ========== ALAMAT ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_alamat_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_alamat_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_alamat_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiIDLng AS id, UtamaTelpStr AS telp_utama, UtamaEmailStr AS email_utama,
      DaruratTelpStr AS telp_darurat, DaruratEmailStr AS email_darurat, DaruratNamaStr AS nama_darurat,
      TinggalJalanStr AS tinggal_jalan, TinggalKelurahanStr AS tinggal_kelurahan, TinggalKecamatanStr AS tinggal_kecamatan,
      TinggalKotaIDLng AS tinggal_kota_id, TinggalKodePosInt AS tinggal_kode_pos, TinggalProvinsiIDLng AS tinggal_provinsi_id,
      TinggalTeleponStr AS tinggal_telp,
      KTPJalanStr AS ktp_jalan, KTPKelurahanStr AS ktp_kelurahan, KTPKecamatanStr AS ktp_kecamatan,
      KTPKotaIDLng AS ktp_kota_id, KTPKodePosInt AS ktp_kode_pos, KTPProvinsiIDLng AS ktp_provinsi_id, KTPTeleponStr AS ktp_telp
    FROM hris.dbo.tblpegawaialamat WITH (NOLOCK) WHERE PegawaiIDLng=@pid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_alamat_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_alamat_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_alamat_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int); DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @jv_telp_utama nvarchar(max)=JSON_VALUE(@j,'$.telp_utama'), @jv_email_utama nvarchar(max)=JSON_VALUE(@j,'$.email_utama'), @jv_telp_darurat nvarchar(max)=JSON_VALUE(@j,'$.telp_darurat'), @jv_email_darurat nvarchar(max)=JSON_VALUE(@j,'$.email_darurat'), @jv_nama_darurat nvarchar(max)=JSON_VALUE(@j,'$.nama_darurat'), @jv_tinggal_jalan nvarchar(max)=JSON_VALUE(@j,'$.tinggal_jalan'), @jv_tinggal_kelurahan nvarchar(max)=JSON_VALUE(@j,'$.tinggal_kelurahan'), @jv_tinggal_kecamatan nvarchar(max)=JSON_VALUE(@j,'$.tinggal_kecamatan'), @jv_tinggal_kota_id nvarchar(max)=JSON_VALUE(@j,'$.tinggal_kota_id'), @jv_tinggal_kode_pos nvarchar(max)=JSON_VALUE(@j,'$.tinggal_kode_pos'), @jv_tinggal_provinsi_id nvarchar(max)=JSON_VALUE(@j,'$.tinggal_provinsi_id'), @jv_tinggal_telp nvarchar(max)=JSON_VALUE(@j,'$.tinggal_telp'), @jv_ktp_jalan nvarchar(max)=JSON_VALUE(@j,'$.ktp_jalan'), @jv_ktp_kelurahan nvarchar(max)=JSON_VALUE(@j,'$.ktp_kelurahan'), @jv_ktp_kecamatan nvarchar(max)=JSON_VALUE(@j,'$.ktp_kecamatan'), @jv_ktp_kota_id nvarchar(max)=JSON_VALUE(@j,'$.ktp_kota_id'), @jv_ktp_kode_pos nvarchar(max)=JSON_VALUE(@j,'$.ktp_kode_pos'), @jv_ktp_provinsi_id nvarchar(max)=JSON_VALUE(@j,'$.ktp_provinsi_id'), @jv_ktp_telp nvarchar(max)=JSON_VALUE(@j,'$.ktp_telp'), @jv_gol_darah_id nvarchar(max)=JSON_VALUE(@j,'$.gol_darah_id'), @jv_tinggi nvarchar(max)=JSON_VALUE(@j,'$.tinggi'), @jv_berat nvarchar(max)=JSON_VALUE(@j,'$.berat'), @jv_kacamata nvarchar(max)=JSON_VALUE(@j,'$.kacamata'), @jv_kacamata_kiri nvarchar(max)=JSON_VALUE(@j,'$.kacamata_kiri'), @jv_kacamata_kanan nvarchar(max)=JSON_VALUE(@j,'$.kacamata_kanan'), @jv_sakit_keras nvarchar(max)=JSON_VALUE(@j,'$.sakit_keras'), @jv_jenis_penyakit nvarchar(max)=JSON_VALUE(@j,'$.jenis_penyakit'), @jv_lama_perawatan nvarchar(max)=JSON_VALUE(@j,'$.lama_perawatan'), @jv_diperiksa_dokter nvarchar(max)=JSON_VALUE(@j,'$.diperiksa_dokter'), @jv_alasan nvarchar(max)=JSON_VALUE(@j,'$.alasan'), @jv_bank_id nvarchar(max)=JSON_VALUE(@j,'$.bank_id'), @jv_no_rekening nvarchar(max)=JSON_VALUE(@j,'$.no_rekening'), @jv_jenis_bayar_id nvarchar(max)=JSON_VALUE(@j,'$.jenis_bayar_id'), @jv_pasangan_nama nvarchar(max)=JSON_VALUE(@j,'$.pasangan_nama'), @jv_pasangan_hubungan_id nvarchar(max)=JSON_VALUE(@j,'$.pasangan_hubungan_id'), @jv_pasangan_bank_id nvarchar(max)=JSON_VALUE(@j,'$.pasangan_bank_id'), @jv_pasangan_no_rekening nvarchar(max)=JSON_VALUE(@j,'$.pasangan_no_rekening'), @jv_pasangan_jenis_bayar_id nvarchar(max)=JSON_VALUE(@j,'$.pasangan_jenis_bayar_id'), @jv_npwp nvarchar(max)=JSON_VALUE(@j,'$.npwp'), @jv_jamsostek nvarchar(max)=JSON_VALUE(@j,'$.jamsostek'), @jv_bpjs nvarchar(max)=JSON_VALUE(@j,'$.bpjs'), @jv_asuransi nvarchar(max)=JSON_VALUE(@j,'$.asuransi'), @jv_status_sipil_id nvarchar(max)=JSON_VALUE(@j,'$.status_sipil_id'), @jv_tempat_tinggal_id nvarchar(max)=JSON_VALUE(@j,'$.tempat_tinggal_id'), @jv_tempat_tinggal_lain nvarchar(max)=JSON_VALUE(@j,'$.tempat_tinggal_lain'), @jv_transportasi_id nvarchar(max)=JSON_VALUE(@j,'$.transportasi_id'), @jv_transportasi_lain nvarchar(max)=JSON_VALUE(@j,'$.transportasi_lain'), @jv_sim1_id nvarchar(max)=JSON_VALUE(@j,'$.sim1_id'), @jv_sim1_tahun nvarchar(max)=JSON_VALUE(@j,'$.sim1_tahun'), @jv_sim1_daerah nvarchar(max)=JSON_VALUE(@j,'$.sim1_daerah'), @jv_sim2_id nvarchar(max)=JSON_VALUE(@j,'$.sim2_id'), @jv_sim2_tahun nvarchar(max)=JSON_VALUE(@j,'$.sim2_tahun'), @jv_sim2_daerah nvarchar(max)=JSON_VALUE(@j,'$.sim2_daerah');
  EXEC POS_SERVER.dbo.xsp_personel_alamat_ss_update
    @p_pegawai_id=@pid,
    @p_UtamaTelpStr=@jv_telp_utama, @p_UtamaEmailStr=@jv_email_utama,
    @p_DaruratTelpStr=@jv_telp_darurat, @p_DaruratEmailStr=@jv_email_darurat,
    @p_DaruratNamaStr=@jv_nama_darurat,
    @p_TinggalJalanStr=@jv_tinggal_jalan, @p_TinggalKelurahanStr=@jv_tinggal_kelurahan,
    @p_TinggalKecamatanStr=@jv_tinggal_kecamatan, @p_TinggalKotaIDLng=@jv_tinggal_kota_id,
    @p_TinggalKodePosInt=@jv_tinggal_kode_pos, @p_TinggalProvinsiIDLng=@jv_tinggal_provinsi_id,
    @p_TinggalTeleponStr=@jv_tinggal_telp,
    @p_KTPJalanStr=@jv_ktp_jalan, @p_KTPKelurahanStr=@jv_ktp_kelurahan,
    @p_KTPKecamatanStr=@jv_ktp_kecamatan, @p_KTPKotaIDLng=@jv_ktp_kota_id,
    @p_KTPKodePosInt=@jv_ktp_kode_pos, @p_KTPProvinsiIDLng=@jv_ktp_provinsi_id,
    @p_KTPTeleponStr=@jv_ktp_telp, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'Alamat tersimpan' responseMessage, JSON_QUERY((SELECT @pid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== KESEHATAN ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kesehatan_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kesehatan_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kesehatan_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiIDLng AS id, GolonganDarahIDLng AS gol_darah_id, TinggiBadanInt AS tinggi, BeratBadanInt AS berat,
      KacaMataInt AS kacamata, KacaMataKiriStr AS kacamata_kiri, KacaMataKananStr AS kacamata_kanan,
      SakitKerasInt AS sakit_keras, JenisPenyakitStr AS jenis_penyakit, LamaPerawatanStr AS lama_perawatan,
      DiperiksaDokterPerusahaanInt AS diperiksa_dokter, AlasanStr AS alasan
    FROM hris.dbo.tblpegawaikesehatan WITH (NOLOCK) WHERE PegawaiIDLng=@pid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kesehatan_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kesehatan_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kesehatan_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int); DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @jv_gol_darah_id nvarchar(max)=JSON_VALUE(@j,'$.gol_darah_id'), @jv_tinggi nvarchar(max)=JSON_VALUE(@j,'$.tinggi'), @jv_berat nvarchar(max)=JSON_VALUE(@j,'$.berat'), @jv_kacamata nvarchar(max)=JSON_VALUE(@j,'$.kacamata'), @jv_kacamata_kiri nvarchar(max)=JSON_VALUE(@j,'$.kacamata_kiri'), @jv_kacamata_kanan nvarchar(max)=JSON_VALUE(@j,'$.kacamata_kanan'), @jv_sakit_keras nvarchar(max)=JSON_VALUE(@j,'$.sakit_keras'), @jv_jenis_penyakit nvarchar(max)=JSON_VALUE(@j,'$.jenis_penyakit'), @jv_lama_perawatan nvarchar(max)=JSON_VALUE(@j,'$.lama_perawatan'), @jv_diperiksa_dokter nvarchar(max)=JSON_VALUE(@j,'$.diperiksa_dokter'), @jv_alasan nvarchar(max)=JSON_VALUE(@j,'$.alasan');
  EXEC POS_SERVER.dbo.xsp_personel_kesehatan_ss_update
    @p_pegawai_id=@pid, @p_GolonganDarahIDLng=@jv_gol_darah_id,
    @p_TinggiBadanInt=@jv_tinggi, @p_BeratBadanInt=@jv_berat,
    @p_KacaMataInt=@jv_kacamata, @p_KacaMataKiriStr=@jv_kacamata_kiri,
    @p_KacaMataKananStr=@jv_kacamata_kanan, @p_SakitKerasInt=@jv_sakit_keras,
    @p_JenisPenyakitStr=@jv_jenis_penyakit, @p_LamaPerawatanStr=@jv_lama_perawatan,
    @p_DiperiksaDokterPerusahaanInt=@jv_diperiksa_dokter, @p_AlasanStr=@jv_alasan,
    @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'Kesehatan tersimpan' responseMessage, JSON_QUERY((SELECT @pid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== BANK ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_bank_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_bank_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_bank_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiIDLng AS id, BankIDLng AS bank_id, NomorRekeningStr AS no_rekening, JenisPembayaranIDLng AS jenis_bayar_id,
      PasanganNamaStr AS pasangan_nama, PasanganHubunganKeluargaIDLng AS pasangan_hubungan_id,
      PasanganBankIDLng AS pasangan_bank_id, PasanganNomorRekeningStr AS pasangan_no_rekening,
      PasanganJenisPembayaranIDLng AS pasangan_jenis_bayar_id,
      NpwpNomorStr AS npwp, JamsostekNomorStr AS jamsostek, BpjsKesehatan AS bpjs, AsuransiNomorStr AS asuransi
    FROM hris.dbo.tblpegawaibank WITH (NOLOCK) WHERE PegawaiIDLng=@pid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_bank_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_bank_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_bank_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int); DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @jv_bank_id nvarchar(max)=JSON_VALUE(@j,'$.bank_id'), @jv_no_rekening nvarchar(max)=JSON_VALUE(@j,'$.no_rekening'), @jv_jenis_bayar_id nvarchar(max)=JSON_VALUE(@j,'$.jenis_bayar_id'), @jv_pasangan_nama nvarchar(max)=JSON_VALUE(@j,'$.pasangan_nama'), @jv_pasangan_hubungan_id nvarchar(max)=JSON_VALUE(@j,'$.pasangan_hubungan_id'), @jv_pasangan_bank_id nvarchar(max)=JSON_VALUE(@j,'$.pasangan_bank_id'), @jv_pasangan_no_rekening nvarchar(max)=JSON_VALUE(@j,'$.pasangan_no_rekening'), @jv_pasangan_jenis_bayar_id nvarchar(max)=JSON_VALUE(@j,'$.pasangan_jenis_bayar_id'), @jv_npwp nvarchar(max)=JSON_VALUE(@j,'$.npwp'), @jv_jamsostek nvarchar(max)=JSON_VALUE(@j,'$.jamsostek'), @jv_bpjs nvarchar(max)=JSON_VALUE(@j,'$.bpjs'), @jv_asuransi nvarchar(max)=JSON_VALUE(@j,'$.asuransi');
  EXEC POS_SERVER.dbo.xsp_personel_bank_ss_update
    @p_pegawai_id=@pid, @p_BankIDLng=@jv_bank_id, @p_NomorRekeningStr=@jv_no_rekening,
    @p_JenisPembayaranIDLng=@jv_jenis_bayar_id, @p_PasanganNamaStr=@jv_pasangan_nama,
    @p_PasanganHubunganKeluargaIDLng=@jv_pasangan_hubungan_id, @p_PasanganBankIDLng=@jv_pasangan_bank_id,
    @p_PasanganNomorRekeningStr=@jv_pasangan_no_rekening, @p_PasanganJenisPembayaranIDLng=@jv_pasangan_jenis_bayar_id,
    @p_NpwpNomorStr=@jv_npwp, @p_JamsostekNomorStr=@jv_jamsostek,
    @p_NoBpjsKesehatan=@jv_bpjs, @p_AsuransiNomorStr=@jv_asuransi, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'Bank tersimpan' responseMessage, JSON_QUERY((SELECT @pid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== SIPIL (form) ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_sipil_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_sipil_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_sipil_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiIDLng AS id, StatusSipilIDLng AS status_sipil_id, TempatTinggalIDLng AS tempat_tinggal_id,
      TempatTinggalLainnyaStr AS tempat_tinggal_lain, TransportasiIDLng AS transportasi_id, TransportasiLainnyaStr AS transportasi_lain,
      Sim1IDLng AS sim1_id, Sim1TahunInt AS sim1_tahun, Sim1KepolisianStr AS sim1_daerah,
      Sim2IDLng AS sim2_id, Sim2TahunInt AS sim2_tahun, Sim2KepolisianStr AS sim2_daerah
    FROM hris.dbo.tblpegawaistatussipil WITH (NOLOCK) WHERE PegawaiIDLng=@pid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_sipil_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_sipil_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_sipil_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int); DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @jv_status_sipil_id nvarchar(max)=JSON_VALUE(@j,'$.status_sipil_id'), @jv_tempat_tinggal_id nvarchar(max)=JSON_VALUE(@j,'$.tempat_tinggal_id'), @jv_tempat_tinggal_lain nvarchar(max)=JSON_VALUE(@j,'$.tempat_tinggal_lain'), @jv_transportasi_id nvarchar(max)=JSON_VALUE(@j,'$.transportasi_id'), @jv_transportasi_lain nvarchar(max)=JSON_VALUE(@j,'$.transportasi_lain'), @jv_sim1_id nvarchar(max)=JSON_VALUE(@j,'$.sim1_id'), @jv_sim1_tahun nvarchar(max)=JSON_VALUE(@j,'$.sim1_tahun'), @jv_sim1_daerah nvarchar(max)=JSON_VALUE(@j,'$.sim1_daerah'), @jv_sim2_id nvarchar(max)=JSON_VALUE(@j,'$.sim2_id'), @jv_sim2_tahun nvarchar(max)=JSON_VALUE(@j,'$.sim2_tahun'), @jv_sim2_daerah nvarchar(max)=JSON_VALUE(@j,'$.sim2_daerah');
  EXEC POS_SERVER.dbo.xsp_personel_sipil_ss_update
    @p_pegawai_id=@pid,
    @p_StatusSipilIDLng=@jv_status_sipil_id,
    @p_TempatTinggalIDLng=@jv_tempat_tinggal_id,
    @p_TempatTinggalLainnyaStr=@jv_tempat_tinggal_lain,
    @p_TransportasiIDLng=@jv_transportasi_id,
    @p_TransportasiLainnyaStr=@jv_transportasi_lain,
    @p_Sim1IDLng=@jv_sim1_id, @p_Sim1TahunInt=@jv_sim1_tahun, @p_Sim1KepolisianStr=@jv_sim1_daerah,
    @p_Sim2IDLng=@jv_sim2_id, @p_Sim2TahunInt=@jv_sim2_tahun, @p_Sim2KepolisianStr=@jv_sim2_daerah,
    @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'Sipil tersimpan' responseMessage, JSON_QUERY((SELECT @pid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO
