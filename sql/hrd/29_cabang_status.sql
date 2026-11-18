/* Cabang aktif/nonaktif — ASP m_cabang.aspx → xsp_update_status_cabang */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_status_process', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_status_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_status_process
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL
, @p_period varchar(30)=NULL, @p_store_id varchar(50)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @j nvarchar(max) = ISNULL(@p_payload, N'{}');
  DECLARE @id int = TRY_CAST(COALESCE(JSON_VALUE(@j, '$.id'), JSON_VALUE(@j, '$.KantorCabangIDLng')) AS int);
  DECLARE @act varchar(30) = UPPER(LTRIM(RTRIM(COALESCE(
      JSON_VALUE(@j, '$.action'),
      JSON_VALUE(@j, '$.ngapain'),
      JSON_VALUE(@j, '$.confirm_status'),
      ''
  ))));
  IF @id IS NULL THROW 50001, 'ID cabang wajib', 1;
  IF @act NOT IN ('AKTIFKAN', 'NONAKTIFKAN') THROW 50002, 'action harus AKTIFKAN atau NONAKTIFKAN', 1;
  IF @act = 'AKTIFKAN'
    UPDATE hris.dbo.tblkantorcabang SET AktifInt = 1 WHERE KantorCabangIDLng = @id;
  ELSE
    UPDATE hris.dbo.tblkantorcabang SET AktifInt = 0 WHERE KantorCabangIDLng = @id;
  IF @@ROWCOUNT = 0 THROW 50003, 'Cabang tidak ditemukan', 1;
  SET @bitparam = (
    SELECT '2002500' responseCode,
           CASE WHEN @act = 'AKTIFKAN' THEN N'Cabang diaktifkan' ELSE N'Cabang dinonaktifkan' END responseMessage,
           JSON_QUERY((SELECT CAST(@id AS varchar(50)) AS id, @act AS action FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
END TRY BEGIN CATCH
  SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
