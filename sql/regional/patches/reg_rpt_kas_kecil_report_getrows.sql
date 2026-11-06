/*
  Report Kas Kecil (REG2) — wrap pos_server.dbo.xsp_tax_kas_kecil_report.
  Filter: year only (@p_year / @p_tahun).
  Columns: STORE_ID, DESKRIPSI, COA, TGL_PENGAJUAN, REMARKS, AMOUNT_OUT, status, keterangan.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_kas_kecil_report_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_kas_kecil_report_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_kas_kecil_report_getrows
(
      @p_keywords varchar(200) = NULL
    , @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @p_is_active varchar(10) = NULL
    , @p_id_brand varchar(50) = NULL
    , @p_id_store varchar(50) = NULL
    , @p_brand varchar(50) = NULL
    , @p_store_id varchar(50) = NULL
    , @p_status varchar(50) = NULL
    , @p_kategori varchar(50) = NULL
    , @p_group varchar(50) = NULL
    , @p_dept varchar(50) = NULL
    , @p_department varchar(50) = NULL
    , @p_cabang varchar(50) = NULL
    , @p_id_cabang varchar(50) = NULL
    , @p_year varchar(10) = NULL
    , @p_month varchar(10) = NULL
    , @p_period varchar(20) = NULL
    , @p_tipe varchar(50) = NULL
    , @p_is_pajak varchar(10) = NULL
    , @p_id_mesin varchar(50) = NULL
    , @p_currentmonth varchar(10) = NULL
    , @p_tahun varchar(10) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @p_plu varchar(80) = NULL
    , @p_article varchar(80) = NULL
    , @p_voucher varchar(80) = NULL
    , @p_invoice varchar(80) = NULL
    , @p_marketplace varchar(80) = NULL
    , @p_multi_store varchar(max) = NULL
    , @p_brand_filter varchar(80) = NULL
    , @p_brand_to varchar(50) = NULL
    , @p_store_to varchar(50) = NULL
    , @p_tgl varchar(30) = NULL
    , @p_provinsi varchar(80) = NULL
    , @p_kota varchar(80) = NULL
    , @p_id_member varchar(80) = NULL
    , @p_confirm_status varchar(50) = NULL
    , @p_gh_id varchar(50) = NULL
    , @p_id_gh varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @year varchar(4) = LEFT(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_year,''), NULLIF(@p_tahun,'')), ''))), 4);
        IF @year = '' OR TRY_CAST(@year AS int) IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'year wajib (YYYY).' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* parity xsp_tax_kas_kecil_report */
        SET @bitparam = (
            SELECT
                '2002500' AS responseCode,
                'success' AS responseMessage,
                JSON_QUERY((
                    SELECT
                        a.STORE_ID,
                        b.DESKRIPSI,
                        a.COA,
                        CONVERT(varchar(10), a.TGL_PENGAJUAN, 23) AS TGL_PENGAJUAN,
                        a.REMARKS,
                        ISNULL(a.AMOUNT_OUT, 0) AS AMOUNT_OUT,
                        a.status,
                        CASE
                            WHEN a.status = 9 THEN 'selesai'
                            WHEN a.status = 8 THEN 'di tolak'
                            WHEN a.status IN (2, 3) THEN 'diajukan'
                            ELSE NULL
                        END AS keterangan
                    FROM pos_server.dbo.dt_kas_kecil a WITH (NOLOCK)
                    LEFT OUTER JOIN pos_server.dbo.WEB_MASTER_COA b WITH (NOLOCK)
                        ON b.CODE = a.COA
                    WHERE YEAR(a.TGL_PENGAJUAN) = TRY_CAST(@year AS int)
                    ORDER BY a.TGL_PENGAJUAN ASC, a.BRAND_ID, a.STORE_ID
                    FOR JSON PATH
                )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH
END
GO
