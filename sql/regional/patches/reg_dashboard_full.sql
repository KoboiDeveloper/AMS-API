/* Regional dashboard â€” single-pass agg (header Grand_Total) + map pulau/kota + ticker head */
USE RBACESS;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_dashboard_summary_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_dashboard_summary_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_dashboard_summary_getrow
(
      @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @p_id_brand varchar(50) = NULL
    , @p_id_cabang varchar(50) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @asof date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date,''))),'') AS date);
        IF @asof IS NULL SET @asof = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date,''))),'') AS date);
        IF @asof IS NULL SET @asof = CAST(GETDATE() AS date);
        DECLARE @prev date = DATEADD(day, -1, @asof);
        DECLARE @chartFrom date = DATEADD(day, -6, @asof);
        DECLARE @monthStart date = DATEFROMPARTS(YEAR(@asof), MONTH(@asof), 1);
        DECLARE @scanFrom date = @monthStart;
        IF @prev < @scanFrom SET @scanFrom = @prev;
        IF @chartFrom < @scanFrom SET @scanFrom = @chartFrom;
        DECLARE @asofExcl datetime = DATEADD(day, 1, CAST(@asof AS datetime));
        DECLARE @scanFromDt datetime = CAST(@scanFrom AS datetime);

        DECLARE @brand varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_id_brand,''))),'');
        IF @brand IN ('ALL','all','0') SET @brand = NULL;
        DECLARE @gh varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_actor_nik,''))),'');

        CREATE TABLE #scope (
            Store varchar(50) NOT NULL PRIMARY KEY,
            Store_desc varchar(200) NULL,
            kota varchar(100) NULL,
            pulau varchar(100) NULL
        );

        IF OBJECT_ID(N'pos_server.dbo.xsp_brand_reg_filter_getrows', N'P') IS NOT NULL AND @gh IS NOT NULL
        BEGIN
            CREATE TABLE #raw (Store_desc varchar(200), Store varchar(50));
            INSERT INTO #raw (Store_desc, Store)
            EXEC pos_server.dbo.xsp_brand_reg_filter_getrows @p_gh_id = @gh;
            INSERT INTO #scope (Store, Store_desc, kota, pulau)
            SELECT DISTINCT
                LTRIM(RTRIM(r.Store)),
                ISNULL(ds.Store_Name, r.Store_desc),
                ISNULL(NULLIF(LTRIM(RTRIM(ds.Store_Kota)), ''), 'UNKNOWN'),
                ISNULL(NULLIF(LTRIM(RTRIM(ds.STORE_PULAU)), ''), 'UNKNOWN')
            FROM #raw AS r
            LEFT JOIN pos_server.dbo.DT_Store AS ds WITH (NOLOCK) ON ds.Store_ID = r.Store
            WHERE NULLIF(LTRIM(RTRIM(r.Store)),'') IS NOT NULL;
            DROP TABLE #raw;
        END
        ELSE IF OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
        BEGIN
            INSERT INTO #scope (Store, Store_desc, kota, pulau)
            SELECT TOP (2000)
                s.Store_ID,
                ISNULL(s.Store_Name, s.Store_ID),
                ISNULL(NULLIF(LTRIM(RTRIM(s.Store_Kota)), ''), 'UNKNOWN'),
                ISNULL(NULLIF(LTRIM(RTRIM(s.STORE_PULAU)), ''), 'UNKNOWN')
            FROM pos_server.dbo.DT_Store AS s WITH (NOLOCK)
            WHERE s.Status_Active = 1;
        END;

        IF @brand IS NOT NULL AND OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
        BEGIN
            DELETE sc
            FROM #scope AS sc
            WHERE NOT EXISTS (
                SELECT 1
                FROM pos_server.dbo.DT_Store AS ds WITH (NOLOCK)
                WHERE ds.Store_ID = sc.Store
                  AND (
                        ds.Store_Brand_ID = @brand
                     OR (@brand = 'CELCIUS' AND ds.Store_Brand_ID IN ('CELCIUS','CELCIUS KIDS'))
                  )
            );
        END;


        /* Drop inactive from sales scope — store aktif hanya Status_Active = 1 */
        DELETE sc
        FROM #scope AS sc
        WHERE NOT EXISTS (
            SELECT 1
            FROM pos_server.dbo.DT_Store AS s WITH (NOLOCK)
            WHERE s.Store_ID = sc.Store
              AND s.Status_Active = 1
        );
        /* KPI store aktif = DT_Store.Status_Active = 1 (scoped brand / GH via #scope) */
        DECLARE @store_count int = (
            SELECT COUNT(1)
            FROM #scope AS sc
            INNER JOIN pos_server.dbo.DT_Store AS s WITH (NOLOCK)
                ON s.Store_ID = sc.Store
            WHERE s.Status_Active = 1
        );

        DECLARE @sales_today money = 0, @sales_yesterday money = 0;
        DECLARE @sales_offline_today money = 0, @sales_offline_yesterday money = 0;
        DECLARE @sales_online_today money = 0, @sales_online_yesterday money = 0;
        DECLARE @sales_week money = 0, @sales_month money = 0;
        DECLARE @sales_offline_week money = 0, @sales_offline_month money = 0;
        DECLARE @sales_online_week money = 0, @sales_online_month money = 0;
        DECLARE @trx_today int = 0, @trx_yesterday int = 0;
        DECLARE @trx_week int = 0, @trx_month int = 0;
        DECLARE @pct_sales decimal(18,2) = 0, @pct_offline decimal(18,2) = 0, @pct_online decimal(18,2) = 0, @pct_trx decimal(18,2) = 0;

        DECLARE @sales7 nvarchar(max) = N'[]';
        DECLARE @topStores nvarchar(max) = N'[]';
        DECLARE @mapPulau nvarchar(max) = N'[]';
        DECLARE @mapKota nvarchar(max) = N'[]';
        DECLARE @mapHotspots nvarchar(max) = N'[]';
        DECLARE @ticker nvarchar(max) = N'[]';

        IF OBJECT_ID(N'pos_server.dbo.TR_SALES_HEADER', N'U') IS NOT NULL
           AND @store_count > 0
        BEGIN
            /* Single scan: header only (Grand_Total), sargable date range */
            SELECT
                a.ID_Store,
                CONVERT(date, a.Tanggal_Transaksi) AS d,
                CASE WHEN ISNULL(a.order_online, 0) = 1 THEN 1 ELSE 0 END AS is_online,
                SUM(CAST(ISNULL(a.Grand_Total, 0) AS money)) AS net,
                COUNT(1) AS trx
            INTO #day_store
            FROM pos_server.dbo.TR_SALES_HEADER AS a WITH (NOLOCK)
            INNER JOIN #scope AS sc ON sc.Store = a.ID_Store
            WHERE a.Tanggal_Transaksi >= @scanFromDt
              AND a.Tanggal_Transaksi < @asofExcl
            GROUP BY
                a.ID_Store,
                CONVERT(date, a.Tanggal_Transaksi),
                CASE WHEN ISNULL(a.order_online, 0) = 1 THEN 1 ELSE 0 END;

            CREATE CLUSTERED INDEX IX_day_store ON #day_store(d, ID_Store);

            SELECT
                @sales_today = ISNULL(SUM(CASE WHEN d = @asof THEN net END), 0),
                @sales_yesterday = ISNULL(SUM(CASE WHEN d = @prev THEN net END), 0),
                @sales_offline_today = ISNULL(SUM(CASE WHEN d = @asof AND is_online = 0 THEN net END), 0),
                @sales_offline_yesterday = ISNULL(SUM(CASE WHEN d = @prev AND is_online = 0 THEN net END), 0),
                @sales_online_today = ISNULL(SUM(CASE WHEN d = @asof AND is_online = 1 THEN net END), 0),
                @sales_online_yesterday = ISNULL(SUM(CASE WHEN d = @prev AND is_online = 1 THEN net END), 0),
                @sales_week = ISNULL(SUM(CASE WHEN DATEPART(ww, d) = DATEPART(ww, @asof) AND YEAR(d) = YEAR(@asof) THEN net END), 0),
                @sales_month = ISNULL(SUM(CASE WHEN d >= @monthStart THEN net END), 0),
                @sales_offline_week = ISNULL(SUM(CASE WHEN DATEPART(ww, d) = DATEPART(ww, @asof) AND YEAR(d) = YEAR(@asof) AND is_online = 0 THEN net END), 0),
                @sales_offline_month = ISNULL(SUM(CASE WHEN d >= @monthStart AND is_online = 0 THEN net END), 0),
                @sales_online_week = ISNULL(SUM(CASE WHEN DATEPART(ww, d) = DATEPART(ww, @asof) AND YEAR(d) = YEAR(@asof) AND is_online = 1 THEN net END), 0),
                @sales_online_month = ISNULL(SUM(CASE WHEN d >= @monthStart AND is_online = 1 THEN net END), 0),
                @trx_today = ISNULL(SUM(CASE WHEN d = @asof THEN trx END), 0),
                @trx_yesterday = ISNULL(SUM(CASE WHEN d = @prev THEN trx END), 0),
                @trx_week = ISNULL(SUM(CASE WHEN DATEPART(ww, d) = DATEPART(ww, @asof) AND YEAR(d) = YEAR(@asof) THEN trx END), 0),
                @trx_month = ISNULL(SUM(CASE WHEN d >= @monthStart THEN trx END), 0)
            FROM #day_store;

            ;WITH days AS (
                SELECT DATEADD(day, v.n, @chartFrom) AS d
                FROM (VALUES (0),(1),(2),(3),(4),(5),(6)) AS v(n)
                WHERE DATEADD(day, v.n, @chartFrom) <= @asof
            ),
            agg AS (
                SELECT
                    d,
                    SUM(CASE WHEN is_online = 0 THEN net ELSE 0 END) AS offline,
                    SUM(CASE WHEN is_online = 1 THEN net ELSE 0 END) AS online
                FROM #day_store
                WHERE d >= @chartFrom
                GROUP BY d
            )
            SELECT @sales7 = ISNULL((
                SELECT
                    CONVERT(varchar(10), d.d, 23) AS date,
                    ISNULL(a.offline, 0) AS offline,
                    ISNULL(a.online, 0) AS online,
                    ISNULL(a.offline, 0) + ISNULL(a.online, 0) AS total
                FROM days AS d
                LEFT JOIN agg AS a ON a.d = d.d
                ORDER BY d.d
                FOR JSON PATH
            ), N'[]');

            SELECT @topStores = ISNULL((
                SELECT TOP (10)
                    sc.Store AS store,
                    ISNULL(sc.Store_desc, sc.Store) AS store_name,
                    sc.kota,
                    sc.pulau,
                    SUM(ds.net) AS total
                FROM #day_store AS ds
                INNER JOIN #scope AS sc ON sc.Store = ds.ID_Store
                WHERE ds.d = @asof
                  AND sc.Store NOT IN (
                      N'01E', N'02E', N'03E', N'04E', N'05E', N'06E',
                      N'07E', N'08E', N'09E', N'10E', N'11E'
                  )
                GROUP BY sc.Store, sc.Store_desc, sc.kota, sc.pulau
                ORDER BY SUM(ds.net) DESC
                FOR JSON PATH
            ), N'[]');

            /* Map: pulau / kota / hotspots (today) */
            DECLARE @salesTodayTotal money = NULLIF(@sales_today, 0);

            SELECT @mapPulau = ISNULL((
                SELECT
                    sc.pulau AS pulau,
                    SUM(ds.net) AS sales,
                    SUM(ds.trx) AS trx,
                    COUNT(DISTINCT sc.Store) AS stores,
                    CASE
                        WHEN @salesTodayTotal IS NULL THEN 0
                        ELSE ROUND(SUM(ds.net) * 100.0 / @salesTodayTotal, 2)
                    END AS share_pct
                FROM #day_store AS ds
                INNER JOIN #scope AS sc ON sc.Store = ds.ID_Store
                WHERE ds.d = @asof
                GROUP BY sc.pulau
                ORDER BY SUM(ds.net) DESC
                FOR JSON PATH
            ), N'[]');

            SELECT @mapKota = ISNULL((
                SELECT TOP (80)
                    sc.kota AS kota,
                    sc.pulau AS pulau,
                    SUM(ds.net) AS sales,
                    SUM(ds.trx) AS trx
                FROM #day_store AS ds
                INNER JOIN #scope AS sc ON sc.Store = ds.ID_Store
                WHERE ds.d = @asof
                GROUP BY sc.kota, sc.pulau
                ORDER BY SUM(ds.net) DESC
                FOR JSON PATH
            ), N'[]');

            SELECT @mapHotspots = ISNULL((
                SELECT TOP (15)
                    sc.kota AS kota,
                    sc.pulau AS pulau,
                    sc.Store AS store_id,
                    ISNULL(sc.Store_desc, sc.Store) AS store_name,
                    SUM(ds.net) AS sales
                FROM #day_store AS ds
                INNER JOIN #scope AS sc ON sc.Store = ds.ID_Store
                WHERE ds.d = @asof
                GROUP BY sc.kota, sc.pulau, sc.Store, sc.Store_desc
                ORDER BY SUM(ds.net) DESC
                FOR JSON PATH
            ), N'[]');

            /* Live ticker head â€” recent headers today (by time desc) */
            SELECT @ticker = ISNULL((
                SELECT TOP (40)
                    CONVERT(varchar(19), a.Tanggal_Transaksi, 126) AS ts,
                    a.ID_Store AS store_id,
                    ISNULL(sc.Store_desc, a.ID_Store) AS store_name,
                    sc.kota,
                    sc.pulau,
                    CAST(ISNULL(a.Grand_Total, 0) AS money) AS amount,
                    CASE WHEN ISNULL(a.order_online, 0) = 1 THEN 'online' ELSE 'offline' END AS channel
                FROM pos_server.dbo.TR_SALES_HEADER AS a WITH (NOLOCK)
                INNER JOIN #scope AS sc ON sc.Store = a.ID_Store
                WHERE a.Tanggal_Transaksi >= CAST(@asof AS datetime)
                  AND a.Tanggal_Transaksi < @asofExcl
                ORDER BY a.Tanggal_Transaksi DESC
                FOR JSON PATH
            ), N'[]');

            DROP TABLE #day_store;
        END;

        SET @pct_sales = CASE
            WHEN ISNULL(@sales_today,0) = 0 THEN 0
            WHEN ISNULL(@sales_yesterday,0) <= @sales_today
                THEN ROUND(ABS((ISNULL(@sales_yesterday,0) - @sales_today) / NULLIF(@sales_today,0) * 100), 2)
            ELSE ROUND(ABS((ISNULL(@sales_yesterday,0) - @sales_today) / NULLIF(@sales_yesterday,0) * 100) * -1, 2)
        END;
        SET @pct_offline = CASE
            WHEN ISNULL(@sales_offline_today,0) = 0 THEN 0
            WHEN ISNULL(@sales_offline_yesterday,0) <= @sales_offline_today
                THEN ROUND(ABS((ISNULL(@sales_offline_yesterday,0) - @sales_offline_today) / NULLIF(@sales_offline_today,0) * 100), 2)
            ELSE ROUND(ABS((ISNULL(@sales_offline_yesterday,0) - @sales_offline_today) / NULLIF(@sales_offline_yesterday,0) * 100) * -1, 2)
        END;
        SET @pct_online = CASE
            WHEN ISNULL(@sales_online_today,0) = 0 THEN 0
            WHEN ISNULL(@sales_online_yesterday,0) <= @sales_online_today
                THEN ROUND(ABS((ISNULL(@sales_online_yesterday,0) - @sales_online_today) / NULLIF(@sales_online_today,0) * 100), 2)
            ELSE ROUND(ABS((ISNULL(@sales_online_yesterday,0) - @sales_online_today) / NULLIF(@sales_online_yesterday,0) * 100) * -1, 2)
        END;
        SET @pct_trx = CASE
            WHEN ISNULL(@trx_today,0) = 0 THEN 0
            WHEN ISNULL(@trx_yesterday,0) <= @trx_today
                THEN ROUND(ABS((ISNULL(@trx_yesterday,0) - @trx_today) * 1.0 / NULLIF(@trx_today,0) * 100), 2)
            ELSE ROUND(ABS((ISNULL(@trx_yesterday,0) - @trx_today) * 1.0 / NULLIF(@trx_yesterday,0) * 100) * -1, 2)
        END;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           CONVERT(varchar(10), @asof, 23) AS as_of,
                           @store_count AS active_store_count,
                           @sales_today AS sales_today,
                           @pct_sales AS sales_today_pct,
                           @sales_week AS sales_week,
                           @sales_month AS sales_month,
                           @sales_offline_today AS sales_offline_today,
                           @pct_offline AS sales_offline_pct,
                           @sales_offline_week AS sales_offline_week,
                           @sales_offline_month AS sales_offline_month,
                           @sales_online_today AS sales_online_today,
                           @pct_online AS sales_online_pct,
                           @sales_online_week AS sales_online_week,
                           @sales_online_month AS sales_online_month,
                           @trx_today AS trx_today,
                           @pct_trx AS trx_today_pct,
                           @trx_week AS trx_week,
                           @trx_month AS trx_month,
                           JSON_QUERY(@sales7) AS sales_7d,
                           JSON_QUERY(@topStores) AS stores_top,
                           JSON_QUERY(@mapPulau) AS map_pulau,
                           JSON_QUERY(@mapKota) AS map_kota,
                           JSON_QUERY(@mapHotspots) AS map_hotspots,
                           JSON_QUERY(@ticker) AS ticker
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        DROP TABLE #scope;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#day_store') IS NOT NULL DROP TABLE #day_store;
        IF OBJECT_ID('tempdb..#scope') IS NOT NULL DROP TABLE #scope;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
