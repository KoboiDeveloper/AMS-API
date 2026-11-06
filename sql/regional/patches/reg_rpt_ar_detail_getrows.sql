/*
  AR Detail (REG2) — port XSP_RPT_sales_ar_GETROWS_print_POS_SERVER (gambar 1).
  Grain: ID_TR_SALES_HEADER. Columns include D_QRIS_* + KINDODANA.
  Tuned: half-open date range (sargable), NOLOCK, optional brand/store/GH scope.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_ar_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_ar_detail_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_ar_detail_getrows
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
        DECLARE @from date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date,''))),'') AS date);
        DECLARE @to date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date,''))),'') AS date);
        IF @from IS NULL OR @to IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'from_date dan to_date wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        IF DATEDIFF(DAY, @from, @to) > 31
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'Range tanggal maksimal 31 hari.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @toX date = DATEADD(DAY, 1, @to);
        DECLARE @brand_id varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand_id IN ('','0') SET @brand_id = 'ALL';
        DECLARE @store_id varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store_id IN ('','0') SET @store_id = 'ALL';

        DECLARE @gh varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,''), NULLIF(@p_actor_nik,'')),''))),'');
        DECLARE @scoped bit = 0;
        CREATE TABLE #sc (store varchar(50) COLLATE Latin1_General_CI_AS NOT NULL PRIMARY KEY);

        IF @gh IS NOT NULL AND (
               EXISTS (SELECT 1 FROM pos_server.dbo.MASTER_GH_DETAIL WITH (NOLOCK) WHERE ID_GROUP_HEAD = @gh)
            OR EXISTS (SELECT 1 FROM pos_server.dbo.MASTER_REGIONAL_DETAIL WITH (NOLOCK) WHERE ID_REGIONAL = @gh))
        BEGIN
            SET @scoped = 1;
            INSERT INTO #sc (store)
            SELECT DISTINCT STORE COLLATE Latin1_General_CI_AS
            FROM (
                SELECT STORE FROM pos_server.dbo.MASTER_GH_DETAIL WITH (NOLOCK) WHERE ID_GROUP_HEAD = @gh
                UNION
                SELECT mgd.STORE
                FROM pos_server.dbo.MASTER_REGIONAL_DETAIL mrd WITH (NOLOCK)
                INNER JOIN pos_server.dbo.MASTER_GH_DETAIL mgd WITH (NOLOCK) ON mgd.ID_GROUP_HEAD = mrd.ID_GROUP_HEAD
                WHERE mrd.ID_REGIONAL = @gh
            ) s WHERE STORE IS NOT NULL;
        END;

        ;WITH pay AS (
            SELECT
                a.ID_TR_SALES_HEADER,
                a.ID_Store,
                CONVERT(varchar(10), a.Tanggal_Transaksi, 23) AS TANGGAL_TRANSAKSI,
                CASE
                    WHEN a.ID_Store = '07e' THEN ISNULL(MAX(mp.TOTALAR), 0)
                    ELSE SUM(CASE WHEN c.TIPE_BAYAR = 'CASH' THEN c.BAYAR ELSE 0 END)
                       + SUM(CASE WHEN c.TIPE_BAYAR = 'Change' THEN c.BAYAR ELSE 0 END)
                END AS CASH,
                SUM(CASE WHEN c.TIPE_BAYAR IN ('K.BCA','K.BNI','K.BRI','K.MANDIRI','D.BCA','D.BNI','D.BRI','D.MANDIRI') THEN c.BAYAR ELSE 0 END) AS CARD,
                SUM(CASE WHEN c.TIPE_BAYAR LIKE 'Voucher%' THEN c.BAYAR ELSE 0 END) AS VOUCHER,
                SUM(CASE WHEN c.TIPE_BAYAR = 'K.OVO' THEN c.BAYAR ELSE 0 END) AS OVO,
                SUM(CASE WHEN c.TIPE_BAYAR = 'K.QRIS' THEN c.BAYAR ELSE 0 END) AS KQRIS,
                SUM(CASE WHEN c.TIPE_BAYAR = 'D.QRIS BCA' THEN c.BAYAR ELSE 0 END) AS D_QRIS_BCA,
                SUM(CASE WHEN c.TIPE_BAYAR = 'D.QRIS BNI' THEN c.BAYAR ELSE 0 END) AS D_QRIS_BNI,
                SUM(CASE WHEN c.TIPE_BAYAR = 'D.QRIS BRI' THEN c.BAYAR ELSE 0 END) AS D_QRIS_BRI,
                SUM(CASE WHEN c.TIPE_BAYAR = 'D.QRIS MDR' THEN c.BAYAR ELSE 0 END) AS D_QRIS_MDR,
                SUM(CASE WHEN c.TIPE_BAYAR = 'K.ATOME' THEN c.BAYAR ELSE 0 END) AS KATOME,
                SUM(CASE WHEN c.TIPE_BAYAR = 'K.INDODANA' THEN c.BAYAR ELSE 0 END) AS KINDODANA,
                SUM(CASE WHEN c.TIPE_BAYAR = 'sisa_Voucher' THEN c.BAYAR ELSE 0 END) AS SISA_VOUCHER,
                SUM(CASE WHEN c.TIPE_BAYAR = 'Nilai Refund' THEN c.BAYAR ELSE 0 END) AS REFUND
            FROM pos_server.dbo.TR_SALES_HEADER AS a WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_PAYMENT_DETAIL AS c WITH (NOLOCK)
                ON c.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER
            INNER JOIN pos_server.dbo.DT_Store AS ds WITH (NOLOCK)
                ON ds.Store_ID = a.ID_Store
            LEFT JOIN pos_server.dbo.MARKETPLACE_AR AS mp WITH (NOLOCK)
                ON mp.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER AND a.ID_Store = '07e'
            WHERE a.Status_Transaksi = 1
              AND a.Tanggal_Transaksi >= @from AND a.Tanggal_Transaksi < @toX
              AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
              AND (@store_id = 'ALL' OR a.ID_Store = @store_id)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = a.ID_Store COLLATE Latin1_General_CI_AS))
              AND (
                    @store_id <> 'ALL'
                 OR a.ID_Store NOT IN (
                        '000-RC','01C','02C','7777','888','999-RC','DEMO888','TST1','000-RIF','999-RIF','RIF888','RC888',
                        '000-RM','999-RM','RM888','RQ888','01e','02e','03e','04e','05e','06E','777','dc000','dc111','dc222',
                        'dc888','dc999','01D','01K','01L','01M','02D','03D','04D','05D','06D','07D','07E','08D','09D','10D',
                        '11D','888-RC','888-RIF','888-RM','ART000','ART111','ART999','BZR01','07E','DS000','GA000','GA999',
                        'MS001','MS002','RC01K','WOL01E','WOL02E','WOL03E','WOL04E','WOL06E','08E','09E','10E','11E'
                    )
              )
              AND (
                    @brand_id <> 'ALL'
                 OR ds.Store_Brand_ID NOT IN (
                        'AEESHA','ART VISUAL','CELCIUS KIDS','DC','DC OLD','GA','MINISTORE','POS TES','DS','KW2','WOL','TEST'
                    )
              )
            GROUP BY a.ID_TR_SALES_HEADER, a.ID_Store, CONVERT(varchar(10), a.Tanggal_Transaksi, 23)
        )
        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           p.ID_TR_SALES_HEADER AS id_tr_sales_header,
                           p.ID_Store AS STORE,
                           p.TANGGAL_TRANSAKSI AS tanggal_transaksi,
                           ISNULL(p.CASH, 0) AS CASH,
                           ISNULL(p.CARD, 0) AS CARD,
                           ISNULL(p.VOUCHER, 0) AS VOUCHER,
                           ISNULL(p.OVO, 0) AS OVO,
                           ISNULL(p.KQRIS, 0) AS KQRIS,
                           ISNULL(p.D_QRIS_BCA, 0) AS D_QRIS_BCA,
                           ISNULL(p.D_QRIS_BNI, 0) AS D_QRIS_BNI,
                           ISNULL(p.D_QRIS_BRI, 0) AS D_QRIS_BRI,
                           ISNULL(p.D_QRIS_MDR, 0) AS D_QRIS_MDR,
                           ISNULL(p.KATOME, 0) AS KATOME,
                           ISNULL(p.KINDODANA, 0) AS KINDODANA,
                           ISNULL(p.SISA_VOUCHER, 0) AS SISA_VOUCHER,
                           ISNULL(p.REFUND, 0) AS REFUND,
                           (
                               ISNULL(p.CASH, 0) + ISNULL(p.CARD, 0) + ISNULL(p.VOUCHER, 0) + ISNULL(p.OVO, 0)
                             + ISNULL(p.KQRIS, 0) + ISNULL(p.D_QRIS_BCA, 0) + ISNULL(p.D_QRIS_BNI, 0)
                             + ISNULL(p.D_QRIS_BRI, 0) + ISNULL(p.D_QRIS_MDR, 0) + ISNULL(p.KATOME, 0)
                             + ISNULL(p.KINDODANA, 0) + ISNULL(p.SISA_VOUCHER, 0) - ISNULL(p.REFUND, 0)
                           ) AS TOTAL
                       FROM pay p
                       ORDER BY p.ID_Store, p.TANGGAL_TRANSAKSI, p.ID_TR_SALES_HEADER
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        DROP TABLE #sc;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#sc') IS NOT NULL DROP TABLE #sc;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
