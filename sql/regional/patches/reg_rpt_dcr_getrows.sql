/*
  DCR - Daily Collection Report (REG2) - NEW SP on RBACESS, COMPOSITE (4 sections of legacy Dcr_rpt.aspx).
  Legacy page: module/Rpt/Dcr_rpt.aspx  (role REG 5/6/70/696/33).
  Ported from (pos_server.dbo.* only; legacy SPs are NEVER EXEC'd / altered):
     1. batch   <- XSP_RPT_DCR_batch_h_GETROW               (BATCH, START_DATE, CLOSING_DATE)
     2. data    <- XSP_RPT_DCR_DAILY_S_SALES_S_GETROWS      (brand+store branch; sales + refund + shopping bag)
     3. payment <- XSP_RPT_DCR_DT_BANK_range_reg_GETROWS    (RPT_DCR_DT_BANK non-XSP SP does not exist; numbers summed
                                                              over the selected stores instead of a formatted pivot row)
     4. cash_detail <- XSP_RPT_DCR_DT_BATCH_D_GETROWS       (TI22_CASH, TI22, PU94_CASH, PU94)
  ALWAYS the date range from_date..to_date for every brand/store combination (ALL brand / ALL store = no filter).
  GH / regional scope is applied through MASTER_GH_DETAIL / MASTER_REGIONAL_DETAIL when @p_id_gh (or actor) is a known GH/regional id.
  JSON: { responseCode, responseMessage, batch:{...}, data:[sales], payment:{...}, cash_detail:[...] }
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_dcr_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_dcr_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_dcr_getrows
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
        DECLARE @from date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_from_date,''), NULLIF(@p_tgl,'')),''))),'') AS date);
        DECLARE @to   date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date,''))),'') AS date);
        IF @from IS NULL SET @from = CAST(GETDATE() AS date);
        IF @to IS NULL SET @to = @from;
        IF @to < @from SET @to = @from;
        DECLARE @toX date = DATEADD(DAY, 1, @to);

        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), NULLIF(@p_brand,'')), 'ALL'))));
        IF @brand IN ('','0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), NULLIF(@p_store_id,'')), 'ALL'))));
        IF @store IN ('','0') SET @store = 'ALL';

        /* ---------------- GH / regional scope (MASTER_GH_DETAIL) ---------------- */
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

        /* ---------------- 1. BATCH header ---------------- */
        DECLARE @batch_json nvarchar(max);
        SET @batch_json = (
            SELECT
                CASE WHEN @from = @to THEN CONVERT(varchar(10), @from, 23)
                     ELSE CONVERT(varchar(10), @from, 23) + ' s/d ' + CONVERT(varchar(10), @to, 23) END AS BATCH,
                ISNULL(FORMAT(MIN(db.Start_Date), 'yyyy-MM-dd HH:mm'), '') AS START_DATE,
                CASE WHEN COUNT(*) = COUNT(db.Closing_Date) THEN ISNULL(FORMAT(MAX(db.Closing_Date), 'yyyy-MM-dd HH:mm'), '') ELSE '' END AS CLOSING_DATE,
                COUNT(*) AS BATCH_COUNT,
                COUNT(*) - COUNT(db.Closing_Date) AS OPEN_COUNT
            FROM pos_server.dbo.DT_BATCH db WITH (NOLOCK)
            LEFT OUTER JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = db.Store_ID
            WHERE db.Tgl >= @from AND db.Tgl < @toX
              AND (@brand = 'ALL' OR ds.Store_Brand_ID = @brand)
              AND (@store = 'ALL' OR db.Store_ID = @store)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = db.Store_ID COLLATE Latin1_General_CI_AS))
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        IF @batch_json IS NULL
            SET @batch_json = N'{"BATCH":"","START_DATE":"","CLOSING_DATE":"","BATCH_COUNT":0,"OPEN_COUNT":0}';

        /* ---------------- 2. SALES (DCR_DAILY_S_SALES_S) ---------------- */
        CREATE TABLE #sales (
            NO_URUT int NULL, Store_ID varchar(50) NULL, tanggal varchar(20) NULL, PLU varchar(200) NULL,
            PRICE decimal(19,2) NULL, HPP decimal(19,2) NULL, MARGIN decimal(19,2) NULL, QTY decimal(19,2) NULL,
            LABA decimal(19,2) NULL, SALES decimal(19,2) NULL, DISCOUNT decimal(19,2) NULL, PP decimal(19,2) NULL,
            NET_SALES decimal(19,2) NULL, NET_LABA decimal(19,2) NULL
        );

        INSERT INTO #sales
        SELECT 0, DSS.Store_ID, NULL, LEFT(DSS.PLU, 1) + N' - ' + ISNULL(WPD.KETERANGAN, ''),
               SUM(ISNULL(DSS.PRICE,0)), SUM(ISNULL(DSS.HPP,0)), SUM(ISNULL(DSS.MARGIN,0)), SUM(ISNULL(DSS.QTY,0)),
               SUM(ISNULL(DSS.LABA,0)), SUM(ISNULL(DSS.SALES,0)), SUM(ISNULL(DSS.DISCOUNT,0)), SUM(ISNULL(DSS.PP,0)),
               SUM(ISNULL(DSS.NET_SALES,0)), SUM(ISNULL(DSS.NET_LABA,0))
        FROM pos_server.dbo.DT_SALES_SUMMARY DSS WITH (NOLOCK)
        LEFT OUTER JOIN pos_server.dbo.DT_Store DS WITH (NOLOCK) ON DS.Store_ID = DSS.Store_ID
        LEFT OUTER JOIN pos_server.dbo.WEB_PLU_DESC WPD WITH (NOLOCK) ON WPD.CODE = LEFT(DSS.PLU, 1)
        WHERE DSS.Tanggal >= @from AND DSS.Tanggal < @toX
          AND (@brand = 'ALL' OR DS.Store_Brand_ID = @brand)
          AND (@store = 'ALL' OR DSS.Store_ID = @store)
          AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = DSS.Store_ID COLLATE Latin1_General_CI_AS))
        GROUP BY LEFT(DSS.PLU, 1), DSS.Store_ID, WPD.KETERANGAN;

        /* refund rows (negative) - detail level QTY / PRICE / NET */
        INSERT INTO #sales
        SELECT 0, TSD.ID_STORE, NULL, LEFT(TSSS.PLU, 1) + N' - ' + ISNULL(WPD.KETERANGAN, ''),
               0, 0, 0, -SUM(ISNULL(TSSS.QTY,0)), 0, -SUM(ISNULL(TSSS.PRICE,0)), 0, 0, -SUM(ISNULL(TSSS.NET,0)), 0
        FROM pos_server.dbo.TR_SALES_REFUND TSD WITH (NOLOCK)
        LEFT OUTER JOIN pos_server.dbo.DT_Store DS WITH (NOLOCK) ON DS.Store_ID = TSD.ID_STORE
        INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL TSSS WITH (NOLOCK) ON TSSS.ID_TR_SALES_REFUND = TSD.ID_TR_SALES_REFUND
        LEFT OUTER JOIN pos_server.dbo.WEB_PLU_DESC WPD WITH (NOLOCK) ON WPD.CODE = LEFT(TSSS.PLU, 1)
        WHERE TSD.TGL_REFUND >= @from AND TSD.TGL_REFUND < @toX
          AND (@brand = 'ALL' OR DS.Store_Brand_ID = @brand)
          AND (@store = 'ALL' OR TSD.ID_STORE = @store)
          AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = TSD.ID_STORE COLLATE Latin1_General_CI_AS))
        GROUP BY LEFT(TSSS.PLU, 1), TSD.ID_STORE, WPD.KETERANGAN;

        /* shopping bag rows */
        INSERT INTO #sales
        SELECT 0, TSH.ID_STORE, NULL, LEFT(TSB.PLU, 1) + N' - SHOPPING BAG',
               0, 0, 0, SUM(ISNULL(TSB.QTY,0)), 0, SUM(ISNULL(TSB.QTY,0)) * ISNULL(TSB.Harga_Jual,0), 0, 0, SUM(ISNULL(TSB.Net,0)), 0
        FROM pos_server.dbo.TR_SALES_HEADER TSH WITH (NOLOCK)
        INNER JOIN pos_server.dbo.TR_SALES_SHOPPING_BAG TSB WITH (NOLOCK) ON TSB.ID_TR_SALES_HEADER = TSH.ID_TR_SALES_HEADER
        LEFT OUTER JOIN pos_server.dbo.DT_Store DS WITH (NOLOCK) ON DS.Store_ID = TSH.ID_STORE
        WHERE TSH.Tanggal_Transaksi >= @from AND TSH.Tanggal_Transaksi < @toX
          AND (@brand = 'ALL' OR DS.Store_Brand_ID = @brand)
          AND (@store = 'ALL' OR TSH.ID_STORE = @store)
          AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = TSH.ID_STORE COLLATE Latin1_General_CI_AS))
        GROUP BY TSH.ID_STORE, TSB.PLU, TSB.Harga_Jual;

        DECLARE @sales_json nvarchar(max);
        SET @sales_json = ISNULL((
            SELECT NO_URUT, Store_ID, tanggal, PLU, PRICE, HPP, MARGIN, QTY, LABA, SALES, DISCOUNT, PP, NET_SALES, NET_LABA
            FROM #sales ORDER BY Store_ID, PLU
            FOR JSON PATH, INCLUDE_NULL_VALUES
        ), N'[]');

        /* ---------------- 3. PAYMENT (DCR_DT_BANK_range_reg, summed over selected stores) ---------------- */
        DECLARE @payment_json nvarchar(max);
        ;WITH p AS (
            SELECT UPPER(LTRIM(RTRIM(A.TIPE_BAYAR))) AS tipe, ISNULL(A.BAYAR, 0) AS bayar,
                   B.order_online AS order_online, B.cod AS cod
            FROM pos_server.dbo.TR_SALES_PAYMENT_DETAIL A WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_HEADER B WITH (NOLOCK) ON B.ID_TR_SALES_HEADER = A.ID_TR_SALES_HEADER
            INNER JOIN pos_server.dbo.DT_Store DS WITH (NOLOCK) ON DS.Store_ID = B.ID_Store
            WHERE B.TANGGAL_TRANSAKSI >= @from AND B.TANGGAL_TRANSAKSI < @toX
              AND (@brand = 'ALL' OR DS.Store_Brand_ID = @brand)
              AND (@store = 'ALL' OR B.ID_Store = @store)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = B.ID_Store COLLATE Latin1_General_CI_AS))
        ), a AS (
            SELECT
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'CASH'           THEN bayar ELSE 0 END) AS cash_raw,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'CHANGE'         THEN bayar ELSE 0 END) AS change_raw,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'D.BCA'          THEN bayar ELSE 0 END) AS dbca,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'K.BCA'          THEN bayar ELSE 0 END) AS kbca,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'D.MANDIRI'      THEN bayar ELSE 0 END) AS dmandiri,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'K.MANDIRI'      THEN bayar ELSE 0 END) AS kmandiri,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'D.BNI'          THEN bayar ELSE 0 END) AS dbni,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'K.BNI'          THEN bayar ELSE 0 END) AS kbni,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'D.BRI'          THEN bayar ELSE 0 END) AS dbri,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'K.BRI'          THEN bayar ELSE 0 END) AS kbri,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'VOUCHER'        THEN bayar ELSE 0 END) AS voucher,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'VOUCHER_ONLINE' THEN bayar ELSE 0 END) AS voucher_online,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'K.OVO'          THEN bayar ELSE 0 END) AS kovo,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'K.ATOME'        THEN bayar ELSE 0 END) AS atome,
                SUM(CASE WHEN (order_online = 0 OR order_online IS NULL) AND tipe = 'K.INDODANA'     THEN bayar ELSE 0 END) AS indodana,
                SUM(CASE WHEN order_online IN (0,1) AND cod = 0 AND tipe = 'K.QRIS'                  THEN bayar ELSE 0 END) AS online_amt,
                SUM(CASE WHEN order_online = 1 AND cod = 1 AND tipe = 'K.QRIS'                       THEN bayar ELSE 0 END) AS cod_amt,
                SUM(CASE WHEN tipe = 'K.QRIS'                                                        THEN bayar ELSE 0 END) AS kqris,
                SUM(CASE WHEN tipe = 'D.QRIS BCA'                                                    THEN bayar ELSE 0 END) AS d_qris_bca,
                SUM(CASE WHEN tipe = 'D.QRIS BNI'                                                    THEN bayar ELSE 0 END) AS d_qris_bni,
                SUM(CASE WHEN tipe = 'D.QRIS BRI'                                                    THEN bayar ELSE 0 END) AS d_qris_bri,
                SUM(CASE WHEN tipe = 'D.QRIS MDR'                                                    THEN bayar ELSE 0 END) AS d_qris_mandiri
            FROM p
        )
        SELECT @payment_json = (
            SELECT
                CAST(ISNULL(cash_raw,0) + ISNULL(change_raw,0) AS decimal(19,2)) AS CASH,
                CAST(ISNULL(dbca,0) AS decimal(19,2)) AS DBCA,
                CAST(ISNULL(kbca,0) AS decimal(19,2)) AS KBCA,
                CAST(ISNULL(dmandiri,0) AS decimal(19,2)) AS DMANDIRI,
                CAST(ISNULL(kmandiri,0) AS decimal(19,2)) AS KMANDIRI,
                CAST(ISNULL(dbni,0) AS decimal(19,2)) AS DBNI,
                CAST(ISNULL(kbni,0) AS decimal(19,2)) AS KBNI,
                CAST(ISNULL(dbri,0) AS decimal(19,2)) AS DBRI,
                CAST(ISNULL(kbri,0) AS decimal(19,2)) AS KBRI,
                CAST(ISNULL(voucher,0) AS decimal(19,2)) AS VOUCHER,
                CAST(ISNULL(voucher_online,0) AS decimal(19,2)) AS VOUCHER_ONLINE,
                CAST(ISNULL(kovo,0) AS decimal(19,2)) AS KOVO,
                CAST(ISNULL(atome,0) AS decimal(19,2)) AS ATOME,
                CAST(ISNULL(indodana,0) AS decimal(19,2)) AS INDODANA,
                CAST(ISNULL(change_raw,0) AS decimal(19,2)) AS [CHANGE],
                CAST(ISNULL(online_amt,0) AS decimal(19,2)) AS ONLINE,
                CAST(ISNULL(cod_amt,0) AS decimal(19,2)) AS COD,
                CAST(ISNULL(kqris,0) AS decimal(19,2)) AS KQRIS,
                CAST(ISNULL(d_qris_bca,0) AS decimal(19,2)) AS D_QRIS_BCA,
                CAST(ISNULL(d_qris_bni,0) AS decimal(19,2)) AS D_QRIS_BNI,
                CAST(ISNULL(d_qris_bri,0) AS decimal(19,2)) AS D_QRIS_BRI,
                CAST(ISNULL(d_qris_mandiri,0) AS decimal(19,2)) AS D_QRIS_MANDIRI,
                CAST(ISNULL(cash_raw,0) + ISNULL(change_raw,0) + ISNULL(dbca,0) + ISNULL(kbca,0) + ISNULL(dmandiri,0) + ISNULL(kmandiri,0)
                   + ISNULL(dbni,0) + ISNULL(kbni,0) + ISNULL(dbri,0) + ISNULL(kbri,0) + ISNULL(voucher,0) + ISNULL(voucher_online,0)
                   + ISNULL(kovo,0) + ISNULL(atome,0) + ISNULL(indodana,0) + ISNULL(online_amt,0) + ISNULL(cod_amt,0)
                   + ISNULL(d_qris_bca,0) + ISNULL(d_qris_bni,0) + ISNULL(d_qris_bri,0) + ISNULL(d_qris_mandiri,0) AS decimal(19,2)) AS totalnyaLOH
            FROM a
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        IF @payment_json IS NULL SET @payment_json = N'{}';

        /* ---------------- 4. CASH DETAIL (DCR_DT_BATCH_D) ---------------- */
        DECLARE @cash_json nvarchar(max);
        SET @cash_json = ISNULL((
            SELECT db.No_Urut AS NO_URUT, db.Store_ID AS STORE_ID, CONVERT(varchar(10), db.Tgl, 23) AS TANGGAL,
                   CAST(ISNULL(db.TI22_CASH,0) AS decimal(19,2)) AS TI22_CASH,
                   CAST(ISNULL(db.PU94_CASH,0) AS decimal(19,2)) AS PU94_CASH,
                   ISNULL(wid.IMAGE_1, 'noimagefound.jpg') AS TI22,
                   ISNULL(wid.IMAGE_2, 'noimagefound.jpg') AS PU94
            FROM pos_server.dbo.DT_BATCH db WITH (NOLOCK)
            LEFT OUTER JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = db.Store_ID
            LEFT OUTER JOIN pos_server.dbo.WEB_IMAGE_DCR wid WITH (NOLOCK) ON wid.ID = db.DCR_ID
            WHERE db.Tgl >= @from AND db.Tgl < @toX
              AND (@brand = 'ALL' OR ds.Store_Brand_ID = @brand)
              AND (@store = 'ALL' OR db.Store_ID = @store)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = db.Store_ID COLLATE Latin1_General_CI_AS))
            ORDER BY db.Tgl, db.Store_ID, db.No_Urut
            FOR JSON PATH, INCLUDE_NULL_VALUES
        ), N'[]');

        SET @bitparam = CONCAT(
            N'{"responseCode":"2002500","responseMessage":"success",',
            N'"batch":', @batch_json,
            N',"data":', @sales_json,
            N',"payment":', @payment_json,
            N',"cash_detail":', @cash_json, N'}');

        DROP TABLE #sales;
        DROP TABLE #sc;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#sales') IS NOT NULL DROP TABLE #sales;
        IF OBJECT_ID('tempdb..#sc') IS NOT NULL DROP TABLE #sc;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
