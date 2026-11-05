USE RBACESS;

GO

/* Form tabs: pendidikan terakhir, kondisi kerja, aktifitas, upload + lookups extension */

/* ========== PENDIDIKAN TERAKHIR ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_terakhir_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_terakhir_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_terakhir_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiIDLng AS id, PendidikanIDLng AS pendidikan_id, NamaLembagaStr AS nama_lembaga,
      KotaIDLng AS kota_id, NegaraIDLng AS negara_id, TahunMasukInt AS tahun_masuk, TahunKeluarInt AS tahun_keluar,
      LulusInt AS lulus, IPKMon AS ipk, CatatanStr AS catatan
    FROM hris.dbo.tblpegawaipendidikan WITH (NOLOCK) WHERE PegawaiIDLng=@pid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_terakhir_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_terakhir_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_terakhir_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int); DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @jv_pendidikan_id nvarchar(max)=JSON_VALUE(@j,'$.pendidikan_id'), @jv_nama_lembaga nvarchar(max)=JSON_VALUE(@j,'$.nama_lembaga'), @jv_kota_id nvarchar(max)=JSON_VALUE(@j,'$.kota_id'), @jv_negara_id nvarchar(max)=JSON_VALUE(@j,'$.negara_id'), @jv_tahun_masuk nvarchar(max)=JSON_VALUE(@j,'$.tahun_masuk'), @jv_tahun_keluar nvarchar(max)=JSON_VALUE(@j,'$.tahun_keluar'), @jv_lulus nvarchar(max)=JSON_VALUE(@j,'$.lulus'), @jv_ipk nvarchar(max)=JSON_VALUE(@j,'$.ipk'), @jv_catatan nvarchar(max)=JSON_VALUE(@j,'$.catatan');
  EXEC POS_SERVER.dbo.xsp_personel_pendidikan_formal_terakhir_ss_update
    @p_pegawai_id=@pid, @p_UserNameStr=@actor,
    @p_PendidikanIDLng=@jv_pendidikan_id, @p_NamaLembagaStr=@jv_nama_lembaga,
    @p_KotaIDLng=@jv_kota_id, @p_NegaraIDLng=@jv_negara_id,
    @p_TahunMasukInt=@jv_tahun_masuk, @p_TahunKeluarInt=@jv_tahun_keluar,
    @p_LulusInt=@jv_lulus, @p_IPKMon=@jv_ipk, @p_CatatanStr=@jv_catatan;
  SET @bitparam=(SELECT '2002500' responseCode,'Pendidikan tersimpan' responseMessage, JSON_QUERY((SELECT @pid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== KONDISI KERJA ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kondisi_kerja_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kondisi_kerja_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kondisi_kerja_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiIDLng AS id, MasihAktifInt AS masih_aktif, GajiAllInMon AS gaji_all_in,
      StrukturOrganisasiStr AS struktur_organisasi, PekerjaanYangMiripStr AS pekerjaan_mirip,
      PekerjaanYangMembantuStr AS pekerjaan_membantu, TunjanganStr AS tunjangan,
      CONVERT(varchar(10), TanggalBergabungDtd, 23) AS tgl_bergabung,
      KenalanDiPerusahaanStr AS kenalan, ReferensiStr AS referensi,
      KerjaShiftInt AS kerja_shift, GantiPekerjaanInt AS ganti_pekerjaan, LemburInt AS lembur,
      KerjaMalamInt AS kerja_malam, DinasInt AS dinas, DitempatkanDiDaerahInt AS ditempatkan_daerah
    FROM hris.dbo.tblpegawaikondisipekerjaan WITH (NOLOCK) WHERE PegawaiIDLng=@pid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kondisi_kerja_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kondisi_kerja_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kondisi_kerja_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int); DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @jv_masih_aktif nvarchar(max)=JSON_VALUE(@j,'$.masih_aktif'), @jv_gaji_all_in nvarchar(max)=JSON_VALUE(@j,'$.gaji_all_in'), @jv_struktur_organisasi nvarchar(max)=JSON_VALUE(@j,'$.struktur_organisasi'), @jv_pekerjaan_mirip nvarchar(max)=JSON_VALUE(@j,'$.pekerjaan_mirip'), @jv_pekerjaan_membantu nvarchar(max)=JSON_VALUE(@j,'$.pekerjaan_membantu'), @jv_tunjangan nvarchar(max)=JSON_VALUE(@j,'$.tunjangan'), @jv_tgl_bergabung nvarchar(max)=JSON_VALUE(@j,'$.tgl_bergabung'), @jv_kenalan nvarchar(max)=JSON_VALUE(@j,'$.kenalan'), @jv_referensi nvarchar(max)=JSON_VALUE(@j,'$.referensi'), @jv_kerja_shift nvarchar(max)=JSON_VALUE(@j,'$.kerja_shift'), @jv_ganti_pekerjaan nvarchar(max)=JSON_VALUE(@j,'$.ganti_pekerjaan'), @jv_lembur nvarchar(max)=JSON_VALUE(@j,'$.lembur'), @jv_kerja_malam nvarchar(max)=JSON_VALUE(@j,'$.kerja_malam'), @jv_dinas nvarchar(max)=JSON_VALUE(@j,'$.dinas'), @jv_ditempatkan_daerah nvarchar(max)=JSON_VALUE(@j,'$.ditempatkan_daerah');
  EXEC POS_SERVER.dbo.xsp_personel_kondisi_kerja_ss_update
    @p_pegawai_id=@pid, @p_UserNameStr=@actor,
    @p_MasihAktifInt=@jv_masih_aktif, @p_GajiAllInMon=@jv_gaji_all_in,
    @p_StrukturOrganisasiStr=@jv_struktur_organisasi,
    @p_PekerjaanYangMiripStr=@jv_pekerjaan_mirip,
    @p_PekerjaanYangMembantuStr=@jv_pekerjaan_membantu,
    @p_TunjanganStr=@jv_tunjangan, @p_TanggalBergabungDtd=@jv_tgl_bergabung,
    @p_KenalanDiPerusahaanStr=@jv_kenalan, @p_ReferensiStr=@jv_referensi,
    @p_KerjaShiftInt=@jv_kerja_shift, @p_GantiPekerjaanInt=@jv_ganti_pekerjaan,
    @p_LemburInt=@jv_lembur, @p_KerjaMalamInt=@jv_kerja_malam,
    @p_DinasInt=@jv_dinas, @p_DitempatkanDiDaerahInt=@jv_ditempatkan_daerah;
  SET @bitparam=(SELECT '2002500' responseCode,'Kondisi kerja tersimpan' responseMessage, JSON_QUERY((SELECT @pid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== AKTIFITAS FORM ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_aktifitas_form_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_aktifitas_form_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_aktifitas_form_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiIDLng AS id, KegemaranStr AS kegemaran, KegiatanLuangStr AS kegiatan_luang,
      SuratKabarStr AS surat_kabar, PernahBerurusanDgnBerwajibInt AS pernah_berurusan,
      KapanDimanaPerihalStr AS kapan_dimana
    FROM hris.dbo.tblpegawaikegemaranhukum WITH (NOLOCK) WHERE PegawaiIDLng=@pid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_aktifitas_form_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_aktifitas_form_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_aktifitas_form_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int); DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @jv_kegemaran nvarchar(max)=JSON_VALUE(@j,'$.kegemaran'), @jv_kegiatan_luang nvarchar(max)=JSON_VALUE(@j,'$.kegiatan_luang'), @jv_surat_kabar nvarchar(max)=JSON_VALUE(@j,'$.surat_kabar'), @jv_pernah_berurusan nvarchar(max)=JSON_VALUE(@j,'$.pernah_berurusan'), @jv_kapan_dimana nvarchar(max)=JSON_VALUE(@j,'$.kapan_dimana');
  EXEC POS_SERVER.dbo.xsp_personel_aktifitas_ss_update
    @p_pegawai_id=@pid,
    @p_KegemaranStr=@jv_kegemaran, @p_KegiatanLuangStr=@jv_kegiatan_luang,
    @p_SuratKabarStr=@jv_surat_kabar,
    @p_PernahBerurusanDgnBerwajibInt=@jv_pernah_berurusan,
    @p_KapanDimanaPerihalStr=@jv_kapan_dimana, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'Aktifitas tersimpan' responseMessage, JSON_QUERY((SELECT @pid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== UPLOAD DOKUMEN ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_upload_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_upload_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_upload_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int);
  DECLARE @nik varchar(50)=(SELECT TOP 1 NomorIndukStr FROM hris.dbo.tblpegawai WITH (NOLOCK) WHERE PegawaiIDLng=@pid);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 @pid AS id, @nik AS nik,
      ISNULL(p.KTP,'') AS ktp, ISNULL(p.NPWP,'') AS npwp, ISNULL(p.KK,'') AS kk, ISNULL(p.ijazah,'') AS ijazah,
      ISNULL(p.Photo,'') AS photo
    FROM (SELECT 1 AS x) d
    LEFT JOIN hris.dbo.web_self_service_photo_pegawai p WITH (NOLOCK) ON p.NIK=@nik
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_upload_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_upload_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_upload_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(@p_id AS int);
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @jv_nik nvarchar(max)=JSON_VALUE(@j,'$.nik');
  DECLARE @jv_ktp nvarchar(max)=JSON_VALUE(@j,'$.ktp');
  DECLARE @jv_npwp nvarchar(max)=JSON_VALUE(@j,'$.npwp');
  DECLARE @jv_kk nvarchar(max)=JSON_VALUE(@j,'$.kk');
  DECLARE @jv_ijazah nvarchar(max)=JSON_VALUE(@j,'$.ijazah');
  DECLARE @jv_photo nvarchar(max)=JSON_VALUE(@j,'$.photo');
  DECLARE @nik varchar(50)=COALESCE(@jv_nik, (SELECT TOP 1 NomorIndukStr FROM hris.dbo.tblpegawai WITH (NOLOCK) WHERE PegawaiIDLng=@pid));
  IF @nik IS NULL OR LTRIM(RTRIM(@nik))='' THROW 50001, 'NIK tidak ditemukan', 1;

  IF NOT EXISTS (SELECT 1 FROM hris.dbo.web_self_service_photo_pegawai WITH (NOLOCK) WHERE NIK=@nik)
    INSERT INTO hris.dbo.web_self_service_photo_pegawai (NIK, KTP, NPWP, KK, ijazah, Photo)
    VALUES (@nik, ISNULL(@jv_ktp,''), ISNULL(@jv_npwp,''), ISNULL(@jv_kk,''), ISNULL(@jv_ijazah,''), ISNULL(@jv_photo,''));
  ELSE
    EXEC POS_SERVER.dbo.xsp_get_user_info_self_upload_document_service_update
      @p_nik=@nik,
      @p_photo_ktp=@jv_ktp,
      @p_photo_npwp=@jv_npwp,
      @p_photo_kk=@jv_kk,
      @p_photo_ijazah=@jv_ijazah;

  IF @jv_photo IS NOT NULL
    UPDATE hris.dbo.web_self_service_photo_pegawai SET Photo=@jv_photo WHERE NIK=@nik;

  SET @bitparam=(SELECT '2002500' responseCode,'Dokumen tersimpan' responseMessage, JSON_QUERY((SELECT @pid id, @nik nik FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO
