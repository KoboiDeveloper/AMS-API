USE RBACESS;

GO

/* Grid tabs for employee info — list by pegawai_id + CRUD wrappers to POS. */

/* ---- helper: standard AMS list signature used by hrdListHandler ---- */
/* keluarga inti */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keluarga_inti_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_inti_getrows;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_inti_getrows
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
    SELECT k.PegawaiKeluargaIntiIDLng AS id, k.PegawaiIDLng AS pegawai_id, k.NamaStr AS nama, k.UsiaInt AS usia,
      k.HubunganKeluargaIDLng AS hubungan_id, h.HubunganKeluargaStr AS hubungan,
      k.PendidikanIDLng AS pendidikan_id, p.PendidikanStr AS pendidikan,
      k.PekerjaanStr AS pekerjaan, k.AlamatStr AS alamat
    FROM hris.dbo.tblpegawaikeluargainti k WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblhubungankeluarga h WITH (NOLOCK) ON h.HubunganKeluargaIDLng=k.HubunganKeluargaIDLng
    LEFT JOIN hris.dbo.tblpendidikan p WITH (NOLOCK) ON p.PendidikanIDLng=k.PendidikanIDLng
    WHERE (@pid IS NULL OR k.PegawaiIDLng=@pid)
    ORDER BY k.PegawaiKeluargaIntiIDLng
    FOR JSON PATH
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keluarga_inti_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_inti_insert;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_inti_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @newid int=NULL;
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_hubungan_id nvarchar(max)=JSON_VALUE(@j,'$.hubungan_id'), @jv_nama nvarchar(max)=JSON_VALUE(@j,'$.nama'), @jv_usia nvarchar(max)=JSON_VALUE(@j,'$.usia'), @jv_pendidikan_id nvarchar(max)=JSON_VALUE(@j,'$.pendidikan_id'), @jv_pekerjaan nvarchar(max)=JSON_VALUE(@j,'$.pekerjaan'), @jv_alamat nvarchar(max)=JSON_VALUE(@j,'$.alamat'), @jv_tgl_lahir nvarchar(max)=JSON_VALUE(@j,'$.tgl_lahir'), @jv_no_ktp nvarchar(max)=JSON_VALUE(@j,'$.no_ktp');
  EXEC POS_SERVER.dbo.xsp_personel_add_keluarga_int_insert
    @p_pegawaikeluargaintidlng=@newid OUTPUT,
    @p_pegawai_id=@jv_pegawai_id, @p_HubunganKeluargaIDLng=@jv_hubungan_id,
    @p_NamaStr=@jv_nama, @p_UsiaInt=@jv_usia, @p_PendidikanIDLng=@jv_pendidikan_id,
    @p_PekerjaanStr=@jv_pekerjaan, @p_AlamatStr=@jv_alamat, @p_UserNameStr=@actor,
    @p_tgl_lahir=@jv_tgl_lahir, @p_no_ktp=@jv_no_ktp;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @newid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keluarga_inti_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_inti_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_inti_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_hubungan_id nvarchar(max)=JSON_VALUE(@j,'$.hubungan_id'), @jv_nama nvarchar(max)=JSON_VALUE(@j,'$.nama'), @jv_usia nvarchar(max)=JSON_VALUE(@j,'$.usia'), @jv_pendidikan_id nvarchar(max)=JSON_VALUE(@j,'$.pendidikan_id'), @jv_pekerjaan nvarchar(max)=JSON_VALUE(@j,'$.pekerjaan'), @jv_alamat nvarchar(max)=JSON_VALUE(@j,'$.alamat'), @jv_tgl_lahir nvarchar(max)=JSON_VALUE(@j,'$.tgl_lahir'), @jv_no_ktp nvarchar(max)=JSON_VALUE(@j,'$.no_ktp');
  EXEC POS_SERVER.dbo.xsp_personel_add_keluarga_int_update
    @p_pegawaikeluargaintidlng=@rid, @p_pegawai_id=@jv_pegawai_id,
    @p_HubunganKeluargaIDLng=@jv_hubungan_id, @p_NamaStr=@jv_nama,
    @p_UsiaInt=@jv_usia, @p_PendidikanIDLng=@jv_pendidikan_id,
    @p_PekerjaanStr=@jv_pekerjaan, @p_AlamatStr=@jv_alamat, @p_UserNameStr=@actor,
    @p_tgl_lahir=@jv_tgl_lahir, @p_no_ktp=@jv_no_ktp;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @rid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keluarga_inti_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_inti_delete;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_inti_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_keluarga_int_delete @p_pegawaikeluargaintidlng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keluarga_inti_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_inti_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_inti_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiKeluargaIntiIDLng AS id, PegawaiIDLng AS pegawai_id, NamaStr AS nama, UsiaInt AS usia,
      HubunganKeluargaIDLng AS hubungan_id, PendidikanIDLng AS pendidikan_id, PekerjaanStr AS pekerjaan, AlamatStr AS alamat
    FROM hris.dbo.tblpegawaikeluargainti WITH (NOLOCK) WHERE PegawaiKeluargaIntiIDLng=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

/* keluarga kandung — mirror inti */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keluarga_kandung_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_kandung_getrows;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_kandung_getrows
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
    SELECT k.PegawaiKeluargaKandungIDLng AS id, k.PegawaiIDLng AS pegawai_id, k.NamaStr AS nama, k.UsiaInt AS usia,
      k.HubunganKeluargaIDLng AS hubungan_id, h.HubunganKeluargaStr AS hubungan,
      k.PendidikanIDLng AS pendidikan_id, p.PendidikanStr AS pendidikan,
      k.PekerjaanStr AS pekerjaan, k.AlamatStr AS alamat
    FROM hris.dbo.tblpegawaikeluargakandung k WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblhubungankeluarga h WITH (NOLOCK) ON h.HubunganKeluargaIDLng=k.HubunganKeluargaIDLng
    LEFT JOIN hris.dbo.tblpendidikan p WITH (NOLOCK) ON p.PendidikanIDLng=k.PendidikanIDLng
    WHERE (@pid IS NULL OR k.PegawaiIDLng=@pid)
    ORDER BY k.PegawaiKeluargaKandungIDLng FOR JSON PATH
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keluarga_kandung_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_kandung_getrow;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_kandung_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 PegawaiKeluargaKandungIDLng AS id, PegawaiIDLng AS pegawai_id, NamaStr AS nama, UsiaInt AS usia,
      HubunganKeluargaIDLng AS hubungan_id, PendidikanIDLng AS pendidikan_id, PekerjaanStr AS pekerjaan, AlamatStr AS alamat
    FROM hris.dbo.tblpegawaikeluargakandung WITH (NOLOCK) WHERE PegawaiKeluargaKandungIDLng=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keluarga_kandung_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_kandung_insert;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_kandung_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @newid int=NULL;
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_hubungan_id nvarchar(max)=JSON_VALUE(@j,'$.hubungan_id'), @jv_nama nvarchar(max)=JSON_VALUE(@j,'$.nama'), @jv_usia nvarchar(max)=JSON_VALUE(@j,'$.usia'), @jv_pendidikan_id nvarchar(max)=JSON_VALUE(@j,'$.pendidikan_id'), @jv_pekerjaan nvarchar(max)=JSON_VALUE(@j,'$.pekerjaan'), @jv_alamat nvarchar(max)=JSON_VALUE(@j,'$.alamat'), @jv_tgl_lahir nvarchar(max)=JSON_VALUE(@j,'$.tgl_lahir'), @jv_no_ktp nvarchar(max)=JSON_VALUE(@j,'$.no_ktp');
  EXEC POS_SERVER.dbo.xsp_personel_add_keluarga_kandung_insert
    @p_PegawaiKeluargaKandungIDLng=@newid OUTPUT,
    @p_pegawai_id=@jv_pegawai_id, @p_HubunganKeluargaIDLng=@jv_hubungan_id,
    @p_NamaStr=@jv_nama, @p_UsiaInt=@jv_usia, @p_PendidikanIDLng=@jv_pendidikan_id,
    @p_PekerjaanStr=@jv_pekerjaan, @p_AlamatStr=@jv_alamat, @p_UserNameStr=@actor,
    @p_tgl_lahir=@jv_tgl_lahir, @p_no_ktp=@jv_no_ktp;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @newid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keluarga_kandung_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_kandung_update;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_kandung_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}'); DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @jv_pegawai_id nvarchar(max)=JSON_VALUE(@j,'$.pegawai_id'), @jv_hubungan_id nvarchar(max)=JSON_VALUE(@j,'$.hubungan_id'), @jv_nama nvarchar(max)=JSON_VALUE(@j,'$.nama'), @jv_usia nvarchar(max)=JSON_VALUE(@j,'$.usia'), @jv_pendidikan_id nvarchar(max)=JSON_VALUE(@j,'$.pendidikan_id'), @jv_pekerjaan nvarchar(max)=JSON_VALUE(@j,'$.pekerjaan'), @jv_alamat nvarchar(max)=JSON_VALUE(@j,'$.alamat'), @jv_tgl_lahir nvarchar(max)=JSON_VALUE(@j,'$.tgl_lahir'), @jv_no_ktp nvarchar(max)=JSON_VALUE(@j,'$.no_ktp');
  EXEC POS_SERVER.dbo.xsp_personel_add_keluarga_kandung_update
    @p_PegawaiKeluargaKandungIDLng=@rid, @p_pegawai_id=@jv_pegawai_id,
    @p_HubunganKeluargaIDLng=@jv_hubungan_id, @p_NamaStr=@jv_nama,
    @p_UsiaInt=@jv_usia, @p_PendidikanIDLng=@jv_pendidikan_id,
    @p_PekerjaanStr=@jv_pekerjaan, @p_AlamatStr=@jv_alamat, @p_UserNameStr=@actor,
    @p_tgl_lahir=@jv_tgl_lahir, @p_no_ktp=@jv_no_ktp;
  SET @bitparam=(SELECT '2002500' responseCode,'OK' responseMessage, JSON_QUERY((SELECT @rid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_keluarga_kandung_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_kandung_delete;

GO

CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_keluarga_kandung_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_keluarga_kandung_delete @p_PegawaiKeluargaKandungIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END

GO
