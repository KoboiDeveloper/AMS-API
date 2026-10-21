/* Live personel getrows — new SP only; reads hris tables (does not alter legacy SPs) */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_personel_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_personel_getrows
(
      @p_keywords varchar(200) = NULL
    , @p_from_date varchar(20) = NULL
    , @p_to_date varchar(20) = NULL
    , @p_is_active varchar(1) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @kw varchar(200) = LTRIM(RTRIM(ISNULL(@p_keywords, '')));
        DECLARE @rows nvarchar(max);

        ;WITH src AS (
            SELECT TOP 200
                CAST(t1.PegawaiIDLng AS varchar(50)) AS id,
                t1.NomorIndukStr AS nik,
                t1.NamaLengkapStr AS employee_name,
                t3.JabatanStr AS job_title,
                t4.DepartemenStr AS department,
                t7.NamaKantorCabangStr AS branch_name,
                t8.BrandStr AS brand,
                t5.StatusPegawaiStr AS status,
                CASE WHEN t1.PegawaiNonAktifInt = 0 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS is_active
            FROM hris.dbo.tblpegawai t1
            LEFT JOIN hris.dbo.tblpegawaijabatan t2 ON t1.PegawaiIDLng = t2.PegawaiIDLng
            LEFT JOIN hris.dbo.tbljabatan t3 ON t2.JabatanIDLng = t3.JabatanIDLng
            LEFT JOIN hris.dbo.tbldepartemen t4 ON t2.DepartemenIDLng = t4.DepartemenIDLng
            LEFT JOIN hris.dbo.tblstatuspegawai t5 ON t2.StatusPegawaiIDLng = t5.StatusPegawaiIDLng
            LEFT JOIN hris.dbo.tblpegawaipenempatan t6 ON t1.PegawaiIDLng = t6.PegawaiIDLng
            LEFT JOIN hris.dbo.tblkantorcabang t7 ON t6.KantorCabangIDLng = t7.KantorCabangIDLng
            LEFT JOIN hris.dbo.tblfixbrand t8 ON t7.BrandIDLng = t8.BrandIDLng
            WHERE (
                    @kw = ''
                 OR t1.NomorIndukStr LIKE '%' + @kw + '%'
                 OR t1.NamaLengkapStr LIKE '%' + @kw + '%'
                 OR t3.JabatanStr LIKE '%' + @kw + '%'
                 OR t7.NamaKantorCabangStr LIKE '%' + @kw + '%'
                )
              AND (
                    @p_is_active IS NULL OR @p_is_active = ''
                 OR (@p_is_active = '1' AND t1.PegawaiNonAktifInt = 0)
                 OR (@p_is_active = '0' AND t1.PegawaiNonAktifInt = 1)
                )
            ORDER BY t1.NamaLengkapStr
        )
        SELECT @rows = (
            SELECT id, nik, employee_name, job_title, department, branch_name, brand, status, is_active
            FROM src
            FOR JSON PATH
        );

        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success' AS responseMessage,
                   JSON_QUERY(ISNULL(@rows, N'[]')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
