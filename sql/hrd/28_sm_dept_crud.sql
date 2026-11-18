/* SM Department — header (sm_dept_list) + detail depts (sm_dept_detail)
   ASP: sm_dept_list.aspx / sm_dept_info.aspx / Lookup_dept.aspx */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* ========== HEADER getrow ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_getrow
( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int = TRY_CAST(@p_id AS int);
  DECLARE @row nvarchar(max);
  SELECT TOP 1 @row = (
    SELECT
        CAST(a.ID AS varchar(50)) AS id
      , a.NIK AS nik
      , COALESCE(
            NULLIF(LTRIM(RTRIM(b.NamaLengkapStr)), ''),
            NULLIF(LTRIM(RTRIM(a.NAMA COLLATE Latin1_General_CI_AS)), ''),
            ''
        ) AS nama
      , ISNULL(j.JabatanStr COLLATE Latin1_General_CI_AS, '') AS jabatan
      , CAST(ISNULL(a.STATUS, 1) AS varchar(10)) AS status
    FROM hris.dbo.SM_DEPT_LIST a WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblpegawai b WITH (NOLOCK) ON b.NomorIndukStr = a.NIK
    LEFT JOIN hris.dbo.tblpegawaijabatan pj WITH (NOLOCK) ON pj.PegawaiIDLng = b.PegawaiIDLng
    LEFT JOIN hris.dbo.tbljabatan j WITH (NOLOCK) ON j.JabatanIDLng = pj.JabatanIDLng
    WHERE a.ID = @rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
  IF @row IS NULL THROW 50001, 'SM department tidak ditemukan', 1;
  SET @bitparam = (SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(@row) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ========== HEADER insert ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_insert
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @j nvarchar(max) = ISNULL(@p_payload, N'{}');
  DECLARE @nik varchar(50) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@j, '$.nik'))), '');
  DECLARE @nama varchar(200) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@j, '$.nama'))), '');
  IF @nik IS NULL THROW 50001, 'NIK wajib diisi', 1;
  IF EXISTS (SELECT 1 FROM hris.dbo.SM_DEPT_LIST WITH (NOLOCK) WHERE NIK = @nik)
    THROW 50002, 'NIK sudah terdaftar sebagai Senior Manager', 1;
  IF @nama IS NULL
    SELECT TOP 1 @nama = NamaLengkapStr FROM hris.dbo.tblpegawai WITH (NOLOCK) WHERE NomorIndukStr = @nik ORDER BY PegawaiIDLng DESC;
  INSERT INTO hris.dbo.SM_DEPT_LIST (NIK, NAMA, STATUS)
  VALUES (@nik, @nama, 1);
  DECLARE @newId int = SCOPE_IDENTITY();
  SET @bitparam = (
    SELECT '2002500' responseCode, N'Senior Manager tersimpan' responseMessage,
           JSON_QUERY((SELECT CAST(@newId AS varchar(50)) AS id, @nik AS nik FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
END TRY BEGIN CATCH
  SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ========== HEADER update ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_update
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int = TRY_CAST(@p_id AS int);
  DECLARE @j nvarchar(max) = ISNULL(@p_payload, N'{}');
  DECLARE @nik varchar(50) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@j, '$.nik'))), '');
  DECLARE @nama varchar(200) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@j, '$.nama'))), '');
  IF @rid IS NULL THROW 50001, 'ID tidak valid', 1;
  IF NOT EXISTS (SELECT 1 FROM hris.dbo.SM_DEPT_LIST WHERE ID = @rid) THROW 50002, 'Data tidak ditemukan', 1;
  IF @nik IS NULL SELECT @nik = NIK FROM hris.dbo.SM_DEPT_LIST WHERE ID = @rid;
  IF @nama IS NULL
    SELECT TOP 1 @nama = NamaLengkapStr FROM hris.dbo.tblpegawai WITH (NOLOCK) WHERE NomorIndukStr = @nik ORDER BY PegawaiIDLng DESC;
  UPDATE hris.dbo.SM_DEPT_LIST SET NIK = @nik, NAMA = @nama WHERE ID = @rid;
  SET @bitparam = (
    SELECT '2002500' responseCode, N'Data diperbarui' responseMessage,
           JSON_QUERY((SELECT CAST(@rid AS varchar(50)) AS id, @nik AS nik FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
END TRY BEGIN CATCH
  SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ========== HEADER delete ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_delete
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int = TRY_CAST(@p_id AS int);
  DECLARE @nik varchar(50);
  SELECT @nik = NIK FROM hris.dbo.SM_DEPT_LIST WHERE ID = @rid;
  IF @nik IS NULL THROW 50001, 'Data tidak ditemukan', 1;
  DELETE FROM hris.dbo.SM_DEPT_DETAIL WHERE NIK_SM = @nik;
  DELETE FROM hris.dbo.SM_DEPT_LIST WHERE ID = @rid;
  SET @bitparam = (SELECT '2002500' responseCode, N'Data dihapus' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ========== DETAIL list (assigned departments) — filter by @p_nik (optional param) ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_detail_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_detail_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_detail_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @p_nik varchar(50)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200) = LTRIM(RTRIM(ISNULL(@p_keywords, '')));
  DECLARE @nik varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_nik, ''))), '');
  IF @nik IS NULL THROW 50001, 'NIK SM wajib', 1;
  DECLARE @rows nvarchar(max);
  SELECT @rows = (
    SELECT
        CAST(d.ID AS varchar(50)) AS id
      , d.NIK_SM AS nik
      , LTRIM(RTRIM(d.DEPT)) AS dept
      , COALESCE(
            dep.DepartemenStr COLLATE Latin1_General_CI_AS,
            LTRIM(RTRIM(d.DEPT COLLATE Latin1_General_CI_AS))
        ) AS department
    FROM hris.dbo.SM_DEPT_DETAIL d WITH (NOLOCK)
    LEFT JOIN hris.dbo.tbldepartemen dep WITH (NOLOCK)
      ON LTRIM(RTRIM(dep.KodeDepartemenStr)) COLLATE Latin1_General_CI_AS
       = LTRIM(RTRIM(d.DEPT)) COLLATE Latin1_General_CI_AS
    WHERE d.NIK_SM = @nik
      AND (
        @kw = ''
        OR d.DEPT LIKE '%' + @kw + '%'
        OR ISNULL(dep.DepartemenStr, '') LIKE '%' + @kw + '%'
      )
    ORDER BY COALESCE(
      dep.DepartemenStr COLLATE Latin1_General_CI_AS,
      d.DEPT COLLATE Latin1_General_CI_AS
    )
    FOR JSON PATH
  );
  SET @bitparam = (SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows, '[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ========== DETAIL insert — payload: { nik, dept } or { nik, depts: [...] } ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_detail_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_detail_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_detail_insert
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @j nvarchar(max) = ISNULL(@p_payload, N'{}');
  DECLARE @nik varchar(50) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@j, '$.nik'))), '');
  IF @nik IS NULL THROW 50001, 'NIK wajib', 1;
  IF NOT EXISTS (SELECT 1 FROM hris.dbo.SM_DEPT_LIST WITH (NOLOCK) WHERE NIK = @nik)
    THROW 50002, 'Senior Manager tidak ditemukan', 1;

  DECLARE @codes TABLE (kode varchar(50) NOT NULL PRIMARY KEY);
  DECLARE @single varchar(50) = NULLIF(LTRIM(RTRIM(JSON_VALUE(@j, '$.dept'))), '');
  IF @single IS NOT NULL INSERT INTO @codes (kode) VALUES (@single);

  INSERT INTO @codes (kode)
  SELECT DISTINCT LTRIM(RTRIM(v.value))
  FROM OPENJSON(@j, '$.depts') v
  WHERE LTRIM(RTRIM(ISNULL(v.value, ''))) <> ''
    AND NOT EXISTS (SELECT 1 FROM @codes c WHERE c.kode = LTRIM(RTRIM(v.value)));

  /* resolve numeric ids → KodeDepartemenStr */
  UPDATE c SET kode = dep.KodeDepartemenStr
  FROM @codes c
  INNER JOIN hris.dbo.tbldepartemen dep WITH (NOLOCK)
    ON TRY_CAST(c.kode AS int) = dep.DepartemenIDLng
   AND TRY_CAST(c.kode AS int) IS NOT NULL
   AND NOT EXISTS (
     SELECT 1 FROM hris.dbo.tbldepartemen x WITH (NOLOCK)
     WHERE LTRIM(RTRIM(x.KodeDepartemenStr)) = LTRIM(RTRIM(c.kode))
   );

  DECLARE @added int = 0;
  DECLARE @kode varchar(50);
  DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT kode FROM @codes;
  OPEN cur;
  FETCH NEXT FROM cur INTO @kode;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    IF @kode IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM hris.dbo.SM_DEPT_DETAIL WITH (NOLOCK)
      WHERE NIK_SM = @nik AND LTRIM(RTRIM(DEPT)) = LTRIM(RTRIM(@kode))
    )
    BEGIN
      INSERT INTO hris.dbo.SM_DEPT_DETAIL (NIK_SM, DEPT) VALUES (@nik, @kode);
      SET @added += 1;
    END
    FETCH NEXT FROM cur INTO @kode;
  END
  CLOSE cur; DEALLOCATE cur;

  SET @bitparam = (
    SELECT '2002500' responseCode,
           CONCAT(N'Department ditambahkan (', @added, N')') responseMessage,
           JSON_QUERY((SELECT @added AS added FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
END TRY BEGIN CATCH
  SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ========== DETAIL delete ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_detail_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_detail_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_detail_delete
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int = TRY_CAST(@p_id AS int);
  IF @rid IS NULL THROW 50001, 'ID detail tidak valid', 1;
  DELETE FROM hris.dbo.SM_DEPT_DETAIL WHERE ID = @rid;
  IF @@ROWCOUNT = 0 THROW 50002, 'Baris department tidak ditemukan', 1;
  SET @bitparam = (SELECT '2002500' responseCode, N'Department dihapus' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* stub getrow for entity registration */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_detail_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_detail_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_detail_getrow
( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int = TRY_CAST(@p_id AS int);
  DECLARE @row nvarchar(max);
  SELECT TOP 1 @row = (
    SELECT CAST(d.ID AS varchar(50)) AS id, d.NIK_SM AS nik, LTRIM(RTRIM(d.DEPT)) AS dept,
           COALESCE(
             dep.DepartemenStr COLLATE Latin1_General_CI_AS,
             LTRIM(RTRIM(d.DEPT COLLATE Latin1_General_CI_AS))
           ) AS department
    FROM hris.dbo.SM_DEPT_DETAIL d WITH (NOLOCK)
    LEFT JOIN hris.dbo.tbldepartemen dep WITH (NOLOCK)
      ON LTRIM(RTRIM(dep.KodeDepartemenStr)) COLLATE Latin1_General_CI_AS
       = LTRIM(RTRIM(d.DEPT)) COLLATE Latin1_General_CI_AS
    WHERE d.ID = @rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
  SET @bitparam = (SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@row, '{}')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* stub update */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_sm_dept_detail_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_detail_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_sm_dept_detail_update
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
  SET @bitparam = (SELECT '4002500' responseCode, N'Update detail tidak didukung — hapus lalu tambah ulang' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END
GO
