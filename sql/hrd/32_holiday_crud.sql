/* Holiday — ASP Absen_Online/master_holiday.aspx → hris.dbo.master_holiday */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @yr int = TRY_CAST(COALESCE(NULLIF(LTRIM(RTRIM(@p_year)),''), NULLIF(LTRIM(RTRIM(@p_tahun)),''), CAST(YEAR(GETDATE()) AS varchar(4))) AS int);
  IF @yr IS NULL SET @yr = YEAR(GETDATE());

  DECLARE @rows nvarchar(max);
  SELECT @rows=(
    SELECT
        CAST(h.ID AS varchar(50)) AS id
      , CONVERT(varchar(10), h.[DATE], 23) AS holiday_date
      , UPPER(FORMAT(h.[DATE], N'dddd', N'id-ID')) AS hari
      , h.DESCRIPTION AS description
      , CASE
          WHEN LOWER(ISNULL(h.IS_CUTI,'false')) IN ('1','true','y','ya','yes') THEN N'YES'
          ELSE N'NO'
        END AS potong_cuti
      , CASE
          WHEN LOWER(ISNULL(h.IS_CUTI,'false')) IN ('1','true','y','ya','yes') THEN CAST(1 AS bit)
          ELSE CAST(0 AS bit)
        END AS is_cuti
    FROM hris.dbo.master_holiday h WITH (NOLOCK)
    WHERE YEAR(h.[DATE]) = @yr
      AND (
        @kw=''
        OR h.DESCRIPTION LIKE '%'+@kw+'%'
        OR CONVERT(varchar(10), h.[DATE], 23) LIKE '%'+@kw+'%'
        OR CONVERT(varchar(10), h.[DATE], 103) LIKE '%'+@kw+'%'
        OR CAST(YEAR(h.[DATE]) AS varchar(4)) LIKE '%'+@kw+'%'
      )
    ORDER BY h.[DATE]
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_getrow
( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @row nvarchar(max);
  SELECT TOP 1 @row=(
    SELECT
        CAST(h.ID AS varchar(50)) AS id
      , CONVERT(varchar(10), h.[DATE], 23) AS holiday_date
      , h.DESCRIPTION AS description
      , CASE
          WHEN LOWER(ISNULL(h.IS_CUTI,'false')) IN ('1','true','y','ya','yes') THEN CAST(1 AS bit)
          ELSE CAST(0 AS bit)
        END AS potong_cuti
    FROM hris.dbo.master_holiday h WITH (NOLOCK)
    WHERE h.ID=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
  IF @row IS NULL THROW 50001, 'Hari libur tidak ditemukan', 1;
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(@row) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_insert
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @dt datetime = COALESCE(
    TRY_CONVERT(datetime, JSON_VALUE(@j,'$.holiday_date'), 23),
    TRY_CONVERT(datetime, JSON_VALUE(@j,'$.date'), 23),
    TRY_CONVERT(datetime, REPLACE(JSON_VALUE(@j,'$.holiday_date'),'/','-'), 23)
  );
  DECLARE @desc nvarchar(200)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.description'))),'');
  IF @dt IS NULL THROW 50001, 'DATE wajib', 1;
  IF @desc IS NULL THROW 50002, 'DESCRIPTION wajib', 1;

  DECLARE @cuti nvarchar(10)=CASE
    WHEN LOWER(ISNULL(COALESCE(JSON_VALUE(@j,'$.potong_cuti'), JSON_VALUE(@j,'$.is_cuti')),'false')) IN ('1','true','y','yes')
    THEN N'True' ELSE N'False' END;

  INSERT INTO hris.dbo.master_holiday ([DATE], DESCRIPTION, IS_CUTI)
  VALUES (@dt, @desc, @cuti);
  DECLARE @newId int=SCOPE_IDENTITY();
  SET @bitparam=(SELECT '2002500' responseCode, N'Hari libur tersimpan' responseMessage,
    JSON_QUERY((SELECT CAST(@newId AS varchar(50)) AS id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_update
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  IF @rid IS NULL THROW 50001, 'ID wajib', 1;
  IF NOT EXISTS (SELECT 1 FROM hris.dbo.master_holiday WHERE ID=@rid) THROW 50002, 'Hari libur tidak ditemukan', 1;

  DECLARE @dt datetime = COALESCE(
    TRY_CONVERT(datetime, JSON_VALUE(@j,'$.holiday_date'), 23),
    TRY_CONVERT(datetime, JSON_VALUE(@j,'$.date'), 23)
  );
  DECLARE @desc nvarchar(200)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.description'))),'');
  DECLARE @cuti nvarchar(10)=CASE
    WHEN LOWER(ISNULL(COALESCE(JSON_VALUE(@j,'$.potong_cuti'), JSON_VALUE(@j,'$.is_cuti')),'false')) IN ('1','true','y','yes')
    THEN N'True' ELSE N'False' END;

  UPDATE hris.dbo.master_holiday SET
      [DATE] = COALESCE(@dt, [DATE])
    , DESCRIPTION = COALESCE(@desc, DESCRIPTION)
    , IS_CUTI = @cuti
  WHERE ID=@rid;

  SET @bitparam=(SELECT '2002500' responseCode, N'Hari libur diperbarui' responseMessage,
    JSON_QUERY((SELECT CAST(@rid AS varchar(50)) AS id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_holiday_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_holiday_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_holiday_delete
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  IF @rid IS NULL THROW 50001, 'ID wajib', 1;
  DELETE FROM hris.dbo.master_holiday WHERE ID=@rid;
  IF @@ROWCOUNT=0 THROW 50002, 'Hari libur tidak ditemukan', 1;
  SET @bitparam=(SELECT '2002500' responseCode, N'Hari libur dihapus' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
