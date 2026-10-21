IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_getrows
(@p_keywords varchar(200)=NULL, @p_from_date varchar(20)=NULL, @p_to_date varchar(20)=NULL, @p_is_active varchar(1)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows = (
    SELECT TOP 200 CAST(JabatanIDLng AS varchar(50)) AS id,
           CAST(JabatanIDLng AS varchar(50)) AS code,
           JabatanStr AS name
    FROM hris.dbo.tbljabatan
    WHERE @kw='' OR JabatanStr LIKE '%'+@kw+'%'
    ORDER BY JabatanStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY(ISNULL(@rows,N'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrows
(@p_keywords varchar(200)=NULL, @p_from_date varchar(20)=NULL, @p_to_date varchar(20)=NULL, @p_is_active varchar(1)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows = (
    SELECT TOP 200 CAST(DepartemenIDLng AS varchar(50)) AS id,
           CAST(DepartemenIDLng AS varchar(50)) AS code,
           DepartemenStr AS name
    FROM hris.dbo.tbldepartemen
    WHERE @kw='' OR DepartemenStr LIKE '%'+@kw+'%'
    ORDER BY DepartemenStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY(ISNULL(@rows,N'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_getrows
(@p_keywords varchar(200)=NULL, @p_from_date varchar(20)=NULL, @p_to_date varchar(20)=NULL, @p_is_active varchar(1)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows = (
    SELECT TOP 200 CAST(DivisiIDLng AS varchar(50)) AS id,
           CAST(DivisiIDLng AS varchar(50)) AS code,
           DivisiStr AS name
    FROM hris.dbo.tbldivisi
    WHERE @kw='' OR DivisiStr LIKE '%'+@kw+'%'
    ORDER BY DivisiStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY(ISNULL(@rows,N'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_getrows
(@p_keywords varchar(200)=NULL, @p_from_date varchar(20)=NULL, @p_to_date varchar(20)=NULL, @p_is_active varchar(1)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows = (
    SELECT TOP 200 CAST(PangkatIDLng AS varchar(50)) AS id,
           CAST(PangkatIDLng AS varchar(50)) AS code,
           PangkatStr AS name
    FROM hris.dbo.tblpangkat
    WHERE @kw='' OR PangkatStr LIKE '%'+@kw+'%'
    ORDER BY PangkatStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY(ISNULL(@rows,N'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_getrows
(@p_keywords varchar(200)=NULL, @p_from_date varchar(20)=NULL, @p_to_date varchar(20)=NULL, @p_is_active varchar(1)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows = (
    SELECT TOP 200 CAST(KantorCabangIDLng AS varchar(50)) AS id,
           CAST(KantorCabangIDLng AS varchar(50)) AS code,
           NamaKantorCabangStr AS name
    FROM hris.dbo.tblkantorcabang
    WHERE @kw='' OR NamaKantorCabangStr LIKE '%'+@kw+'%'
    ORDER BY NamaKantorCabangStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY(ISNULL(@rows,N'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrows
(@p_keywords varchar(200)=NULL, @p_from_date varchar(20)=NULL, @p_to_date varchar(20)=NULL, @p_is_active varchar(1)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows = (
    SELECT TOP 200 CAST(BrandIDLng AS varchar(50)) AS id,
           CAST(BrandIDLng AS varchar(50)) AS code,
           BrandStr AS name
    FROM hris.dbo.tblformbrand
    WHERE @kw='' OR BrandStr LIKE '%'+@kw+'%'
    ORDER BY BrandStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY(ISNULL(@rows,N'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_getrows
(@p_keywords varchar(200)=NULL, @p_from_date varchar(20)=NULL, @p_to_date varchar(20)=NULL, @p_is_active varchar(1)=NULL, @bitparam varchar(max) OUTPUT)
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows = (
    SELECT TOP 200 CAST(GolonganIDLng AS varchar(50)) AS id,
           CAST(GolonganIDLng AS varchar(50)) AS code,
           GolonganStr AS name
    FROM hris.dbo.tblgolongan
    WHERE @kw='' OR GolonganStr LIKE '%'+@kw+'%'
    ORDER BY GolonganStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY(ISNULL(@rows,N'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
