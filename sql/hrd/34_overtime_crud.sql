/* Overtime list — ASP Overtime_List.aspx / Lookup_overtime_info.aspx
   Source: hris.dbo.web_overtime (legacy xsp_rekap_overtime_*)
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* ---- getrows ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @st varchar(50)=LTRIM(RTRIM(ISNULL(@p_status,'')));
  DECLARE @d1 date = TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(@p_from_date)),''));
  DECLARE @d2 date = TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(@p_to_date)),''));
  IF @d1 IS NULL SET @d1 = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
  IF @d2 IS NULL SET @d2 = CAST(GETDATE() AS date);

  DECLARE @rows nvarchar(max);
  SELECT @rows=(
    SELECT
        CAST(a.ID AS varchar(50)) AS id
      , FORMAT(a.TANGGAL, 'yyyy-MM-dd') AS tanggal
      , a.KATEGORI AS day
      , a.KATEGORI AS jenis_lembur
      , a.NIKSTR AS nik
      , b.NamaLengkapStr AS employee_name
      , b.NamaLengkapStr AS nama
      , d.DepartemenStr AS department
      , a.STATUS AS status
      , CASE WHEN a.STATUS = N'NEW' THEN N'important' ELSE N'info' END AS status_color
      , e.email AS email
      , CASE WHEN a.STATUS = N'APPROVED BY HRD' THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END AS selectable
    FROM hris.dbo.web_overtime a WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblpegawai b WITH (NOLOCK) ON b.NomorIndukStr = a.NIKSTR
    LEFT JOIN hris.dbo.tblpegawaijabatan c WITH (NOLOCK) ON c.PegawaiIDLng = b.PegawaiIDLng
    LEFT JOIN hris.dbo.tbldepartemen d WITH (NOLOCK) ON d.DepartemenIDLng = c.DepartemenIDLng
    LEFT JOIN POS_SERVER.dbo.WEB_USER_MAIN e WITH (NOLOCK)
      ON e.ID_USER = b.NomorIndukStr COLLATE Latin1_General_CI_AS
    WHERE a.TANGGAL >= @d1 AND a.TANGGAL < DATEADD(day, 1, @d2)
      AND (@st = '' OR a.STATUS = @st)
      AND (
        @kw = ''
        OR a.NIKSTR LIKE '%'+@kw+'%'
        OR b.NamaLengkapStr LIKE '%'+@kw+'%'
        OR d.DepartemenStr LIKE '%'+@kw+'%'
        OR a.STATUS LIKE '%'+@kw+'%'
        OR a.KATEGORI LIKE '%'+@kw+'%'
      )
    ORDER BY a.TANGGAL DESC, a.ID DESC
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ---- getrow ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_getrow
( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int = TRY_CAST(@p_id AS int);
  IF @rid IS NULL THROW 50001, 'ID wajib', 1;
  DECLARE @row nvarchar(max);
  SELECT TOP 1 @row=(
    SELECT
        CAST(a.ID AS varchar(50)) AS id
      , a.NIKSTR AS nik
      , b.NamaLengkapStr AS nama
      , b.NamaLengkapStr AS employee_name
      , d.DepartemenStr AS department
      , j.JabatanStr AS jabatan
      , a.KATEGORI AS jenis_lembur
      , FORMAT(a.TANGGAL, 'yyyy-MM-dd') AS tanggal_lembur
      , a.jam_dari AS dari_jam
      , a.jam_sampai AS sampai_jam
      , a.REASON AS keterangan
      , CASE WHEN ISNULL(a.KELUAR_KANTOR,0)=1 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS diluar_kantor
      , a.STATUS AS status
      , FORMAT(a.CRE_DATE, 'dd MMMM yyyy HH:mm', 'id-ID') AS tanggal_pengajuan
      , ISNULL(FORMAT(a.managerial_approve_date, 'dd MMMM yyyy HH:mm', 'id-ID'), N' - ') AS tanggal_approve_atasan
      , ISNULL(FORMAT(a.HRD_APPROVE_DATE, 'dd MMMM yyyy HH:mm', 'id-ID'), N' - ') AS tanggal_approve_hrd
    FROM hris.dbo.web_overtime a WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblpegawai b WITH (NOLOCK) ON b.NomorIndukStr = a.NIKSTR
    LEFT JOIN hris.dbo.tblpegawaijabatan c WITH (NOLOCK) ON c.PegawaiIDLng = b.PegawaiIDLng
    LEFT JOIN hris.dbo.tbldepartemen d WITH (NOLOCK) ON d.DepartemenIDLng = c.DepartemenIDLng
    LEFT JOIN hris.dbo.tbljabatan j WITH (NOLOCK) ON j.JabatanIDLng = c.JabatanIDLng
    WHERE a.ID = @rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
  IF @row IS NULL THROW 50002, 'Data overtime tidak ditemukan', 1;
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(@row) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ---- insert (HRD path → APPROVED BY HRD) ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_insert
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @nik varchar(30)=NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.nik'), JSON_VALUE(@j,'$.nikstr')))),'');
  DECLARE @kat varchar(50)=NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.jenis_lembur'), JSON_VALUE(@j,'$.kategori')))),'');
  DECLARE @tgl date=TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.tanggal_lembur'), JSON_VALUE(@j,'$.tanggal')))),''));
  DECLARE @jd varchar(50)=NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.dari_jam'), JSON_VALUE(@j,'$.jam_dari')))),'');
  DECLARE @js varchar(50)=NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.sampai_jam'), JSON_VALUE(@j,'$.jam_sampai')))),'');
  DECLARE @reason varchar(300)=NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.keterangan'), JSON_VALUE(@j,'$.reason')))),'');
  DECLARE @keluar bit = CASE
    WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.diluar_kantor'), JSON_VALUE(@j,'$.keluar_kantor'))) IN ('1','true','y','yes') THEN 1
    ELSE 0 END;
  DECLARE @actor varchar(50)=COALESCE(NULLIF(@p_created_by,''), NULLIF(@p_actor_nik,''), 'portal');

  IF @nik IS NULL THROW 50001, 'NIK wajib', 1;
  IF @kat IS NULL OR @kat IN ('PILIH','') THROW 50002, 'Jenis lembur wajib', 1;
  IF @tgl IS NULL THROW 50003, 'Tanggal lembur wajib', 1;
  IF @jd IS NULL THROW 50004, 'Dari jam wajib', 1;
  IF @js IS NULL THROW 50005, 'Sampai jam wajib', 1;
  IF @reason IS NULL THROW 50006, 'Subjek kerja wajib', 1;

  IF EXISTS (SELECT 1 FROM hris.dbo.web_overtime WITH (NOLOCK) WHERE NIKSTR=@nik AND TANGGAL=@tgl)
    THROW 50007, 'DATA SUDAH DI INPUT', 1;

  DECLARE @newId int;
  INSERT INTO hris.dbo.web_overtime
    (nikstr, KATEGORI, TANGGAL, jam_dari, jam_sampai, REASON,
     CRE_IP_ADDRESS, CRE_BY, CRE_DATE, HRD_APPROVE_DATE, MANAGERIAL_APPROVE_DATE, KELUAR_KANTOR, STATUS)
  VALUES
    (@nik, @kat, @tgl, @jd, @js, @reason,
     'portal', @actor, GETDATE(), GETDATE(), GETDATE(), @keluar, N'APPROVED BY HRD');
  SET @newId = SCOPE_IDENTITY();

  SET @bitparam=(SELECT '2002500' responseCode, N'Data tersimpan' responseMessage,
    JSON_QUERY((SELECT CAST(@newId AS varchar(50)) AS id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ---- update ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_update
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  IF @rid IS NULL THROW 50001, 'ID wajib', 1;
  IF NOT EXISTS (SELECT 1 FROM hris.dbo.web_overtime WHERE ID=@rid)
    THROW 50002, 'Data overtime tidak ditemukan', 1;

  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @nik varchar(30)=NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.nik'), JSON_VALUE(@j,'$.nikstr')))),'');
  DECLARE @kat varchar(50)=NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.jenis_lembur'), JSON_VALUE(@j,'$.kategori')))),'');
  DECLARE @tgl date=TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.tanggal_lembur'), JSON_VALUE(@j,'$.tanggal')))),''));
  DECLARE @jd varchar(50)=NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.dari_jam'), JSON_VALUE(@j,'$.jam_dari')))),'');
  DECLARE @js varchar(50)=NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.sampai_jam'), JSON_VALUE(@j,'$.jam_sampai')))),'');
  DECLARE @reason varchar(300)=NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.keterangan'), JSON_VALUE(@j,'$.reason')))),'');
  DECLARE @keluar bit = CASE
    WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.diluar_kantor'), JSON_VALUE(@j,'$.keluar_kantor'))) IN ('1','true','y','yes') THEN 1
    ELSE 0 END;

  IF @nik IS NULL THROW 50003, 'NIK wajib', 1;
  IF @kat IS NULL OR @kat IN ('PILIH','') THROW 50004, 'Jenis lembur wajib', 1;
  IF @tgl IS NULL THROW 50005, 'Tanggal lembur wajib', 1;

  UPDATE hris.dbo.web_overtime
  SET nikstr=@nik, KATEGORI=@kat, TANGGAL=@tgl, jam_dari=@jd, jam_sampai=@js,
      REASON=@reason, KELUAR_KANTOR=@keluar
  WHERE ID=@rid;

  SET @bitparam=(SELECT '2002500' responseCode, N'Data diperbarui' responseMessage,
    JSON_QUERY((SELECT CAST(@rid AS varchar(50)) AS id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ---- delete ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_delete
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(COALESCE(@p_id, JSON_VALUE(@p_payload,'$.id')) AS int);
  IF @rid IS NULL THROW 50001, 'ID wajib', 1;
  DELETE FROM hris.dbo.web_overtime WHERE ID=@rid;
  SET @bitparam=(SELECT '2002500' responseCode, N'Data dihapus' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* ---- approve (bulk) — ASP rekap_overtime_approved ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_approve_process', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_approve_process;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_approve_process
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL
, @p_period varchar(30)=NULL, @p_store_id varchar(50)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @ids TABLE (id int PRIMARY KEY);

  INSERT INTO @ids(id)
  SELECT DISTINCT TRY_CAST([value] AS int)
  FROM OPENJSON(@j, '$.ids')
  WHERE TRY_CAST([value] AS int) IS NOT NULL;

  IF NOT EXISTS (SELECT 1 FROM @ids)
  BEGIN
    DECLARE @single int = TRY_CAST(COALESCE(JSON_VALUE(@j,'$.id'), JSON_VALUE(@j,'$.ID')) AS int);
    IF @single IS NOT NULL INSERT INTO @ids(id) VALUES (@single);
  END

  IF NOT EXISTS (SELECT 1 FROM @ids) THROW 50001, 'Pilih data untuk di-approve', 1;

  UPDATE o
  SET status = N'APPROVED BY HRD', HRD_APPROVE_DATE = GETDATE()
  FROM hris.dbo.web_overtime o
  INNER JOIN @ids i ON i.id = o.ID
  WHERE o.status <> N'APPROVED BY HRD';

  DECLARE @n int = @@ROWCOUNT;
  SET @bitparam=(SELECT '2002500' responseCode,
    CONCAT(N'Approved ', @n, N' data') responseMessage,
    JSON_QUERY((SELECT @n AS approved_count FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
