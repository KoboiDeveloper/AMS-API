/* Regional dashboard — sales KPI + chart/top stores (ops KPIs removed for lighter query) */
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
        DECLARE @brand varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_id_brand,''))),'');
        IF @brand IN ('ALL','all','0') SET @brand = NULL;
        DECLARE @gh varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_actor_nik,''))),'');

        CREATE TABLE #scope (Store varchar(50) NOT NULL PRIMARY KEY, Store_desc varchar(200) NULL);

        IF OBJECT_ID(N'pos_server.dbo.xsp_brand_reg_filter_getrows', N'P') IS NOT NULL AND @gh IS NOT NULL
        BEGIN
            CREATE TABLE #raw (Store_desc varchar(200), Store varchar(50));
            INSERT INTO #raw (Store_desc, Store)
            EXEC pos_server.dbo.xsp_brand_reg_filter_getrows @p_gh_id = @gh;
            INSERT INTO #scope (Store, Store_desc)
            SELECT DISTINCT LTRIM(RTRIM(Store)), Store_desc
            FROM #raw
            WHERE NULLIF(LTRIM(RTRIM(Store)),'') IS NOT NULL;
            DROP TABLE #raw;
        END
        ELSE IF OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
        BEGIN
            INSERT INTO #scope (Store, Store_desc)
            SELECT TOP (800) s.Store_ID, ISNULL(s.Store_Name, s.Store_ID)
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

        DECLARE @store_count int = (SELECT COUNT(1) FROM #scope);

        DECLARE @sales_today money = 0, @sales_yesterday money = 0;
        DECLARE @sales_offline_today money = 0, @sales_offline_yesterday money = 0;
        DECLARE @sales_online_today money = 0, @sales_online_yesterday money = 0;
        DECLARE @sales_week money = 0, @sales_month money = 0;
        DECLARE @sales_offline_week money = 0, @sales_offline_month money = 0;
        DECLARE @sales_online_week money = 0, @sales_online_month money = 0;
        DECLARE @trx_today int = 0, @trx_yesterday int = 0;
        DECLARE @trx_week int = 0, @trx_month int = 0;
        DECLARE @pct_sales decimal(18,2) = 0, @pct_offline decimal(18,2) = 0, @pct_online decimal(18,2) = 0, @pct_trx decimal(18,2) = 0;

        IF OBJECT_ID(N'pos_server.dbo.TR_SALES_HEADER', N'U') IS NOT NULL
           AND OBJECT_ID(N'pos_server.dbo.TR_SALES_DETAIL', N'U') IS NOT NULL
           AND @store_count > 0
        BEGIN
            ;WITH base AS (
                SELECT
                    a.ID_Store,
                    CONVERT(date, a.Tanggal_Transaksi) AS d,
                    CASE WHEN ISNULL(a.order_online, 0) = 1 THEN 1 ELSE 0 END AS is_online,
                    SUM(CAST(b.Net AS money)) AS net,
                    COUNT(DISTINCT a.ID_TR_SALES_HEADER) AS trx
                FROM pos_server.dbo.TR_SALES_HEADER AS a WITH (NOLOCK)
                INNER JOIN pos_server.dbo.TR_SALES_DETAIL AS b WITH (NOLOCK)
                    ON b.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER
                INNER JOIN #scope AS sc ON sc.Store = a.ID_Store
                WHERE a.Tanggal_Transaksi >= @monthStart
                  AND a.Tanggal_Transaksi < DATEADD(day, 1, @asof)
                GROUP BY a.ID_Store, CONVERT(date, a.Tanggal_Transaksi), CASE WHEN ISNULL(a.order_online, 0) = 1 THEN 1 ELSE 0 END
            )
            SELECT
                @sales_today = ISNULL(SUM(CASE WHEN d = @asof THEN net END), 0),
                @sales_yesterday = ISNULL(SUM(CASE WHEN d = @prev THEN net END), 0),
                @sales_offline_today = ISNULL(SUM(CASE WHEN d = @asof AND is_online = 0 THEN net END), 0),
                @sales_offline_yesterday = ISNULL(SUM(CASE WHEN d = @prev AND is_online = 0 THEN net END), 0),
                @sales_online_today = ISNULL(SUM(CASE WHEN d = @asof AND is_online = 1 THEN net END), 0),
                @sales_online_yesterday = ISNULL(SUM(CASE WHEN d = @prev AND is_online = 1 THEN net END), 0),
                @sales_week = ISNULL(SUM(CASE WHEN DATEPART(ww, d) = DATEPART(ww, @asof) AND YEAR(d) = YEAR(@asof) THEN net END), 0),
                @sales_month = ISNULL(SUM(net), 0),
                @sales_offline_week = ISNULL(SUM(CASE WHEN DATEPART(ww, d) = DATEPART(ww, @asof) AND YEAR(d) = YEAR(@asof) AND is_online = 0 THEN net END), 0),
                @sales_offline_month = ISNULL(SUM(CASE WHEN is_online = 0 THEN net END), 0),
                @sales_online_week = ISNULL(SUM(CASE WHEN DATEPART(ww, d) = DATEPART(ww, @asof) AND YEAR(d) = YEAR(@asof) AND is_online = 1 THEN net END), 0),
                @sales_online_month = ISNULL(SUM(CASE WHEN is_online = 1 THEN net END), 0),
                @trx_today = ISNULL(SUM(CASE WHEN d = @asof THEN trx END), 0),
                @trx_yesterday = ISNULL(SUM(CASE WHEN d = @prev THEN trx END), 0),
                @trx_week = ISNULL(SUM(CASE WHEN DATEPART(ww, d) = DATEPART(ww, @asof) AND YEAR(d) = YEAR(@asof) THEN trx END), 0),
                @trx_month = ISNULL(SUM(trx), 0)
            FROM base;

            /* also need yesterday if prev is prior month — extend scan */
            IF @prev < @monthStart
            BEGIN
                SELECT
                    @sales_yesterday = ISNULL(SUM(CAST(b.Net AS money)), 0),
                    @sales_offline_yesterday = ISNULL(SUM(CASE WHEN ISNULL(a.order_online,0)=0 THEN CAST(b.Net AS money) END), 0),
                    @sales_online_yesterday = ISNULL(SUM(CASE WHEN ISNULL(a.order_online,0)=1 THEN CAST(b.Net AS money) END), 0),
                    @trx_yesterday = COUNT(DISTINCT a.ID_TR_SALES_HEADER)
                FROM pos_server.dbo.TR_SALES_HEADER AS a WITH (NOLOCK)
                INNER JOIN pos_server.dbo.TR_SALES_DETAIL AS b WITH (NOLOCK)
                    ON b.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER
                INNER JOIN #scope AS sc ON sc.Store = a.ID_Store
                WHERE DATEDIFF(DAY, a.Tanggal_Transaksi, @prev) = 0;
            END;
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

        /* Ops KPIs (absen/kas/AR/ST) removed — keep SP light */

        DECLARE @sales7 nvarchar(max) = N'[]';
        DECLARE @topStores nvarchar(max) = N'[]';

        IF OBJECT_ID(N'pos_server.dbo.TR_SALES_HEADER', N'U') IS NOT NULL
           AND OBJECT_ID(N'pos_server.dbo.TR_SALES_DETAIL', N'U') IS NOT NULL
           AND @store_count > 0
        BEGIN
            ;WITH days AS (
                SELECT DATEADD(day, v.n, @chartFrom) AS d
                FROM (VALUES (0),(1),(2),(3),(4),(5),(6)) AS v(n)
                WHERE DATEADD(day, v.n, @chartFrom) <= @asof
            ),
            agg AS (
                SELECT
                    CONVERT(date, a.Tanggal_Transaksi) AS d,
                    SUM(CASE WHEN ISNULL(a.order_online,0)=0 THEN CAST(b.Net AS money) ELSE 0 END) AS offline,
                    SUM(CASE WHEN ISNULL(a.order_online,0)=1 THEN CAST(b.Net AS money) ELSE 0 END) AS online
                FROM pos_server.dbo.TR_SALES_HEADER AS a WITH (NOLOCK)
                INNER JOIN pos_server.dbo.TR_SALES_DETAIL AS b WITH (NOLOCK)
                    ON b.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER
                INNER JOIN #scope AS sc ON sc.Store = a.ID_Store
                WHERE a.Tanggal_Transaksi >= @chartFrom
                  AND a.Tanggal_Transaksi < DATEADD(day, 1, @asof)
                GROUP BY CONVERT(date, a.Tanggal_Transaksi)
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
                    SUM(CAST(b.Net AS money)) AS total
                FROM pos_server.dbo.TR_SALES_HEADER AS a WITH (NOLOCK)
                INNER JOIN pos_server.dbo.TR_SALES_DETAIL AS b WITH (NOLOCK)
                    ON b.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER
                INNER JOIN #scope AS sc ON sc.Store = a.ID_Store
                WHERE DATEDIFF(DAY, a.Tanggal_Transaksi, @asof) = 0
                GROUP BY sc.Store, sc.Store_desc
                ORDER BY SUM(CAST(b.Net AS money)) DESC
                FOR JSON PATH
            ), N'[]');
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
                           JSON_QUERY(@topStores) AS stores_top
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        DROP TABLE #scope;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#scope') IS NOT NULL DROP TABLE #scope;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
