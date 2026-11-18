/* HRD Master lists — live HRIS data (ASP m_*.aspx / lookup_*_info) */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* shared signature helper note: matches hrdListParamKeys */
DECLARE @noop int;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rows nvarchar(max);
  SELECT @rows=(
    SELECT TOP 1
        CAST(p.PerusahaanIDLng AS varchar(50)) AS id
      , p.NamaPerusahaanStr AS nama_perusahaan
      , p.AlamatPerusahaan1Str AS alamat_1
      , p.AlamatPerusahaan2Str AS alamat_2
      , p.AlamatPerusahaan3Str AS alamat_3
      , CAST(p.KotaIDLng AS varchar(50)) AS kota_id
      , k.KotaStr AS kota
      , CAST(p.KodePosLng AS varchar(50)) AS kode_pos
      , CAST(p.ProvinsiIDLng AS varchar(50)) AS provinsi_id
      , CAST(p.NegaraIDLng AS varchar(50)) AS negara_id
      , p.BidangUsahaStr AS bidang_usaha
      , CAST(p.NomorTeleponKodeLng AS varchar(50)) AS telepon_kode
      , CAST(p.NomorTelepon1Lng AS varchar(50)) AS telepon_1
      , CAST(p.NomorTelepon2Lng AS varchar(50)) AS telepon_2
      , CAST(p.FaxKodeLng AS varchar(50)) AS fax_kode
      , CAST(p.FaxNomorLng AS varchar(50)) AS fax_nomor
      , p.WebsiteStr AS website
      , p.EmailStr AS email
      , p.PimpinanPerusahaanStr AS pimpinan
      , p.NPWPStr AS npwp
      , p.NomorPKPStr AS nomor_pkp
      , CONVERT(varchar(10), p.TanggalPKPDtd, 23) AS tanggal_pkp
    FROM hris.dbo.tblperusahaan p WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblkota k WITH (NOLOCK) ON k.KotaIDLng=p.KotaIDLng
    ORDER BY p.PerusahaanIDLng
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_getrow
( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @row nvarchar(max);
  SELECT TOP 1 @row=(
    SELECT
        CAST(p.PerusahaanIDLng AS varchar(50)) AS id
      , p.NamaPerusahaanStr AS nama_perusahaan
      , p.AlamatPerusahaan1Str AS alamat_1
      , p.AlamatPerusahaan2Str AS alamat_2
      , p.AlamatPerusahaan3Str AS alamat_3
      , CAST(p.KotaIDLng AS varchar(50)) AS kota_id
      , k.KotaStr AS kota
      , CAST(p.KodePosLng AS varchar(50)) AS kode_pos
      , CAST(p.ProvinsiIDLng AS varchar(50)) AS provinsi_id
      , CAST(p.NegaraIDLng AS varchar(50)) AS negara_id
      , p.BidangUsahaStr AS bidang_usaha
      , CAST(p.NomorTeleponKodeLng AS varchar(50)) AS telepon_kode
      , CAST(p.NomorTelepon1Lng AS varchar(50)) AS telepon_1
      , CAST(p.NomorTelepon2Lng AS varchar(50)) AS telepon_2
      , CAST(p.FaxKodeLng AS varchar(50)) AS fax_kode
      , CAST(p.FaxNomorLng AS varchar(50)) AS fax_nomor
      , p.WebsiteStr AS website
      , p.EmailStr AS email
      , p.PimpinanPerusahaanStr AS pimpinan
      , p.NPWPStr AS npwp
      , p.NomorPKPStr AS nomor_pkp
      , CONVERT(varchar(10), p.TanggalPKPDtd, 23) AS tanggal_pkp
    FROM hris.dbo.tblperusahaan p WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblkota k WITH (NOLOCK) ON k.KotaIDLng=p.KotaIDLng
    WHERE (@p_id IS NULL OR @p_id='' OR CAST(p.PerusahaanIDLng AS varchar(50))=@p_id)
    ORDER BY p.PerusahaanIDLng
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@row,'{}')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_perusahaan_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_perusahaan_update
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @j nvarchar(max)=@p_payload;
  DECLARE @id int = TRY_CONVERT(int, NULLIF(@p_id,''));
  IF @id IS NULL SELECT TOP 1 @id = PerusahaanIDLng FROM hris.dbo.tblperusahaan WITH (NOLOCK) ORDER BY PerusahaanIDLng;
  UPDATE hris.dbo.tblperusahaan SET
      NamaPerusahaanStr = COALESCE(JSON_VALUE(@j,'$.nama_perusahaan'), NamaPerusahaanStr)
    , AlamatPerusahaan1Str = COALESCE(JSON_VALUE(@j,'$.alamat_1'), AlamatPerusahaan1Str)
    , AlamatPerusahaan2Str = COALESCE(JSON_VALUE(@j,'$.alamat_2'), AlamatPerusahaan2Str)
    , AlamatPerusahaan3Str = COALESCE(JSON_VALUE(@j,'$.alamat_3'), AlamatPerusahaan3Str)
    , KotaIDLng = COALESCE(TRY_CONVERT(int, JSON_VALUE(@j,'$.kota_id')), KotaIDLng)
    , KodePosLng = COALESCE(TRY_CONVERT(int, JSON_VALUE(@j,'$.kode_pos')), KodePosLng)
    , ProvinsiIDLng = COALESCE(TRY_CONVERT(int, JSON_VALUE(@j,'$.provinsi_id')), ProvinsiIDLng)
    , NegaraIDLng = COALESCE(TRY_CONVERT(int, JSON_VALUE(@j,'$.negara_id')), NegaraIDLng)
    , BidangUsahaStr = COALESCE(JSON_VALUE(@j,'$.bidang_usaha'), BidangUsahaStr)
    , NomorTeleponKodeLng = COALESCE(TRY_CONVERT(int, JSON_VALUE(@j,'$.telepon_kode')), NomorTeleponKodeLng)
    , NomorTelepon1Lng = COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@j,'$.telepon_1')), NomorTelepon1Lng)
    , NomorTelepon2Lng = COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@j,'$.telepon_2')), NomorTelepon2Lng)
    , FaxKodeLng = COALESCE(TRY_CONVERT(int, JSON_VALUE(@j,'$.fax_kode')), FaxKodeLng)
    , FaxNomorLng = COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@j,'$.fax_nomor')), FaxNomorLng)
    , WebsiteStr = COALESCE(JSON_VALUE(@j,'$.website'), WebsiteStr)
    , EmailStr = COALESCE(JSON_VALUE(@j,'$.email'), EmailStr)
    , PimpinanPerusahaanStr = COALESCE(JSON_VALUE(@j,'$.pimpinan'), PimpinanPerusahaanStr)
    , NPWPStr = COALESCE(JSON_VALUE(@j,'$.npwp'), NPWPStr)
    , NomorPKPStr = COALESCE(JSON_VALUE(@j,'$.nomor_pkp'), NomorPKPStr)
    , TanggalPKPDtd = COALESCE(TRY_CONVERT(datetime, JSON_VALUE(@j,'$.tanggal_pkp')), TanggalPKPDtd)
    , UserNameStr = COALESCE(NULLIF(@p_updated_by,''), NULLIF(@p_actor_nik,''), UserNameStr)
    , LastUpdateDtd = GETDATE()
  WHERE PerusahaanIDLng=@id;
  SET @bitparam=(SELECT '2002500' responseCode, N'SUKSES' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '5002500' responseCode, LEFT(ERROR_MESSAGE(),400) responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_cabang_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_cabang_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows=(
    SELECT
        CAST(c.KantorCabangIDLng AS varchar(50)) AS id
      , CAST(c.BrandIDLng AS varchar(50)) AS brand_id
      , ISNULL(b.BrandStr, CAST(c.BrandIDLng AS varchar(50))) AS brand
      , c.KodeKantorCabangStr AS kode
      , c.NamaKantorCabangStr AS nama
      , c.AlamatStr AS alamat
      , CAST(c.KotaIDLng AS varchar(50)) AS kota
      , CAST(c.ProvinsiIDLng AS varchar(50)) AS provinsi
      , CAST(c.NegaraIDLng AS varchar(50)) AS negara
      , c.NomorTeleponStr AS telepon
      , c.NomorFaxStr AS fax
      , c.PimpinanCabangStr AS pimpinan
      , CAST(c.BankIDLng AS varchar(50)) AS bank
      , c.NomorRekeningStr AS nomor_rekening
      , c.NomorRekeningIDStr AS no_id
      , c.RekeningAtasNamaStr AS atas_nama
      , CAST(ISNULL(c.AktifInt, 1) AS int) AS aktif
      , CASE WHEN ISNULL(c.AktifInt,1)=1 THEN 'AKTIF' ELSE 'TIDAK AKTIF' END AS status
      , CASE WHEN ISNULL(c.AktifInt,1)=1 THEN 'NONAKTIFKAN' ELSE 'AKTIFKAN' END AS confirm_status
    FROM hris.dbo.tblkantorcabang c WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblfixbrand b WITH (NOLOCK) ON b.BrandIDLng=c.BrandIDLng
    WHERE (@kw='' OR c.NamaKantorCabangStr LIKE '%'+@kw+'%' OR c.KodeKantorCabangStr LIKE '%'+@kw+'%')
    ORDER BY c.NamaKantorCabangStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_divisi_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_divisi_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows=(
    SELECT CAST(DivisiIDLng AS varchar(50)) AS id, KodeDivisiStr AS kode, DivisiStr AS nama, KeteranganStr AS keterangan
    FROM hris.dbo.tbldivisi WITH (NOLOCK)
    WHERE (@kw='' OR DivisiStr LIKE '%'+@kw+'%' OR KodeDivisiStr LIKE '%'+@kw+'%')
    ORDER BY DivisiStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows=(
    SELECT
        CAST(d.DepartemenIDLng AS varchar(50)) AS id
      , d.KodeDepartemenStr AS kode
      , d.DepartemenStr AS nama
      , d.KeteranganStr AS keterangan
      , CAST(d.DivisiIDLng AS varchar(50)) AS divisi
      , CAST(d.DivisiIDLng AS varchar(50)) AS divisi_id
      , v.DivisiStr AS divisi_nama
    FROM hris.dbo.tbldepartemen d WITH (NOLOCK)
    LEFT JOIN hris.dbo.tbldivisi v WITH (NOLOCK) ON v.DivisiIDLng=d.DivisiIDLng
    WHERE (@kw='' OR d.DepartemenStr LIKE '%'+@kw+'%' OR d.KodeDepartemenStr LIKE '%'+@kw+'%')
    ORDER BY d.DepartemenStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_departemen_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_departemen_getrow
( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int = TRY_CAST(@p_id AS int);
  DECLARE @row nvarchar(max);
  SELECT TOP 1 @row = (
    SELECT
        CAST(d.DepartemenIDLng AS varchar(50)) AS id
      , d.KodeDepartemenStr AS kode
      , d.DepartemenStr AS nama
      , d.KeteranganStr AS keterangan
      , CAST(d.DivisiIDLng AS varchar(50)) AS divisi
      , CAST(d.DivisiIDLng AS varchar(50)) AS divisi_id
      , v.DivisiStr AS divisi_nama
    FROM hris.dbo.tbldepartemen d WITH (NOLOCK)
    LEFT JOIN hris.dbo.tbldivisi v WITH (NOLOCK) ON v.DivisiIDLng=d.DivisiIDLng
    WHERE d.DepartemenIDLng = @rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
  IF @row IS NULL THROW 50001, 'Departemen tidak ditemukan', 1;
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(@row) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_golongan_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_golongan_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows=(
    SELECT CAST(GolonganIDLng AS varchar(50)) AS id, GolonganStr AS nama, KeteranganStr AS keterangan
    FROM hris.dbo.tblgolongan WITH (NOLOCK)
    WHERE (@kw='' OR GolonganStr LIKE '%'+@kw+'%')
    ORDER BY GolonganStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_pangkat_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_pangkat_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows=(
    SELECT CAST(PangkatIDLng AS varchar(50)) AS id, KodePangkatStr AS kode, PangkatStr AS nama, KeteranganStr AS keterangan
    FROM hris.dbo.tblpangkat WITH (NOLOCK)
    WHERE (@kw='' OR PangkatStr LIKE '%'+@kw+'%' OR KodePangkatStr LIKE '%'+@kw+'%')
    ORDER BY PangkatStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_master_jabatan_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_master_jabatan_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows=(
    SELECT CAST(JabatanIDLng AS varchar(50)) AS id, KodeJabatanStr AS kode, JabatanStr AS nama
    FROM hris.dbo.tbljabatan WITH (NOLOCK)
    WHERE (@kw='' OR JabatanStr LIKE '%'+@kw+'%' OR KodeJabatanStr LIKE '%'+@kw+'%')
    ORDER BY JabatanStr
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
