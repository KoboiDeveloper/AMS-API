USE RBACESS;
GO
/* Minimal CRUD for personel kontrak/status/promosi/mutasi — wraps POS SPs */

/* ---- KONTRAK ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kontrak_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 t1.PersonnelKontrakIDLng AS id, t1.PegawaiIDLng AS pegawai_id, t2.NomorIndukStr AS nik, t2.NamaLengkapStr AS employee_name,
      t1.NomorKontrakStr AS no_kontrak, CONVERT(varchar(10), t1.TanggalKontrakDtd, 23) AS tanggal_surat,
      CONVERT(varchar(10), t1.TanggalBerakhirKontrakSebelumnyaDtd, 23) AS tanggal_berakhir_sebelumnya,
      CONVERT(varchar(10), t1.TanggalEfektifDtd, 23) AS tgl_mulai, CONVERT(varchar(10), t1.TanggalBerakhirDtd, 23) AS tanggal_berakhir,
      t1.LamaBulanInt AS lama_bulan, t1.LamaBulanTerbilangStr AS terbilang,
      t1.DepartemenIDLng AS department, t1.DepartemenBagianIDLng AS unit, t1.PangkatIDLng AS pangkat,
      t1.JabatanIDLng AS jabatan, t1.GolonganIDLng AS golongan, t1.GolonganTingkatanIDLng AS tingkat,
      t1.KantorCabangIDLng AS penempatan, t1.HonorPerBulanMon AS ump
    FROM hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng=t2.PegawaiIDLng
    WHERE t1.PersonnelKontrakIDLng=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kontrak_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @pid int=TRY_CAST(JSON_VALUE(@j,'$.pegawai_id') AS int);
  DECLARE @nik varchar(50)=JSON_VALUE(@j,'$.nik');
  IF @pid IS NULL AND @nik IS NOT NULL
    SELECT TOP 1 @pid=PegawaiIDLng FROM hris.dbo.tblpegawai WITH (NOLOCK) WHERE NomorIndukStr=@nik ORDER BY PegawaiIDLng DESC;
  IF @pid IS NULL THROW 50001, 'pegawai tidak ditemukan', 1;
  DECLARE @no_kontrak nvarchar(100)=JSON_VALUE(@j,'$.no_kontrak');
  DECLARE @tanggal_surat nvarchar(30)=JSON_VALUE(@j,'$.tanggal_surat');
  DECLARE @lama_bulan nvarchar(20)=JSON_VALUE(@j,'$.lama_bulan');
  DECLARE @terbilang nvarchar(100)=JSON_VALUE(@j,'$.terbilang');
  DECLARE @tgl_mulai nvarchar(30)=JSON_VALUE(@j,'$.tgl_mulai');
  DECLARE @tanggal_berakhir nvarchar(30)=JSON_VALUE(@j,'$.tanggal_berakhir');
  DECLARE @department nvarchar(50)=JSON_VALUE(@j,'$.department');
  DECLARE @pangkat nvarchar(50)=JSON_VALUE(@j,'$.pangkat');
  DECLARE @jabatan nvarchar(50)=JSON_VALUE(@j,'$.jabatan');
  DECLARE @golongan nvarchar(50)=JSON_VALUE(@j,'$.golongan');
  DECLARE @tingkat nvarchar(50)=JSON_VALUE(@j,'$.tingkat');
  DECLARE @penempatan nvarchar(50)=JSON_VALUE(@j,'$.penempatan');
  DECLARE @ump nvarchar(50)=JSON_VALUE(@j,'$.ump');
  EXEC POS_SERVER.dbo.xsp_personel_add_kontrak_insert
    @p_PegawaiIDLng=@pid, @p_NomorKontrakStr=@no_kontrak, @p_TanggalKontrakDtd=@tanggal_surat,
    @p_LamaBulanInt=@lama_bulan, @p_LamaBulanTerbilangStr=@terbilang,
    @p_TanggalEfektifDtd=@tgl_mulai, @p_TanggalBerakhirDtd=@tanggal_berakhir,
    @p_DepartemenIDLng=@department, @p_PangkatIDLng=@pangkat, @p_JabatanIDLng=@jabatan,
    @p_GolonganIDLng=@golongan, @p_GolonganTingkatanIDLng=@tingkat, @p_KantorCabangIDLng=@penempatan,
    @p_HonorPerBulanMon=@ump, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'Kontrak tersimpan' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kontrak_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @pid int=TRY_CAST(JSON_VALUE(@j,'$.pegawai_id') AS int);
  IF @pid IS NULL SELECT TOP 1 @pid=PegawaiIDLng FROM hris.dbo.tblpersonnelkontrak WITH (NOLOCK) WHERE PersonnelKontrakIDLng=@rid;
  DECLARE @no_kontrak nvarchar(100)=JSON_VALUE(@j,'$.no_kontrak');
  DECLARE @tanggal_surat nvarchar(30)=JSON_VALUE(@j,'$.tanggal_surat');
  DECLARE @lama_bulan nvarchar(20)=JSON_VALUE(@j,'$.lama_bulan');
  DECLARE @terbilang nvarchar(100)=JSON_VALUE(@j,'$.terbilang');
  DECLARE @tgl_mulai nvarchar(30)=JSON_VALUE(@j,'$.tgl_mulai');
  DECLARE @tanggal_berakhir nvarchar(30)=JSON_VALUE(@j,'$.tanggal_berakhir');
  DECLARE @department nvarchar(50)=JSON_VALUE(@j,'$.department');
  DECLARE @pangkat nvarchar(50)=JSON_VALUE(@j,'$.pangkat');
  DECLARE @jabatan nvarchar(50)=JSON_VALUE(@j,'$.jabatan');
  DECLARE @golongan nvarchar(50)=JSON_VALUE(@j,'$.golongan');
  DECLARE @tingkat nvarchar(50)=JSON_VALUE(@j,'$.tingkat');
  DECLARE @penempatan nvarchar(50)=JSON_VALUE(@j,'$.penempatan');
  DECLARE @ump nvarchar(50)=JSON_VALUE(@j,'$.ump');
  EXEC POS_SERVER.dbo.xsp_personel_add_kontrak_update
    @p_PersonnelKontrakIDLng=@rid, @p_PegawaiIDLng=@pid, @p_NomorKontrakStr=@no_kontrak, @p_TanggalKontrakDtd=@tanggal_surat,
    @p_LamaBulanInt=@lama_bulan, @p_LamaBulanTerbilangStr=@terbilang,
    @p_TanggalEfektifDtd=@tgl_mulai, @p_TanggalBerakhirDtd=@tanggal_berakhir,
    @p_DepartemenIDLng=@department, @p_PangkatIDLng=@pangkat, @p_JabatanIDLng=@jabatan,
    @p_GolonganIDLng=@golongan, @p_GolonganTingkatanIDLng=@tingkat, @p_KantorCabangIDLng=@penempatan,
    @p_HonorPerBulanMon=@ump, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'Kontrak diubah' responseMessage, JSON_QUERY((SELECT @rid id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kontrak_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_kontrak_delete @p_PersonnelKontrakIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

/* ---- STATUS ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_status_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_status_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_status_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 t1.PersonnelStatusIDLng AS id, t1.PegawaiIDLng AS pegawai_id, b.NomorIndukStr AS nik, b.NamaLengkapStr AS employee_name,
      t1.NomorStatusStr AS no_status, CONVERT(varchar(10), t1.TanggalEfektifDtd, 23) AS tanggal_aktif,
      t1.SekarangStatusIDLng AS status_sekarang, t1.SekarangGroupPegawaiIDLng AS group_sekarang, t1.CatatanStr AS catatan
    FROM hris.dbo.tblpersonnelstatus t1 WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblpegawai b WITH (NOLOCK) ON b.PegawaiIDLng=t1.PegawaiIDLng
    WHERE t1.PersonnelStatusIDLng=@rid FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_status_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_status_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_status_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @pid int=TRY_CAST(JSON_VALUE(@j,'$.pegawai_id') AS int);
  DECLARE @nik varchar(50)=JSON_VALUE(@j,'$.nik');
  IF @pid IS NULL AND @nik IS NOT NULL SELECT TOP 1 @pid=PegawaiIDLng FROM hris.dbo.tblpegawai WITH (NOLOCK) WHERE NomorIndukStr=@nik;
  IF @pid IS NULL THROW 50001, 'pegawai tidak ditemukan', 1;
  DECLARE @no_status nvarchar(100)=JSON_VALUE(@j,'$.no_status');
  DECLARE @status_sekarang nvarchar(50)=JSON_VALUE(@j,'$.status_sekarang');
  DECLARE @group_sekarang nvarchar(50)=JSON_VALUE(@j,'$.group_sekarang');
  DECLARE @tanggal_aktif nvarchar(30)=JSON_VALUE(@j,'$.tanggal_aktif');
  DECLARE @catatan nvarchar(500)=JSON_VALUE(@j,'$.catatan');
  EXEC POS_SERVER.dbo.xsp_personel_add_status_insert
    @p_PegawaiIDLng=@pid, @p_NomorStatusStr=@no_status, @p_SekarangStatusIDLng=@status_sekarang,
    @p_SekarangGroupPegawaiIDLng=@group_sekarang, @p_TanggalEfektifDtd=@tanggal_aktif,
    @p_CatatanStr=@catatan, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'Status tersimpan' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_status_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_status_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_status_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @pid int=TRY_CAST(JSON_VALUE(@j,'$.pegawai_id') AS int);
  IF @pid IS NULL SELECT TOP 1 @pid=PegawaiIDLng FROM hris.dbo.tblpersonnelstatus WITH (NOLOCK) WHERE PersonnelStatusIDLng=TRY_CAST(@p_id AS int);
  DECLARE @no_status nvarchar(100)=JSON_VALUE(@j,'$.no_status');
  DECLARE @status_sekarang nvarchar(50)=JSON_VALUE(@j,'$.status_sekarang');
  DECLARE @group_sekarang nvarchar(50)=JSON_VALUE(@j,'$.group_sekarang');
  DECLARE @tanggal_aktif nvarchar(30)=JSON_VALUE(@j,'$.tanggal_aktif');
  DECLARE @catatan nvarchar(500)=JSON_VALUE(@j,'$.catatan');
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_status_update
    @p_PersonnelStatusIDLng=@rid, @p_PegawaiIDLng=@pid, @p_NomorStatusStr=@no_status, @p_SekarangStatusIDLng=@status_sekarang,
    @p_SekarangGroupPegawaiIDLng=@group_sekarang, @p_TanggalEfektifDtd=@tanggal_aktif,
    @p_CatatanStr=@catatan, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'Status diubah' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_status_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_status_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_status_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_add_status_delete @p_PersonnelStatusIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

/* Promosi/mutasi: getrow + soft stubs that return clear message if write params unknown */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_promosi_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 t1.PersonnelPromosiIDLng AS id, t1.PegawaiIDLng AS pegawai_id, t2.NomorIndukStr AS nik, t2.NamaLengkapStr AS employee_name,
      t1.NomorPromosiStr AS nomor, CONVERT(varchar(10), t1.TanggalEfektifDtd, 23) AS tanggal_efektif,
      t1.SebelumJabatanIDLng AS jabatan_sebelum_id, t1.SekarangJabatanIDLng AS jabatan_sekarang_id
    FROM hris.dbo.tblpersonnelpromosi t1 WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng=t2.PegawaiIDLng
    WHERE t1.PersonnelPromosiIDLng=@rid FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_mutasi_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_getrow (@p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
    SELECT TOP 1 t1.PersonnelMutasiIDLng AS id, t1.PegawaiIDLng AS pegawai_id, tp.NomorIndukStr AS nik, tp.NamaLengkapStr AS employee_name,
      t1.NomorMutasiStr AS nomor, CONVERT(varchar(10), t1.TanggalEfektifDtd, 23) AS tanggal_efektif,
      t1.KantorCabangSebelumIDLng AS cabang_sebelum_id, t1.KantorCabangSekarangIDLng AS cabang_sekarang_id
    FROM hris.dbo.tblpersonnelmutasi t1 WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblpegawai tp WITH (NOLOCK) ON tp.PegawaiIDLng=t1.PegawaiIDLng
    WHERE t1.PersonnelMutasiIDLng=@rid FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO
