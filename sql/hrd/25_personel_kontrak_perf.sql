USE RBACESS;
GO
/* Personel kontrak getrows — tune for list + expiry badges ≤3s.
   - Empty search: recent contracts UNION contracts ending within 2 months (not blind TOP 5000).
   - Numeric keyword: NIK / no.kontrak / pegawai_id prefix (index-friendly).
   - Text keyword: name/dept contains, capped TOP.
   - OUTER APPLY latest pegawaijabatan (safe if 1:N later). */
SET NOCOUNT ON;
GO

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
, @p_pegawai_id varchar(50)=NULL
, @bitparam varchar(max) OUTPUT )
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    DECLARE @kw varchar(200) = LTRIM(RTRIM(ISNULL(@p_keywords, '')));
    DECLARE @pid int = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_pegawai_id, ''))), '') AS int);
    DECLARE @kwIsNum bit = CASE
      WHEN @kw <> '' AND PATINDEX('%[^0-9]%', @kw) = 0 THEN 1 ELSE 0 END;
    DECLARE @today date = CAST(GETDATE() AS date);
    DECLARE @until date = DATEADD(month, 2, @today);

    IF OBJECT_ID('tempdb..#kontrak_ids') IS NOT NULL DROP TABLE #kontrak_ids;
    CREATE TABLE #kontrak_ids (id int NOT NULL PRIMARY KEY);

    IF @pid IS NOT NULL
    BEGIN
      INSERT INTO #kontrak_ids (id)
      SELECT t1.PersonnelKontrakIDLng
      FROM hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
      WHERE t1.PegawaiIDLng = @pid;
    END
    ELSE IF @kw = ''
    BEGIN
      /* Recent list for paging + all contracts ending in next 2 months for badges. */
      INSERT INTO #kontrak_ids (id)
      SELECT id FROM (
        SELECT TOP (1500) t1.PersonnelKontrakIDLng AS id
        FROM hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
        ORDER BY t1.PersonnelKontrakIDLng DESC
      ) r
      UNION
      SELECT t1.PersonnelKontrakIDLng
      FROM hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
      WHERE t1.TanggalBerakhirDtd IS NOT NULL
        AND t1.TanggalBerakhirDtd >= @today
        AND t1.TanggalBerakhirDtd < @until;
    END
    ELSE IF @kwIsNum = 1
    BEGIN
      INSERT INTO #kontrak_ids (id)
      SELECT TOP (500) t1.PersonnelKontrakIDLng
      FROM hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
      LEFT JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng = t2.PegawaiIDLng
      WHERE t2.NomorIndukStr LIKE @kw + '%'
         OR t1.NomorKontrakStr LIKE @kw + '%'
         OR CAST(t1.PegawaiIDLng AS varchar(30)) = @kw
         OR CAST(t1.PersonnelKontrakIDLng AS varchar(30)) = @kw
      ORDER BY t1.PersonnelKontrakIDLng DESC;
    END
    ELSE
    BEGIN
      INSERT INTO #kontrak_ids (id)
      SELECT TOP (500) t1.PersonnelKontrakIDLng
      FROM hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
      LEFT JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng = t2.PegawaiIDLng
      OUTER APPLY (
        SELECT TOP (1) pj.DepartemenIDLng, pj.JabatanIDLng, pj.PangkatIDLng, pj.StatusPegawaiIDLng
        FROM hris.dbo.tblpegawaijabatan pj WITH (NOLOCK)
        WHERE pj.PegawaiIDLng = t1.PegawaiIDLng
        ORDER BY pj.PegawaiJabatanIDLng DESC
      ) pj
      LEFT JOIN hris.dbo.tbldepartemen dept WITH (NOLOCK) ON t1.DepartemenIDLng = dept.DepartemenIDLng
      LEFT JOIN hris.dbo.tbldepartemen deptNow WITH (NOLOCK) ON pj.DepartemenIDLng = deptNow.DepartemenIDLng
      LEFT JOIN hris.dbo.tbljabatan jab WITH (NOLOCK) ON t1.JabatanIDLng = jab.JabatanIDLng
      LEFT JOIN hris.dbo.tbljabatan jabNow WITH (NOLOCK) ON pj.JabatanIDLng = jabNow.JabatanIDLng
      LEFT JOIN hris.dbo.tblstatuspegawai st WITH (NOLOCK) ON pj.StatusPegawaiIDLng = st.StatusPegawaiIDLng
      WHERE t2.NamaLengkapStr LIKE '%' + @kw + '%'
         OR t1.NomorKontrakStr LIKE '%' + @kw + '%'
         OR ISNULL(dept.DepartemenStr, '') LIKE '%' + @kw + '%'
         OR ISNULL(deptNow.DepartemenStr, '') LIKE '%' + @kw + '%'
         OR ISNULL(jab.JabatanStr, '') LIKE '%' + @kw + '%'
         OR ISNULL(jabNow.JabatanStr, '') LIKE '%' + @kw + '%'
         OR ISNULL(st.StatusPegawaiStr, '') LIKE '%' + @kw + '%'
      ORDER BY t1.PersonnelKontrakIDLng DESC;
    END

    SET @bitparam = (
      SELECT '2002500' responseCode, 'success' responseMessage,
        JSON_QUERY((
          SELECT
              t1.PersonnelKontrakIDLng AS id
            , t1.PegawaiIDLng AS pegawai_id
            , t2.NomorIndukStr AS nik
            , t2.NamaLengkapStr AS employee_name
            , t1.NomorKontrakStr AS no_kontrak
            , CONVERT(varchar(10), t1.TanggalKontrakDtd, 23) AS tanggal_surat
            , CONVERT(varchar(10), t1.TanggalBerakhirKontrakSebelumnyaDtd, 23) AS tanggal_berakhir_sebelumnya
            , CONVERT(varchar(10), t1.TanggalEfektifDtd, 23) AS tgl_mulai
            , CONVERT(varchar(10), t1.TanggalBerakhirDtd, 23) AS tanggal_berakhir
            , t1.LamaBulanInt AS lama_bulan
            , t1.LamaBulanTerbilangStr AS terbilang
            , COALESCE(NULLIF(t1.DepartemenIDLng, 0), pj.DepartemenIDLng) AS department
            , COALESCE(
                NULLIF(LTRIM(RTRIM(dept.DepartemenStr)), ''),
                NULLIF(LTRIM(RTRIM(deptNow.DepartemenStr)), ''),
                ''
              ) AS department_name
            , t1.DepartemenBagianIDLng AS unit
            , COALESCE(NULLIF(t1.PangkatIDLng, 0), pj.PangkatIDLng) AS pangkat
            , COALESCE(
                NULLIF(LTRIM(RTRIM(png.PangkatStr)), ''),
                NULLIF(LTRIM(RTRIM(pngNow.PangkatStr)), ''),
                ''
              ) AS pangkat_name
            , COALESCE(NULLIF(t1.JabatanIDLng, 0), pj.JabatanIDLng) AS jabatan
            , COALESCE(
                NULLIF(LTRIM(RTRIM(jab.JabatanStr)), ''),
                NULLIF(LTRIM(RTRIM(jabNow.JabatanStr)), ''),
                ''
              ) AS jabatan_name
            , t1.GolonganIDLng AS golongan
            , t1.GolonganTingkatanIDLng AS tingkat
            , t1.KantorCabangIDLng AS penempatan
            , t1.HonorPerBulanMon AS ump
            , ISNULL(NULLIF(LTRIM(RTRIM(st.StatusPegawaiStr)), ''), '') AS status_pegawai
            , t2.PegawaiNonAktifInt AS pegawai_non_aktif
            , CASE WHEN t2.PegawaiNonAktifInt = 0 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS is_active
          FROM #kontrak_ids ids
          INNER JOIN hris.dbo.tblpersonnelkontrak t1 WITH (NOLOCK)
            ON t1.PersonnelKontrakIDLng = ids.id
          LEFT JOIN hris.dbo.tblpegawai t2 WITH (NOLOCK) ON t1.PegawaiIDLng = t2.PegawaiIDLng
          LEFT JOIN hris.dbo.tbldepartemen dept WITH (NOLOCK) ON t1.DepartemenIDLng = dept.DepartemenIDLng
          LEFT JOIN hris.dbo.tbljabatan jab WITH (NOLOCK) ON t1.JabatanIDLng = jab.JabatanIDLng
          LEFT JOIN hris.dbo.tblpangkat png WITH (NOLOCK) ON t1.PangkatIDLng = png.PangkatIDLng
          OUTER APPLY (
            SELECT TOP (1)
                pj.DepartemenIDLng, pj.JabatanIDLng, pj.PangkatIDLng, pj.StatusPegawaiIDLng
            FROM hris.dbo.tblpegawaijabatan pj WITH (NOLOCK)
            WHERE pj.PegawaiIDLng = t1.PegawaiIDLng
            ORDER BY pj.PegawaiJabatanIDLng DESC
          ) pj
          LEFT JOIN hris.dbo.tblstatuspegawai st WITH (NOLOCK) ON pj.StatusPegawaiIDLng = st.StatusPegawaiIDLng
          LEFT JOIN hris.dbo.tbldepartemen deptNow WITH (NOLOCK) ON pj.DepartemenIDLng = deptNow.DepartemenIDLng
          LEFT JOIN hris.dbo.tbljabatan jabNow WITH (NOLOCK) ON pj.JabatanIDLng = jabNow.JabatanIDLng
          LEFT JOIN hris.dbo.tblpangkat pngNow WITH (NOLOCK) ON pj.PangkatIDLng = pngNow.PangkatIDLng
          ORDER BY t1.PersonnelKontrakIDLng DESC
          FOR JSON PATH
        )) data
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
  END TRY
  BEGIN CATCH
    SET @bitparam = (
      SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
  END CATCH
END
GO
