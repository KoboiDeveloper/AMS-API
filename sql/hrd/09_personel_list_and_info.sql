USE RBACESS;
GO

/* Fix list = legacy xsp_personal_list_getrows */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows
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
  DECLARE @st varchar(50)=UPPER(LTRIM(RTRIM(ISNULL(@p_status,''))));
  IF @st='' AND @p_is_active IN ('1','true','TRUE') SET @st='ACTIVE';
  IF @st='' AND @p_is_active IN ('0','false','FALSE') SET @st='NON ACTIVE';
  IF @st='' SET @st='ACTIVE';

  /* Match legacy POS_SERVER.dbo.xsp_personal_list_getrows (order by PegawaiIDLng). */
  SET @bitparam=(
    SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
      SELECT TOP 5000
        t1.PegawaiIDLng AS id,
        t8.BrandStr AS brand,
        t7.NamaKantorCabangStr AS branch_name,
        t1.NomorIndukStr AS nik,
        t1.NamaLengkapStr AS employee_name,
        t10.PangkatStr AS pangkat,
        t3.JabatanStr AS job_title,
        t4.DepartemenStr AS department,
        t5.StatusPegawaiStr AS status,
        t1.PegawaiNonAktifInt AS pegawai_non_aktif,
        CASE WHEN t1.PegawaiNonAktifInt=0 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS is_active
      FROM hris.dbo.tblpegawai t1 WITH (NOLOCK)
      LEFT JOIN hris.dbo.tblpegawaijabatan t2 WITH (NOLOCK) ON t1.PegawaiIDLng=t2.PegawaiIDLng
      LEFT JOIN hris.dbo.tbljabatan t3 WITH (NOLOCK) ON t2.JabatanIDLng=t3.JabatanIDLng
      LEFT JOIN hris.dbo.tbldepartemen t4 WITH (NOLOCK) ON t2.DepartemenIDLng=t4.DepartemenIDLng
      LEFT JOIN hris.dbo.tblstatuspegawai t5 WITH (NOLOCK) ON t2.StatusPegawaiIDLng=t5.StatusPegawaiIDLng
      LEFT JOIN hris.dbo.tblpegawaipenempatan t6 WITH (NOLOCK) ON t1.PegawaiIDLng=t6.PegawaiIDLng
      LEFT JOIN hris.dbo.tblkantorcabang t7 WITH (NOLOCK) ON t6.KantorCabangIDLng=t7.KantorCabangIDLng
      LEFT JOIN hris.dbo.tblfixbrand t8 WITH (NOLOCK) ON t7.BrandIDLng=t8.BrandIDLng
      LEFT JOIN hris.dbo.tblpegawaibank t9 WITH (NOLOCK) ON t1.PegawaiIDLng=t9.PegawaiIDLng
      LEFT JOIN hris.dbo.tblpangkat t10 WITH (NOLOCK) ON t2.PangkatIDLng=t10.PangkatIDLng
      WHERE (
          CASE WHEN @st='ACTIVE' THEN '0' WHEN @st='NON ACTIVE' THEN '1' ELSE CAST(t1.PegawaiNonAktifInt AS varchar(10)) END
        ) = CAST(t1.PegawaiNonAktifInt AS varchar(10))
        AND (
          ISNULL(t8.BrandStr,'') LIKE '%'+@kw+'%'
          OR ISNULL(t7.NamaKantorCabangStr,'') LIKE '%'+@kw+'%'
          OR ISNULL(t1.NomorIndukStr,'') LIKE '%'+@kw+'%'
          OR ISNULL(t1.NamaLengkapStr,'') LIKE '%'+@kw+'%'
          OR ISNULL(t10.PangkatStr,'') LIKE '%'+@kw+'%'
          OR ISNULL(t3.JabatanStr,'') LIKE '%'+@kw+'%'
          OR ISNULL(t4.DepartemenStr,'') LIKE '%'+@kw+'%'
          OR ISNULL(t5.StatusPegawaiStr,'') LIKE '%'+@kw+'%'
          OR ISNULL(t9.NomorRekeningStr,'') LIKE '%'+@kw+'%'
        )
      ORDER BY t1.PegawaiIDLng
      FOR JSON PATH
    )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END
GO

/* Detail identitas = legacy personel_identitas_getrow */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_getrow
(
  @p_id varchar(50),
  @bitparam varchar(max) OUTPUT
)
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @pid int = TRY_CAST(@p_id AS int);
  SET @bitparam=(
    SELECT '2002500' responseCode,'success' responseMessage, JSON_QUERY((
      SELECT TOP 1
        t1.PegawaiIDLng AS id,
        t1.NomorIndukStr AS nik,
        t1.NamaLengkapStr AS employee_name,
        t1.NamaPanggilanStr AS nama_panggilan,
        t1.TempatLahirIDLng AS tempat_lahir_id,
        CONVERT(varchar(10), t1.TanggalLahirDtd, 23) AS tanggal_lahir,
        t1.JenisKelaminIDLng AS jenis_kelamin_id,
        t1.AgamaIDLng AS agama_id,
        t1.KebangsaanIDLng AS warga_negara_id,
        t1.NomorKTPStr AS no_ktp,
        CONVERT(varchar(10), t1.KTPBerlakuHinggaDtd, 23) AS masa_berlaku_ktp,
        t1.RangkumanStr AS rangkuman,
        CONVERT(varchar(10), t1.TanggalMulaiAktifDtd, 23) AS active_date,
        CONVERT(varchar(10), rs.TanggalEfektifDtd, 23) AS resign_date,
        t1.LokasiAbsensiIDLng AS lokasi_absen_id,
        t2.LokasiAbsensiStr AS lokasi_absen,
        t1.PegawaiNonAktifInt AS status_aktif,
        CASE WHEN t1.PegawaiNonAktifInt=0 THEN 'Aktif' ELSE 'Nonaktif' END AS status_aktif_label,
        t1.UserNameStr AS updated_by,
        CONVERT(varchar(19), t1.LastUpdateDtd, 120) AS last_update,
        j.JabatanStr AS jabatan,
        d.DepartemenStr AS department,
        dv.DivisiStr AS divisi,
        sp.StatusPegawaiStr AS status_pegawai,
        kc.NamaKantorCabangStr AS branch_name,
        fb.BrandStr AS brand
      FROM hris.dbo.tblpegawai t1 WITH (NOLOCK)
      LEFT JOIN hris.dbo.tbllokasiabsensi t2 WITH (NOLOCK) ON t2.LokasiAbsensiIDLng=t1.LokasiAbsensiIDLng
      LEFT JOIN hris.dbo.tblpersonnelresignheader rs WITH (NOLOCK) ON rs.PegawaiIDLng=t1.PegawaiIDLng
      LEFT JOIN hris.dbo.tblpegawaijabatan pj WITH (NOLOCK) ON pj.PegawaiIDLng=t1.PegawaiIDLng
      LEFT JOIN hris.dbo.tbljabatan j WITH (NOLOCK) ON j.JabatanIDLng=pj.JabatanIDLng
      LEFT JOIN hris.dbo.tbldepartemen d WITH (NOLOCK) ON d.DepartemenIDLng=pj.DepartemenIDLng
      LEFT JOIN hris.dbo.tbldivisi dv WITH (NOLOCK) ON dv.DivisiIDLng=d.DivisiIDLng
      LEFT JOIN hris.dbo.tblstatuspegawai sp WITH (NOLOCK) ON sp.StatusPegawaiIDLng=pj.StatusPegawaiIDLng
      LEFT JOIN hris.dbo.tblpegawaipenempatan pp WITH (NOLOCK) ON pp.PegawaiIDLng=t1.PegawaiIDLng
      LEFT JOIN hris.dbo.tblkantorcabang kc WITH (NOLOCK) ON kc.KantorCabangIDLng=pp.KantorCabangIDLng
      LEFT JOIN hris.dbo.tblfixbrand fb WITH (NOLOCK) ON fb.BrandIDLng=kc.BrandIDLng
      WHERE t1.PegawaiIDLng=@pid
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END
GO

/* Extend lookup types used by employeeinfo */
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
      SET @rows=(SELECT CAST(x.idbrand AS varchar(50)) AS value, x.description AS label FROM (
          SELECT CAST('DS' AS varchar(20)) AS idbrand, CAST('Discount Store' AS varchar(100)) AS description
          UNION ALL SELECT CAST(IDBrand AS varchar(20)), CAST(Description AS varchar(100)) FROM ACCT.dbo.GL_Brand WHERE AktifGL='1'
        ) x WHERE (@kw='' OR x.description LIKE '%'+@kw+'%' OR x.idbrand LIKE '%'+@kw+'%') ORDER BY x.idbrand FOR JSON PATH);
    ELSE IF @t IN ('store','id_store')
      SET @rows=(SELECT CAST(s.Store_ID AS varchar(50)) AS value, CAST(ISNULL(NULLIF(LTRIM(RTRIM(s.Store_Name)),''), s.Store_ID) AS varchar(200)) AS label
        FROM POS_SERVER.dbo.DT_Store s WITH (NOLOCK)
        WHERE ISNULL(s.Status_Active,1)=1 AND (@pid='' OR s.Store_Brand_ID=@pid OR s.Brand_ACCT=@pid OR s.Store_Brand_ID_2=@pid)
          AND (@kw='' OR s.Store_ID LIKE '%'+@kw+'%' OR ISNULL(s.Store_Name,'') LIKE '%'+@kw+'%')
        ORDER BY s.Store_Name FOR JSON PATH);
    ELSE IF @t IN ('cabang','penempatan','id_cabang')
      SET @rows=(SELECT CAST(KantorCabangIDLng AS varchar(50)) AS value, CAST(NamaKantorCabangStr AS varchar(200)) AS label
        FROM hris.dbo.tblkantorcabang WITH (NOLOCK) WHERE (@kw='' OR NamaKantorCabangStr LIKE '%'+@kw+'%') ORDER BY NamaKantorCabangStr FOR JSON PATH);
    ELSE IF @t IN ('department','dept','departemen')
      SET @rows=(SELECT CAST(DepartemenIDLng AS varchar(50)) AS value, CAST(DepartemenStr AS varchar(200)) AS label
        FROM hris.dbo.tbldepartemen WITH (NOLOCK) WHERE (@kw='' OR DepartemenStr LIKE '%'+@kw+'%') ORDER BY DepartemenStr FOR JSON PATH);
    ELSE IF @t IN ('unit','bagian')
      SET @rows=(SELECT CAST(DepartemenBagianIDLng AS varchar(50)) AS value,
               CAST(ISNULL(NULLIF(DepartemenBagianStr,''), KodeDepartemenBagianStr) AS varchar(200)) AS label
        FROM hris.dbo.tbldepartemenbagian WITH (NOLOCK)
        WHERE (@pid='' OR CAST(DepartemenIDLng AS varchar(50))=@pid)
          AND (@kw='' OR ISNULL(DepartemenBagianStr,'') LIKE '%'+@kw+'%' OR ISNULL(KodeDepartemenBagianStr,'') LIKE '%'+@kw+'%')
        ORDER BY DepartemenBagianStr FOR JSON PATH);
    ELSE IF @t='pangkat'
      SET @rows=(SELECT CAST(PangkatIDLng AS varchar(50)) AS value, CAST(PangkatStr AS varchar(200)) AS label FROM hris.dbo.tblpangkat WITH (NOLOCK) WHERE (@kw='' OR PangkatStr LIKE '%'+@kw+'%') ORDER BY PangkatStr FOR JSON PATH);
    ELSE IF @t='jabatan'
      SET @rows=(SELECT CAST(JabatanIDLng AS varchar(50)) AS value, CAST(JabatanStr AS varchar(200)) AS label FROM hris.dbo.tbljabatan WITH (NOLOCK) WHERE (@kw='' OR JabatanStr LIKE '%'+@kw+'%') ORDER BY JabatanStr FOR JSON PATH);
    ELSE IF @t IN ('golongan','level')
      SET @rows=(SELECT CAST(GolonganIDLng AS varchar(50)) AS value, CAST(GolonganStr AS varchar(200)) AS label FROM hris.dbo.tblgolongan WITH (NOLOCK) WHERE (@kw='' OR GolonganStr LIKE '%'+@kw+'%') ORDER BY GolonganStr FOR JSON PATH);
    ELSE IF @t='tingkat'
      SET @rows=(SELECT CAST(GolonganTingkatanIDLng AS varchar(50)) AS value, CAST(GolonganTingkatanStr AS varchar(200)) AS label
        FROM hris.dbo.tblgolongantingkatan WITH (NOLOCK) WHERE (@pid='' OR CAST(GolonganIDLng AS varchar(50))=@pid) AND (@kw='' OR GolonganTingkatanStr LIKE '%'+@kw+'%') ORDER BY GolonganTingkatanStr FOR JSON PATH);
    ELSE IF @t IN ('status_pegawai','status')
      SET @rows=(SELECT CAST(StatusPegawaiIDLng AS varchar(50)) AS value, CAST(StatusPegawaiStr AS varchar(200)) AS label FROM hris.dbo.tblstatuspegawai WITH (NOLOCK) WHERE (@kw='' OR StatusPegawaiStr LIKE '%'+@kw+'%') ORDER BY StatusPegawaiStr FOR JSON PATH);
    ELSE IF @t IN ('group','group_pegawai')
      SET @rows=(SELECT CAST(GroupPegawaiIDLng AS varchar(50)) AS value, CAST(GroupPegawaiStr AS varchar(200)) AS label FROM hris.dbo.tblkelompokpegawai WITH (NOLOCK) WHERE (@kw='' OR GroupPegawaiStr LIKE '%'+@kw+'%') ORDER BY GroupPegawaiStr FOR JSON PATH);
    ELSE IF @t IN ('alasan_resign','tipe_resign')
      SET @rows=(SELECT CAST(AlasanResignIDLng AS varchar(50)) AS value, CAST(AlasanResignStr AS varchar(200)) AS label FROM hris.dbo.tblalasanresign WITH (NOLOCK) WHERE (@kw='' OR AlasanResignStr LIKE '%'+@kw+'%') ORDER BY AlasanResignStr FOR JSON PATH);
    ELSE IF @t='divisi'
      SET @rows=(SELECT CAST(DivisiIDLng AS varchar(50)) AS value, CAST(DivisiStr AS varchar(200)) AS label FROM hris.dbo.tbldivisi WITH (NOLOCK) WHERE (@kw='' OR DivisiStr LIKE '%'+@kw+'%') ORDER BY DivisiStr FOR JSON PATH);
    ELSE IF @t='kota'
      SET @rows=(SELECT CAST(KotaIDLng AS varchar(50)) AS value, CAST(KotaStr AS varchar(200)) AS label FROM hris.dbo.tblkota WITH (NOLOCK) WHERE (@kw='' OR KotaStr LIKE '%'+@kw+'%') ORDER BY KotaStr FOR JSON PATH);
    ELSE IF @t='provinsi'
      SET @rows=(SELECT CAST(ProvinsiIDLng AS varchar(50)) AS value, CAST(ProvinsiStr AS varchar(200)) AS label FROM hris.dbo.tblprovinsi WITH (NOLOCK) WHERE (@kw='' OR ProvinsiStr LIKE '%'+@kw+'%') ORDER BY ProvinsiStr FOR JSON PATH);
    ELSE IF @t IN ('negara','warga_negara','kebangsaan')
      SET @rows=(SELECT CAST(NegaraIDLng AS varchar(50)) AS value, CAST(NegaraStr AS varchar(200)) AS label FROM hris.dbo.tblnegara WITH (NOLOCK) WHERE (@kw='' OR NegaraStr LIKE '%'+@kw+'%') ORDER BY NegaraStr FOR JSON PATH);
    ELSE IF @t='agama'
      SET @rows=(SELECT CAST(AgamaIDLng AS varchar(50)) AS value, CAST(AgamaStr AS varchar(200)) AS label FROM hris.dbo.tblagama WITH (NOLOCK) WHERE (@kw='' OR AgamaStr LIKE '%'+@kw+'%') ORDER BY AgamaStr FOR JSON PATH);
    ELSE IF @t IN ('jenis_kelamin','kelamin')
      SET @rows=(SELECT CAST(JenisKelaminIDLng AS varchar(50)) AS value, CAST(JenisKelaminStr AS varchar(200)) AS label FROM hris.dbo.tbljeniskelamin WITH (NOLOCK) ORDER BY JenisKelaminIDLng FOR JSON PATH);
    ELSE IF @t IN ('lokasi_absen','lokasi')
      SET @rows=(SELECT CAST(LokasiAbsensiIDLng AS varchar(50)) AS value, CAST(LokasiAbsensiStr AS varchar(200)) AS label FROM hris.dbo.tbllokasiabsensi WITH (NOLOCK) WHERE (@kw='' OR LokasiAbsensiStr LIKE '%'+@kw+'%') ORDER BY LokasiAbsensiStr FOR JSON PATH);
    ELSE IF @t IN ('status_aktif','status_active')
      SET @rows=(SELECT * FROM (SELECT '0' AS value, 'Aktif' AS label UNION ALL SELECT '1', 'Nonaktif') x FOR JSON PATH);
    ELSE
    BEGIN
      SET @bitparam=(SELECT '4002500' responseCode, N'Unknown lookup type: '+ISNULL(@p_type,'') responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
      RETURN;
    END

    SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END TRY
  BEGIN CATCH
    SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END CATCH
END
GO
