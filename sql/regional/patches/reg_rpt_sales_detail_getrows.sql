/*
  Sales Detail / DAILY SALES DETAIL (REG2)
  Legacy page : module/Rpt/Seles_Detail.aspx (REG role — NOT Sales_Detail.aspx item list)
  Legacy SPs ported (pos_server.dbo.* only — NEVER EXEC / alter legacy):
     XSP_RPT_SALES_HEADER_GETROWS           @p_tipe = POS
     XSP_RPT_SALES_HEADER_ONLINE_GETROWS    @p_tipe = ONLINE
     XSP_RPT_SALES_HEADER_ALL_GETROWS       @p_tipe = ALL  (+ totals)
     XSP_RPT_SALES_HEADER_ALL_TOTAL_GETROW  embedded when ALL
     XSP_RPT_SALES_DETAIL_WOMAN_GETROWS     @p_tipe = WOMAN

  Param map (Go regListHandler):
     @p_tipe       = POS | ONLINE | ALL | WOMAN
     @p_id_brand / @p_id_store / @p_from_date / @p_to_date
     @p_id_gh / @p_gh_id / @p_actor_nik  = regional scope
     @p_confirm_status = rolle_code (ONLINE image upload visibility; REG = 5 → no upload)

  JSON:
     POS/ONLINE/WOMAN: { responseCode, responseMessage, data:[...] }
     ALL:              { ..., data:[...], totals:{ TOTAL_POS, TOTAL_ONLINE_ORDER, GRAND_TOTAL } }
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_sales_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_detail_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_detail_getrows
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

        DECLARE @tipe varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(@p_tipe,'POS'))));
        IF @tipe NOT IN ('POS','ONLINE','ALL','WOMAN') SET @tipe = 'POS';

        DECLARE @rolle varchar(20) = LTRIM(RTRIM(ISNULL(@p_confirm_status,'5')));
        IF @rolle = '' SET @rolle = '5';

        /* -------- GH / regional scope -------- */
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

        /* ===================== WOMAN (item-level) ===================== */
        IF @tipe = 'WOMAN'
        BEGIN
            CREATE TABLE #fc (kode varchar(10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY);
            INSERT INTO #fc (kode)
            SELECT DISTINCT LTRIM(RTRIM(KODE)) COLLATE SQL_Latin1_General_CP1_CI_AS
            FROM spacex.dbo.master_class WITH (NOLOCK)
            WHERE GENDER = 'female' AND KODE IS NOT NULL;

            DECLARE @woman_json nvarchar(max);
            SET @woman_json = ISNULL((
                SELECT
                    ROW_NUMBER() OVER (ORDER BY ds.Store_ID ASC, tsh.Tanggal_Transaksi, tsd.PLU) AS NO,
                    ds.Store_ID + ' - ' + ISNULL(ds.Store_Kota,'') AS ID_STORE,
                    tsd.PLU,
                    FORMAT(tsh.Tanggal_Transaksi, 'yyyy-MM-dd HH:mm:ss') AS TGL,
                    tsd.ARTICLE,
                    tsd.DESKRIPSI,
                    tsd.HPP,
                    tsd.PPN,
                    tsd.Harga_Jual,
                    tsd.QTY,
                    tsd.Net AS NET
                FROM pos_server.dbo.TR_SALES_HEADER tsh WITH (NOLOCK)
                INNER JOIN pos_server.dbo.TR_SALES_DETAIL tsd WITH (NOLOCK)
                    ON tsd.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
                INNER JOIN #fc fc ON fc.kode = LEFT(tsd.PLU, 3) COLLATE SQL_Latin1_General_CP1_CI_AS
                LEFT JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK)
                    ON ds.Store_ID = tsd.ID_Store
                WHERE tsh.Tanggal_Transaksi >= @from AND tsh.Tanggal_Transaksi < @toX
                  AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = tsd.ID_Store COLLATE Latin1_General_CI_AS))
                ORDER BY ds.Store_ID, tsh.Tanggal_Transaksi, tsd.PLU
                FOR JSON PATH, INCLUDE_NULL_VALUES
            ), N'[]');

            DROP TABLE #fc;
            SET @bitparam = CONCAT(
                N'{"responseCode":"2002500","responseMessage":"success","data":', @woman_json, N'}');
            DROP TABLE #sc;
            RETURN;
        END;

        /* ===================== POS / ONLINE / ALL (header) ===================== */
        CREATE TABLE #hdr (
            NO_URUT            bigint NULL,
            WAKTU_URUT         datetime NULL,
            ID_TR_SALES_HEADER varchar(50) COLLATE Latin1_General_CI_AS NULL,
            BILLING_CODE       varchar(20) NULL,
            ID_STORE           varchar(50) NULL,
            ID_USER            varchar(50) NULL,
            TANGGAL_TRANSAKSI  varchar(30) NULL,
            QTY                decimal(19,2) NULL,
            TOTAL_HPP         decimal(19,2) NULL,
            PPN                decimal(19,2) NULL,
            SUB_TOTAL          decimal(19,2) NULL,
            TOTAL_DISCOUNT    decimal(19,2) NULL,
            PERSONAL_DISCOUNT_PERSEN decimal(19,2) NULL,
            PERSONAL_DISCOUNT  decimal(19,2) NULL,
            GRAND_TOTAL        decimal(19,2) NULL,
            STATUS_ECR         varchar(20) NULL,
            STYLE_STATUS       varchar(80) NULL,
            NIK_AC_NON_ECR     varchar(50) NULL,
            DISABLE_NIK        varchar(40) NULL,
            STATUS             varchar(40) NULL,
            BGCLASS            varchar(40) NULL,
            IMAGE              varchar(260) NULL,
            BUTTON_UPLOAD_STATUS varchar(40) NULL,
            IMAGE_DISPLAY_STATUS varchar(20) NULL,
            DISPLAY            varchar(20) NULL,
            DISPLAY_UPLOAD     varchar(20) NULL,
            SORT_STATUS        varchar(40) NULL
        );

        ;WITH refund AS (
            SELECT ID_TR_SALES_HEADER, TIPE_BAYAR, BAYAR
            FROM pos_server.dbo.TR_SALES_PAYMENT_DETAIL WITH (NOLOCK)
            WHERE TIPE_BAYAR = 'NILAI REFUND'
        ),
        qris AS (
            SELECT ID_TR_SALES_HEADER, TIPE_BAYAR, BAYAR
            FROM pos_server.dbo.TR_SALES_PAYMENT_DETAIL WITH (NOLOCK)
            WHERE TIPE_BAYAR = 'K.QRIS'
        ),
        base AS (
            SELECT
                tsh.NO_URUT,
                tsh.WAKTU_URUT,
                tsh.ID_TR_SALES_HEADER,
                LEFT(tsh.ID_TR_SALES_HEADER, 6) + RIGHT(tsh.ID_TR_SALES_HEADER, 6) AS BILLING_CODE,
                tsh.ID_Store AS ID_STORE,
                tsh.ID_User AS ID_USER,
                FORMAT(tsh.Tanggal_Transaksi, 'yyyy-MM-dd HH:mm:ss') AS TANGGAL_TRANSAKSI,
                SUM(ISNULL(tsd.QTY, 0)) AS QTY,
                SUM(CASE WHEN tsd.QTY > 0 THEN tsd.QTY * tsd.HPP ELSE 0 END) AS TOTAL_HPP,
                tsh.PPN,
                tsh.Sub_Total AS SUB_TOTAL,
                tsh.Total_Discount AS TOTAL_DISCOUNT,
                tsh.Personal_Discount_Persen AS PERSONAL_DISCOUNT_PERSEN,
                tsh.Personal_Discount AS PERSONAL_DISCOUNT,
                CASE
                    WHEN r.TIPE_BAYAR = 'Nilai Refund' THEN tsh.Grand_Total - ISNULL(r.BAYAR, 0)
                    ELSE tsh.Grand_Total
                END AS GRAND_TOTAL_RAW,
                tsh.ecr,
                tsh.NIK_AC_NON_ECR,
                tsh.order_online,
                tsh.COD,
                tsh.Bon_Manual,
                q.TIPE_BAYAR AS QRIS_TIPE
            FROM pos_server.dbo.TR_SALES_HEADER tsh WITH (NOLOCK)
            LEFT JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK)
                ON ds.Store_ID = tsh.ID_Store
            LEFT JOIN pos_server.dbo.TR_SALES_DETAIL tsd WITH (NOLOCK)
                ON tsd.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
            LEFT JOIN refund r
                ON r.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
            LEFT JOIN qris q
                ON q.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
            WHERE tsh.Tanggal_Transaksi >= @from AND tsh.Tanggal_Transaksi < @toX
              AND tsh.Status_Transaksi = 1
              AND (tsd.PLU IS NULL OR LEFT(tsd.PLU, 2) <> '01')
              AND ds.Store_ID NOT IN ('01E','02E','03E','04E','05E','06E','07E','08E','09E','10E','11E')
              AND (@brand = 'ALL' OR ds.Store_Brand_ID = @brand)
              AND (@store = 'ALL' OR tsh.ID_Store = @store)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = tsh.ID_Store COLLATE Latin1_General_CI_AS))
              AND (
                    (@tipe = 'POS' AND ISNULL(tsh.Bon_Manual, 0) = 0 AND (tsh.order_online = 0 OR tsh.order_online IS NULL))
                 OR (@tipe = 'ONLINE' AND tsh.order_online IN (1, 2))
                 OR (@tipe = 'ALL')
              )
            GROUP BY
                tsh.NO_URUT, tsh.WAKTU_URUT, tsh.ID_TR_SALES_HEADER, tsh.ID_Store, tsh.ID_User,
                tsh.Tanggal_Transaksi, tsh.PPN, tsh.Sub_Total, tsh.Total_Discount,
                tsh.Personal_Discount_Persen, tsh.Personal_Discount, tsh.Grand_Total,
                r.TIPE_BAYAR, r.BAYAR, tsh.ecr, tsh.NIK_AC_NON_ECR, tsh.order_online, tsh.COD,
                tsh.Bon_Manual, q.TIPE_BAYAR
        )
        INSERT INTO #hdr (
            NO_URUT, WAKTU_URUT, ID_TR_SALES_HEADER, BILLING_CODE, ID_STORE, ID_USER,
            TANGGAL_TRANSAKSI, QTY, TOTAL_HPP, PPN, SUB_TOTAL, TOTAL_DISCOUNT,
            PERSONAL_DISCOUNT_PERSEN, PERSONAL_DISCOUNT, GRAND_TOTAL,
            STATUS_ECR, STYLE_STATUS, NIK_AC_NON_ECR, DISABLE_NIK,
            STATUS, BGCLASS, SORT_STATUS
        )
        SELECT
            b.NO_URUT,
            b.WAKTU_URUT,
            b.ID_TR_SALES_HEADER,
            b.BILLING_CODE,
            b.ID_STORE,
            b.ID_USER,
            b.TANGGAL_TRANSAKSI,
            b.QTY,
            b.TOTAL_HPP,
            b.PPN,
            b.SUB_TOTAL,
            b.TOTAL_DISCOUNT,
            b.PERSONAL_DISCOUNT_PERSEN,
            b.PERSONAL_DISCOUNT,
            CASE WHEN ISNULL(b.GRAND_TOTAL_RAW, 0) <= 0 THEN 0 ELSE b.GRAND_TOTAL_RAW END,
            CASE WHEN b.ecr = 1 THEN 'ECR' ELSE 'NON ECR' END,
            CASE WHEN b.ecr = 1 THEN 'style="color:darkcyan"' ELSE 'style="color:black"' END,
            b.NIK_AC_NON_ECR,
            CASE WHEN b.ecr = 1 THEN 'style="display:none"' ELSE 'style="display:block"' END,
            /* STATUS / BGCLASS */
            CASE
                WHEN @tipe = 'ALL' THEN
                    CASE WHEN ISNULL(b.order_online, 0) = 0 THEN 'POS' WHEN b.order_online = 1 THEN 'ONLINE' END
                WHEN @tipe = 'ONLINE' THEN
                    CASE
                        WHEN b.order_online = 1 AND ISNULL(b.COD, 0) = 0 AND b.QRIS_TIPE = 'K.QRIS' THEN 'QRIS'
                        WHEN ISNULL(b.order_online, 0) = 0 AND ISNULL(b.COD, 0) = 1 AND b.QRIS_TIPE = 'K.QRIS' THEN 'QRIS'
                        WHEN b.order_online = 1 AND ISNULL(b.COD, 0) = 0 THEN 'DIRECT SELLING'
                        WHEN b.order_online = 1 AND ISNULL(b.COD, 0) = 1 THEN 'CASH ON DELIVERY'
                    END
                ELSE NULL
            END,
            CASE
                WHEN @tipe = 'ALL' THEN
                    CASE WHEN ISNULL(b.order_online, 0) = 0 THEN 'badge bg-important' WHEN b.order_online = 1 THEN 'badge bg-success' END
                WHEN @tipe = 'ONLINE' THEN
                    CASE
                        WHEN b.order_online = 1 AND ISNULL(b.COD, 0) = 0 AND b.QRIS_TIPE = 'K.QRIS' THEN 'badge bg-warning'
                        WHEN ISNULL(b.order_online, 0) = 0 AND ISNULL(b.COD, 0) = 1 AND b.QRIS_TIPE = 'K.QRIS' THEN 'badge bg-warning'
                        WHEN b.order_online = 1 AND ISNULL(b.COD, 0) = 0 THEN 'badge bg-info'
                        WHEN b.order_online = 1 AND ISNULL(b.COD, 0) = 1 THEN 'badge bg-success'
                    END
                ELSE NULL
            END,
            CASE
                WHEN @tipe = 'ONLINE' THEN
                    CASE
                        WHEN b.order_online = 1 AND ISNULL(b.COD, 0) = 0 AND b.QRIS_TIPE = 'K.QRIS' THEN 'QRIS'
                        WHEN ISNULL(b.order_online, 0) = 0 AND ISNULL(b.COD, 0) = 1 AND b.QRIS_TIPE = 'K.QRIS' THEN 'QRIS'
                        WHEN b.order_online = 1 AND ISNULL(b.COD, 0) = 0 THEN 'DIRECT SELLING'
                        WHEN b.order_online = 1 AND ISNULL(b.COD, 0) = 1 THEN 'CASH ON DELIVERY'
                    END
                ELSE NULL
            END
        FROM base b;

        /* ONLINE: bukti image + display flags */
        IF @tipe = 'ONLINE'
        BEGIN
            UPDATE h
            SET
                IMAGE = CASE WHEN ISNULL(b.IMAGE, '') = '' THEN 'NoimageUpload.png' ELSE b.IMAGE END,
                BUTTON_UPLOAD_STATUS = CASE WHEN ISNULL(b.IMAGE, '') = '' THEN 'Upload Bukti' ELSE 'Update Bukti' END,
                IMAGE_DISPLAY_STATUS = CASE WHEN ISNULL(b.IMAGE, '') = '' THEN 'none' ELSE 'normal' END,
                DISPLAY = CASE WHEN h.STATUS = 'CASH ON DELIVERY' THEN 'none' ELSE 'normal' END,
                DISPLAY_UPLOAD = CASE
                    WHEN h.STATUS = 'CASH ON DELIVERY' THEN 'none'
                    WHEN h.STATUS = 'DIRECT SELLING' AND @rolle = '1' THEN 'normal'
                    WHEN h.STATUS = 'DIRECT SELLING' AND @rolle <> '1' THEN 'none'
                    ELSE 'none'
                END
            FROM #hdr h
            LEFT JOIN pos_server.dbo.WEB_BUKTI_DIRECT_SELLING b WITH (NOLOCK)
                ON b.ID_TR_SALES_HEADER COLLATE SQL_Latin1_General_CP1_CI_AS
                 = h.ID_TR_SALES_HEADER COLLATE SQL_Latin1_General_CP1_CI_AS;
        END;

        DECLARE @data_json nvarchar(max);
        IF @tipe = 'ONLINE'
            SET @data_json = ISNULL((
                SELECT NO_URUT, ID_TR_SALES_HEADER, BILLING_CODE, ID_STORE, ID_USER, TANGGAL_TRANSAKSI,
                       QTY, TOTAL_HPP, PPN, SUB_TOTAL, TOTAL_DISCOUNT, PERSONAL_DISCOUNT_PERSEN,
                       PERSONAL_DISCOUNT, GRAND_TOTAL, STATUS, BGCLASS, IMAGE, BUTTON_UPLOAD_STATUS,
                       IMAGE_DISPLAY_STATUS, DISPLAY, DISPLAY_UPLOAD
                FROM #hdr
                ORDER BY SORT_STATUS DESC, TANGGAL_TRANSAKSI DESC
                FOR JSON PATH, INCLUDE_NULL_VALUES
            ), N'[]');
        ELSE IF @tipe = 'ALL'
            SET @data_json = ISNULL((
                SELECT NO_URUT, ID_TR_SALES_HEADER, BILLING_CODE, ID_STORE, ID_USER, TANGGAL_TRANSAKSI,
                       QTY, TOTAL_HPP, PPN, SUB_TOTAL, TOTAL_DISCOUNT, PERSONAL_DISCOUNT_PERSEN,
                       PERSONAL_DISCOUNT, GRAND_TOTAL, STATUS, BGCLASS
                FROM #hdr
                ORDER BY TANGGAL_TRANSAKSI DESC
                FOR JSON PATH, INCLUDE_NULL_VALUES
            ), N'[]');
        ELSE
            SET @data_json = ISNULL((
                SELECT NO_URUT, ID_TR_SALES_HEADER, BILLING_CODE, ID_STORE, ID_USER, TANGGAL_TRANSAKSI,
                       QTY, TOTAL_HPP, PPN, SUB_TOTAL, TOTAL_DISCOUNT, PERSONAL_DISCOUNT_PERSEN,
                       PERSONAL_DISCOUNT, GRAND_TOTAL, STATUS_ECR, STYLE_STATUS, NIK_AC_NON_ECR, DISABLE_NIK
                FROM #hdr
                ORDER BY TANGGAL_TRANSAKSI DESC
                FOR JSON PATH, INCLUDE_NULL_VALUES
            ), N'[]');

        IF @tipe = 'ALL'
        BEGIN
            /* totals: POS (non-online, non-manual) + ONLINE — same spirit as ALL_TOTAL_GETROW */
            DECLARE @tot_pos decimal(19,2) = 0;
            DECLARE @tot_online decimal(19,2) = 0;

            SELECT @tot_pos = ISNULL(SUM(CASE WHEN ISNULL(tsh.order_online, 0) = 0 AND ISNULL(tsh.Bon_Manual, 0) = 0 THEN tsh.Grand_Total ELSE 0 END), 0),
                   @tot_online = ISNULL(SUM(CASE WHEN tsh.order_online = 1 THEN tsh.Grand_Total ELSE 0 END), 0)
            FROM pos_server.dbo.TR_SALES_HEADER tsh WITH (NOLOCK)
            LEFT JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = tsh.ID_Store
            WHERE tsh.Tanggal_Transaksi >= @from AND tsh.Tanggal_Transaksi < @toX
              AND tsh.Status_Transaksi = 1
              AND ds.Store_ID NOT IN ('01E','02E','03E','04E','05E','06E','07E','08E','09E','10E','11E')
              AND (@brand = 'ALL' OR ds.Store_Brand_ID = @brand)
              AND (@store = 'ALL' OR tsh.ID_Store = @store)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = tsh.ID_Store COLLATE Latin1_General_CI_AS));

            DECLARE @totals_json nvarchar(max) = (
                SELECT
                    CONVERT(decimal(18,2), @tot_pos) AS TOTAL_POS,
                    CONVERT(decimal(18,2), 0) AS TOTAL_BON_MANUAL,
                    CONVERT(decimal(18,2), @tot_online) AS TOTAL_ONLINE_ORDER,
                    CONVERT(decimal(18,2), @tot_pos + @tot_online) AS GRAND_TOTAL
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

            SET @bitparam = CONCAT(
                N'{"responseCode":"2002500","responseMessage":"success","data":', @data_json,
                N',"totals":', @totals_json, N'}');
        END
        ELSE
        BEGIN
            SET @bitparam = CONCAT(
                N'{"responseCode":"2002500","responseMessage":"success","data":', @data_json, N'}');
        END;

        DROP TABLE #hdr;
        DROP TABLE #sc;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#hdr') IS NOT NULL DROP TABLE #hdr;
        IF OBJECT_ID('tempdb..#fc') IS NOT NULL DROP TABLE #fc;
        IF OBJECT_ID('tempdb..#sc') IS NOT NULL DROP TABLE #sc;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
