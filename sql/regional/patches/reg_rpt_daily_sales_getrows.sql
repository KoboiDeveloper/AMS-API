/*
  Daily Sales Summary (REG2) - NEW SP on RBACESS (xsp_ams_new_reg_rpt_daily_sales_getrows).
  Legacy page : module/Rpt/Daily_s_sales.aspx (REG role 5/6/70/696/33 routing).
  Legacy SPs ported (pos_server.dbo.* only - legacy SPs are NEVER EXEC'd / altered):
     XSP_RPT_DAILY_S_SALES_S_GETROWS                          digit FULL , mode 1 DETAIL
     XSP_RPT_DAILY_S_SALES_S__hdate_GETROWS                   digit FULL , mode 1 DETAIL + hide date
     XSP_RPT_DAILY_S_SALES_S_TOTAL_GETROWS                    digit FULL , mode 2 TOTAL
     XSP_RPT_DAILY_S_SALES_S_PLU3_GETROWS                     digit 3    , mode 1
     XSP_RPT_DAILY_S_SALES_S_PLU3_TOTAL_GETROWS               digit 3    , mode 2
     XSP_RPT_DAILY_S_SALES_S_PLU1_GETROWS                     digit 1    , mode 1
     XSP_RPT_DAILY_S_SALES_S_PLU1_TOTAL_GETROWS               digit 1    , mode 2
     XSP_RPT_DAILY_S_SALES_S_PLU_GRAD_TOTAL_GETROWS           any digit  , mode 3 (GRAND TOTAL per store)
     XSP_RPT_DAILY_S_SALES_S_PLU_GROUP_BRAND_GRAD_TOTAL_GETROWS  digit 1, mode 3, store = GROUP_BRAND

  Param mapping (Go regListHandler keys):
     @p_plu            = digit  (FULL | 3 | 1)
     @p_tipe           = mode   (1 DETAIL | 2 TOTAL | 3 GRAND TOTAL)
     @p_confirm_status = hide_date (0|1)  -> only FULL + DETAIL
     @p_is_active      = online   (0|1)
     @p_id_brand / @p_id_store (ALL | id | GROUP_BRAND)
     @p_id_gh / @p_actor_nik   = GH / regional scope (applied only when the id exists in
                                 MASTER_GH_DETAIL / MASTER_REGIONAL_DETAIL)
  Output columns (legacy names): NO_URUT, WAKTU_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL,
     MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_daily_sales_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_daily_sales_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_daily_sales_getrows
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
        /* ---------------- params ---------------- */
        DECLARE @from date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date,''))),'') AS date);
        DECLARE @to   date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date,''))),'') AS date);
        IF @from IS NULL OR @to IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'from_date dan to_date wajib diisi.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        DECLARE @toX date = DATEADD(DAY, 1, @to);

        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), NULLIF(@p_brand,'')), 'ALL'))));
        IF @brand IN ('','0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), NULLIF(@p_store_id,'')), 'ALL'))));
        IF @store IN ('','0') SET @store = 'ALL';

        DECLARE @digit varchar(10) = UPPER(LTRIM(RTRIM(ISNULL(@p_plu,''))));
        IF @digit NOT IN ('3','1') SET @digit = 'FULL';
        DECLARE @mode int = CASE LTRIM(RTRIM(ISNULL(@p_tipe,''))) WHEN '2' THEN 2 WHEN '3' THEN 3 ELSE 1 END;
        DECLARE @hide bit = CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(@p_confirm_status,'')))) IN ('1','true','y','yes') THEN 1 ELSE 0 END;
        DECLARE @online bit = CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(@p_is_active,'')))) IN ('1','true','y','yes','online') THEN 1 ELSE 0 END;

        /* GROUP_BRAND only exists in legacy for digit 1 + GRAND TOTAL; elsewhere it behaves like ALL stores */
        DECLARE @gb bit = 0;
        IF @store = 'GROUP_BRAND'
        BEGIN
            IF @digit = '1' AND @mode = 3 SET @gb = 1;
            SET @store = 'ALL';
        END;
        IF @hide = 1 AND NOT (@digit = 'FULL' AND @mode = 1) SET @hide = 0;

        /* some legacy SPs have no @p_online param (always exclude online) */
        DECLARE @online_eff bit = CASE
              WHEN @digit = '3' AND @mode = 1 THEN 0
              WHEN @digit = '1' AND @mode IN (1,2) THEN 0
              WHEN @digit = 'FULL' AND @mode = 1 AND @hide = 1 THEN 0
              ELSE @online END;

        /* ---------------- GH / regional scope ---------------- */
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
                SELECT mgd.STORE FROM pos_server.dbo.MASTER_REGIONAL_DETAIL mrd WITH (NOLOCK)
                  INNER JOIN pos_server.dbo.MASTER_GH_DETAIL mgd WITH (NOLOCK) ON mgd.ID_GROUP_HEAD = mrd.ID_GROUP_HEAD
                 WHERE mrd.ID_REGIONAL = @gh
            ) s WHERE STORE IS NOT NULL;
        END;

        CREATE TABLE #out (
            NO_URUT bigint NULL, WAKTU_URUT varchar(20) NULL, Store_ID varchar(50) NULL, tanggal varchar(20) NULL,
            PLU varchar(80) NULL, PRICE decimal(19,2) NULL, HPP decimal(19,2) NULL, HPP_TOTAL decimal(19,2) NULL, MARGIN decimal(19,2) NULL,
            QTY decimal(19,2) NULL, LABA decimal(19,2) NULL, SALES decimal(19,2) NULL, DISCOUNT decimal(19,2) NULL, PP decimal(19,2) NULL,
            NET_SALES decimal(19,2) NULL, NET_LABA decimal(19,2) NULL, NET_PERSENTASE decimal(19,4) NULL, SORT_NULL int NULL
        );

        IF @gb = 1
        BEGIN
            /* ===== PLU_GROUP_BRAND_GRAD_TOTAL: per BRAND, no brand/store filter, no PLASTIK, online filter only on refunds ===== */
            INSERT INTO #out (NO_URUT, Store_ID, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE)
            SELECT ROW_NUMBER() OVER (ORDER BY x.BRAND), x.BRAND, NULL,
                   SUM(x.PRICE), SUM(x.HPP), 0, SUM(x.MARGIN), SUM(x.QTY), SUM(x.LABA), SUM(x.SALES),
                   SUM(x.DISCOUNT), SUM(x.PP), SUM(x.NET_SALES), SUM(x.NET_LABA),
                   (SUM(x.NET_SALES) - SUM(x.HPP)) / NULLIF(SUM(x.NET_SALES),0) * 100
            FROM (
                SELECT CASE WHEN DS.Store_Brand_ID IN ('FLIES','IWAN FASHION') THEN 'FLIES'
                            WHEN DS.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
                            ELSE DS.Store_Brand_ID END AS BRAND,
                       CAST(ISNULL(DSS.PRICE,0) AS float) AS PRICE,
                       CAST(ISNULL(DSS.HPP,0) AS float) * DSS.QTY AS HPP,
                       CAST(ISNULL(DSS.MARGIN,0) AS float) AS MARGIN,
                       CAST(DSS.QTY AS float) AS QTY,
                       CAST(ISNULL(DSS.LABA,0) AS float) AS LABA,
                       CAST(ISNULL(DSS.SALES,0) AS float) AS SALES,
                       CAST(ISNULL(DSS.DISCOUNT,0) AS float) AS DISCOUNT,
                       CAST(ISNULL(DSS.PP,0) AS float) AS PP,
                       CAST(ISNULL(DSS.NET_SALES,0) AS float) AS NET_SALES,
                       CAST(ISNULL(DSS.NET_LABA,0) AS float) AS NET_LABA
                FROM pos_server.dbo.DT_SALES_SUMMARY DSS WITH (NOLOCK)
                INNER JOIN pos_server.dbo.DT_PLU DP WITH (NOLOCK) ON DP.PLU = DSS.PLU
                LEFT OUTER JOIN pos_server.dbo.DT_Store DS WITH (NOLOCK) ON DS.Store_ID = DSS.Store_ID
                WHERE DSS.Tanggal >= @from AND DSS.Tanggal < @toX
                  AND DP.ARTICLE <> 'PLASTIK'
                  AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = DSS.Store_ID COLLATE Latin1_General_CI_AS))
                UNION ALL
                SELECT CASE WHEN DS.Store_Brand_ID IN ('FLIES','IWAN FASHION') THEN 'FLIES'
                            WHEN DS.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
                            ELSE DS.Store_Brand_ID END,
                       0, 0, 0, -CAST(TSD.DIST_QTY AS float), 0, 0, 0, 0, -CAST(TSD.TOTAL_PRICE AS float), 0
                FROM pos_server.dbo.TR_SALES_REFUND TSD WITH (NOLOCK)
                LEFT OUTER JOIN pos_server.dbo.DT_Store DS WITH (NOLOCK) ON DS.Store_ID = TSD.ID_STORE
                INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL TSSS WITH (NOLOCK) ON TSSS.ID_TR_SALES_REFUND = TSD.ID_TR_SALES_REFUND
                WHERE ((@online = 0 AND DS.Store_Brand_ID_2 <> 'online') OR (@online = 1 AND DS.Store_Brand_ID_2 IS NOT NULL))
                  AND TSD.TGL_REFUND >= @from AND TSD.TGL_REFUND < @toX
                  AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = TSD.ID_STORE COLLATE Latin1_General_CI_AS))
            ) x
            GROUP BY x.BRAND;
        END
        ELSE
        BEGIN
            /* ===== shared filtered base: DT_SALES_SUMMARY ===== */
            SELECT DSS.NO_URUT, DSS.WAKTU_URUT, DSS.Store_ID, DSS.Tanggal, DSS.PLU,
                   CAST(ISNULL(DSS.PRICE,0) AS float) AS PRICE,
                   CAST(ISNULL(DSS.HPP,0) AS float) AS HPP,
                   CAST(ISNULL(DSS.MARGIN,0) AS float) AS MARGIN,
                   CAST(ISNULL(DSS.QTY,0) AS float) AS QTY,
                   CAST(ISNULL(DSS.LABA,0) AS float) AS LABA,
                   CAST(ISNULL(DSS.SALES,0) AS float) AS SALES,
                   CAST(ISNULL(DSS.DISCOUNT,0) AS float) AS DISCOUNT,
                   CAST(ISNULL(DSS.PP,0) AS float) AS PP,
                   CAST(ISNULL(DSS.NET_SALES,0) AS float) AS NET_SALES,
                   CAST(ISNULL(DSS.NET_LABA,0) AS float) AS NET_LABA
            INTO #b
            FROM pos_server.dbo.DT_SALES_SUMMARY DSS WITH (NOLOCK)
            LEFT OUTER JOIN pos_server.dbo.DT_Store DS WITH (NOLOCK) ON DS.Store_ID = DSS.Store_ID
            WHERE DSS.Tanggal >= @from AND DSS.Tanggal < @toX
              AND ((@online_eff = 0 AND DS.Store_Brand_ID_2 <> 'online') OR (@online_eff = 1 AND DS.Store_Brand_ID_2 IS NOT NULL))
              AND (@brand = 'ALL' OR DS.Store_Brand_ID = @brand)
              AND (@store = 'ALL' OR DSS.Store_ID = @store)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = DSS.Store_ID COLLATE Latin1_General_CI_AS));

            /* ===== refund rows (same filters) - detail-joined (legacy) or header-only (GRAND with brand/store) ===== */
            CREATE TABLE #r (Store_ID varchar(50) NULL, PLU varchar(80) NULL, QTY float NULL, NET float NULL);
            DECLARE @ref_detail bit = CASE WHEN @mode = 3 AND (@brand <> 'ALL' OR @store <> 'ALL') THEN 0 ELSE 1 END;
            DECLARE @want_ref bit = CASE WHEN @digit = '1' THEN 0 ELSE 1 END;   /* PLU1 / PLU1_TOTAL have no refund rows */
            IF @want_ref = 1
            BEGIN
                IF @ref_detail = 1
                    INSERT INTO #r (Store_ID, PLU, QTY, NET)
                    SELECT TSD.ID_STORE, TSSS.PLU, CAST(TSD.DIST_QTY AS float), CAST(TSD.TOTAL_PRICE AS float)
                    FROM pos_server.dbo.TR_SALES_REFUND TSD WITH (NOLOCK)
                    LEFT OUTER JOIN pos_server.dbo.DT_Store DS WITH (NOLOCK) ON DS.Store_ID = TSD.ID_STORE
                    INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL TSSS WITH (NOLOCK) ON TSSS.ID_TR_SALES_REFUND = TSD.ID_TR_SALES_REFUND
                    WHERE ((@online_eff = 0 AND DS.Store_Brand_ID_2 <> 'online') OR (@online_eff = 1 AND DS.Store_Brand_ID_2 IS NOT NULL))
                      AND TSD.TGL_REFUND >= @from AND TSD.TGL_REFUND < @toX
                      AND (@brand = 'ALL' OR DS.Store_Brand_ID = @brand)
                      AND (@store = 'ALL' OR TSD.ID_STORE = @store)
                      AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = TSD.ID_STORE COLLATE Latin1_General_CI_AS));
                ELSE
                    INSERT INTO #r (Store_ID, PLU, QTY, NET)
                    SELECT TSD.ID_STORE, NULL, CAST(TSD.DIST_QTY AS float), CAST(TSD.TOTAL_PRICE AS float)
                    FROM pos_server.dbo.TR_SALES_REFUND TSD WITH (NOLOCK)
                    LEFT OUTER JOIN pos_server.dbo.DT_Store DS WITH (NOLOCK) ON DS.Store_ID = TSD.ID_STORE
                    WHERE ((@online_eff = 0 AND DS.Store_Brand_ID_2 <> 'online') OR (@online_eff = 1 AND DS.Store_Brand_ID_2 IS NOT NULL))
                      AND TSD.TGL_REFUND >= @from AND TSD.TGL_REFUND < @toX
                      AND (@brand = 'ALL' OR DS.Store_Brand_ID = @brand)
                      AND (@store = 'ALL' OR TSD.ID_STORE = @store)
                      AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = TSD.ID_STORE COLLATE Latin1_General_CI_AS));
            END;

            IF @digit = 'FULL' AND @mode = 1
            BEGIN
                /* ===== FULL DETAIL (GETROWS / _hdate_GETROWS) ===== */
                INSERT INTO #out (NO_URUT, WAKTU_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT CASE WHEN @hide = 1 THEN NULL ELSE b.NO_URUT END,
                       CASE WHEN @hide = 1 THEN NULL ELSE FORMAT(b.WAKTU_URUT, 'yyyy-MM-dd') END,
                       b.Store_ID,
                       CASE WHEN @hide = 1 THEN NULL ELSE FORMAT(b.Tanggal, 'yyyy-MM-dd') END,
                       b.PLU, b.PRICE, b.HPP, b.HPP * b.QTY, b.MARGIN, b.QTY, b.LABA, b.SALES, b.DISCOUNT, b.PP,
                       b.NET_SALES, b.NET_LABA,
                       (b.NET_SALES - b.HPP * b.QTY) / NULLIF(b.NET_SALES, 0) * 100, 0
                FROM #b b;

                INSERT INTO #out (NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT CASE WHEN @hide = 1 THEN NULL ELSE 0 END, NULL, NULL, r.PLU, 0, 0, 0, 0, -r.QTY, 0, 0, 0, 0, -r.NET, 0, 0, 1
                FROM #r r;
            END
            ELSE IF @digit = 'FULL' AND @mode = 2
            BEGIN
                /* ===== FULL TOTAL (TOTAL_GETROWS): group PLU + store ===== */
                INSERT INTO #out (NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT 0, b.Store_ID, NULL, b.PLU, SUM(b.PRICE), SUM(b.HPP), 0, SUM(b.MARGIN), SUM(b.QTY), SUM(b.LABA),
                       SUM(b.SALES), SUM(b.DISCOUNT), SUM(b.PP), SUM(b.NET_SALES), SUM(b.NET_LABA), 0, 0
                FROM #b b GROUP BY b.PLU, b.Store_ID;

                INSERT INTO #out (NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT 0, NULL, NULL, r.PLU, 0, 0, 0, 0, -r.QTY, 0, 0, 0, 0, -r.NET, 0, 0, 1
                FROM #r r;
            END
            ELSE IF @digit = '3' AND @mode = 1
            BEGIN
                /* ===== PLU3 DETAIL: store + tanggal + LEFT(PLU,3) ===== */
                INSERT INTO #out (NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT 0, b.Store_ID, FORMAT(b.Tanggal, 'yyyy-MM-dd'), LEFT(b.PLU, 3), SUM(b.PRICE), SUM(b.HPP), 0, SUM(b.MARGIN),
                       SUM(b.QTY), SUM(b.LABA), SUM(b.SALES), SUM(b.DISCOUNT), SUM(b.PP), SUM(b.NET_SALES), SUM(b.NET_LABA), 0, 0
                FROM #b b GROUP BY b.Store_ID, b.Tanggal, LEFT(b.PLU, 3);

                INSERT INTO #out (NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT 0, NULL, NULL, LEFT(r.PLU, 3), 0, 0, 0, 0, -r.QTY, 0, 0, 0, 0, -r.NET, 0, 0, 1
                FROM #r r;
            END
            ELSE IF @digit = '3' AND @mode = 2
            BEGIN
                /* ===== PLU3 TOTAL: store + LEFT(PLU,3); ALL/ALL excludes stores 7777 / '' ===== */
                INSERT INTO #out (NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT 0, b.Store_ID, NULL, LEFT(b.PLU, 3), SUM(b.PRICE), SUM(b.HPP), 0, SUM(b.MARGIN), SUM(b.QTY), SUM(b.LABA),
                       SUM(b.SALES), SUM(b.DISCOUNT), SUM(b.PP), SUM(b.NET_SALES), SUM(b.NET_LABA), 0, 0
                FROM #b b
                WHERE NOT (@brand = 'ALL' AND @store = 'ALL' AND b.Store_ID IN ('7777',''))
                GROUP BY b.Store_ID, LEFT(b.PLU, 3);

                INSERT INTO #out (NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT 0, NULL, NULL, LEFT(r.PLU, 3), 0, 0, 0, 0, -r.QTY, 0, 0, 0, 0, -r.NET, 0, 0, 1
                FROM #r r
                WHERE NOT (@brand = 'ALL' AND @store = 'ALL' AND r.Store_ID IN ('7777',''));
            END
            ELSE IF @digit = '1' AND @mode = 1
            BEGIN
                /* ===== PLU1 DETAIL: store + tanggal + LEFT(PLU,1); HPP = SUM(HPP) ===== */
                INSERT INTO #out (NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT 0, b.Store_ID, FORMAT(b.Tanggal, 'yyyy-MM-dd'), LEFT(b.PLU, 1), SUM(b.PRICE), SUM(b.HPP), 0, SUM(b.MARGIN),
                       SUM(b.QTY), SUM(b.LABA), SUM(b.SALES), SUM(b.DISCOUNT), SUM(b.PP), SUM(b.NET_SALES), SUM(b.NET_LABA), 0, 0
                FROM #b b GROUP BY b.Store_ID, b.Tanggal, LEFT(b.PLU, 1);
            END
            ELSE IF @digit = '1' AND @mode = 2
            BEGIN
                /* ===== PLU1 TOTAL: store + LEFT(PLU,1); HPP = SUM(HPP*QTY) ===== */
                INSERT INTO #out (NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT 0, b.Store_ID, NULL, LEFT(b.PLU, 1), SUM(b.PRICE), SUM(b.HPP * b.QTY), 0, SUM(b.MARGIN), SUM(b.QTY), SUM(b.LABA),
                       SUM(b.SALES), SUM(b.DISCOUNT), SUM(b.PP), SUM(b.NET_SALES), SUM(b.NET_LABA), 0, 0
                FROM #b b GROUP BY b.Store_ID, LEFT(b.PLU, 1);
            END
            ELSE
            BEGIN
                /* ===== GRAND TOTAL per store (PLU_GRAD_TOTAL): HPP = SUM(HPP*QTY); ALL/ALL excludes PLASTIK ===== */
                INSERT INTO #out (NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA, NET_PERSENTASE, SORT_NULL)
                SELECT 0, x.Store_ID, NULL, NULL, SUM(x.PRICE), SUM(x.HPP), 0, SUM(x.MARGIN), SUM(x.QTY), SUM(x.LABA),
                       SUM(x.SALES), SUM(x.DISCOUNT), SUM(x.PP), SUM(x.NET_SALES), SUM(x.NET_LABA),
                       (SUM(x.NET_SALES) - SUM(x.HPP)) / NULLIF(SUM(x.NET_SALES), 0) * 100, 0
                FROM (
                    SELECT b.Store_ID, b.PRICE, b.HPP * b.QTY AS HPP, b.MARGIN, b.QTY, b.LABA, b.SALES, b.DISCOUNT, b.PP, b.NET_SALES, b.NET_LABA
                    FROM #b b
                    WHERE NOT (@brand = 'ALL' AND @store = 'ALL')
                       OR EXISTS (SELECT 1 FROM pos_server.dbo.DT_PLU dp WITH (NOLOCK) WHERE dp.PLU = b.PLU AND dp.ARTICLE <> 'PLASTIK')
                    UNION ALL
                    SELECT r.Store_ID, 0, 0, 0, -r.QTY, 0, 0, 0, 0, -r.NET, 0
                    FROM #r r
                ) x
                GROUP BY x.Store_ID;
            END;

            DROP TABLE #b;
            DROP TABLE #r;
        END;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT NO_URUT, WAKTU_URUT, Store_ID, tanggal, PLU, PRICE, HPP, HPP_TOTAL, MARGIN, QTY, LABA, SALES,
                              DISCOUNT, PP, NET_SALES, NET_LABA, ISNULL(NET_PERSENTASE, 0) AS NET_PERSENTASE
                       FROM #out
                       ORDER BY ISNULL(SORT_NULL, 0), Store_ID, tanggal, PLU
                       FOR JSON PATH, INCLUDE_NULL_VALUES
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        DROP TABLE #out;
        DROP TABLE #sc;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#b') IS NOT NULL DROP TABLE #b;
        IF OBJECT_ID('tempdb..#r') IS NOT NULL DROP TABLE #r;
        IF OBJECT_ID('tempdb..#out') IS NOT NULL DROP TABLE #out;
        IF OBJECT_ID('tempdb..#sc') IS NOT NULL DROP TABLE #sc;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
