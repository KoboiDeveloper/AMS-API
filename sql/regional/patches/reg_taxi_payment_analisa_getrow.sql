/*
  Taxi Analisa Payment — agregat dari logic AR Detail (payment) + Rico Summary (PLU).
  Output: 1 objek analisa (bukan raw rows). Dipanggil hanya via Go API.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_taxi_payment_analisa_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_taxi_payment_analisa_getrow;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_taxi_payment_analisa_getrow
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

        /* ---- Payment pivot (same channels as AR Detail export) ---- */
        CREATE TABLE #pay (
            STORE varchar(50) NOT NULL,
            TANGGAL varchar(10) NOT NULL,
            CASH float NOT NULL DEFAULT 0,
            CARD float NOT NULL DEFAULT 0,
            VOUCHER float NOT NULL DEFAULT 0,
            OVO float NOT NULL DEFAULT 0,
            KQRIS float NOT NULL DEFAULT 0,
            D_QRIS_BCA float NOT NULL DEFAULT 0,
            D_QRIS_BNI float NOT NULL DEFAULT 0,
            D_QRIS_BRI float NOT NULL DEFAULT 0,
            D_QRIS_MDR float NOT NULL DEFAULT 0,
            KATOME float NOT NULL DEFAULT 0,
            KINDODANA float NOT NULL DEFAULT 0,
            SISA_VOUCHER float NOT NULL DEFAULT 0,
            REFUND float NOT NULL DEFAULT 0,
            TOTAL float NOT NULL DEFAULT 0,
            TRX int NOT NULL DEFAULT 0
        );

        INSERT INTO #pay (STORE, TANGGAL, CASH, CARD, VOUCHER, OVO, KQRIS, D_QRIS_BCA, D_QRIS_BNI, D_QRIS_BRI, D_QRIS_MDR, KATOME, KINDODANA, SISA_VOUCHER, REFUND, TOTAL, TRX)
        SELECT
            a.ID_Store,
            CONVERT(varchar(10), a.Tanggal_Transaksi, 23),
            SUM(CASE WHEN c.TIPE_BAYAR = 'CASH' THEN c.BAYAR ELSE 0 END)
              + SUM(CASE WHEN c.TIPE_BAYAR = 'Change' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR IN ('K.BCA','K.BNI','K.BRI','K.MANDIRI','D.BCA','D.BNI','D.BRI','D.MANDIRI') THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR LIKE 'Voucher%' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR = 'K.OVO' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR = 'K.QRIS' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR = 'D.QRIS BCA' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR = 'D.QRIS BNI' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR = 'D.QRIS BRI' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR = 'D.QRIS MDR' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR = 'K.ATOME' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR = 'K.INDODANA' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR = 'sisa_Voucher' THEN c.BAYAR ELSE 0 END),
            SUM(CASE WHEN c.TIPE_BAYAR = 'Nilai Refund' THEN c.BAYAR ELSE 0 END),
            0,
            COUNT(DISTINCT a.ID_TR_SALES_HEADER)
        FROM pos_server.dbo.TR_SALES_HEADER a WITH (NOLOCK)
        INNER JOIN pos_server.dbo.TR_SALES_PAYMENT_DETAIL c WITH (NOLOCK)
            ON c.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER
        INNER JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = a.ID_Store
        WHERE a.Status_Transaksi = 1
          AND a.Tanggal_Transaksi >= @from AND a.Tanggal_Transaksi < @toX
          AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
          AND (@store_id = 'ALL' OR a.ID_Store = @store_id)
          AND (
                @store_id <> 'ALL'
             OR a.ID_Store NOT IN (
                    '000-RC','01C','02C','7777','888','999-RC','DEMO888','TST1','000-RIF','999-RIF','RIF888','RC888',
                    /* include marketplace 01e–06E,08E–11E (taxi analisa) */
                    '000-RM','999-RM','RM888','RQ888','777','dc000','dc111','dc222',
                    'dc888','dc999','01D','01K','01L','01M','02D','03D','04D','05D','06D','07D','07E','08D','09D','10D',
                    '11D','888-RC','888-RIF','888-RM','ART000','ART111','ART999','BZR01','07E','DS000','GA000','GA999',
                    'MS001','MS002','RC01K','WOL01E','WOL02E','WOL03E','WOL04E','WOL06E'
                )
          )
          AND (
                @brand_id <> 'ALL'
             OR ds.Store_Brand_ID NOT IN (
                    'AEESHA','ART VISUAL','CELCIUS KIDS','DC','DC OLD','GA','MINISTORE','POS TES','DS','KW2','WOL','TEST'
                )
          )
        GROUP BY a.ID_Store, CONVERT(varchar(10), a.Tanggal_Transaksi, 23);

        UPDATE #pay SET TOTAL =
            CASH + CARD + VOUCHER + OVO + KQRIS + D_QRIS_BCA + D_QRIS_BNI + D_QRIS_BRI + D_QRIS_MDR
          + KATOME + KINDODANA + SISA_VOUCHER - REFUND;

        /* ---- PLU summary (Rico) by store+day for banding ---- */
        CREATE TABLE #plu (
            STORE varchar(50) NOT NULL,
            TANGGAL varchar(10) NOT NULL,
            TOTAL float NOT NULL DEFAULT 0,
            PLU_ROWS int NOT NULL DEFAULT 0,
            PLU_SELISIH_ROWS int NOT NULL DEFAULT 0
        );

        ;WITH lines AS (
            SELECT
                tsh.ID_Store,
                tsh.ID_TR_SALES_HEADER,
                CONVERT(varchar(10), tsh.Tanggal_Transaksi, 23) AS tanggal,
                tsd.PLU,
                CAST(tsd.net AS float) AS Net,
                CAST(0 AS float) AS diskon,
                CAST(0 AS float) AS REFUND_TOT,
                CAST(0 AS float) AS PPLUS,
                CAST(tsd.net AS float) AS PRICE
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
              AND (
                    @store_id <> 'ALL'
                 OR tsh.ID_Store NOT IN (
                        '000-RC','01C','02C','7777','888','999-RC','DEMO888','TST1','000-RIF','999-RIF','RIF888','RC888',
                        /* include marketplace 01e–06E,08E–11E (taxi analisa) */
                        '000-RM','999-RM','RM888','RQ888','777','dc000','dc111','dc222',
                        'dc888','dc999','01D','01K','01L','01M','02D','03D','04D','05D','06D','07D','07E','08D','09D','10D',
                        '11D','888-RC','888-RIF','888-RM','ART000','ART111','ART999','BZR01','07E','DS000','GA000','GA999',
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
            SELECT tsh.ID_Store, tsh.ID_TR_SALES_HEADER, CONVERT(varchar(10), tsh.Tanggal_Transaksi, 23), tsd.PLU,
                   0, CAST(tsd.net AS float), 0, 0, 0
            FROM pos_server.dbo.TR_SALES_HEADER tsh WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_DETAIL tsd WITH (NOLOCK) ON tsd.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
            INNER JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = tsh.ID_Store
            WHERE tsh.Status_Transaksi = 1
              AND tsh.Tanggal_Transaksi >= @from AND tsh.Tanggal_Transaksi < @toX
              AND (tsd.DESKRIPSI LIKE '%PP-%' OR tsd.DESKRIPSI LIKE '%DISC-%')
              AND LEFT(CONVERT(varchar(40), tsd.net), 1) = '-'
              AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
              AND (@store_id = 'ALL' OR tsh.ID_Store = @store_id)
            UNION ALL
            SELECT tsh.ID_Store, tsh.ID_TR_SALES_HEADER, CONVERT(varchar(10), tsh.Tanggal_Transaksi, 23), tsd.PLU,
                   0, 0, 0, CAST(tsd.net AS float), 0
            FROM pos_server.dbo.TR_SALES_HEADER tsh WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_DETAIL tsd WITH (NOLOCK) ON tsd.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
            INNER JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = tsh.ID_Store
            WHERE tsh.Status_Transaksi = 1
              AND tsh.Tanggal_Transaksi >= @from AND tsh.Tanggal_Transaksi < @toX
              AND tsd.DESKRIPSI LIKE '%PP-%'
              AND LEFT(CONVERT(varchar(40), tsd.net), 1) <> '-'
              AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
              AND (@store_id = 'ALL' OR tsh.ID_Store = @store_id)
            UNION ALL
            SELECT tsr.ID_Store, tsr.ID_TR_SALES_HEADER, CONVERT(varchar(10), tsr.TGL_REFUND, 23), tsd.PLU,
                   0, 0, CAST(tsd.NET AS float), 0, 0
            FROM pos_server.dbo.TR_SALES_REFUND tsr WITH (NOLOCK)
            INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL tsd WITH (NOLOCK) ON tsd.ID_TR_SALES_REFUND = tsr.ID_TR_SALES_REFUND
            INNER JOIN pos_server.dbo.DT_Store ds WITH (NOLOCK) ON ds.Store_ID = tsr.ID_Store
            WHERE tsr.TGL_REFUND >= @from AND tsr.TGL_REFUND < @toX
              AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
              AND (@store_id = 'ALL' OR tsr.ID_Store = @store_id)
        ),
        line_agg AS (
            SELECT
                ID_Store AS STORE,
                tanggal AS TANGGAL,
                SUM(Net) + SUM(diskon) + SUM(PPLUS) - SUM(REFUND_TOT) AS TOTAL,
                SUM(PRICE) AS PRICE,
                SUM(diskon) + SUM(PPLUS) AS DISKON
            FROM lines
            GROUP BY ID_Store, ID_TR_SALES_HEADER, PLU, tanggal
        )
        INSERT INTO #plu (STORE, TANGGAL, TOTAL, PLU_ROWS, PLU_SELISIH_ROWS)
        SELECT
            STORE,
            TANGGAL,
            SUM(TOTAL),
            COUNT(*),
            SUM(CASE WHEN ABS(TOTAL - (PRICE + DISKON)) > 0.009 THEN 1 ELSE 0 END)
        FROM line_agg
        GROUP BY STORE, TANGGAL;

        /* Payment vs Summary by store + day */
        CREATE TABLE #gap (
            STORE varchar(50) NOT NULL,
            TANGGAL varchar(10) NOT NULL,
            payment float NOT NULL,
            summary float NOT NULL,
            selisih float NOT NULL
        );

        INSERT INTO #gap (STORE, TANGGAL, payment, summary, selisih)
        SELECT
            COALESCE(p.STORE, s.STORE),
            COALESCE(p.TANGGAL, s.TANGGAL),
            ISNULL(p.TOTAL, 0),
            ISNULL(s.TOTAL, 0),
            ISNULL(p.TOTAL, 0) - ISNULL(s.TOTAL, 0)
        FROM (
            SELECT STORE, TANGGAL, SUM(TOTAL) AS TOTAL FROM #pay GROUP BY STORE, TANGGAL
        ) p
        FULL OUTER JOIN (
            SELECT STORE, TANGGAL, SUM(TOTAL) AS TOTAL FROM #plu GROUP BY STORE, TANGGAL
        ) s ON s.STORE = p.STORE AND s.TANGGAL = p.TANGGAL;

        DECLARE @total_plu float = (SELECT ISNULL(SUM(TOTAL), 0) FROM #plu);
        DECLARE @plu_rows int = (SELECT ISNULL(SUM(PLU_ROWS), 0) FROM #plu);
        DECLARE @plu_selisih_rows int = (SELECT ISNULL(SUM(PLU_SELISIH_ROWS), 0) FROM #plu);
        DECLARE @total_pay float = (SELECT ISNULL(SUM(TOTAL), 0) FROM #pay);
        DECLARE @selisih float = @total_pay - @total_plu;
        DECLARE @trx int = (SELECT ISNULL(SUM(TRX), 0) FROM #pay);
        DECLARE @stores int = (SELECT COUNT(DISTINCT STORE) FROM #pay);
        DECLARE @gap_store_count int = (SELECT COUNT(*) FROM (SELECT STORE FROM #gap WHERE ABS(selisih) > 0.5 GROUP BY STORE) x);
        DECLARE @gap_day_count int = (SELECT COUNT(*) FROM #gap WHERE ABS(selisih) > 0.5);
        DECLARE @gap_pay_gt int = (SELECT COUNT(*) FROM #gap WHERE selisih > 0.5);
        DECLARE @gap_sum_gt int = (SELECT COUNT(*) FROM #gap WHERE selisih < -0.5);
        DECLARE @cash float = (SELECT ISNULL(SUM(CASH), 0) FROM #pay);
        DECLARE @card float = (SELECT ISNULL(SUM(CARD), 0) FROM #pay);
        DECLARE @voucher float = (SELECT ISNULL(SUM(VOUCHER), 0) FROM #pay);
        DECLARE @ovo float = (SELECT ISNULL(SUM(OVO), 0) FROM #pay);
        DECLARE @kqris float = (SELECT ISNULL(SUM(KQRIS), 0) FROM #pay);
        DECLARE @dqbca float = (SELECT ISNULL(SUM(D_QRIS_BCA), 0) FROM #pay);
        DECLARE @dqbni float = (SELECT ISNULL(SUM(D_QRIS_BNI), 0) FROM #pay);
        DECLARE @dqbri float = (SELECT ISNULL(SUM(D_QRIS_BRI), 0) FROM #pay);
        DECLARE @dqmdr float = (SELECT ISNULL(SUM(D_QRIS_MDR), 0) FROM #pay);
        DECLARE @atome float = (SELECT ISNULL(SUM(KATOME), 0) FROM #pay);
        DECLARE @indodana float = (SELECT ISNULL(SUM(KINDODANA), 0) FROM #pay);
        DECLARE @sisa float = (SELECT ISNULL(SUM(SISA_VOUCHER), 0) FROM #pay);
        DECLARE @refund float = (SELECT ISNULL(SUM(REFUND), 0) FROM #pay);

        DECLARE @insight varchar(500) =
            CASE
                WHEN ABS(@selisih) < 0.5 THEN N'Payment dan Summary cocok (selisih ~0).'
                WHEN @selisih < 0 THEN N'Payment lebih kecil dari Summary PLU. Cek store/hari di tabel selisih (payment kurang / summary lebih).'
                ELSE N'Payment lebih besar dari Summary PLU. Cek store/hari di tabel selisih (payment lebih / summary kurang).'
            END;

        SET @bitparam = (
            SELECT
                '2002500' AS responseCode,
                'success' AS responseMessage,
                JSON_QUERY((
                    SELECT
                        CONVERT(varchar(10), @from, 23) AS from_date,
                        CONVERT(varchar(10), @to, 23) AS to_date,
                        @trx AS trx_count,
                        @stores AS store_count,
                        @plu_rows AS plu_rows,
                        @plu_selisih_rows AS plu_selisih_rows,
                        @total_pay AS total_payment,
                        @total_plu AS total_summary,
                        @selisih AS selisih_payment_summary,
                        @gap_store_count AS selisih_store_count,
                        @gap_day_count AS selisih_day_count,
                        @gap_pay_gt AS selisih_payment_lebih_count,
                        @gap_sum_gt AS selisih_summary_lebih_count,
                        @insight AS selisih_insight,
                        @cash AS CASH,
                        @card AS CARD,
                        @voucher AS VOUCHER,
                        @ovo AS OVO,
                        @kqris AS KQRIS,
                        @dqbca AS D_QRIS_BCA,
                        @dqbni AS D_QRIS_BNI,
                        @dqbri AS D_QRIS_BRI,
                        @dqmdr AS D_QRIS_MDR,
                        @atome AS KATOME,
                        @indodana AS KINDODANA,
                        @sisa AS SISA_VOUCHER,
                        @refund AS REFUND,
                        JSON_QUERY((
                            SELECT store, total, trx
                            FROM (
                                SELECT TOP 15
                                    STORE AS store,
                                    SUM(TOTAL) AS total,
                                    SUM(TRX) AS trx
                                FROM #pay
                                GROUP BY STORE
                                ORDER BY SUM(TOTAL) DESC
                            ) ts
                            FOR JSON PATH
                        )) AS top_stores,
                        JSON_QUERY((
                            SELECT tanggal, total, trx
                            FROM (
                                SELECT
                                    TANGGAL AS tanggal,
                                    SUM(TOTAL) AS total,
                                    SUM(TRX) AS trx
                                FROM #pay
                                GROUP BY TANGGAL
                            ) dy
                            ORDER BY tanggal
                            FOR JSON PATH
                        )) AS daily,
                        JSON_QUERY((
                            SELECT store, payment, summary, selisih
                            FROM (
                                SELECT TOP 30
                                    STORE AS store,
                                    SUM(payment) AS payment,
                                    SUM(summary) AS summary,
                                    SUM(selisih) AS selisih
                                FROM #gap
                                GROUP BY STORE
                                HAVING ABS(SUM(selisih)) > 0.5
                                ORDER BY ABS(SUM(selisih)) DESC
                            ) gs
                            FOR JSON PATH
                        )) AS selisih_by_store,
                        JSON_QUERY((
                            SELECT tanggal, payment, summary, selisih
                            FROM (
                                SELECT TOP 31
                                    TANGGAL AS tanggal,
                                    SUM(payment) AS payment,
                                    SUM(summary) AS summary,
                                    SUM(selisih) AS selisih
                                FROM #gap
                                GROUP BY TANGGAL
                                ORDER BY TANGGAL
                            ) gd
                            FOR JSON PATH
                        )) AS selisih_by_day
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        DROP TABLE #gap;
        DROP TABLE #plu;
        DROP TABLE #pay;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#gap') IS NOT NULL DROP TABLE #gap;
        IF OBJECT_ID('tempdb..#plu') IS NOT NULL DROP TABLE #plu;
        IF OBJECT_ID('tempdb..#pay') IS NOT NULL DROP TABLE #pay;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
