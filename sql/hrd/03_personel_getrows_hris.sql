/* Enhance personel list with hris data — CREATE OR ALTER only, no legacy DROP */
CREATE OR ALTER PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows
(
      @p_keywords varchar(200) = NULL
    , @p_from_date varchar(20) = NULL
    , @p_to_date varchar(20) = NULL
    , @p_is_active varchar(1) = NULL
    , @p_status varchar(20) = NULL
    , @p_search varchar(150) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @kw varchar(200) = LTRIM(RTRIM(ISNULL(NULLIF(@p_keywords,''), ISNULL(@p_search,''))));
        DECLARE @status varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(@p_status,''))));
        IF @status = '' AND @p_is_active = '1' SET @status = 'ACTIVE';
        IF @status = '' AND @p_is_active = '0' SET @status = 'NON ACTIVE';

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                        SELECT TOP 2000
                            t1.PegawaiIDLng AS id,
                            t1.NomorIndukStr AS nik,
                            t1.NamaLengkapStr AS employee_name,
                            t8.BrandStr AS brand,
                            t7.NamaKantorCabangStr AS cabang,
                            t10.PangkatStr AS pangkat,
                            t3.JabatanStr AS jabatan,
                            t4.DepartemenStr AS departemen,
                            t5.StatusPegawaiStr AS status_pegawai,
                            CONVERT(varchar(11), t1.TanggalMulaiAktifDtd, 106) AS tanggal_aktif,
                            CASE WHEN t1.PegawaiNonAktifInt = 0 THEN 1 ELSE 0 END AS is_active
                        FROM hris.dbo.tblpegawai t1
                        LEFT JOIN hris.dbo.tblpegawaijabatan t2 ON t1.PegawaiIDLng = t2.PegawaiIDLng
                        LEFT JOIN hris.dbo.tbljabatan t3 ON t2.JabatanIDLng = t3.JabatanIDLng
                        LEFT JOIN hris.dbo.tbldepartemen t4 ON t2.DepartemenIDLng = t4.DepartemenIDLng
                        LEFT JOIN hris.dbo.tblstatuspegawai t5 ON t2.StatusPegawaiIDLng = t5.StatusPegawaiIDLng
                        LEFT JOIN hris.dbo.tblpegawaipenempatan t6 ON t1.PegawaiIDLng = t6.PegawaiIDLng
                        LEFT JOIN hris.dbo.tblkantorcabang t7 ON t6.KantorCabangIDLng = t7.KantorCabangIDLng
                        LEFT JOIN hris.dbo.tblformbrand t8 ON t7.BrandIDLng = t8.BrandIDLng
                        LEFT JOIN hris.dbo.tblpangkat t10 ON t2.PangkatIDLng = t10.PangkatIDLng
                        WHERE (
                                (@status = 'ACTIVE' AND t1.PegawaiNonAktifInt = 0)
                             OR (@status = 'NON ACTIVE' AND t1.PegawaiNonAktifInt = 1)
                             OR (@status NOT IN ('ACTIVE','NON ACTIVE'))
                            )
                          AND (
                                @kw = ''
                             OR t1.NomorIndukStr LIKE '%' + @kw + '%'
                             OR t1.NamaLengkapStr LIKE '%' + @kw + '%'
                             OR ISNULL(t3.JabatanStr,'') LIKE '%' + @kw + '%'
                             OR ISNULL(t7.NamaKantorCabangStr,'') LIKE '%' + @kw + '%'
                             OR ISNULL(t8.BrandStr,'') LIKE '%' + @kw + '%'
                          )
                        FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
