/* HRD: real personel list SPs (from hris) + shared lookup SP */
USE RBACESS;
GO

/* ========== LOOKUP ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_lookup_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_lookup_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_lookup_getrows
(
  @p_type varchar(50),
  @p_keywords varchar(200)=NULL,
  @p_parent_id varchar(50)=NULL,
  @bitparam varchar(max) OUTPUT
)
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
    DECLARE @pid varchar(50)=LTRIM(RTRIM(ISNULL(@p_parent_id,'')));
    DECLARE @t varchar(50)=LOWER(LTRIM(RTRIM(ISNULL(@p_type,''))));
    DECLARE @rows nvarchar(max);

    IF @t IN ('brand','id_brand')
      SET @rows=(
        SELECT CAST(x.idbrand AS varchar(50)) AS value, x.description AS label
        FROM (
          SELECT CAST('DS' AS varchar(20)) AS idbrand, CAST('Discount Store' AS varchar(100)) AS description
          UNION ALL
          SELECT CAST(IDBrand AS varchar(20)), CAST(Description AS varchar(100))
          FROM ACCT.dbo.GL_Brand WHERE AktifGL='1'
        ) x
        WHERE (@kw='' OR x.description LIKE '%'+@kw+'%' OR x.idbrand LIKE '%'+@kw+'%')
        ORDER BY x.idbrand
        FOR JSON PATH
      );
    ELSE IF @t IN ('store','id_store')
      SET @rows=(
        SELECT CAST(s.Store_ID AS varchar(50)) AS value,
               CAST(ISNULL(NULLIF(LTRIM(RTRIM(s.Store_Name)),''), s.Store_ID) AS varchar(200)) AS label
        FROM POS_SERVER.dbo.DT_Store s WITH (NOLOCK)
        WHERE ISNULL(s.Status_Active,1)=1
          AND (@pid='' OR s.Store_Brand_ID=@pid OR s.Brand_ACCT=@pid OR s.Store_Brand_ID_2=@pid)
          AND (@kw='' OR s.Store_ID LIKE '%'+@kw+'%' OR ISNULL(s.Store_Name,'') LIKE '%'+@kw+'%')
        ORDER BY s.Store_Name
        FOR JSON PATH
      );
    ELSE IF @t IN ('cabang','penempatan','id_cabang')
      SET @rows=(
        SELECT CAST(KantorCabangIDLng AS varchar(50)) AS value,
               CAST(NamaKantorCabangStr AS varchar(200)) AS label
        FROM hris.dbo.tblkantorcabang WITH (NOLOCK)
        WHERE (@kw='' OR NamaKantorCabangStr LIKE '%'+@kw+'%')
        ORDER BY NamaKantorCabangStr
        FOR JSON PATH
      );
    ELSE IF @t IN ('department','dept','departemen')
      SET @rows=(
        SELECT CAST(DepartemenIDLng AS varchar(50)) AS value,
               CAST(DepartemenStr AS varchar(200)) AS label
        FROM hris.dbo.tbldepartemen WITH (NOLOCK)
        WHERE (@kw='' OR DepartemenStr LIKE '%'+@kw+'%')
        ORDER BY DepartemenStr
        FOR JSON PATH
      );
    ELSE IF @t IN ('unit','bagian')
      SET @rows=(
        SELECT CAST(DepartemenBagianIDLng AS varchar(50)) AS value,
               CAST(ISNULL(NULLIF(DepartemenBagianStr,''), KodeDepartemenBagianStr) AS varchar(200)) AS label
        FROM hris.dbo.tbldepartemenbagian WITH (NOLOCK)
        WHERE (@pid='' OR CAST(DepartemenIDLng AS varchar(50))=@pid)
          AND (@kw='' OR ISNULL(DepartemenBagianStr,'') LIKE '%'+@kw+'%' OR ISNULL(KodeDepartemenBagianStr,'') LIKE '%'+@kw+'%')
        ORDER BY DepartemenBagianStr
        FOR JSON PATH
      );
    ELSE IF @t='pangkat'
      SET @rows=(
        SELECT CAST(PangkatIDLng AS varchar(50)) AS value, CAST(PangkatStr AS varchar(200)) AS label
        FROM hris.dbo.tblpangkat WITH (NOLOCK)
        WHERE (@kw='' OR PangkatStr LIKE '%'+@kw+'%')
        ORDER BY PangkatStr
        FOR JSON PATH
      );
    ELSE IF @t='jabatan'
      SET @rows=(
        SELECT CAST(JabatanIDLng AS varchar(50)) AS value, CAST(JabatanStr AS varchar(200)) AS label
        FROM hris.dbo.tbljabatan WITH (NOLOCK)
        WHERE (@kw='' OR JabatanStr LIKE '%'+@kw+'%')
        ORDER BY JabatanStr
        FOR JSON PATH
      );
    ELSE IF @t IN ('golongan','level')
      SET @rows=(
        SELECT CAST(GolonganIDLng AS varchar(50)) AS value, CAST(GolonganStr AS varchar(200)) AS label
        FROM hris.dbo.tblgolongan WITH (NOLOCK)
        WHERE (@kw='' OR GolonganStr LIKE '%'+@kw+'%')
        ORDER BY GolonganStr
        FOR JSON PATH
      );
    ELSE IF @t='tingkat'
      SET @rows=(
        SELECT CAST(GolonganTingkatanIDLng AS varchar(50)) AS value,
               CAST(GolonganTingkatanStr AS varchar(200)) AS label
        FROM hris.dbo.tblgolongantingkatan WITH (NOLOCK)
        WHERE (@pid='' OR CAST(GolonganIDLng AS varchar(50))=@pid)
          AND (@kw='' OR GolonganTingkatanStr LIKE '%'+@kw+'%')
        ORDER BY GolonganTingkatanStr
        FOR JSON PATH
      );
    ELSE IF @t IN ('status_pegawai','status')
      SET @rows=(
        SELECT CAST(StatusPegawaiIDLng AS varchar(50)) AS value,
               CAST(StatusPegawaiStr AS varchar(200)) AS label
        FROM hris.dbo.tblstatuspegawai WITH (NOLOCK)
        WHERE (@kw='' OR StatusPegawaiStr LIKE '%'+@kw+'%')
        ORDER BY StatusPegawaiStr
        FOR JSON PATH
      );
    ELSE IF @t IN ('group','group_pegawai')
      SET @rows=(
        SELECT CAST(GroupPegawaiIDLng AS varchar(50)) AS value,
               CAST(GroupPegawaiStr AS varchar(200)) AS label
        FROM hris.dbo.tblkelompokpegawai WITH (NOLOCK)
        WHERE (@kw='' OR GroupPegawaiStr LIKE '%'+@kw+'%')
        ORDER BY GroupPegawaiStr
        FOR JSON PATH
      );
    ELSE IF @t IN ('alasan_resign','tipe_resign')
      SET @rows=(
        SELECT CAST(AlasanResignIDLng AS varchar(50)) AS value,
               CAST(AlasanResignStr AS varchar(200)) AS label
        FROM hris.dbo.tblalasanresign WITH (NOLOCK)
        WHERE (@kw='' OR AlasanResignStr LIKE '%'+@kw+'%')
        ORDER BY AlasanResignStr
        FOR JSON PATH
      );
    ELSE IF @t IN ('divisi')
      SET @rows=(
        SELECT CAST(DivisiIDLng AS varchar(50)) AS value, CAST(DivisiStr AS varchar(200)) AS label
        FROM hris.dbo.tbldivisi WITH (NOLOCK)
        WHERE (@kw='' OR DivisiStr LIKE '%'+@kw+'%')
        ORDER BY DivisiStr
        FOR JSON PATH
      );
    ELSE IF @t IN ('kota')
      SET @rows=(
        SELECT CAST(KotaIDLng AS varchar(50)) AS value, CAST(KotaStr AS varchar(200)) AS label
        FROM hris.dbo.tblkota WITH (NOLOCK)
        WHERE (@kw='' OR KotaStr LIKE '%'+@kw+'%')
        ORDER BY KotaStr
        FOR JSON PATH
      );
    ELSE IF @t IN ('provinsi')
      SET @rows=(
        SELECT CAST(ProvinsiIDLng AS varchar(50)) AS value, CAST(ProvinsiStr AS varchar(200)) AS label
        FROM hris.dbo.tblprovinsi WITH (NOLOCK)
        WHERE (@kw='' OR ProvinsiStr LIKE '%'+@kw+'%')
        ORDER BY ProvinsiStr
        FOR JSON PATH
      );
    ELSE IF @t IN ('negara')
      SET @rows=(
        SELECT CAST(NegaraIDLng AS varchar(50)) AS value, CAST(NegaraStr AS varchar(200)) AS label
        FROM hris.dbo.tblnegara WITH (NOLOCK)
        WHERE (@kw='' OR NegaraStr LIKE '%'+@kw+'%')
        ORDER BY NegaraStr
        FOR JSON PATH
      );
    ELSE
    BEGIN
      SET @bitparam=(SELECT '4002500' responseCode, N'Unknown lookup type: '+ISNULL(@p_type,'') responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
      RETURN;
    END

    SET @bitparam=(
      SELECT '2002500' responseCode, N'success' responseMessage,
             JSON_QUERY(ISNULL(@rows,'[]')) data
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
  END TRY
  BEGIN CATCH
    SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END CATCH
END
GO

/* ========== PERSONEL KONTRAK ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kontrak_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_getrows
(   @p_keywords varchar(200)=NULL
, @p_from_date varchar(30)=NULL
, @p_to_date varchar(30)=NULL
, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL
, @p_id_store varchar(50)=NULL
, @p_brand varchar(50)=NULL
, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL
, @p_kategori varchar(50)=NULL
, @p_group varchar(50)=NULL
, @p_dept varchar(50)=NULL
, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL
, @p_id_cabang varchar(50)=NULL
, @p_year varchar(10)=NULL
, @p_month varchar(10)=NULL
, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL
, @p_is_pajak varchar(10)=NULL
, @p_id_mesin varchar(50)=NULL
, @p_currentmonth varchar(20)=NULL
, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  SET @bitparam=(
    SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
      SELECT TOP 5000
        t1.PersonnelKontrakIDLng AS id,
        t1.PegawaiIDLng AS pegawai_id,
        t2.NomorIndukStr AS nik,
        t2.NamaLengkapStr AS employee_name,
        t1.NomorKontrakStr AS no_kontrak,
        CONVERT(varchar(10), t1.TanggalKontrakDtd, 23) AS tanggal_surat,
        CONVERT(varchar(10), t1.TanggalBerakhirKontrakSebelumnyaDtd, 23) AS tanggal_berakhir_sebelumnya,
        CONVERT(varchar(10), t1.TanggalEfektifDtd, 23) AS tgl_mulai,
        CONVERT(varchar(10), t1.TanggalBerakhirDtd, 23) AS tanggal_berakhir,
        t1.LamaBulanInt AS lama_bulan,
        t1.LamaBulanTerbilangStr AS terbilang,
        t1.DepartemenIDLng AS department,
        t1.DepartemenBagianIDLng AS unit,
        t1.PangkatIDLng AS pangkat,
        t1.JabatanIDLng AS jabatan,
        t1.GolonganIDLng AS golongan,
        t1.GolonganTingkatanIDLng AS tingkat,
        t1.KantorCabangIDLng AS penempatan,
        t1.HonorPerBulanMon AS ump
      FROM hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
      LEFT JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng=t2.PegawaiIDLng
      WHERE (@kw='' OR CAST(t1.PegawaiIDLng AS varchar(30)) LIKE '%'+@kw+'%'
        OR ISNULL(t2.NamaLengkapStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(t2.NomorIndukStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(t1.NomorKontrakStr,'') LIKE '%'+@kw+'%')
      ORDER BY t1.PersonnelKontrakIDLng DESC
      FOR JSON PATH
    )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END
GO

/* ========== PERSONEL STATUS ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_status_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_status_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_status_getrows
(   @p_keywords varchar(200)=NULL
, @p_from_date varchar(30)=NULL
, @p_to_date varchar(30)=NULL
, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL
, @p_id_store varchar(50)=NULL
, @p_brand varchar(50)=NULL
, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL
, @p_kategori varchar(50)=NULL
, @p_group varchar(50)=NULL
, @p_dept varchar(50)=NULL
, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL
, @p_id_cabang varchar(50)=NULL
, @p_year varchar(10)=NULL
, @p_month varchar(10)=NULL
, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL
, @p_is_pajak varchar(10)=NULL
, @p_id_mesin varchar(50)=NULL
, @p_currentmonth varchar(20)=NULL
, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  SET @bitparam=(
    SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
      SELECT TOP 5000
        t1.PersonnelStatusIDLng AS id,
        t1.PegawaiIDLng AS pegawai_id,
        b.NomorIndukStr AS nik,
        b.NamaLengkapStr AS employee_name,
        t1.NomorStatusStr AS nomor,
        ISNULL(t2.StatusPegawaiStr,' - ') AS status_lama,
        t3.StatusPegawaiStr AS status_baru,
        CONVERT(varchar(10), t1.TanggalEfektifDtd, 23) AS tanggal_efektif
      FROM hris.dbo.tblpersonnelstatus t1 WITH (NOLOCK)
      LEFT JOIN hris.dbo.tblstatuspegawai t2 WITH (NOLOCK) ON t1.SebelumStatusIDLng=t2.StatusPegawaiIDLng
      LEFT JOIN hris.dbo.tblstatuspegawai t3 WITH (NOLOCK) ON t1.SekarangStatusIDLng=t3.StatusPegawaiIDLng
      LEFT JOIN hris.dbo.tblpegawai b WITH (NOLOCK) ON b.PegawaiIDLng=t1.PegawaiIDLng
      WHERE (@kw='' OR CAST(t1.PegawaiIDLng AS varchar(30)) LIKE '%'+@kw+'%'
        OR ISNULL(t1.NomorStatusStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(b.NomorIndukStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(b.NamaLengkapStr,'') LIKE '%'+@kw+'%')
      ORDER BY t1.PersonnelStatusIDLng DESC
      FOR JSON PATH
    )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END
GO

/* ========== PERSONEL PROMOSI ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_promosi_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_promosi_getrows
(   @p_keywords varchar(200)=NULL
, @p_from_date varchar(30)=NULL
, @p_to_date varchar(30)=NULL
, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL
, @p_id_store varchar(50)=NULL
, @p_brand varchar(50)=NULL
, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL
, @p_kategori varchar(50)=NULL
, @p_group varchar(50)=NULL
, @p_dept varchar(50)=NULL
, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL
, @p_id_cabang varchar(50)=NULL
, @p_year varchar(10)=NULL
, @p_month varchar(10)=NULL
, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL
, @p_is_pajak varchar(10)=NULL
, @p_id_mesin varchar(50)=NULL
, @p_currentmonth varchar(20)=NULL
, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  SET @bitparam=(
    SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
      SELECT TOP 5000
        t1.PersonnelPromosiIDLng AS id,
        t1.PegawaiIDLng AS pegawai_id,
        t2.NomorIndukStr AS nik,
        t2.NamaLengkapStr AS employee_name,
        t1.NomorPromosiStr AS nomor,
        t3.JabatanStr AS jabatan_sebelum,
        t5.JabatanStr AS jabatan_sekarang,
        CONVERT(varchar(10), t1.TanggalEfektifDtd, 23) AS tanggal_efektif
      FROM hris.dbo.tblpersonnelpromosi t1 WITH (NOLOCK)
      LEFT JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng=t2.PegawaiIDLng
      LEFT JOIN hris.dbo.tbljabatan t3 WITH (NOLOCK) ON t1.SebelumJabatanIDLng=t3.JabatanIDLng
      LEFT JOIN hris.dbo.tbljabatan t5 WITH (NOLOCK) ON t1.SekarangJabatanIDLng=t5.JabatanIDLng
      WHERE (@kw='' OR CAST(t1.PegawaiIDLng AS varchar(30)) LIKE '%'+@kw+'%'
        OR ISNULL(t2.NamaLengkapStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(t2.NomorIndukStr,'') LIKE '%'+@kw+'%')
      ORDER BY t1.PersonnelPromosiIDLng DESC
      FOR JSON PATH
    )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END
GO

/* ========== PERSONEL MUTASI ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_mutasi_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_mutasi_getrows
(   @p_keywords varchar(200)=NULL
, @p_from_date varchar(30)=NULL
, @p_to_date varchar(30)=NULL
, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL
, @p_id_store varchar(50)=NULL
, @p_brand varchar(50)=NULL
, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL
, @p_kategori varchar(50)=NULL
, @p_group varchar(50)=NULL
, @p_dept varchar(50)=NULL
, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL
, @p_id_cabang varchar(50)=NULL
, @p_year varchar(10)=NULL
, @p_month varchar(10)=NULL
, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL
, @p_is_pajak varchar(10)=NULL
, @p_id_mesin varchar(50)=NULL
, @p_currentmonth varchar(20)=NULL
, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  SET @bitparam=(
    SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
      SELECT TOP 5000
        t1.PersonnelMutasiIDLng AS id,
        t1.PegawaiIDLng AS pegawai_id,
        tp.NomorIndukStr AS nik,
        tp.NamaLengkapStr AS employee_name,
        t1.NomorMutasiStr AS nomor,
        t2.NamaKantorCabangStr AS cabang_sebelum,
        t4.NamaKantorCabangStr AS cabang_sekarang,
        CONVERT(varchar(10), t1.TanggalEfektifDtd, 23) AS tanggal_efektif
      FROM hris.dbo.tblpersonnelmutasi t1 WITH (NOLOCK)
      LEFT JOIN hris.dbo.tblkantorcabang t2 WITH (NOLOCK) ON t1.KantorCabangSebelumIDLng=t2.KantorCabangIDLng
      LEFT JOIN hris.dbo.tblkantorcabang t4 WITH (NOLOCK) ON t1.KantorCabangSekarangIDLng=t4.KantorCabangIDLng
      LEFT JOIN hris.dbo.tblpegawai tp WITH (NOLOCK) ON tp.PegawaiIDLng=t1.PegawaiIDLng
      WHERE (@kw='' OR CAST(t1.PegawaiIDLng AS varchar(30)) LIKE '%'+@kw+'%'
        OR ISNULL(tp.NomorIndukStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(tp.NamaLengkapStr,'') LIKE '%'+@kw+'%')
      ORDER BY t1.PersonnelMutasiIDLng DESC
      FOR JSON PATH
    )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END
GO

/* ========== PERSONEL RESIGN ========== */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_resign_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_resign_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_resign_getrows
(   @p_keywords varchar(200)=NULL
, @p_from_date varchar(30)=NULL
, @p_to_date varchar(30)=NULL
, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL
, @p_id_store varchar(50)=NULL
, @p_brand varchar(50)=NULL
, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL
, @p_kategori varchar(50)=NULL
, @p_group varchar(50)=NULL
, @p_dept varchar(50)=NULL
, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL
, @p_id_cabang varchar(50)=NULL
, @p_year varchar(10)=NULL
, @p_month varchar(10)=NULL
, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL
, @p_is_pajak varchar(10)=NULL
, @p_id_mesin varchar(50)=NULL
, @p_currentmonth varchar(20)=NULL
, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  SET @bitparam=(
    SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
      SELECT TOP 5000
        t1.PersonnelResignHeaderIDLng AS id,
        t2.NomorIndukStr AS nik,
        t2.NamaLengkapStr AS employee_name,
        t5.DepartemenStr AS department,
        CONVERT(varchar(10), t1.TanggalEfektifDtd, 23) AS tgl_resign,
        t7.NamaKantorCabangStr AS cabang
      FROM hris.dbo.tblpersonnelresignheader t1 WITH (NOLOCK)
      LEFT JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng=t2.PegawaiIDLng
      LEFT JOIN hris.dbo.tblpegawaijabatan t3 WITH (NOLOCK) ON t2.PegawaiIDLng=t3.PegawaiIDLng
      LEFT JOIN hris.dbo.tbldepartemen t5 WITH (NOLOCK) ON t3.DepartemenIDLng=t5.DepartemenIDLng
      LEFT JOIN hris.dbo.tblpegawaipenempatan t6 WITH (NOLOCK) ON t2.PegawaiIDLng=t6.PegawaiIDLng
      LEFT JOIN hris.dbo.tblkantorcabang t7 WITH (NOLOCK) ON t6.KantorCabangIDLng=t7.KantorCabangIDLng
      WHERE (@kw='' OR ISNULL(t2.NamaLengkapStr,'') LIKE '%'+@kw+'%' OR ISNULL(t2.NomorIndukStr,'') LIKE '%'+@kw+'%')
      ORDER BY t1.TanggalEfektifDtd DESC
      FOR JSON PATH
    )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END
GO
