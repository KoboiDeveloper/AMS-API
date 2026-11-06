/*
  AR Detail Summary (REG2) — port XSP_TARIKAN_AR_DETAIL_RICO_print_POS_SERVER (gambar 2).
  Columns: STORE, TANGGAL_TRANSAKSI, PLU, QTY, HPP, PRICE, DISKON, TOTAL, RUMUS, SELISIH, REFUND.
  Tuned: half-open date, NOLOCK, no rico_ngehe temp table, optional brand/store/GH.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_ar_detail_summary_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_ar_detail_summary_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_ar_detail_summary_getrows
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

        ;WITH lines AS (
            /* Product + shopping bag lines */
            SELECT
                tsh.ID_Store,
                tsh.ID_TR_SALES_HEADER,
                CONVERT(varchar(10), tsh.Tanggal_Transaksi, 23) AS tanggal,
                tsd.PLU,
                CAST(tsd.qty AS float) AS qty,
                CAST(tsd.HPP AS float) AS hpp,
                CAST(tsd.net AS float) AS Harga_Jual,
                CAST(tsd.net AS float) AS Net,
                CAST(0 AS float) AS diskon,
                CAST(0 AS float) AS REFUND_TOT,
                CAST(0 AS float) AS PPLUS
            FROM pos_server.dbo.TR_SALES_HEADER tsh WITH (NOLOCK)
            INNER JOIN (
                SELECT ID_TR_SALES_HEADER, PLU, qty, HPP, net, DESKRIPSI
                FROM pos_server.dbo.TR_SALES_DETAIL WITH (NOLOCK)
                UNION ALL
                SELECT ID_TR_SALES_HEADER, PLU, qty, HPP, net, DESKRIPSI
                FROM pos_server.dbo.TR_SALES_SHOPPING_BAG WITH (NOLOCK)
            ) tsd ON tsd.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
            INNER JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = tsh.ID_Store
            WHERE tsh.Status_Transaksi = 1
              AND tsh.Tanggal_Transaksi >= @from AND tsh.Tanggal_Transaksi < @toX
              AND tsd.QTY > 0
              AND ISNULL(tsd.DESKRIPSI, '') NOT LIKE '%PP-%'
              AND ISNULL(tsd.DESKRIPSI, '') NOT LIKE '%DISC-%'
              AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
              AND (@store_id = 'ALL' OR tsh.ID_Store = @store_id)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = tsh.ID_Store COLLATE Latin1_General_CI_AS))
              AND (
                    @store_id <> 'ALL'
                 OR tsh.ID_Store NOT IN (
                        '000-RC','01C','02C','7777','888','999-RC','DEMO888','TST1','000-RIF','999-RIF','RIF888','RC888',
                        /* include marketplace 01e–06E,08E–11E */
                        '000-RM','999-RM','RM888','RQ888','777','dc000','dc111','dc222',
                        /* include marketplace 01e–11E (incl. 07E) */
                        'dc888','dc999','01D','01K','01L','01M','02D','03D','04D','05D','06D','07D','08D','09D','10D',
                        '11D','888-RC','888-RIF','888-RM','ART000','ART111','ART999','BZR01','DS000','GA000','GA999',
                        'MS001','MS002','RC01K','WOL01E','WOL02E','WOL03E','WOL04E','WOL06E'
                    )
              )
              AND (
                    @brand_id <> 'ALL'
                 OR ds.Store_Brand_ID NOT IN (
                        'AEESHA','ART VISUAL','CELCIUS KIDS','DC','DC OLD','GA','MINISTORE','POS TES','DS','KW2','WOL','TEST'
                    )
              )

            UNION ALL
            /* Diskon (negative PP/DISC) */
            SELECT
                tsh.ID_Store,
                tsh.ID_TR_SALES_HEADER,
                CONVERT(varchar(10), tsh.Tanggal_Transaksi, 23),
                tsd.PLU,
                0, 0, 0, 0,
                CAST(tsd.net AS float),
                0,
                0
            FROM pos_server.dbo.TR_SALES_HEADER tsh WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_DETAIL tsd WITH (NOLOCK)
                ON tsd.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
            INNER JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = tsh.ID_Store
            WHERE tsh.Status_Transaksi = 1
              AND tsh.Tanggal_Transaksi >= @from AND tsh.Tanggal_Transaksi < @toX
              AND (tsd.DESKRIPSI LIKE '%PP-%' OR tsd.DESKRIPSI LIKE '%DISC-%')
              AND LEFT(CONVERT(varchar(40), tsd.net), 1) = '-'
              AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
              AND (@store_id = 'ALL' OR tsh.ID_Store = @store_id)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = tsh.ID_Store COLLATE Latin1_General_CI_AS))

            UNION ALL
            /* PP plus */
            SELECT
                tsh.ID_Store,
                tsh.ID_TR_SALES_HEADER,
                CONVERT(varchar(10), tsh.Tanggal_Transaksi, 23),
                tsd.PLU,
                0, 0, 0, 0,
                0,
                0,
                CAST(tsd.net AS float)
            FROM pos_server.dbo.TR_SALES_HEADER tsh WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_DETAIL tsd WITH (NOLOCK)
                ON tsd.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
            INNER JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = tsh.ID_Store
            WHERE tsh.Status_Transaksi = 1
              AND tsh.Tanggal_Transaksi >= @from AND tsh.Tanggal_Transaksi < @toX
              AND tsd.DESKRIPSI LIKE '%PP-%'
              AND LEFT(CONVERT(varchar(40), tsd.net), 1) <> '-'
              AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
              AND (@store_id = 'ALL' OR tsh.ID_Store = @store_id)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = tsh.ID_Store COLLATE Latin1_General_CI_AS))

            UNION ALL
            /* Refund — parity XSP_TARIKAN_AR_DETAIL_RICO_print_POS_SERVER:
               pakai TGL_REFUND apa adanya (dengan jam), jangan truncate ke tanggal.
               Di ASP sale = yyyy-MM-dd (jam 00:00) vs refund = datetime penuh →
               GROUP BY memecah 2 baris PLU sama: 1 sale + 1 refund. */
            SELECT
                tsr.ID_Store,
                tsr.ID_TR_SALES_HEADER,
                CONVERT(varchar(23), tsr.TGL_REFUND, 121),
                tsd.PLU,
                0, 0, 0, 0,
                0,
                CAST(tsd.NET AS float),
                0
            FROM pos_server.dbo.TR_SALES_REFUND tsr WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL tsd WITH (NOLOCK)
                ON tsd.ID_TR_SALES_REFUND = tsr.ID_TR_SALES_REFUND
            INNER JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = tsr.ID_Store
            WHERE tsr.TGL_REFUND >= @from AND tsr.TGL_REFUND < @toX
              AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
              AND (@store_id = 'ALL' OR tsr.ID_Store = @store_id)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = tsr.ID_Store COLLATE Latin1_General_CI_AS))
        ),
        agg AS (
            SELECT
                x.ID_Store AS STORE,
                x.tanggal AS TANGGAL_TRANSAKSI,
                x.PLU,
                SUM(x.qty) AS QTY,
                SUM(x.hpp) AS HPP,
                SUM(x.Harga_Jual) AS PRICE,
                SUM(x.diskon) + SUM(x.PPLUS) AS DISKON,
                SUM(x.Net) + SUM(x.diskon) + SUM(x.PPLUS) - SUM(x.REFUND_TOT) AS TOTAL,
                SUM(x.Net) + SUM(x.diskon) + SUM(x.PPLUS) - SUM(x.REFUND_TOT) AS RUMUS,
                CAST(0 AS float) AS SELISIH,
                SUM(x.REFUND_TOT) AS REFUND
            FROM lines x
            GROUP BY x.ID_Store, x.ID_TR_SALES_HEADER, x.PLU, x.tanggal
        )
        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           a.STORE,
                           a.TANGGAL_TRANSAKSI,
                           a.PLU,
                           ISNULL(a.QTY, 0) AS QTY,
                           ISNULL(a.HPP, 0) AS HPP,
                           ISNULL(a.PRICE, 0) AS PRICE,
                           ISNULL(a.DISKON, 0) AS DISKON,
                           ISNULL(a.TOTAL, 0) AS TOTAL,
                           ISNULL(a.RUMUS, 0) AS RUMUS,
                           /* Banding: TOTAL vs PRICE+DISKON (gambar 2) */
                           ISNULL(a.TOTAL, 0) - (ISNULL(a.PRICE, 0) + ISNULL(a.DISKON, 0)) AS SELISIH,
                           ISNULL(a.REFUND, 0) AS REFUND
                       FROM agg a
                       ORDER BY a.STORE, a.TANGGAL_TRANSAKSI, a.PLU
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
