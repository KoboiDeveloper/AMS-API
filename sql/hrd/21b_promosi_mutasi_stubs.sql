USE RBACESS;
GO
/* Stub write SPs so routes don't 500 until full field mapping is finished. */

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_promosi_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON;
  SET @bitparam=(SELECT '4002500' responseCode, N'Promosi insert: mapping field legacy belum lengkap — gunakan employeeinfo.aspx sementara' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_promosi_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON;
  SET @bitparam=(SELECT '4002500' responseCode, N'Promosi update: mapping field legacy belum lengkap' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_promosi_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_promosi_delete @p_PersonnelPromosiIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_mutasi_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_insert
(@p_payload nvarchar(max)=NULL,@p_created_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @pid int=TRY_CAST(JSON_VALUE(@j,'$.pegawai_id') AS int);
  DECLARE @nik varchar(50)=JSON_VALUE(@j,'$.nik');
  IF @pid IS NULL AND @nik IS NOT NULL SELECT TOP 1 @pid=PegawaiIDLng FROM hris.dbo.tblpegawai WITH (NOLOCK) WHERE NomorIndukStr=@nik;
  IF @pid IS NULL THROW 50001, 'pegawai tidak ditemukan', 1;
  DECLARE @nomor nvarchar(100)=COALESCE(JSON_VALUE(@j,'$.nomor'), JSON_VALUE(@j,'$.no_mutasi'));
  DECLARE @tgl_mutasi nvarchar(30)=COALESCE(JSON_VALUE(@j,'$.tanggal_mutasi'), JSON_VALUE(@j,'$.tanggal_surat'));
  DECLARE @cabang_sebelum nvarchar(50)=COALESCE(JSON_VALUE(@j,'$.cabang_sebelum_id'), JSON_VALUE(@j,'$.cabang_sebelum'));
  DECLARE @cabang_sekarang nvarchar(50)=COALESCE(JSON_VALUE(@j,'$.cabang_sekarang_id'), JSON_VALUE(@j,'$.cabang_sekarang'), JSON_VALUE(@j,'$.penempatan'));
  DECLARE @tgl_efektif nvarchar(30)=COALESCE(JSON_VALUE(@j,'$.tanggal_efektif'), JSON_VALUE(@j,'$.tanggal_aktif'));
  DECLARE @catatan nvarchar(500)=JSON_VALUE(@j,'$.catatan');
  EXEC POS_SERVER.dbo.xsp_personel_mutasi_insert
    @p_PegawaiIDLng=@pid, @p_NomorMutasiStr=@nomor, @p_TanggalMutasiDtd=@tgl_mutasi,
    @p_KantorCabangSebelumIDLng=@cabang_sebelum, @p_KantorCabangSekarangIDLng=@cabang_sekarang,
    @p_TanggalEfektifDtd=@tgl_efektif, @p_CatatanStr=@catatan, @p_UserNameStr=@actor;
  SET @bitparam=(SELECT '2002500' responseCode,'Mutasi tersimpan' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_mutasi_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_update
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON;
  SET @bitparam=(SELECT '4002500' responseCode, N'Mutasi update: mapping field legacy belum lengkap' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_mutasi_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_delete
(@p_id varchar(50)=NULL,@p_payload nvarchar(max)=NULL,@p_updated_by varchar(50)=NULL,@p_actor_nik varchar(50)=NULL,@bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  EXEC POS_SERVER.dbo.xsp_personel_mutasi_delete @p_PersonnelMutasiIDLng=@rid;
  SET @bitparam=(SELECT '2002500' responseCode,'Deleted' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); END CATCH END
GO
