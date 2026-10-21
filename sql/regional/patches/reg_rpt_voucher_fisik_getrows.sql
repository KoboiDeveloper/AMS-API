/*
  Voucher Fisik (REG2) — ASP parity module/Tools/voucher_rpt.aspx
  Rewritten (not EXEC legacy) so brand/store filter push-down — legacy SP terlalu berat.
  Detail: patches/reg_rpt_voucher_fisik_detail_getrows.sql
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_voucher_fisik_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_voucher_fisik_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_voucher_fisik_getrows
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
        DECLARE @status varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_status, 'ALL'))));
        IF @status = '' SET @status = 'ALL';
        IF @status NOT IN ('ALL', 'TERPAKAI', 'BELUM TERPAKAI', 'EXPIRED') SET @status = 'ALL';

        DECLARE @kw varchar(100) = LTRIM(RTRIM(ISNULL(@p_keywords, '')));
        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand IN ('', '0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store IN ('', '0') SET @store = 'ALL';
        DECLARE @year varchar(10) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_year,''), NULLIF(@p_tahun,'')), 'ALL')));
        IF @year IN ('', '0') SET @year = 'ALL';
        DECLARE @yr int = TRY_CAST(@year AS int);

        IF @brand = 'ALL' AND @store = 'ALL' AND @year = 'ALL'
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'Pilih Brand, Store, dan/atau Tahun dulu — load ALL terlalu berat.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @id_by_voucher varchar(32) = NULL;
        IF @kw <> ''
        BEGIN
            SELECT TOP 1 @id_by_voucher = a.ID_VOUCHER
            FROM pos_server.dbo.DT_VOUCHER_MARCOMM a
            LEFT JOIN pos_server.dbo.DT_VOUCHER_MARCOMM_DETAIL b ON a.ID_VOUCHER = b.ID_VOUCHER
            WHERE b.NO_VOUCHER = @kw;
        END;

        CREATE TABLE #vids (ID_VOUCHER varchar(32) NOT NULL PRIMARY KEY);
        IF @store <> 'ALL'
        BEGIN
            INSERT INTO #vids (ID_VOUCHER)
            SELECT DISTINCT d.ID_VOUCHER
            FROM pos_server.dbo.DT_VOUCHER_MARCOMM_DETAIL d
            WHERE UPPER(LTRIM(RTRIM(ISNULL(d.STORE_ID, '')))) = @store;
        END;

        ;WITH base AS (
            SELECT
                a.ID_VOUCHER,
                a.no_urut,
                a.QTY_VOUCHER AS qty,
                a.TIPE_VOUCHER AS tipe,
                ISNULL(a.NOMINAL, 0) AS nominal,
                a.CRE_DATE,
                a.NO_JOURNAL,
                b.NOMINAL AS NOMINAL_PERVOUCHER,
                a.BRAND,
                a.KETERANGAN,
                SUM(CASE WHEN b.STATUS_PENGGUNAAN = 1 THEN 1 ELSE 0 END) AS sudah_digunakan,
                SUM(CASE WHEN b.STATUS_PENGGUNAAN = 0 THEN 1 ELSE 0 END) AS yang_belum_digunakan
            FROM pos_server.dbo.DT_VOUCHER_MARCOMM a
            INNER JOIN pos_server.dbo.DT_VOUCHER_MARCOMM_DETAIL b ON b.ID_VOUCHER = a.ID_VOUCHER
            WHERE (@brand = 'ALL' OR UPPER(LTRIM(RTRIM(ISNULL(a.BRAND, '')))) = @brand)
              AND (@store = 'ALL' OR EXISTS (SELECT 1 FROM #vids v WHERE v.ID_VOUCHER = a.ID_VOUCHER))
              AND (@year = 'ALL' OR (@yr IS NOT NULL AND YEAR(a.CRE_DATE) = @yr))
              AND (
                    @status <> 'EXPIRED'
                    OR DATEDIFF(day, a.END_DATE, GETDATE()) > 0
                  )
            GROUP BY
                a.ID_VOUCHER, a.no_urut, a.QTY_VOUCHER, a.TIPE_VOUCHER, a.NOMINAL,
                a.CRE_DATE, a.NO_JOURNAL, b.NOMINAL, a.BRAND, a.KETERANGAN
        ),
        filtered AS (
            SELECT
                x.ID_VOUCHER,
                x.tipe AS TIPE_VOUCHER,
                CAST(x.qty AS varchar(20)) AS QTY,
                x.nominal AS MAXNOMINAL,
                x.CRE_DATE,
                CASE
                    WHEN @status = 'ALL' THEN x.qty - SUM(x.sudah_digunakan)
                    WHEN @status = 'TERPAKAI' THEN SUM(x.sudah_digunakan)
                    ELSE SUM(x.yang_belum_digunakan)
                END AS QTY_Z,
                FORMAT(x.NOMINAL_PERVOUCHER, '#,##') AS NOMINAL,
                x.BRAND,
                x.KETERANGAN
            FROM base x
            WHERE (
                @kw = ''
                OR x.tipe LIKE '%' + @kw + '%'
                OR ISNULL(x.NO_JOURNAL, '') LIKE '%' + @kw + '%'
                OR CONVERT(varchar(30), x.CRE_DATE, 120) LIKE '%' + @kw + '%'
                OR ISNULL(x.BRAND, '') LIKE '%' + @kw + '%'
                OR ISNULL(x.KETERANGAN, '') LIKE '%' + @kw + '%'
                OR (@id_by_voucher IS NOT NULL AND x.ID_VOUCHER = @id_by_voucher)
                OR x.ID_VOUCHER LIKE '%' + @kw + '%'
            )
            GROUP BY
                x.ID_VOUCHER, x.no_urut, x.qty, x.tipe, x.nominal, x.NOMINAL_PERVOUCHER,
                x.CRE_DATE, x.NO_JOURNAL, x.BRAND, x.KETERANGAN
        )
        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           f.ID_VOUCHER AS ID_VOUCHER,
                           f.TIPE_VOUCHER AS TIPE_VOUCHER,
                           LTRIM(RTRIM(ISNULL(f.QTY, ''))) AS QTY,
                           CAST(ISNULL(f.MAXNOMINAL, 0) AS float) AS MAXNOMINAL,
                           CONVERT(varchar(19), f.CRE_DATE, 120) AS CRE_DATE,
                           CAST(ISNULL(f.QTY_Z, 0) AS float) AS QTY_Z,
                           f.NOMINAL AS NOMINAL,
                           f.BRAND AS BRAND,
                           f.KETERANGAN AS KETERANGAN
                       FROM filtered f
                       ORDER BY f.CRE_DATE DESC, f.MAXNOMINAL DESC
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
