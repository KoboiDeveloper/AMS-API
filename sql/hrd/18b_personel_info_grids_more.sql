USE RBACESS;

GO

/* Remaining employee-info grids: pendidikan formal/nonformal, bahasa, keahlian, pengalaman, organisasi */

/* ========== PENDIDIKAN FORMAL ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_formal_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_formal_getrows;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_formal_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @p_pegawai_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_pegawai_id,''))),'') AS int);
  IF @pid IS NULL SET @pid=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'') AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT k.PegawaiPendFormalIDLng AS id, k.PegawaiIDLng AS pegawai_id, k.PendidikanIDLng AS pendidikan_id,
      p.PendidikanStr AS pendidikan, k.NamaLembagaStr AS nama_lembaga, k.PeriodeStr AS periode,
      k.JurusanStr AS jurusan, k.KotaIDLng AS kota_id, kota.KotaStr AS kota
    FROM hris.dbo.tblpegawaipendformal k WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblpendidikan p WITH (NOLOCK) ON p.PendidikanIDLng=k.PendidikanIDLng
    LEFT JOIN hris.dbo.tblkota kota WITH (NOLOCK) ON kota.KotaIDLng=k.KotaIDLng
    WHERE (@pid IS NULL OR k.PegawaiIDLng=@pid)
    ORDER BY k.PegawaiPendFormalIDLng FOR JSON PATH
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_formal_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_formal_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_formal_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiPendFormalIDLng AS id, PegawaiIDLng AS pegawai_id, PendidikanIDLng AS pendidikan_id,
      NamaLembagaStr AS nama_lembaga, PeriodeStr AS periode, JurusanStr AS jurusan, KotaIDLng AS kota_id
    FROM hris.dbo.tblpegawaipendformal WITH (NOLOCK) WHERE PegawaiPendFormalIDLng=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_formal_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_formal_insert;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_formal_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @newid int=NULL;
  DECLARE @jv_pendidikan_id nvarchar(max)=JSON_VALUE(@j,'$.pendidikan_id'), @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_nama_lembaga nvarchar(max)=JSON_VALUE(@j,'$.nama_lembaga'), @jv_periode nvarchar(max)=JSON_VALUE(@j,'$.periode'), @jv_jurusan nvarchar(max)=JSON_VALUE(@j,'$.jurusan'), @jv_kota_id nvarchar(max)=JSON_VALUE(@j,'$.kota_id'), @jv_materi nvarchar(max)=JSON_VALUE(@j,'$.materi'), @jv_penyelenggara nvarchar(max)=JSON_VALUE(@j,'$.penyelenggara'), @jv_tahun nvarchar(max)=JSON_VALUE(@j,'$.tahun'), @jv_bahasa_id nvarchar(max)=JSON_VALUE(@j,'$.bahasa_id'), @jv_bicara_id nvarchar(max)=JSON_VALUE(@j,'$.bicara_id'), @jv_menulis_id nvarchar(max)=JSON_VALUE(@j,'$.menulis_id'), @jv_keahlian nvarchar(max)=JSON_VALUE(@j,'$.keahlian'), @jv_kemampuan nvarchar(max)=JSON_VALUE(@j,'$.kemampuan'), @jv_perusahaan nvarchar(max)=JSON_VALUE(@j,'$.perusahaan'), @jv_alamat nvarchar(max)=JSON_VALUE(@j,'$.alamat'), @jv_jabatan nvarchar(max)=JSON_VALUE(@j,'$.jabatan'), @jv_alasan_resign nvarchar(max)=JSON_VALUE(@j,'$.alasan_resign'), @jv_organisasi nvarchar(max)=JSON_VALUE(@j,'$.organisasi');
  EXEC POS_SERVER.dbo.xsp_personel_add_pendidikan_formal_insert
    @p_PegawaiPendFormalIDLng=@newid OUTPUT, @p_PendidikanIDLng=@jv_pendidikan_id,
    @p_pegawai_id=@jv_pegawai_id, @p_NamaLembagaStr=@jv_nama_lembaga,
    @p_PeriodeStr=@jv_periode, @p_JurusanStr=@jv_jurusan,
    @p_KotaIDLng=@jv_kota_id, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @newid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_formal_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_formal_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_formal_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @jv_pendidikan_id nvarchar(max)=JSON_VALUE(@j,'$.pendidikan_id'), @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_nama_lembaga nvarchar(max)=JSON_VALUE(@j,'$.nama_lembaga'), @jv_periode nvarchar(max)=JSON_VALUE(@j,'$.periode'), @jv_jurusan nvarchar(max)=JSON_VALUE(@j,'$.jurusan'), @jv_kota_id nvarchar(max)=JSON_VALUE(@j,'$.kota_id');
  EXEC POS_SERVER.dbo.xsp_personel_add_pendidikan_formal_update
    @p_PegawaiPendFormalIDLng=@rid, @p_PendidikanIDLng=@jv_pendidikan_id,
    @p_pegawai_id=@jv_pegawai_id, @p_NamaLembagaStr=@jv_nama_lembaga,
    @p_PeriodeStr=@jv_periode, @p_JurusanStr=@jv_jurusan,
    @p_KotaIDLng=@jv_kota_id, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @rid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_formal_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_formal_delete;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_formal_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_pendidikan_formal_delete @p_PegawaiPendFormalIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== PENDIDIKAN NONFORMAL ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_getrows;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @p_pegawai_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_pegawai_id,''))),'') AS int);
  IF @pid IS NULL SET @pid=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'') AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT k.PegawaiPendNonFormalIDLng AS id, k.PegawaiIDLng AS pegawai_id, k.MateriStr AS materi,
      k.PenyelenggaraStr AS penyelenggara, k.TahunInt AS tahun, k.KotaIDLng AS kota_id, kota.KotaStr AS kota
    FROM hris.dbo.tblpegawaipendnonformal k WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblkota kota WITH (NOLOCK) ON kota.KotaIDLng=k.KotaIDLng
    WHERE (@pid IS NULL OR k.PegawaiIDLng=@pid)
    ORDER BY k.PegawaiPendNonFormalIDLng FOR JSON PATH
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiPendNonFormalIDLng AS id, PegawaiIDLng AS pegawai_id, MateriStr AS materi,
      PenyelenggaraStr AS penyelenggara, TahunInt AS tahun, KotaIDLng AS kota_id
    FROM hris.dbo.tblpegawaipendnonformal WITH (NOLOCK) WHERE PegawaiPendNonFormalIDLng=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_insert;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @newid int=NULL;
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_materi nvarchar(max)=JSON_VALUE(@j,'$.materi'), @jv_penyelenggara nvarchar(max)=JSON_VALUE(@j,'$.penyelenggara'), @jv_tahun nvarchar(max)=JSON_VALUE(@j,'$.tahun'), @jv_kota_id nvarchar(max)=JSON_VALUE(@j,'$.kota_id');
  EXEC POS_SERVER.dbo.xsp_personel_add_pendidikan_non_formal_insert
    @p_PegawaiPendNonFormalIDLng=@newid OUTPUT, @p_PegawaiIDLng=@jv_pegawai_id,
    @p_MateriStr=@jv_materi, @p_PenyelenggaraStr=@jv_penyelenggara,
    @p_TahunInt=@jv_tahun, @p_KotaIDLng=@jv_kota_id, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @newid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_materi nvarchar(max)=JSON_VALUE(@j,'$.materi'), @jv_penyelenggara nvarchar(max)=JSON_VALUE(@j,'$.penyelenggara'), @jv_tahun nvarchar(max)=JSON_VALUE(@j,'$.tahun'), @jv_kota_id nvarchar(max)=JSON_VALUE(@j,'$.kota_id');
  EXEC POS_SERVER.dbo.xsp_personel_add_pendidikan_non_formal_update
    @p_PegawaiPendNonFormalIDLng=@rid, @p_PegawaiIDLng=@jv_pegawai_id,
    @p_MateriStr=@jv_materi, @p_PenyelenggaraStr=@jv_penyelenggara,
    @p_TahunInt=@jv_tahun, @p_KotaIDLng=@jv_kota_id, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @rid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_delete;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pendidikan_nonformal_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_pendidikan_Non_formal_delete @p_PegawaiPendNonFormalIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== BAHASA ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_bahasa_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_bahasa_getrows;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_bahasa_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @p_pegawai_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_pegawai_id,''))),'') AS int);
  IF @pid IS NULL SET @pid=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'') AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT k.PegawaiBahasaIDLng AS id, k.PegawaiIDLng AS pegawai_id, k.BahasaIDLng AS bahasa_id, b.BahasaStr AS bahasa,
      k.BicaraTingkatkeahlianIDLng AS bicara_id, tb.TingkatKeahlianStr AS bicara,
      k.MenulisTingkatKehlianIDLng AS menulis_id, tm.TingkatKeahlianStr AS menulis
    FROM hris.dbo.tblpegawaibahasa k WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblbahasa b WITH (NOLOCK) ON b.BahasaIDLng=k.BahasaIDLng
    LEFT JOIN hris.dbo.tblfixtingkatkeahlian tb WITH (NOLOCK) ON tb.TingkatKeahlianIDLng=k.BicaraTingkatkeahlianIDLng
    LEFT JOIN hris.dbo.tblfixtingkatkeahlian tm WITH (NOLOCK) ON tm.TingkatKeahlianIDLng=k.MenulisTingkatKehlianIDLng
    WHERE (@pid IS NULL OR k.PegawaiIDLng=@pid)
    ORDER BY k.PegawaiBahasaIDLng FOR JSON PATH
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_bahasa_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_bahasa_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_bahasa_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiBahasaIDLng AS id, PegawaiIDLng AS pegawai_id, BahasaIDLng AS bahasa_id,
      BicaraTingkatkeahlianIDLng AS bicara_id, MenulisTingkatKehlianIDLng AS menulis_id
    FROM hris.dbo.tblpegawaibahasa WITH (NOLOCK) WHERE PegawaiBahasaIDLng=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_bahasa_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_bahasa_insert;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_bahasa_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @newid int=NULL;
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_bahasa_id nvarchar(max)=JSON_VALUE(@j,'$.bahasa_id'), @jv_bicara_id nvarchar(max)=JSON_VALUE(@j,'$.bicara_id'), @jv_menulis_id nvarchar(max)=JSON_VALUE(@j,'$.menulis_id');
  EXEC POS_SERVER.dbo.xsp_personel_add_bahasa_insert
    @p_PegawaiBahasaIDLng=@newid OUTPUT, @p_PegawaiIDLng=@jv_pegawai_id,
    @p_BahasaIDLng=@jv_bahasa_id, @p_BicaraTingkatkeahlianIDLng=@jv_bicara_id,
    @p_MenulisTingkatKehlianIDLng=@jv_menulis_id, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @newid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_bahasa_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_bahasa_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_bahasa_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_bahasa_id nvarchar(max)=JSON_VALUE(@j,'$.bahasa_id'), @jv_bicara_id nvarchar(max)=JSON_VALUE(@j,'$.bicara_id'), @jv_menulis_id nvarchar(max)=JSON_VALUE(@j,'$.menulis_id');
  EXEC POS_SERVER.dbo.xsp_personel_add_bahasa_update
    @p_PegawaiBahasaIDLng=@rid, @p_PegawaiIDLng=@jv_pegawai_id,
    @p_BahasaIDLng=@jv_bahasa_id, @p_BicaraTingkatkeahlianIDLng=@jv_bicara_id,
    @p_MenulisTingkatKehlianIDLng=@jv_menulis_id, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @rid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_bahasa_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_bahasa_delete;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_bahasa_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_bahasa_delete @p_PegawaiBahasaIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== KEAHLIAN ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keahlian_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keahlian_getrows;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keahlian_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @p_pegawai_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_pegawai_id,''))),'') AS int);
  IF @pid IS NULL SET @pid=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'') AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT PegawaiKeahlianIDLng AS id, PegawaiIDLng AS pegawai_id, KeahlianStr AS keahlian, KemampuanStr AS kemampuan
    FROM hris.dbo.tblpegawaikeahlian WITH (NOLOCK)
    WHERE (@pid IS NULL OR PegawaiIDLng=@pid)
    ORDER BY PegawaiKeahlianIDLng FOR JSON PATH
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keahlian_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keahlian_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keahlian_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiKeahlianIDLng AS id, PegawaiIDLng AS pegawai_id, KeahlianStr AS keahlian, KemampuanStr AS kemampuan
    FROM hris.dbo.tblpegawaikeahlian WITH (NOLOCK) WHERE PegawaiKeahlianIDLng=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keahlian_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keahlian_insert;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keahlian_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @newid int=NULL;
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_keahlian nvarchar(max)=JSON_VALUE(@j,'$.keahlian'), @jv_kemampuan nvarchar(max)=JSON_VALUE(@j,'$.kemampuan');
  EXEC POS_SERVER.dbo.xsp_personel_add_keahlian_insert
    @p_PegawaiKeahlianIDLng=@newid OUTPUT, @p_PegawaiIDLng=@jv_pegawai_id,
    @p_KeahlianStr=@jv_keahlian, @p_KemampuanStr=@jv_kemampuan, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @newid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keahlian_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keahlian_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keahlian_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_keahlian nvarchar(max)=JSON_VALUE(@j,'$.keahlian'), @jv_kemampuan nvarchar(max)=JSON_VALUE(@j,'$.kemampuan');
  EXEC POS_SERVER.dbo.xsp_personel_add_keahlian_update
    @p_PegawaiKeahlianIDLng=@rid, @p_PegawaiIDLng=@jv_pegawai_id,
    @p_KeahlianStr=@jv_keahlian, @p_KemampuanStr=@jv_kemampuan, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @rid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keahlian_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keahlian_delete;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keahlian_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_keahlian_delete @p_PegawaiKeahlianIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== PENGALAMAN KERJA ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pengalaman_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pengalaman_getrows;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pengalaman_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @p_pegawai_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_pegawai_id,''))),'') AS int);
  IF @pid IS NULL SET @pid=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'') AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT PegawaiPengalamanKerjaIDLng AS id, PegawaiIDLng AS pegawai_id, PerusahaanStr AS perusahaan,
      PeriodeStr AS periode, AlamatStr AS alamat, JabatanStr AS jabatan, AlasanResignStr AS alasan_resign
    FROM hris.dbo.tblpegawaipengalamankerja WITH (NOLOCK)
    WHERE (@pid IS NULL OR PegawaiIDLng=@pid)
    ORDER BY PegawaiPengalamanKerjaIDLng FOR JSON PATH
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pengalaman_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pengalaman_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pengalaman_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiPengalamanKerjaIDLng AS id, PegawaiIDLng AS pegawai_id, PerusahaanStr AS perusahaan,
      PeriodeStr AS periode, AlamatStr AS alamat, JabatanStr AS jabatan, AlasanResignStr AS alasan_resign
    FROM hris.dbo.tblpegawaipengalamankerja WITH (NOLOCK) WHERE PegawaiPengalamanKerjaIDLng=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pengalaman_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pengalaman_insert;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pengalaman_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @newid int=NULL;
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_perusahaan nvarchar(max)=JSON_VALUE(@j,'$.perusahaan'), @jv_periode nvarchar(max)=JSON_VALUE(@j,'$.periode'), @jv_alamat nvarchar(max)=JSON_VALUE(@j,'$.alamat'), @jv_jabatan nvarchar(max)=JSON_VALUE(@j,'$.jabatan'), @jv_alasan_resign nvarchar(max)=JSON_VALUE(@j,'$.alasan_resign');
  EXEC POS_SERVER.dbo.xsp_personel_add_pengalaman_kerja_insert
    @p_PegawaiPengalamanKerjaIDLng=@newid OUTPUT, @p_PegawaiIDLng=@jv_pegawai_id,
    @p_PerusahaanStr=@jv_perusahaan, @p_PeriodeStr=@jv_periode,
    @p_AlamatStr=@jv_alamat, @p_JabatanStr=@jv_jabatan,
    @p_AlasanResignStr=@jv_alasan_resign, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @newid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pengalaman_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pengalaman_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pengalaman_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_perusahaan nvarchar(max)=JSON_VALUE(@j,'$.perusahaan'), @jv_periode nvarchar(max)=JSON_VALUE(@j,'$.periode'), @jv_alamat nvarchar(max)=JSON_VALUE(@j,'$.alamat'), @jv_jabatan nvarchar(max)=JSON_VALUE(@j,'$.jabatan'), @jv_alasan_resign nvarchar(max)=JSON_VALUE(@j,'$.alasan_resign');
  EXEC POS_SERVER.dbo.xsp_personel_add_pengalaman_kerja_update
    @p_PegawaiPengalamanKerjaIDLng=@rid, @p_PegawaiIDLng=@jv_pegawai_id,
    @p_PerusahaanStr=@jv_perusahaan, @p_PeriodeStr=@jv_periode,
    @p_AlamatStr=@jv_alamat, @p_JabatanStr=@jv_jabatan,
    @p_AlasanResignStr=@jv_alasan_resign, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @rid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_pengalaman_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_pengalaman_delete;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_pengalaman_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_pengalaman_kerja_delete @p_PegawaiPengalamanKerjaIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* ========== ORGANISASI ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_organisasi_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_organisasi_getrows;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_organisasi_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @p_pegawai_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @pid int=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_pegawai_id,''))),'') AS int);
  IF @pid IS NULL SET @pid=TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'') AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT PegawaiOrganisasiIDLng AS id, PegawaiIDLng AS pegawai_id, OrganisasiStr AS organisasi,
      PeriodeStr AS periode, JabatanStr AS jabatan
    FROM hris.dbo.tblpegawaiorganisasi WITH (NOLOCK)
    WHERE (@pid IS NULL OR PegawaiIDLng=@pid)
    ORDER BY PegawaiOrganisasiIDLng FOR JSON PATH
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_organisasi_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_organisasi_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_organisasi_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiOrganisasiIDLng AS id, PegawaiIDLng AS pegawai_id, OrganisasiStr AS organisasi,
      PeriodeStr AS periode, JabatanStr AS jabatan
    FROM hris.dbo.tblpegawaiorganisasi WITH (NOLOCK) WHERE PegawaiOrganisasiIDLng=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_organisasi_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_organisasi_insert;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_organisasi_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @newid int=NULL;
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_organisasi nvarchar(max)=JSON_VALUE(@j,'$.organisasi'), @jv_periode nvarchar(max)=JSON_VALUE(@j,'$.periode'), @jv_jabatan nvarchar(max)=JSON_VALUE(@j,'$.jabatan');
  EXEC POS_SERVER.dbo.xsp_personel_add_organisasi_insert
    @p_PegawaiOrganisasiIDLng=@newid OUTPUT, @p_PegawaiIDLng=@jv_pegawai_id,
    @p_OrganisasiStr=@jv_organisasi, @p_PeriodeStr=@jv_periode,
    @p_JabatanStr=@jv_jabatan, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @newid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_organisasi_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_organisasi_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_organisasi_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_organisasi nvarchar(max)=JSON_VALUE(@j,'$.organisasi'), @jv_periode nvarchar(max)=JSON_VALUE(@j,'$.periode'), @jv_jabatan nvarchar(max)=JSON_VALUE(@j,'$.jabatan');
  EXEC POS_SERVER.dbo.xsp_personel_add_organisasi_update
    @p_PegawaiOrganisasiIDLng=@rid, @p_PegawaiIDLng=@jv_pegawai_id,
    @p_OrganisasiStr=@jv_organisasi, @p_PeriodeStr=@jv_periode,
    @p_JabatanStr=@jv_jabatan, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @rid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_organisasi_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_organisasi_delete;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_organisasi_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_organisasi_delete @p_PegawaiOrganisasiIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO
