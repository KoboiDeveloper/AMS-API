/*
  ASBC by QTY (REG2) - NEW SP on RBACESS (xsp_ams_new_reg_rpt_asbc_qty_getrows).
  Legacy page : module/Rpt/ASBC.aspx (+ .cs)
  Legacy SP   : XSP_ANALISA_SALES_BY_CLASS  (6 near-identical IF branches by gh/brand/store ALL-ness)
               -> NEVER EXEC'd / altered. Everything is read from pos_server.dbo.* only.

  Clean rewrite: filters (GH scope + brand list + store list) are resolved ONCE into #stores,
  then a single query path produces the same numbers as the legacy branches:
     (gh+brand+store) / (ALL gh+brand+store) / (gh+ALL brand+store) / (gh+brand+ALL store) /
     (ALL gh+brand+ALL store) / (gh+ALL brand+ALL store) / ALL-ALL-ALL

  Param mapping (Go regListHandler keys):
     @p_from_date | @p_tgl              = anchor date (@p_date in legacy)
                                          @from_date = 1st of month, @to_date = anchor; LY = same range -1 year
     @p_brand_filter | @p_id_brand | @p_brand   = brand (ALL | name | comma list)
     @p_multi_store  | @p_id_store | @p_store_id = store (ALL | id   | comma list)
     @p_id_gh | @p_gh_id | @p_group | @p_actor_nik = kode GH / regional (ALL = no scope; applied only
                                          when the id exists in MASTER_GH_DETAIL / MASTER_REGIONAL_DETAIL)

  Output columns (legacy grid names):
     KODE_group, KODE, DESKRIPSI, SALES_QTY_TAHUN_SEBELUMNYA, SALES_QTY_BERJALAN, GROWTH,
     PERSEN_GROWTH, KONTRIBUSI, inventory_stock, stock_day, ket
  Rows: detail per CLASS (LEFT(PLU,3)), Sub Total per LEFT(CLASS,2) (KODE_group = 'xx total'),
        GRAND TOTAL (KODE_group = '9999999999999 totalgRANDtoT').

  Notes:
   - STRING_SPLIT is used for comma lists (dbo.func_split exists on POS only).
   - Inventory = DT_STOCK_SUMMARY.Z of the latest NO_URUT per (Store_ID, PLU) inside from..to.
   - ket: STOP when stock_day > 90 (or no sales / stock sitting), else KIRIM (Sub/Grand total = '').
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_asbc_qty_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_asbc_qty_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_asbc_qty_getrows
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
        /* ---------------- dates (legacy: @from_date = 1st of month, @to_date = @p_date) ---------------- */
        DECLARE @p_date date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_from_date,''), NULLIF(@p_tgl,'')),''))),'') AS date);
        IF @p_date IS NULL SET @p_date = CAST(GETDATE() AS date);
        DECLARE @from_date date = DATEFROMPARTS(YEAR(@p_date), MONTH(@p_date), 1);
        DECLARE @to_date date = @p_date;
        DECLARE @to_x date = DATEADD(DAY, 1, @to_date);
        DECLARE @ly_from date = DATEADD(YEAR, -1, @from_date);
        DECLARE @ly_to_x date = DATEADD(DAY, 1, DATEADD(YEAR, -1, @to_date));
        DECLARE @jumlah_hari int = DAY(@to_date);

        /* ---------------- filters ---------------- */
        DECLARE @brand_raw varchar(max) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_brand_filter,''), NULLIF(@p_id_brand,''), NULLIF(@p_brand,'')), 'ALL'))));
        DECLARE @store_raw varchar(max) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_multi_store,''), NULLIF(@p_id_store,''), NULLIF(@p_store_id,'')), 'ALL'))));
        IF @brand_raw IN ('','0') SET @brand_raw = 'ALL';
        IF @store_raw IN ('','0') SET @store_raw = 'ALL';

        CREATE TABLE #br (brand varchar(100) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY);
        CREATE TABLE #st (store varchar(50)  COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY);
        INSERT INTO #br (brand)
            SELECT DISTINCT UPPER(LTRIM(RTRIM(value))) FROM STRING_SPLIT(@brand_raw, ',') WHERE LTRIM(RTRIM(value)) <> '';
        INSERT INTO #st (store)
            SELECT DISTINCT UPPER(LTRIM(RTRIM(value))) FROM STRING_SPLIT(@store_raw, ',') WHERE LTRIM(RTRIM(value)) <> '';
        DECLARE @brand_all bit = CASE WHEN EXISTS (SELECT 1 FROM #br WHERE brand = 'ALL') OR NOT EXISTS (SELECT 1 FROM #br) THEN 1 ELSE 0 END;
        DECLARE @store_all bit = CASE WHEN EXISTS (SELECT 1 FROM #st WHERE store = 'ALL') OR NOT EXISTS (SELECT 1 FROM #st) THEN 1 ELSE 0 END;

        /* GH / regional scope (same rule as daily sales: only when the id is a real GH / regional id) */
        DECLARE @gh varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,''), NULLIF(@p_group,''), NULLIF(@p_actor_nik,'')),''))),'');
        DECLARE @scoped bit = 0;
        CREATE TABLE #sc (store varchar(50) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY);
        IF @gh IS NOT NULL AND UPPER(@gh) <> 'ALL' AND (
               EXISTS (SELECT 1 FROM pos_server.dbo.MASTER_GH_DETAIL WITH (NOLOCK) WHERE ID_GROUP_HEAD = @gh)
            OR EXISTS (SELECT 1 FROM pos_server.dbo.MASTER_REGIONAL_DETAIL WITH (NOLOCK) WHERE ID_REGIONAL = @gh))
        BEGIN
            SET @scoped = 1;
            INSERT INTO #sc (store)
            SELECT DISTINCT STORE COLLATE DATABASE_DEFAULT
            FROM (
                SELECT STORE FROM pos_server.dbo.MASTER_GH_DETAIL WITH (NOLOCK) WHERE ID_GROUP_HEAD = @gh
                UNION
                SELECT mgd.STORE FROM pos_server.dbo.MASTER_REGIONAL_DETAIL mrd WITH (NOLOCK)
                  INNER JOIN pos_server.dbo.MASTER_GH_DETAIL mgd WITH (NOLOCK) ON mgd.ID_GROUP_HEAD = mrd.ID_GROUP_HEAD
                 WHERE mrd.ID_REGIONAL = @gh
            ) s WHERE STORE IS NOT NULL;
        END;

        /* ---------------- #stores = gh scope âˆ© brand list âˆ© store list ---------------- */
        CREATE TABLE #stores (store varchar(50) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY);
        INSERT INTO #stores (store)
        SELECT DISTINCT ds.Store_ID COLLATE DATABASE_DEFAULT
        FROM pos_server.dbo.DT_Store ds WITH (NOLOCK)
        WHERE ds.Store_ID IS NOT NULL
          AND (@brand_all = 1 OR EXISTS (
                 SELECT 1 FROM #br b
                 WHERE b.brand = UPPER(ds.Store_Brand_ID) COLLATE DATABASE_DEFAULT
                    OR (b.brand = 'CELCIUS' AND UPPER(ds.Store_Brand_ID) = 'CELCIUS KIDS')))
          AND (@store_all = 1 OR EXISTS (SELECT 1 FROM #st s WHERE s.store = UPPER(ds.Store_ID) COLLATE DATABASE_DEFAULT))
          AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc c WHERE c.store = ds.Store_ID COLLATE DATABASE_DEFAULT));

        /* ---------------- base per CLASS ---------------- */
        CREATE TABLE #cls (kode varchar(3) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
                           ly float NOT NULL, mtd float NOT NULL, inv float NOT NULL);

        /* LY + MTD in one pass over the two ranges */
        SELECT LEFT(a.PLU, 3) COLLATE DATABASE_DEFAULT AS kode,
               SUM(CASE WHEN a.Tanggal >= @ly_from AND a.Tanggal < @ly_to_x THEN CAST(ISNULL(a.QTY,0) AS float) ELSE 0 END) AS ly,
               SUM(CASE WHEN a.Tanggal >= @from_date AND a.Tanggal < @to_x THEN CAST(ISNULL(a.QTY,0) AS float) ELSE 0 END) AS mtd
        INTO #sales
        FROM pos_server.dbo.DT_SALES_SUMMARY a WITH (NOLOCK)
        INNER JOIN #stores s ON s.store = a.Store_ID COLLATE DATABASE_DEFAULT
        WHERE (a.Tanggal >= @ly_from AND a.Tanggal < @ly_to_x)
           OR (a.Tanggal >= @from_date AND a.Tanggal < @to_x)
        GROUP BY LEFT(a.PLU, 3) COLLATE DATABASE_DEFAULT
        OPTION (RECOMPILE);

        /* @akumulasi_tahun_berjalan: MTD qty of all filtered stores (denominator of KONTRIBUSI) */
        DECLARE @akumulasi float = ISNULL((SELECT SUM(mtd) FROM #sales), 0);

        /* inventory: latest NO_URUT per (store, PLU) within from..to */
        SELECT LEFT(x.PLU, 3) COLLATE DATABASE_DEFAULT AS kode, SUM(CAST(ISNULL(x.Z,0) AS float)) AS inv
        INTO #inv
        FROM (
            SELECT a.PLU, a.Z,
                   ROW_NUMBER() OVER (PARTITION BY a.Store_ID, a.PLU ORDER BY a.NO_URUT DESC) AS rn
            FROM pos_server.dbo.DT_STOCK_SUMMARY a WITH (NOLOCK)
            INNER JOIN #stores s ON s.store = a.Store_ID COLLATE DATABASE_DEFAULT
            WHERE a.Tanggal >= @from_date AND a.Tanggal < @to_x
        ) x
        WHERE x.rn = 1
        GROUP BY LEFT(x.PLU, 3) COLLATE DATABASE_DEFAULT
        OPTION (RECOMPILE);

        INSERT INTO #cls (kode, ly, mtd, inv)
        SELECT k.kode, ISNULL(s.ly,0), ISNULL(s.mtd,0), ISNULL(i.inv,0)
        FROM (SELECT kode FROM #sales UNION SELECT kode FROM #inv) k
        LEFT JOIN #sales s ON s.kode = k.kode
        LEFT JOIN #inv   i ON i.kode = k.kode
        WHERE ISNULL(s.ly,0) <> 0 OR ISNULL(s.mtd,0) <> 0 OR ISNULL(i.inv,0) <> 0;

        /* ---------------- detail + sub total + grand total ---------------- */
        CREATE TABLE #agg (grp varchar(40) NOT NULL, kode varchar(10) NOT NULL, descr varchar(200) NULL,
                           ly float NOT NULL, mtd float NOT NULL, inv float NOT NULL,
                           lvl int NOT NULL, ord1 varchar(40) NOT NULL, ord2 int NOT NULL, ord3 varchar(10) NOT NULL);

        /* detail per class (inner join MASTER_CLASS like legacy) */
        INSERT INTO #agg (grp, kode, descr, ly, mtd, inv, lvl, ord1, ord2, ord3)
        SELECT LEFT(c.kode, 2), c.kode, mc.DESKRIPSI, c.ly, c.mtd, c.inv, 0, LEFT(c.kode, 2), 0, c.kode
        FROM #cls c
        INNER JOIN pos_server.dbo.MASTER_CLASS mc WITH (NOLOCK) ON mc.KODE = c.kode;

        /* sub total per 2-char group */
        INSERT INTO #agg (grp, kode, descr, ly, mtd, inv, lvl, ord1, ord2, ord3)
        SELECT g.grp + ' total', '', 'Sub Total:', SUM(g.ly), SUM(g.mtd), SUM(g.inv), 1, g.grp, 1, ''
        FROM #agg g WHERE g.lvl = 0
        GROUP BY g.grp;

        /* grand total */
        INSERT INTO #agg (grp, kode, descr, ly, mtd, inv, lvl, ord1, ord2, ord3)
        SELECT '9999999999999 totalgRANDtoT', '', 'GRAND TOTAL:', SUM(g.ly), SUM(g.mtd), SUM(g.inv), 2, 'ZZZ', 0, ''
        FROM #agg g WHERE g.lvl = 0
        HAVING COUNT(*) > 0;

        /* ---------------- output ---------------- */
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT d.KODE_group, d.KODE, d.DESKRIPSI,
                              d.SALES_QTY_TAHUN_SEBELUMNYA, d.SALES_QTY_BERJALAN, d.GROWTH, d.PERSEN_GROWTH, d.KONTRIBUSI,
                              d.inventory_stock, d.stock_day,
                              CASE WHEN d.lvl <> 0 THEN ''
                                   WHEN d.SALES_QTY_BERJALAN = 0 THEN 'STOP'
                                   WHEN d.raw_stock_day > 90 THEN 'STOP'
                                   ELSE 'KIRIM' END AS ket
                       FROM (
                           SELECT a.grp AS KODE_group, a.kode AS KODE, a.descr AS DESKRIPSI,
                                  a.ly AS SALES_QTY_TAHUN_SEBELUMNYA,
                                  a.mtd AS SALES_QTY_BERJALAN,
                                  a.mtd - a.ly AS GROWTH,
                                  ROUND(ISNULL(CASE WHEN a.ly = 0 THEN a.mtd - a.ly
                                                    WHEN a.ly > 0 THEN (a.mtd - a.ly) / a.ly * 100 END, 0), 0) AS PERSEN_GROWTH,
                                  ROUND(CASE WHEN @akumulasi > 0 THEN a.mtd / @akumulasi * 100 ELSE 0 END, 0) AS KONTRIBUSI,
                                  a.inv AS inventory_stock,
                                  ROUND(CASE WHEN a.mtd = 0 THEN 0 ELSE a.inv / a.mtd * @jumlah_hari END, 0) AS stock_day,
                                  CASE WHEN a.mtd = 0 THEN 0 ELSE a.inv / a.mtd * @jumlah_hari END AS raw_stock_day,
                                  a.lvl, a.ord1, a.ord2, a.ord3
                           FROM #agg a
                       ) d
                       ORDER BY d.ord1, d.ord2, d.ord3
                       FOR JSON PATH, INCLUDE_NULL_VALUES
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        DROP TABLE #agg; DROP TABLE #cls; DROP TABLE #sales; DROP TABLE #inv;
        DROP TABLE #stores; DROP TABLE #sc; DROP TABLE #st; DROP TABLE #br;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#agg') IS NOT NULL DROP TABLE #agg;
        IF OBJECT_ID('tempdb..#cls') IS NOT NULL DROP TABLE #cls;
        IF OBJECT_ID('tempdb..#sales') IS NOT NULL DROP TABLE #sales;
        IF OBJECT_ID('tempdb..#inv') IS NOT NULL DROP TABLE #inv;
        IF OBJECT_ID('tempdb..#stores') IS NOT NULL DROP TABLE #stores;
        IF OBJECT_ID('tempdb..#sc') IS NOT NULL DROP TABLE #sc;
        IF OBJECT_ID('tempdb..#st') IS NOT NULL DROP TABLE #st;
        IF OBJECT_ID('tempdb..#br') IS NOT NULL DROP TABLE #br;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
