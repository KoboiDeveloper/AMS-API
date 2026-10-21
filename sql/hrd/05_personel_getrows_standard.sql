IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows
( @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
 DECLARE @active varchar(10)=LTRIM(RTRIM(ISNULL(@p_is_active,'')));
 SET @bitparam=(SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
  SELECT TOP 2000 t1.PegawaiIDLng AS id, t1.NomorIndukStr AS nik, t1.NamaLengkapStr AS employee_name,
   CAST(NULL AS varchar(100)) AS brand, t7.NamaKantorCabangStr AS branch_name, t3.JabatanStr AS job_title,
   t4.DepartemenStr AS department, t5.StatusPegawaiStr AS status,
   CASE WHEN t1.PegawaiNonAktifInt=0 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS is_active
  FROM hris.dbo.tblpegawai t1
  LEFT JOIN hris.dbo.tblpegawaijabatan t2 ON t1.PegawaiIDLng=t2.PegawaiIDLng
  LEFT JOIN hris.dbo.tbljabatan t3 ON t2.JabatanIDLng=t3.JabatanIDLng
  LEFT JOIN hris.dbo.tbldepartemen t4 ON t2.DepartemenIDLng=t4.DepartemenIDLng
  LEFT JOIN hris.dbo.tblstatuspegawai t5 ON t2.StatusPegawaiIDLng=t5.StatusPegawaiIDLng
  LEFT JOIN hris.dbo.tblpegawaipenempatan t6 ON t1.PegawaiIDLng=t6.PegawaiIDLng
  LEFT JOIN hris.dbo.tblkantorcabang t7 ON t6.KantorCabangIDLng=t7.KantorCabangIDLng
  WHERE ((@active IN ('1','true','TRUE') AND t1.PegawaiNonAktifInt=0) OR (@active IN ('0','false','FALSE') AND t1.PegawaiNonAktifInt=1) OR (@active=''))
    AND (@kw='' OR t1.NomorIndukStr LIKE '%'+@kw+'%' OR t1.NamaLengkapStr LIKE '%'+@kw+'%' OR ISNULL(t3.JabatanStr,'') LIKE '%'+@kw+'%' OR ISNULL(t7.NamaKantorCabangStr,'') LIKE '%'+@kw+'%')
  FOR JSON PATH)) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
 SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END
GO