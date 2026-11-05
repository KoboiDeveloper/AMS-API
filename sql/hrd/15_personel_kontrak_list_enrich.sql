USE RBACESS;
GO

/* Enrich personel-kontrak list: dept/jabatan/pangkat names + status pegawai.
   Needed for FE expiry badges (2 months, exclude Tetap, group by dept). */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_kontrak_getrows', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_kontrak_getrows;
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
        /* Prefer ID di kontrak; FE form tetap pakai ini. */
        COALESCE(NULLIF(t1.DepartemenIDLng, 0), pj.DepartemenIDLng) AS department,
        /* Nama: kontrak → fallback jabatan pegawai saat ini (banyak kontrak tanpa DepartemenID). */
        COALESCE(
          NULLIF(LTRIM(RTRIM(dept.DepartemenStr)), ''),
          NULLIF(LTRIM(RTRIM(deptNow.DepartemenStr)), ''),
          ''
        ) AS department_name,
        t1.DepartemenBagianIDLng AS unit,
        COALESCE(NULLIF(t1.PangkatIDLng, 0), pj.PangkatIDLng) AS pangkat,
        COALESCE(
          NULLIF(LTRIM(RTRIM(png.PangkatStr)), ''),
          NULLIF(LTRIM(RTRIM(pngNow.PangkatStr)), ''),
          ''
        ) AS pangkat_name,
        COALESCE(NULLIF(t1.JabatanIDLng, 0), pj.JabatanIDLng) AS jabatan,
        COALESCE(
          NULLIF(LTRIM(RTRIM(jab.JabatanStr)), ''),
          NULLIF(LTRIM(RTRIM(jabNow.JabatanStr)), ''),
          ''
        ) AS jabatan_name,
        t1.GolonganIDLng AS golongan,
        t1.GolonganTingkatanIDLng AS tingkat,
        t1.KantorCabangIDLng AS penempatan,
        t1.HonorPerBulanMon AS ump,
        ISNULL(NULLIF(LTRIM(RTRIM(st.StatusPegawaiStr)), ''), '') AS status_pegawai,
        t2.PegawaiNonAktifInt AS pegawai_non_aktif,
        CASE WHEN t2.PegawaiNonAktifInt=0 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS is_active
      FROM hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
      LEFT JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng=t2.PegawaiIDLng
      LEFT JOIN hris.dbo.tbldepartemen dept WITH (NOLOCK) ON t1.DepartemenIDLng=dept.DepartemenIDLng
      LEFT JOIN hris.dbo.tbljabatan jab WITH (NOLOCK) ON t1.JabatanIDLng=jab.JabatanIDLng
      LEFT JOIN hris.dbo.tblpangkat png WITH (NOLOCK) ON t1.PangkatIDLng=png.PangkatIDLng
      LEFT JOIN hris.dbo.tblpegawaijabatan pj WITH (NOLOCK) ON t1.PegawaiIDLng=pj.PegawaiIDLng
      LEFT JOIN hris.dbo.tblstatuspegawai st WITH (NOLOCK) ON pj.StatusPegawaiIDLng=st.StatusPegawaiIDLng
      LEFT JOIN hris.dbo.tbldepartemen deptNow WITH (NOLOCK) ON pj.DepartemenIDLng=deptNow.DepartemenIDLng
      LEFT JOIN hris.dbo.tbljabatan jabNow WITH (NOLOCK) ON pj.JabatanIDLng=jabNow.JabatanIDLng
      LEFT JOIN hris.dbo.tblpangkat pngNow WITH (NOLOCK) ON pj.PangkatIDLng=pngNow.PangkatIDLng
      WHERE (@kw='' OR CAST(t1.PegawaiIDLng AS varchar(30)) LIKE '%'+@kw+'%'
        OR ISNULL(t2.NamaLengkapStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(t2.NomorIndukStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(t1.NomorKontrakStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(dept.DepartemenStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(deptNow.DepartemenStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(jab.JabatanStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(jabNow.JabatanStr,'') LIKE '%'+@kw+'%'
        OR ISNULL(st.StatusPegawaiStr,'') LIKE '%'+@kw+'%')
      ORDER BY t1.PersonnelKontrakIDLng DESC
      FOR JSON PATH
    )) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH END
GO
