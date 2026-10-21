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


