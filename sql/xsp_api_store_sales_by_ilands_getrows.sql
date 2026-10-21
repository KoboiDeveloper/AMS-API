-- Sales per pulau. Satu kali baca pembayaran per toko + tanggal,
-- supaya tidak memindai TR_SALES_HEADER / TR_SALES_PAYMENT_DETAIL berulang kali.
-- NOLOCK: laporan ini tidak menahan delete transaksi di kasir.
ALTER PROCEDURE [dbo].[xsp_api_store_sales_by_ilands_getrows]
(
      @p_from_date datetime
    , @p_to_date   datetime
    , @p_brand     varchar(20)
    , @p_token     varchar(200)
    , @bitparam    varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @p_token = 'kontol kontol kontol anjing tai babi'
    BEGIN
        DECLARE @from datetime = CAST(CAST(@p_from_date AS date) AS datetime);
        DECLARE @to_excl datetime = DATEADD(DAY, 1, CAST(CAST(@p_to_date AS date) AS datetime));

        SELECT
            a.Store_ID,
            a.STORE_KOTA,
            a.STORE_PULAU
        INTO #brand
        FROM DT_Store a WITH (NOLOCK)
        WHERE (
            CASE
                WHEN a.Store_Brand_ID = 'IWAN FASHION'
                     AND (a.Store_ID NOT LIKE '%D' AND LEFT(a.Store_ID, 1) != 'T' AND RIGHT(a.Store_ID, 1) != 'E')
                    THEN 'FLIES'
                WHEN (a.Store_Brand_ID = 'IWAN FASHION'
                      AND (a.Store_ID LIKE '%D' OR LEFT(a.Store_ID, 1) = 'T' AND RIGHT(a.Store_ID, 1) != 'E'))
                     OR LEFT(a.Store_ID, 2) = 'ds'
                    THEN 'DISCOUNT STORE'
                WHEN a.Store_ID IN ('01E','02E','03E','04E','06E','07E','08E','09E','010E','011E')
                    THEN 'ONLINE'
                WHEN a.Store_Brand_ID = 'CELCIUS KIDS'
                    THEN 'CELCIUS'
                ELSE a.Store_Brand_ID
            END
        ) = @p_brand
          AND (a.Store_Brand_ID_2 != 'ONLINE' OR a.Store_ID != '777' OR a.Store_ID NOT LIKE 'dc%');

        CREATE UNIQUE CLUSTERED INDEX IX_brand ON #brand(Store_ID);

        SELECT Store_ID
        INTO #rawbrand
        FROM DT_Store WITH (NOLOCK)
        WHERE Store_Brand_ID = @p_brand;

        CREATE UNIQUE CLUSTERED INDEX IX_rawbrand ON #rawbrand(Store_ID);

        SELECT
            s.Store_ID,
            SUM(CASE WHEN (b.order_online = 0 OR b.order_online IS NULL) AND tspd.TIPE_BAYAR != 'K.QRIS' THEN tspd.BAYAR ELSE 0 END) AS total_offline,
            SUM(CASE WHEN b.order_online = 1 AND b.cod = 0 AND tspd.TIPE_BAYAR != 'K.QRIS' THEN tspd.BAYAR ELSE 0 END) AS total_direct,
            SUM(CASE WHEN (b.order_online = 1 AND tspd.TIPE_BAYAR = 'K.QRIS') OR (b.order_online = 0 AND tspd.TIPE_BAYAR = 'K.QRIS') THEN tspd.BAYAR ELSE 0 END) AS total_qris,
            SUM(CASE WHEN b.order_online = 1 AND b.cod = 1 AND tspd.TIPE_BAYAR != 'K.QRIS' THEN tspd.BAYAR ELSE 0 END) AS cod
        INTO #pay
        FROM #brand s
        INNER JOIN TR_SALES_HEADER b WITH (NOLOCK)
            ON b.ID_Store = s.Store_ID
           AND b.Tanggal_Transaksi >= @from
           AND b.Tanggal_Transaksi < @to_excl
        INNER JOIN TR_SALES_PAYMENT_DETAIL tspd WITH (NOLOCK)
            ON tspd.ID_TR_SALES_HEADER = b.ID_TR_SALES_HEADER
        WHERE
            (((b.order_online = 0 OR b.order_online IS NULL) AND tspd.TIPE_BAYAR != 'K.QRIS')
             OR (b.order_online = 1 AND b.cod = 0 AND tspd.TIPE_BAYAR != 'K.QRIS')
             OR ((b.order_online = 1 AND tspd.TIPE_BAYAR = 'K.QRIS') OR (b.order_online = 0 AND tspd.TIPE_BAYAR = 'K.QRIS'))
             OR (b.order_online = 1 AND b.cod = 1 AND tspd.TIPE_BAYAR != 'K.QRIS'))
        GROUP BY s.Store_ID;

        SELECT s.Store_ID, SUM(c.TOTAL_PRICE) AS refund
        INTO #ref
        FROM #brand s
        INNER JOIN TR_SALES_REFUND c WITH (NOLOCK)
            ON c.ID_STORE = s.Store_ID
           AND c.TGL_REFUND >= @from
           AND c.TGL_REFUND < @to_excl
        GROUP BY s.Store_ID;

        SELECT DISTINCT h.ID_Store AS Store_ID
        INTO #bag
        FROM #rawbrand s
        INNER JOIN TR_SALES_HEADER h WITH (NOLOCK)
            ON h.ID_Store = s.Store_ID
           AND h.Tanggal_Transaksi >= @from
           AND h.Tanggal_Transaksi < @to_excl
        WHERE EXISTS (
            SELECT 1
            FROM TR_SALES_SHOPPING_BAG a WITH (NOLOCK)
            WHERE a.ID_TR_SALES_HEADER = h.ID_TR_SALES_HEADER
        );

        SELECT Store_ID INTO #keys FROM #pay
        UNION
        SELECT Store_ID FROM #ref
        UNION
        SELECT Store_ID FROM #bag;

        SET @bitparam = (
            SELECT
                '2002500' AS responseCode,
                'success' AS responseMessage,
                JSON_QUERY((
                    SELECT
                        st.STORE_PULAU,
                        CASE
                            WHEN LEFT(k.Store_ID, 3) = 'rcw' AND LEN(k.Store_ID) = 5 THEN 'RCW0' + RIGHT(k.Store_ID, 2)
                            ELSE k.Store_ID
                        END COLLATE Latin1_General_CI_AS + ' - ' + st.STORE_KOTA AS ID_Store,
                        CASE
                            WHEN ISNULL(p.total_offline, 0) + ISNULL(p.total_direct, 0) + ISNULL(p.total_qris, 0) + ISNULL(p.cod, 0) - ISNULL(r.refund, 0) = 0 THEN CAST(0 AS money)
                            ELSE ISNULL(p.total_offline, 0) + ISNULL(p.total_direct, 0) + ISNULL(p.total_qris, 0) + ISNULL(p.cod, 0) - ISNULL(r.refund, 0)
                        END AS TOTAL
                    FROM #keys k
                    INNER JOIN DT_Store st WITH (NOLOCK) ON st.Store_ID = k.Store_ID
                    LEFT JOIN #pay p ON p.Store_ID = k.Store_ID
                    LEFT JOIN #ref r ON r.Store_ID = k.Store_ID
                    WHERE k.Store_ID NOT IN (
                        '000-RC','01C','02C','7777','888','999-RC','DEMO888','TST1','000-RIF','999-RIF','RIF888','RC888',
                        '000-RM','999-RM','RM888','RQ888','01E','02E','03E','04E','05E','06E','07E','08E','09E','010E','011E'
                    )
                    ORDER BY st.STORE_PULAU, k.Store_ID
                    FOR JSON PATH
                )) AS salesDetailbyIland
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END
    ELSE
        SET @bitparam = (
            SELECT '4002500' AS responseCode, 'Not Found' AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
END
GO
