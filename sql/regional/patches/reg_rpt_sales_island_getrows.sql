/*
  Sales By Island (REG2) — NEW SP on RBACESS.
  Logic parity with pos_server.dbo.xsp_api_store_sales_by_ilands_getrows
  (legacy salesiland.aspx → /v1.0/store/sales/iland).
  Does NOT EXEC the legacy SP — queries pos_server tables from RBACESS.
  Filters: from_date, to_date, id_brand (Brand only — no store).
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_sales_island_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_island_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_island_getrows
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
        DECLARE @brand varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand, ''), @p_brand), '')));
        IF @brand = '' OR @brand IN ('0')
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'brandID wajib diisi.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* Normalize UI aliases → mapped brand names used by legacy CASE */
        DECLARE @brand_key varchar(50) = UPPER(@brand);
        IF @brand_key IN ('DISCOUNT', 'DS', 'DISCOUNT STORE') SET @brand = 'DISCOUNT STORE';
        ELSE IF @brand_key = 'ONLINE' SET @brand = 'ONLINE';
        ELSE IF @brand_key = 'CELCIUS' SET @brand = 'CELCIUS';
        ELSE IF @brand_key = 'CELCIUS WOMAN' SET @brand = 'CELCIUS WOMAN';
        ELSE IF @brand_key = 'FLIES' SET @brand = 'FLIES';
        ELSE IF @brand_key = 'MISSISSIPPI' SET @brand = 'MISSISSIPPI';
        ELSE IF @brand_key = 'QUEENSLAND' SET @brand = 'QUEENSLAND';
        ELSE IF @brand_key = 'AEESHA' SET @brand = 'AEESHA';
        /* else keep raw (e.g. IWAN FASHION) — same as salesiland.aspx SelectedValue */

        DECLARE @from_d date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date, ''))), '') AS date);
        DECLARE @to_d date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date, ''))), '') AS date);
        IF @from_d IS NULL OR @to_d IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'fromDate dan toDate wajib diisi.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;
        IF @from_d > @to_d
        BEGIN
            DECLARE @swap date = @from_d;
            SET @from_d = @to_d;
            SET @to_d = @swap;
        END;

        DECLARE @from datetime = CAST(@from_d AS datetime);
        DECLARE @to_excl datetime = DATEADD(DAY, 1, CAST(@to_d AS datetime));

        IF OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NULL
           OR OBJECT_ID(N'pos_server.dbo.TR_SALES_HEADER', N'U') IS NULL
           OR OBJECT_ID(N'pos_server.dbo.TR_SALES_PAYMENT_DETAIL', N'U') IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'pos_server sales tables not reachable from RBACESS' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SELECT
            a.Store_ID,
            a.STORE_KOTA,
            a.STORE_PULAU
        INTO #brand
        FROM pos_server.dbo.DT_Store a WITH (NOLOCK)
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
        ) = @brand
          AND (a.Store_Brand_ID_2 != 'ONLINE' OR a.Store_ID != '777' OR a.Store_ID NOT LIKE 'dc%');

        CREATE UNIQUE CLUSTERED INDEX IX_brand ON #brand(Store_ID);

        SELECT Store_ID
        INTO #rawbrand
        FROM pos_server.dbo.DT_Store WITH (NOLOCK)
        WHERE Store_Brand_ID = @brand;

        CREATE UNIQUE CLUSTERED INDEX IX_rawbrand ON #rawbrand(Store_ID);

        SELECT
            s.Store_ID,
            SUM(CASE WHEN (b.order_online = 0 OR b.order_online IS NULL) AND tspd.TIPE_BAYAR != 'K.QRIS' THEN tspd.BAYAR ELSE 0 END) AS total_offline,
            SUM(CASE WHEN b.order_online = 1 AND b.cod = 0 AND tspd.TIPE_BAYAR != 'K.QRIS' THEN tspd.BAYAR ELSE 0 END) AS total_direct,
            SUM(CASE WHEN (b.order_online = 1 AND tspd.TIPE_BAYAR = 'K.QRIS') OR (b.order_online = 0 AND tspd.TIPE_BAYAR = 'K.QRIS') THEN tspd.BAYAR ELSE 0 END) AS total_qris,
            SUM(CASE WHEN b.order_online = 1 AND b.cod = 1 AND tspd.TIPE_BAYAR != 'K.QRIS' THEN tspd.BAYAR ELSE 0 END) AS cod
        INTO #pay
        FROM #brand s
        INNER JOIN pos_server.dbo.TR_SALES_HEADER b WITH (NOLOCK)
            ON b.ID_Store = s.Store_ID
           AND b.Tanggal_Transaksi >= @from
           AND b.Tanggal_Transaksi < @to_excl
        INNER JOIN pos_server.dbo.TR_SALES_PAYMENT_DETAIL tspd WITH (NOLOCK)
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
        INNER JOIN pos_server.dbo.TR_SALES_REFUND c WITH (NOLOCK)
            ON c.ID_STORE = s.Store_ID
           AND c.TGL_REFUND >= @from
           AND c.TGL_REFUND < @to_excl
        GROUP BY s.Store_ID;

        SELECT DISTINCT h.ID_Store AS Store_ID
        INTO #bag
        FROM #rawbrand s
        INNER JOIN pos_server.dbo.TR_SALES_HEADER h WITH (NOLOCK)
            ON h.ID_Store = s.Store_ID
           AND h.Tanggal_Transaksi >= @from
           AND h.Tanggal_Transaksi < @to_excl
        WHERE EXISTS (
            SELECT 1
            FROM pos_server.dbo.TR_SALES_SHOPPING_BAG a WITH (NOLOCK)
            WHERE a.ID_TR_SALES_HEADER = h.ID_TR_SALES_HEADER
        );

        SELECT Store_ID INTO #keys FROM #pay
        UNION
        SELECT Store_ID FROM #ref
        UNION
        SELECT Store_ID FROM #bag;

        /* Flat rows — UI groups by STORE_PULAU (same as salesiland.aspx) */
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
                            WHEN ISNULL(p.total_offline, 0) + ISNULL(p.total_direct, 0) + ISNULL(p.total_qris, 0) + ISNULL(p.cod, 0) - ISNULL(r.refund, 0) = 0
                                THEN CAST(0 AS money)
                            ELSE ISNULL(p.total_offline, 0) + ISNULL(p.total_direct, 0) + ISNULL(p.total_qris, 0) + ISNULL(p.cod, 0) - ISNULL(r.refund, 0)
                        END AS TOTAL
                    FROM #keys k
                    INNER JOIN pos_server.dbo.DT_Store st WITH (NOLOCK) ON st.Store_ID = k.Store_ID
                    LEFT JOIN #pay p ON p.Store_ID = k.Store_ID
                    LEFT JOIN #ref r ON r.Store_ID = k.Store_ID
                    WHERE k.Store_ID NOT IN (
                        '000-RC','01C','02C','7777','888','999-RC','DEMO888','TST1','000-RIF','999-RIF','RIF888','RC888',
                        '000-RM','999-RM','RM888','RQ888','01E','02E','03E','04E','05E','06E','07E','08E','09E','010E','011E'
                    )
                    ORDER BY st.STORE_PULAU, k.Store_ID
                    FOR JSON PATH
                )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        DROP TABLE #keys;
        DROP TABLE #bag;
        DROP TABLE #ref;
        DROP TABLE #pay;
        DROP TABLE #rawbrand;
        DROP TABLE #brand;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#keys') IS NOT NULL DROP TABLE #keys;
        IF OBJECT_ID('tempdb..#bag') IS NOT NULL DROP TABLE #bag;
        IF OBJECT_ID('tempdb..#ref') IS NOT NULL DROP TABLE #ref;
        IF OBJECT_ID('tempdb..#pay') IS NOT NULL DROP TABLE #pay;
        IF OBJECT_ID('tempdb..#rawbrand') IS NOT NULL DROP TABLE #rawbrand;
        IF OBJECT_ID('tempdb..#brand') IS NOT NULL DROP TABLE #brand;
        SET @bitparam = (
            SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH
END
GO
