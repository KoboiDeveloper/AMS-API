/* Marcomm — Analisa Member (dashboard dinamis per brand)

   Database : POS_SERVER
   Jalankan : _sqlrun.exe -db pos -f sql/marcomm/03_member_analytics.sql

   Semua objek di sini HANYA MEMBACA data (SELECT ... WITH (NOLOCK)). Tabel sementara (#...)
   hidup di tempdb selama satu pemanggilan saja.

   Tidak ada DROP. Tiap objek dibuat sebagai stub bila namanya belum ada, lalu isinya dipasang
   dengan ALTER. ALTER hanya menyentuh objek milik skrip ini:
     dbo.fn_marcomm_analytics_*  dan  dbo.xsp_marcomm_analytics_*

   Aturan bersama
   - Periode  : transaksi dengan tanggal @p_from_date s.d. @p_to_date (inklusif).
   - Recency  : dihitung terhadap @p_to_date, bukan GETDATE(), supaya periode lama bisa dibuka ulang.
   - @p_brand : '' / NULL / 'ALL' = semua brand.
   - Brand diambil dari DT_Store.Store_Brand_ID (tidak ada daftar brand yang ditulis mati).
   - Baris is_total = 1 ('SEMUA BRAND') dihitung ulang dari member unik, bukan penjumlahan brand,
     karena satu member bisa belanja di beberapa brand.

   Sudut pandang brand
   - brand transaksi : brand store tempat transaksi.
   - member per brand: member dihitung di tiap brand tempat ia belanja.
   - brand dominan   : brand dengan belanja (rupiah) terbesar per member (member dihitung sekali).
   - brand utama     : brand dengan jumlah transaksi terbanyak per member di periode (member dihitung
                       sekali). Dipakai di brandhome_*; sengaja dibedakan dari brand dominan.
   - brand pertama   : brand pada hari belanja pertama member.
                       Di retention dan fn_marcomm_analytics_member: hari belanja pertama DI DALAM periode.
                       Di brandhome_*: transaksi pertama SEPANJANG RIWAYAT, tidak ikut berubah bila
                       periode diganti.
*/
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------------
   Dasar 1: transaksi member + brand store
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.fn_marcomm_analytics_tx') IS NULL
  EXEC (N'CREATE FUNCTION dbo.fn_marcomm_analytics_tx() RETURNS TABLE AS RETURN (SELECT 1 AS stub)');
GO
ALTER FUNCTION dbo.fn_marcomm_analytics_tx ()
RETURNS TABLE
AS
RETURN
  SELECT
      t.ID_MEMBER COLLATE DATABASE_DEFAULT                        AS id_member
    , UPPER(LTRIM(RTRIM(s.Store_Brand_ID))) COLLATE DATABASE_DEFAULT AS brand
    , t.ID_STORE COLLATE DATABASE_DEFAULT                         AS id_store
    , t.ID_TR_SALES_HEADER                                        AS id_tr_sales_header
    , t.TIME_STAMP                                                AS ts
    , CONVERT(date, t.TIME_STAMP)                                 AS tgl
    , t.GRAND_TOTAL                                               AS grand_total
  FROM SYS_MEMBER.dbo.DT_POS_TRANSACTION_LOG AS t WITH (NOLOCK)
  INNER JOIN dbo.DT_Store AS s WITH (NOLOCK) ON s.Store_ID = t.ID_STORE
  WHERE ISNULL(t.ID_MEMBER, '') <> ''
    AND ISNULL(s.Store_Brand_ID, '') <> '';
GO

/* ---------------------------------------------------------------------------
   Dasar 2: satu baris per member untuk satu periode (frekuensi, recency, brand, segmen)

   Segmen (urutan penting, yang pertama cocok dipakai):
     A VIP                 : belanja >= batas bawah tier ID 5
     B Loyal aktif         : beli <= 180 hari, >= 3 hari belanja
     C Potensial           : beli <= 180 hari, 2 hari belanja
     D Baru                : beli <= 90 hari, 1 hari belanja
     E Sekali beli 91-180  : beli 91-180 hari, 1 hari belanja
     F Berisiko bernilai   : beli 181-365 hari, bernilai
     G Sekali beli 181-365 : beli 181-365 hari, tidak bernilai
     H Hilang bernilai     : beli > 365 hari, bernilai
     I Hilang sekali beli  : beli > 365 hari, tidak bernilai
   "bernilai" = >= 2 hari belanja ATAU belanja >= batas bawah tier ID 2.
   Batas rupiah dibaca dari DT_MEMBER_TIER_HEADER, jadi ikut berubah bila Master Tier diubah.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.fn_marcomm_analytics_member') IS NULL
  EXEC (N'CREATE FUNCTION dbo.fn_marcomm_analytics_member(@p_from_date date, @p_to_date date) RETURNS TABLE AS RETURN (SELECT 1 AS stub)');
GO
ALTER FUNCTION dbo.fn_marcomm_analytics_member (@p_from_date date, @p_to_date date)
RETURNS TABLE
AS
RETURN
  WITH tx AS (
    SELECT id_member, brand, id_store, tgl, grand_total
    FROM dbo.fn_marcomm_analytics_tx()
    WHERE tgl >= @p_from_date AND tgl <= @p_to_date
  ),
  mb AS (
    SELECT id_member, brand, COUNT(*) AS trx, SUM(grand_total) AS total
    FROM tx
    GROUP BY id_member, brand
  ),
  dom AS (
    SELECT id_member, brand,
           ROW_NUMBER() OVER (PARTITION BY id_member ORDER BY total DESC, trx DESC, brand) AS rn
    FROM mb
  ),
  fd AS (
    SELECT id_member, brand,
           ROW_NUMBER() OVER (PARTITION BY id_member ORDER BY tgl, SUM(grand_total) DESC, brand) AS rn
    FROM tx
    GROUP BY id_member, brand, tgl
  ),
  m AS (
    SELECT id_member
         , COUNT(*)                 AS trx
         , COUNT(DISTINCT tgl)      AS hari_belanja
         , COUNT(DISTINCT id_store) AS stores
         , COUNT(DISTINCT brand)    AS n_brand
         , SUM(grand_total)         AS total
         , MIN(tgl)                 AS first_tgl
         , MAX(tgl)                 AS last_tgl
    FROM tx
    GROUP BY id_member
  ),
  cfg AS (
    SELECT
        ISNULL((SELECT MAX(h.AMOUNT_FROM) FROM SYS_MEMBER.dbo.DT_MEMBER_TIER_HEADER AS h WITH (NOLOCK) WHERE h.ID = 5), 9000000) AS vip_min
      , ISNULL((SELECT MAX(h.AMOUNT_FROM) FROM SYS_MEMBER.dbo.DT_MEMBER_TIER_HEADER AS h WITH (NOLOCK) WHERE h.ID = 2), 1500000) AS value_min
  )
  SELECT
      m.id_member, m.trx, m.hari_belanja, m.stores, m.n_brand, m.total, m.first_tgl, m.last_tgl
    , x.hari
    , d.brand AS brand_dominan
    , f.brand AS brand_pertama
    , c.vip_min, c.value_min
    , CAST(CASE
        WHEN m.total >= c.vip_min                                                          THEN 'A'
        WHEN x.hari <= 180 AND m.hari_belanja >= 3                                         THEN 'B'
        WHEN x.hari <= 180 AND m.hari_belanja = 2                                          THEN 'C'
        WHEN x.hari <= 90  AND m.hari_belanja = 1                                          THEN 'D'
        WHEN x.hari <= 180 AND m.hari_belanja = 1                                          THEN 'E'
        WHEN x.hari <= 365 AND (m.hari_belanja >= 2 OR m.total >= c.value_min)             THEN 'F'
        WHEN x.hari <= 365                                                                 THEN 'G'
        WHEN m.hari_belanja >= 2 OR m.total >= c.value_min                                 THEN 'H'
        ELSE 'I'
      END AS char(1)) AS segmen
  FROM m
  CROSS APPLY (SELECT DATEDIFF(day, m.last_tgl, @p_to_date) AS hari) AS x
  INNER JOIN dom AS d ON d.id_member = m.id_member AND d.rn = 1
  INNER JOIN fd  AS f ON f.id_member = m.id_member AND f.rn = 1
  CROSS JOIN cfg AS c;
GO

/* ---------------------------------------------------------------------------
   meta: cakupan data per brand (untuk daftar brand dan batas tanggal data)
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_meta') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_meta AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_meta
AS
BEGIN
  SET NOCOUNT ON;

  SELECT id_member, brand, tgl, ts
  INTO #tx
  FROM dbo.fn_marcomm_analytics_tx();

  SELECT brand, CAST(0 AS int) AS is_total
       , COUNT(*) AS trx, COUNT(DISTINCT id_member) AS members
       , MIN(tgl) AS first_tgl, MAX(tgl) AS last_tgl, MAX(ts) AS last_ts
  FROM #tx
  GROUP BY brand
  UNION ALL
  SELECT 'SEMUA BRAND', 1
       , COUNT(*), COUNT(DISTINCT id_member)
       , MIN(tgl), MAX(tgl), MAX(ts)
  FROM #tx
  ORDER BY is_total, brand;
END
GO

/* ---------------------------------------------------------------------------
   brand_overview: ringkasan per brand (brand transaksi + member per brand)
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_brand_overview') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_brand_overview AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_brand_overview
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT id_member, brand, id_store, tgl, grand_total
  INTO #tx
  FROM dbo.fn_marcomm_analytics_tx()
  WHERE tgl >= @p_from_date AND tgl <= @p_to_date;

  /* belanja pertama sepanjang riwayat, untuk menandai member yang baru mulai belanja di periode ini */
  SELECT id_member, MIN(tgl) AS first_tgl
  INTO #first
  FROM dbo.fn_marcomm_analytics_tx()
  GROUP BY id_member;

  SELECT brand, id_member, COUNT(*) AS trx, COUNT(DISTINCT tgl) AS hari_belanja, SUM(grand_total) AS total
  INTO #mb
  FROM #tx
  GROUP BY brand, id_member;

  SELECT id_member, COUNT(*) AS trx, COUNT(DISTINCT tgl) AS hari_belanja, SUM(grand_total) AS total
  INTO #m
  FROM #tx
  GROUP BY id_member;

  SELECT b.brand, CAST(0 AS int) AS is_total
       , b.members, b.trx, b.omzet, s.stores, b.sekali_belanja, b.repeat_buyer, b.member_baru
  FROM (
    SELECT mb.brand
         , COUNT(*)      AS members
         , SUM(mb.trx)   AS trx
         , SUM(mb.total) AS omzet
         , SUM(CASE WHEN mb.hari_belanja = 1 THEN 1 ELSE 0 END)        AS sekali_belanja
         , SUM(CASE WHEN mb.hari_belanja >= 2 THEN 1 ELSE 0 END)       AS repeat_buyer
         , SUM(CASE WHEN f.first_tgl >= @p_from_date THEN 1 ELSE 0 END) AS member_baru
    FROM #mb AS mb
    INNER JOIN #first AS f ON f.id_member = mb.id_member
    GROUP BY mb.brand
  ) AS b
  INNER JOIN (SELECT brand, COUNT(DISTINCT id_store) AS stores FROM #tx GROUP BY brand) AS s ON s.brand = b.brand
  WHERE (@brand = '' OR b.brand = @brand)
  UNION ALL
  SELECT 'SEMUA BRAND', 1
       , COUNT(*), ISNULL(SUM(m.trx), 0), ISNULL(SUM(m.total), 0)
       , (SELECT COUNT(DISTINCT id_store) FROM #tx)
       , ISNULL(SUM(CASE WHEN m.hari_belanja = 1 THEN 1 ELSE 0 END), 0)
       , ISNULL(SUM(CASE WHEN m.hari_belanja >= 2 THEN 1 ELSE 0 END), 0)
       , ISNULL(SUM(CASE WHEN f.first_tgl >= @p_from_date THEN 1 ELSE 0 END), 0)
  FROM #m AS m
  INNER JOIN #first AS f ON f.id_member = m.id_member
  ORDER BY is_total, omzet DESC;
END
GO

/* ---------------------------------------------------------------------------
   trend: per bulan x brand (brand transaksi)
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_trend') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_trend AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_trend
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT id_member, MIN(tgl) AS first_tgl
  INTO #first
  FROM dbo.fn_marcomm_analytics_tx()
  GROUP BY id_member;

  SELECT CONVERT(char(7), t.tgl, 120) AS bulan, t.brand, t.id_member, t.id_store, t.grand_total
       , CASE WHEN CONVERT(char(7), f.first_tgl, 120) = CONVERT(char(7), t.tgl, 120) THEN 1 ELSE 0 END AS is_baru
  INTO #x
  FROM dbo.fn_marcomm_analytics_tx() AS t
  INNER JOIN #first AS f ON f.id_member = t.id_member
  WHERE t.tgl >= @p_from_date AND t.tgl <= @p_to_date;

  SELECT bulan, brand, CAST(0 AS int) AS is_total
       , SUM(trx) AS trx, COUNT(*) AS members, SUM(omzet) AS omzet
       , (SELECT COUNT(DISTINCT x.id_store) FROM #x AS x WHERE x.bulan = g.bulan AND x.brand = g.brand) AS stores
       , SUM(is_baru) AS member_baru
  FROM (
    SELECT bulan, brand, id_member, COUNT(*) AS trx, SUM(grand_total) AS omzet, MAX(is_baru) AS is_baru
    FROM #x
    GROUP BY bulan, brand, id_member
  ) AS g
  WHERE (@brand = '' OR brand = @brand)
  GROUP BY bulan, brand
  UNION ALL
  SELECT bulan, 'SEMUA BRAND', 1
       , SUM(trx), COUNT(*), SUM(omzet)
       , (SELECT COUNT(DISTINCT x.id_store) FROM #x AS x WHERE x.bulan = g.bulan)
       , SUM(is_baru)
  FROM (
    SELECT bulan, id_member, COUNT(*) AS trx, SUM(grand_total) AS omzet, MAX(is_baru) AS is_baru
    FROM #x
    GROUP BY bulan, id_member
  ) AS g
  GROUP BY bulan
  ORDER BY bulan, is_total, brand;
END
GO

/* ---------------------------------------------------------------------------
   retention: frekuensi + recency (member per brand) dan kohort balik belanja (brand pertama)
   Kohort hanya menghitung member yang sudah melewati jendela 30/90/180 hari sampai @p_to_date.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_retention') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_retention AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_retention
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  /* satu baris per member x brand x hari belanja */
  SELECT id_member, brand, tgl, SUM(grand_total) AS total
  INTO #d
  FROM dbo.fn_marcomm_analytics_tx()
  WHERE tgl >= @p_from_date AND tgl <= @p_to_date
  GROUP BY id_member, brand, tgl;

  CREATE CLUSTERED INDEX ix_d ON #d (id_member, tgl);

  SELECT brand, id_member, COUNT(*) AS hari_belanja, DATEDIFF(day, MAX(tgl), @p_to_date) AS hari
  INTO #mb
  FROM #d
  GROUP BY brand, id_member;

  SELECT id_member, COUNT(DISTINCT tgl) AS hari_belanja, DATEDIFF(day, MAX(tgl), @p_to_date) AS hari
  INTO #m
  FROM #d
  GROUP BY id_member;

  ;WITH f AS (
    SELECT id_member, brand, tgl,
           ROW_NUMBER() OVER (PARTITION BY id_member ORDER BY tgl, total DESC, brand) AS rn
    FROM #d
  )
  SELECT f.id_member, f.brand AS brand_pertama, f.tgl AS first_tgl
       , DATEDIFF(day, f.tgl, @p_to_date) AS umur
       , DATEDIFF(day, f.tgl, (SELECT MIN(d.tgl) FROM #d AS d WHERE d.id_member = f.id_member AND d.tgl > f.tgl)) AS gap_any
       , DATEDIFF(day, f.tgl, (SELECT MIN(d.tgl) FROM #d AS d WHERE d.id_member = f.id_member AND d.tgl > f.tgl AND d.brand = f.brand)) AS gap_same
       , DATEDIFF(day, f.tgl, (SELECT MIN(d.tgl) FROM #d AS d WHERE d.id_member = f.id_member AND d.tgl > f.tgl AND d.brand <> f.brand)) AS gap_other
  INTO #k
  FROM f
  WHERE f.rn = 1;

  SELECT x.brand, CAST(0 AS int) AS is_total
       , x.members, x.hb1, x.hb2, x.hb3p
       , x.r_0_30, x.r_31_90, x.r_91_180, x.r_181_365, x.r_365p
       , ISNULL(k.k30_members, 0)  AS k30_members,  ISNULL(k.k30_balik, 0)  AS k30_balik
       , ISNULL(k.k90_members, 0)  AS k90_members,  ISNULL(k.k90_balik, 0)  AS k90_balik
       , ISNULL(k.k180_members, 0) AS k180_members, ISNULL(k.k180_balik, 0) AS k180_balik
       , ISNULL(k.k180_balik_sama, 0) AS k180_balik_sama, ISNULL(k.k180_balik_lain, 0) AS k180_balik_lain
  FROM (
    SELECT brand
         , COUNT(*) AS members
         , SUM(CASE WHEN hari_belanja = 1 THEN 1 ELSE 0 END)  AS hb1
         , SUM(CASE WHEN hari_belanja = 2 THEN 1 ELSE 0 END)  AS hb2
         , SUM(CASE WHEN hari_belanja >= 3 THEN 1 ELSE 0 END) AS hb3p
         , SUM(CASE WHEN hari <= 30 THEN 1 ELSE 0 END)                AS r_0_30
         , SUM(CASE WHEN hari BETWEEN 31 AND 90 THEN 1 ELSE 0 END)    AS r_31_90
         , SUM(CASE WHEN hari BETWEEN 91 AND 180 THEN 1 ELSE 0 END)   AS r_91_180
         , SUM(CASE WHEN hari BETWEEN 181 AND 365 THEN 1 ELSE 0 END)  AS r_181_365
         , SUM(CASE WHEN hari > 365 THEN 1 ELSE 0 END)                AS r_365p
    FROM #mb
    GROUP BY brand
  ) AS x
  LEFT JOIN (
    SELECT brand_pertama AS brand
         , SUM(CASE WHEN umur >= 30 THEN 1 ELSE 0 END)                         AS k30_members
         , SUM(CASE WHEN umur >= 30 AND gap_any <= 30 THEN 1 ELSE 0 END)       AS k30_balik
         , SUM(CASE WHEN umur >= 90 THEN 1 ELSE 0 END)                         AS k90_members
         , SUM(CASE WHEN umur >= 90 AND gap_any <= 90 THEN 1 ELSE 0 END)       AS k90_balik
         , SUM(CASE WHEN umur >= 180 THEN 1 ELSE 0 END)                        AS k180_members
         , SUM(CASE WHEN umur >= 180 AND gap_any <= 180 THEN 1 ELSE 0 END)     AS k180_balik
         , SUM(CASE WHEN umur >= 180 AND gap_same <= 180 THEN 1 ELSE 0 END)    AS k180_balik_sama
         , SUM(CASE WHEN umur >= 180 AND gap_other <= 180 THEN 1 ELSE 0 END)   AS k180_balik_lain
    FROM #k
    GROUP BY brand_pertama
  ) AS k ON k.brand = x.brand
  WHERE (@brand = '' OR x.brand = @brand)
  UNION ALL
  SELECT 'SEMUA BRAND', 1
       , a.members, a.hb1, a.hb2, a.hb3p
       , a.r_0_30, a.r_31_90, a.r_91_180, a.r_181_365, a.r_365p
       , k.k30_members, k.k30_balik, k.k90_members, k.k90_balik
       , k.k180_members, k.k180_balik, k.k180_balik_sama, k.k180_balik_lain
  FROM (
    SELECT COUNT(*) AS members
         , ISNULL(SUM(CASE WHEN hari_belanja = 1 THEN 1 ELSE 0 END), 0)  AS hb1
         , ISNULL(SUM(CASE WHEN hari_belanja = 2 THEN 1 ELSE 0 END), 0)  AS hb2
         , ISNULL(SUM(CASE WHEN hari_belanja >= 3 THEN 1 ELSE 0 END), 0) AS hb3p
         , ISNULL(SUM(CASE WHEN hari <= 30 THEN 1 ELSE 0 END), 0)                AS r_0_30
         , ISNULL(SUM(CASE WHEN hari BETWEEN 31 AND 90 THEN 1 ELSE 0 END), 0)    AS r_31_90
         , ISNULL(SUM(CASE WHEN hari BETWEEN 91 AND 180 THEN 1 ELSE 0 END), 0)   AS r_91_180
         , ISNULL(SUM(CASE WHEN hari BETWEEN 181 AND 365 THEN 1 ELSE 0 END), 0)  AS r_181_365
         , ISNULL(SUM(CASE WHEN hari > 365 THEN 1 ELSE 0 END), 0)                AS r_365p
    FROM #m
  ) AS a
  CROSS JOIN (
    SELECT ISNULL(SUM(CASE WHEN umur >= 30 THEN 1 ELSE 0 END), 0)                        AS k30_members
         , ISNULL(SUM(CASE WHEN umur >= 30 AND gap_any <= 30 THEN 1 ELSE 0 END), 0)      AS k30_balik
         , ISNULL(SUM(CASE WHEN umur >= 90 THEN 1 ELSE 0 END), 0)                        AS k90_members
         , ISNULL(SUM(CASE WHEN umur >= 90 AND gap_any <= 90 THEN 1 ELSE 0 END), 0)      AS k90_balik
         , ISNULL(SUM(CASE WHEN umur >= 180 THEN 1 ELSE 0 END), 0)                       AS k180_members
         , ISNULL(SUM(CASE WHEN umur >= 180 AND gap_any <= 180 THEN 1 ELSE 0 END), 0)    AS k180_balik
         , ISNULL(SUM(CASE WHEN umur >= 180 AND gap_same <= 180 THEN 1 ELSE 0 END), 0)   AS k180_balik_sama
         , ISNULL(SUM(CASE WHEN umur >= 180 AND gap_other <= 180 THEN 1 ELSE 0 END), 0)  AS k180_balik_lain
    FROM #k
  ) AS k
  ORDER BY is_total, brand;
END
GO

/* ---------------------------------------------------------------------------
   segment: segmen x brand dominan (tiap member dihitung sekali, jadi boleh dijumlah)
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_segment') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_segment AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_segment
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT segmen, brand_dominan, trx, hari_belanja, total, vip_min, value_min
  INTO #m
  FROM dbo.fn_marcomm_analytics_member(@p_from_date, @p_to_date);

  SELECT segmen, brand_dominan AS brand
       , COUNT(*) AS members, SUM(trx) AS trx, SUM(total) AS omzet, SUM(hari_belanja) AS hari_belanja
       , MAX(vip_min) AS vip_min, MAX(value_min) AS value_min
  FROM #m
  WHERE (@brand = '' OR brand_dominan = @brand)
  GROUP BY segmen, brand_dominan
  ORDER BY segmen, brand_dominan;
END
GO

/* ---------------------------------------------------------------------------
   crossbrand_brand: member eksklusif vs lintas brand (member per brand)
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_crossbrand_brand') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_crossbrand_brand AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_crossbrand_brand
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT id_member, brand, SUM(grand_total) AS total
  INTO #mb
  FROM dbo.fn_marcomm_analytics_tx()
  WHERE tgl >= @p_from_date AND tgl <= @p_to_date
  GROUP BY id_member, brand;

  SELECT id_member, COUNT(*) AS n_brand, SUM(total) AS total_all
  INTO #mt
  FROM #mb
  GROUP BY id_member;

  SELECT mb.brand, CAST(0 AS int) AS is_total
       , COUNT(*) AS members
       , SUM(CASE WHEN mt.n_brand = 1 THEN 1 ELSE 0 END)  AS eksklusif
       , SUM(CASE WHEN mt.n_brand >= 2 THEN 1 ELSE 0 END) AS lintas
       , SUM(mb.total) AS omzet_brand
       , SUM(CASE WHEN mt.n_brand = 1 THEN mt.total_all ELSE 0 END)             AS omzet_eksklusif
       , SUM(CASE WHEN mt.n_brand >= 2 THEN mt.total_all ELSE 0 END)            AS omzet_lintas_total
       , SUM(CASE WHEN mt.n_brand >= 2 THEN mt.total_all - mb.total ELSE 0 END) AS omzet_lintas_di_brand_lain
  FROM #mb AS mb
  INNER JOIN #mt AS mt ON mt.id_member = mb.id_member
  WHERE (@brand = '' OR mb.brand = @brand)
  GROUP BY mb.brand
  UNION ALL
  SELECT 'SEMUA BRAND', 1
       , COUNT(*)
       , ISNULL(SUM(CASE WHEN n_brand = 1 THEN 1 ELSE 0 END), 0)
       , ISNULL(SUM(CASE WHEN n_brand >= 2 THEN 1 ELSE 0 END), 0)
       , ISNULL(SUM(total_all), 0)
       , ISNULL(SUM(CASE WHEN n_brand = 1 THEN total_all ELSE 0 END), 0)
       , ISNULL(SUM(CASE WHEN n_brand >= 2 THEN total_all ELSE 0 END), 0)
       , CAST(0 AS decimal(18, 2))
  FROM #mt
  ORDER BY is_total, brand;
END
GO

/* ---------------------------------------------------------------------------
   crossbrand_pair: jumlah member yang belanja di dua brand sekaligus
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_crossbrand_pair') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_crossbrand_pair AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_crossbrand_pair
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT DISTINCT id_member, brand
  INTO #pb
  FROM dbo.fn_marcomm_analytics_tx()
  WHERE tgl >= @p_from_date AND tgl <= @p_to_date;

  SELECT brand, COUNT(*) AS members
  INTO #bm
  FROM #pb
  GROUP BY brand;

  SELECT p.brand_a, p.brand_b, p.members, a.members AS members_a, b.members AS members_b
  FROM (
    SELECT x.brand AS brand_a, y.brand AS brand_b, COUNT(*) AS members
    FROM #pb AS x
    INNER JOIN #pb AS y ON y.id_member = x.id_member AND y.brand > x.brand
    GROUP BY x.brand, y.brand
  ) AS p
  INNER JOIN #bm AS a ON a.brand = p.brand_a
  INNER JOIN #bm AS b ON b.brand = p.brand_b
  WHERE (@brand = '' OR p.brand_a = @brand OR p.brand_b = @brand)
  ORDER BY p.members DESC, p.brand_a, p.brand_b;
END
GO

/* ---------------------------------------------------------------------------
   Dasar 3: satu baris per member yang bertransaksi di periode, dengan brand pertama dan brand utama

   Brand pertama : brand pada transaksi pertama member sepanjang riwayat (urut waktu transaksi).
                   Transaksi pertama selalu lebih awal dari transaksi di periode, jadi cukup dibaca
                   sampai @p_to_date.
   is_baru       : transaksi pertama sepanjang riwayat jatuh di dalam periode.
   Brand utama   : brand dengan jumlah transaksi terbanyak di periode. Seri diputus oleh omzet lebih
                   besar, lalu transaksi paling baru, lalu nama brand.
   n_teratas     : jumlah brand yang sama-sama punya transaksi terbanyak (>= 2 berarti seri).
   trx, total    : seluruh transaksi dan belanja member di periode, semua brand.
   n_brand       : jumlah brand tempat member bertransaksi di periode.
   last_tgl      : tanggal transaksi terakhir member di periode.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.fn_marcomm_analytics_brandhome') IS NULL
  EXEC (N'CREATE FUNCTION dbo.fn_marcomm_analytics_brandhome(@p_from_date date, @p_to_date date) RETURNS TABLE AS RETURN (SELECT 1 AS stub)');
GO
ALTER FUNCTION dbo.fn_marcomm_analytics_brandhome (@p_from_date date, @p_to_date date)
RETURNS TABLE
AS
RETURN
  WITH f AS (
    SELECT id_member, brand, tgl,
           ROW_NUMBER() OVER (PARTITION BY id_member ORDER BY ts, id_tr_sales_header, brand) AS rn
    FROM dbo.fn_marcomm_analytics_tx()
    WHERE tgl <= @p_to_date
  ),
  mb AS (
    SELECT id_member, brand, COUNT(*) AS trx, ISNULL(SUM(grand_total), 0) AS total, MAX(ts) AS last_ts
    FROM dbo.fn_marcomm_analytics_tx()
    WHERE tgl >= @p_from_date AND tgl <= @p_to_date
    GROUP BY id_member, brand
  ),
  y AS (
    SELECT id_member, brand, trx, total, last_ts
         , MAX(trx)   OVER (PARTITION BY id_member) AS trx_max
         , SUM(trx)   OVER (PARTITION BY id_member) AS trx_all
         , SUM(total) OVER (PARTITION BY id_member) AS total_all
         , MAX(last_ts) OVER (PARTITION BY id_member) AS last_ts_all
         , COUNT(*)   OVER (PARTITION BY id_member) AS n_brand
    FROM mb
  ),
  u AS (
    SELECT id_member, brand, trx, trx_all, total_all, last_ts_all, n_brand
         , ROW_NUMBER() OVER (PARTITION BY id_member ORDER BY trx DESC, total DESC, last_ts DESC, brand) AS rn
         , SUM(CASE WHEN trx = trx_max THEN 1 ELSE 0 END) OVER (PARTITION BY id_member) AS n_teratas
    FROM y
  )
  SELECT u.id_member
       , f.brand AS brand_pertama
       , f.tgl   AS first_tgl
       , CAST(CASE WHEN f.tgl >= @p_from_date THEN 1 ELSE 0 END AS int) AS is_baru
       , u.brand     AS brand_utama
       , u.trx       AS trx_di_utama
       , u.trx_all   AS trx
       , u.total_all AS total
       , u.n_teratas
       , u.n_brand
       , CONVERT(date, u.last_ts_all) AS last_tgl
  FROM u
  INNER JOIN f ON f.id_member = u.id_member AND f.rn = 1
  WHERE u.rn = 1;
GO

/* ---------------------------------------------------------------------------
   brandhome_brand: member per brand menurut brand pertama dan menurut brand utama
   Tiap member dihitung sekali di tiap sudut pandang, jadi jumlah semua brand = baris SEMUA BRAND.
   setia      : brand utama = brand pertama.
   setia_lama : sama, hanya untuk member lama (transaksi pertamanya sebelum periode). Member baru
                dengan satu transaksi otomatis "setia", jadi angka member lama lebih bermakna.
   Kolom *_utama dan seri/satu_transaksi dikelompokkan menurut brand utama; trx_utama dan omzet_utama
   adalah seluruh transaksi/belanja member itu di semua brand.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_brandhome_brand') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_brandhome_brand AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_brandhome_brand
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT id_member, brand_pertama, is_baru, brand_utama, trx_di_utama, trx, total, n_teratas
  INTO #j
  FROM dbo.fn_marcomm_analytics_brandhome(@p_from_date, @p_to_date);

  SELECT b.brand, CAST(0 AS int) AS is_total
       , ISNULL(p.members_pertama, 0)    AS members_pertama
       , ISNULL(p.baru_pertama, 0)       AS baru_pertama
       , ISNULL(p.setia, 0)              AS setia
       , ISNULL(p.setia_lama, 0)         AS setia_lama
       , ISNULL(u.members_utama, 0)      AS members_utama
       , ISNULL(u.trx_utama, 0)          AS trx_utama
       , ISNULL(u.omzet_utama, 0)        AS omzet_utama
       , ISNULL(u.trx_di_brand_utama, 0) AS trx_di_brand_utama
       , ISNULL(u.seri, 0)               AS seri
       , ISNULL(u.satu_transaksi, 0)     AS satu_transaksi
  FROM (SELECT brand_pertama AS brand FROM #j UNION SELECT brand_utama FROM #j) AS b
  LEFT JOIN (
    SELECT brand_pertama AS brand
         , COUNT(*)     AS members_pertama
         , SUM(is_baru) AS baru_pertama
         , SUM(CASE WHEN brand_utama = brand_pertama THEN 1 ELSE 0 END) AS setia
         , SUM(CASE WHEN brand_utama = brand_pertama AND is_baru = 0 THEN 1 ELSE 0 END) AS setia_lama
    FROM #j
    GROUP BY brand_pertama
  ) AS p ON p.brand = b.brand
  LEFT JOIN (
    SELECT brand_utama AS brand
         , COUNT(*)          AS members_utama
         , SUM(trx)          AS trx_utama
         , SUM(total)        AS omzet_utama
         , SUM(trx_di_utama) AS trx_di_brand_utama
         , SUM(CASE WHEN n_teratas >= 2 THEN 1 ELSE 0 END) AS seri
         , SUM(CASE WHEN trx = 1 THEN 1 ELSE 0 END)        AS satu_transaksi
    FROM #j
    GROUP BY brand_utama
  ) AS u ON u.brand = b.brand
  WHERE (@brand = '' OR b.brand = @brand)
  UNION ALL
  SELECT 'SEMUA BRAND', 1
       , COUNT(*)
       , ISNULL(SUM(is_baru), 0)
       , ISNULL(SUM(CASE WHEN brand_utama = brand_pertama THEN 1 ELSE 0 END), 0)
       , ISNULL(SUM(CASE WHEN brand_utama = brand_pertama AND is_baru = 0 THEN 1 ELSE 0 END), 0)
       , COUNT(*)
       , ISNULL(SUM(trx), 0)
       , ISNULL(SUM(total), 0)
       , ISNULL(SUM(trx_di_utama), 0)
       , ISNULL(SUM(CASE WHEN n_teratas >= 2 THEN 1 ELSE 0 END), 0)
       , ISNULL(SUM(CASE WHEN trx = 1 THEN 1 ELSE 0 END), 0)
  FROM #j
  ORDER BY is_total, brand;
END
GO

/* ---------------------------------------------------------------------------
   brandhome_matrix: perpindahan dari brand pertama ke brand utama (jumlah member per pasangan)
   brand_pertama = brand_utama berarti member tetap paling sering bertransaksi di brand awalnya.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_brandhome_matrix') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_brandhome_matrix AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_brandhome_matrix
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT brand_pertama, brand_utama
  INTO #j
  FROM dbo.fn_marcomm_analytics_brandhome(@p_from_date, @p_to_date);

  SELECT brand_pertama, brand_utama, COUNT(*) AS members
  FROM #j
  WHERE (@brand = '' OR brand_pertama = @brand OR brand_utama = @brand)
  GROUP BY brand_pertama, brand_utama
  ORDER BY brand_pertama, brand_utama;
END
GO

/* ---------------------------------------------------------------------------
   brandhome_trend: member baru per bulan menurut brand pertama
   Hanya member yang transaksi pertamanya sepanjang riwayat jatuh di dalam periode.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_brandhome_trend') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_brandhome_trend AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_brandhome_trend
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT brand_pertama, first_tgl
  INTO #j
  FROM dbo.fn_marcomm_analytics_brandhome(@p_from_date, @p_to_date)
  WHERE is_baru = 1;

  SELECT CONVERT(char(7), first_tgl, 120) AS bulan, brand_pertama, COUNT(*) AS members
  FROM #j
  WHERE (@brand = '' OR brand_pertama = @brand)
  GROUP BY CONVERT(char(7), first_tgl, 120), brand_pertama
  ORDER BY bulan, brand_pertama;
END
GO

/* ---------------------------------------------------------------------------
   brandhome_members: daftar member menurut brand pertama dan/atau brand utama, dengan paging
   @p_brand_pertama / @p_brand_utama : '' = semua brand.
   @p_baru : 1 = member baru (transaksi pertamanya di periode), 0 = member lama, lainnya = semua.
   Urut dari total belanja terbesar di periode.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_brandhome_members') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_brandhome_members AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_brandhome_members
(
    @p_from_date     date
  , @p_to_date       date
  , @p_brand_pertama varchar(50) = ''
  , @p_brand_utama   varchar(50) = ''
  , @p_baru          int = -1
  , @p_page          int = 1
  , @p_page_size     int = 50
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @first varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand_pertama, ''))));
  IF @first IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @first = '';
  DECLARE @main varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand_utama, ''))));
  IF @main IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @main = '';
  DECLARE @baru int = CASE WHEN @p_baru IN (0, 1) THEN @p_baru ELSE -1 END;
  DECLARE @size int = CASE WHEN ISNULL(@p_page_size, 0) < 1 THEN 50 WHEN @p_page_size > 20000 THEN 20000 ELSE @p_page_size END;
  DECLARE @page int = CASE WHEN ISNULL(@p_page, 0) < 1 THEN 1 ELSE @p_page END;

  SELECT id_member, brand_pertama, first_tgl, is_baru, brand_utama, trx_di_utama, trx, total, n_teratas, n_brand, last_tgl
  INTO #j
  FROM dbo.fn_marcomm_analytics_brandhome(@p_from_date, @p_to_date);

  SELECT COUNT(*) OVER () AS total_rows
       , j.brand_pertama, j.brand_utama, j.is_baru
       , mm.ID_MEMBER_APPS AS id_member_apps, mm.Nama AS nama, mm.NoTelpon AS no_telpon, mm.Email AS email
       , mm.Jenis_kelamin AS jenis_kelamin
       , j.trx, j.trx_di_utama, j.n_brand, j.n_teratas, j.total
       , j.first_tgl, j.last_tgl
       , j.id_member
  FROM #j AS j
  LEFT JOIN dbo.dt_member AS mm WITH (NOLOCK)
    ON mm.ID_MEMBER COLLATE DATABASE_DEFAULT = j.id_member COLLATE DATABASE_DEFAULT
  WHERE (@first = '' OR j.brand_pertama = @first)
    AND (@main = '' OR j.brand_utama = @main)
    AND (@baru = -1 OR j.is_baru = @baru)
  ORDER BY j.total DESC, j.id_member
  OFFSET (@page - 1) * @size ROWS FETCH NEXT @size ROWS ONLY;
END
GO

/* ---------------------------------------------------------------------------
   voucher: voucher yang dibuat di periode, per kategori x jenis x brand dominan member
   Status pakai/hangus adalah kondisi saat ini (GETDATE()).
   Brand dominan dihitung dari seluruh riwayat sampai @p_to_date.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_voucher') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_voucher AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_voucher
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';
  DECLARE @now datetime = GETDATE();

  SELECT id_member, brand_dominan
  INTO #m
  FROM dbo.fn_marcomm_analytics_member(CONVERT(date, '20000101'), @p_to_date);

  SELECT id_member, ts
  INTO #t
  FROM dbo.fn_marcomm_analytics_tx();

  CREATE CLUSTERED INDEX ix_t ON #t (id_member, ts);

  SELECT v.ID_MEMBER COLLATE DATABASE_DEFAULT AS id_member
       , UPPER(ISNULL(NULLIF(LTRIM(RTRIM(v.CATEGORY)), ''), '(TANPA KATEGORI)')) COLLATE DATABASE_DEFAULT AS kategori
       , CASE WHEN ISNULL(v.PointVoucher, 0) = 0 THEN 'GRATIS' ELSE 'TUKAR POIN' END AS jenis
       , CASE WHEN UPPER(ISNULL(v.TIPE_POTONGAN, '')) = 'NOMINAL' THEN v.NilaiVoucher ELSE 0 END AS nilai_nominal
       , v.Tanggal_Buat, v.Tanggal_Expired
       , CASE WHEN v.Status_Penggunaan = '1' THEN 1 ELSE 0 END AS dipakai
  INTO #v0
  FROM SYS_MEMBER.dbo.DT_MEMBER_VOUCHER AS v WITH (NOLOCK)
  WHERE v.Tanggal_Buat >= @p_from_date
    AND v.Tanggal_Buat < DATEADD(day, 1, @p_to_date);

  SELECT v.id_member, v.kategori, v.jenis, v.nilai_nominal, v.dipakai
       , ISNULL(m.brand_dominan, 'TANPA TRANSAKSI') AS brand
       , CASE WHEN v.dipakai = 0 AND v.Tanggal_Expired < @now THEN 1 ELSE 0 END  AS hangus
       , CASE WHEN v.dipakai = 0 AND (v.Tanggal_Expired >= @now OR v.Tanggal_Expired IS NULL) THEN 1 ELSE 0 END AS aktif
       , CASE WHEN v.dipakai = 0 AND EXISTS (
                SELECT 1 FROM #t AS t
                WHERE t.id_member = v.id_member AND t.ts >= v.Tanggal_Buat AND t.ts <= v.Tanggal_Expired
              ) THEN 1 ELSE 0 END AS belanja_tanpa_pakai
  INTO #v
  FROM #v0 AS v
  LEFT JOIN #m AS m ON m.id_member = v.id_member;

  SELECT kategori, jenis, brand, CAST(0 AS int) AS is_total
       , COUNT(*) AS voucher, COUNT(DISTINCT id_member) AS members
       , SUM(nilai_nominal) AS nilai_nominal
       , SUM(dipakai) AS dipakai, SUM(hangus) AS hangus, SUM(aktif) AS aktif
       , SUM(belanja_tanpa_pakai) AS belanja_tanpa_pakai
  FROM #v
  WHERE (@brand = '' OR brand = @brand)
  GROUP BY kategori, jenis, brand
  UNION ALL
  SELECT kategori, jenis, 'SEMUA BRAND', 1
       , COUNT(*), COUNT(DISTINCT id_member)
       , SUM(nilai_nominal)
       , SUM(dipakai), SUM(hangus), SUM(aktif)
       , SUM(belanja_tanpa_pakai)
  FROM #v
  GROUP BY kategori, jenis
  ORDER BY kategori, jenis, is_total, brand;
END
GO

/* ---------------------------------------------------------------------------
   birthday: member pembeli yang ulang tahun dalam @p_days hari setelah @p_to_date,
   per brand dominan. lolos_email = syarat SP email ulang tahun (validasi_email dan validasi_data).
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_birthday') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_birthday AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_birthday
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
  , @p_days      int = 30
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';
  DECLARE @tier1 decimal(18, 2) =
    ISNULL((SELECT MAX(h.AMOUNT_FROM) FROM SYS_MEMBER.dbo.DT_MEMBER_TIER_HEADER AS h WITH (NOLOCK) WHERE h.ID = 1), 750000);

  SELECT id_member, brand_dominan, total, hari
  INTO #m
  FROM dbo.fn_marcomm_analytics_member(@p_from_date, @p_to_date);

  SELECT m.brand_dominan AS brand, m.total, m.hari
       , ISNULL(mm.validasi_email, 0) AS validasi_email
       , ISNULL(mm.validasi_data, 0)  AS validasi_data
       , CASE WHEN ISNULL(LTRIM(RTRIM(mm.NoTelpon)), '') <> '' THEN 1 ELSE 0 END AS punya_telp
       , CASE WHEN mm.TglLahir IS NULL OR YEAR(mm.TglLahir) < 1930 OR CONVERT(date, mm.TglLahir) > @p_to_date
              THEN NULL ELSE CONVERT(date, mm.TglLahir) END AS dob
  INTO #b
  FROM #m AS m
  INNER JOIN dbo.dt_member AS mm WITH (NOLOCK)
    ON mm.ID_MEMBER COLLATE DATABASE_DEFAULT = m.id_member COLLATE DATABASE_DEFAULT;

  ;WITH c AS (
    SELECT b.*
         , CASE WHEN b.dob IS NULL THEN NULL
                WHEN x.bday >= @p_to_date THEN DATEDIFF(day, @p_to_date, x.bday)
                ELSE DATEDIFF(day, @p_to_date, DATEADD(year, 1, x.bday)) END AS hari_ke_ultah
    FROM #b AS b
    OUTER APPLY (SELECT DATEADD(year, DATEDIFF(year, b.dob, @p_to_date), b.dob) AS bday) AS x
  )
  SELECT brand
       , COUNT(*) AS members
       , SUM(CASE WHEN dob IS NULL THEN 1 ELSE 0 END) AS dob_tidak_valid
       , SUM(CASE WHEN validasi_email = 1 AND validasi_data = 1 THEN 1 ELSE 0 END) AS members_lolos_email
       , SUM(CASE WHEN hari_ke_ultah <= @p_days THEN 1 ELSE 0 END) AS ultah
       , SUM(CASE WHEN hari_ke_ultah <= @p_days AND validasi_email = 1 AND validasi_data = 1 THEN 1 ELSE 0 END) AS ultah_lolos_email
       , SUM(CASE WHEN hari_ke_ultah <= @p_days AND punya_telp = 1 THEN 1 ELSE 0 END) AS ultah_punya_telp
       , SUM(CASE WHEN hari_ke_ultah <= @p_days AND hari <= 180 THEN 1 ELSE 0 END)    AS ultah_aktif_180
       , SUM(CASE WHEN hari_ke_ultah <= @p_days AND total >= @tier1 THEN 1 ELSE 0 END) AS ultah_tier1_plus
       , @p_days AS jendela_hari
  FROM c
  WHERE (@brand = '' OR brand = @brand)
  GROUP BY brand
  ORDER BY brand;
END
GO

/* ---------------------------------------------------------------------------
   tier_gap: tier menurut belanja di periode x brand dominan, dan member yang hampir naik tier
   @p_gap = selisih rupiah maksimum ke batas tier berikutnya yang dianggap "hampir naik".
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_tier_gap') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_tier_gap AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_tier_gap
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
  , @p_gap       decimal(18, 2) = 250000
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT h.ID AS tier_id, LTRIM(RTRIM(h.TIER_NAME)) AS tier_name, h.AMOUNT_FROM AS amount_from
       , LEAD(h.AMOUNT_FROM) OVER (ORDER BY h.AMOUNT_FROM) AS next_from
  INTO #tier
  FROM SYS_MEMBER.dbo.DT_MEMBER_TIER_HEADER AS h WITH (NOLOCK)
  WHERE ISNULL(h.IS_ACTIVE, 1) = 1;

  SELECT id_member, brand_dominan, total, hari
  INTO #m
  FROM dbo.fn_marcomm_analytics_member(@p_from_date, @p_to_date);

  /* tier tertinggi yang tercatat per member (sama seperti SP email ulang tahun) */
  SELECT t.ID_MEMBER COLLATE DATABASE_DEFAULT AS id_member, MAX(h.AMOUNT_FROM) AS amount_from
  INTO #reg
  FROM SYS_MEMBER.dbo.DT_MEMBER_TIER AS t WITH (NOLOCK)
  INNER JOIN SYS_MEMBER.dbo.DT_MEMBER_TIER_HEADER AS h WITH (NOLOCK) ON h.ID = t.ID_TIER
  GROUP BY t.ID_MEMBER COLLATE DATABASE_DEFAULT;

  SELECT m.brand_dominan AS brand, tr.tier_id, tr.tier_name, tr.amount_from, tr.next_from
       , COUNT(*) AS members, SUM(m.total) AS omzet
       , SUM(CASE WHEN tr.next_from IS NOT NULL AND tr.next_from - m.total <= @p_gap THEN 1 ELSE 0 END) AS dekat_naik
       , SUM(CASE WHEN tr.next_from IS NOT NULL AND tr.next_from - m.total <= @p_gap AND m.hari <= 180 THEN 1 ELSE 0 END) AS dekat_naik_aktif
       , SUM(CASE WHEN m.hari > 180 THEN 1 ELSE 0 END) AS pasif_180
       , SUM(CASE WHEN r.amount_from IS NOT NULL AND r.amount_from < tr.amount_from THEN 1 ELSE 0 END) AS tier_tercatat_lebih_rendah
       , @p_gap AS gap
  FROM #m AS m
  CROSS APPLY (
    SELECT TOP (1) t.tier_id, t.tier_name, t.amount_from, t.next_from
    FROM #tier AS t
    WHERE t.amount_from <= m.total
    ORDER BY t.amount_from DESC
  ) AS tr
  LEFT JOIN #reg AS r ON r.id_member = m.id_member
  WHERE (@brand = '' OR m.brand_dominan = @brand)
  GROUP BY m.brand_dominan, tr.tier_id, tr.tier_name, tr.amount_from, tr.next_from
  ORDER BY tr.amount_from, m.brand_dominan;
END
GO

/* ---------------------------------------------------------------------------
   profile: gender dan kelompok umur (member per brand); umur dihitung per @p_to_date
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_profile') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_profile AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_profile
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT id_member, brand, COUNT(*) AS trx, SUM(grand_total) AS total
  INTO #mb
  FROM dbo.fn_marcomm_analytics_tx()
  WHERE tgl >= @p_from_date AND tgl <= @p_to_date
  GROUP BY id_member, brand;

  SELECT id_member INTO #ids FROM #mb GROUP BY id_member;

  SELECT i.id_member
       , CASE UPPER(LTRIM(RTRIM(ISNULL(mm.Jenis_kelamin, ''))))
           WHEN 'L' THEN 'L' WHEN 'P' THEN 'P' ELSE 'TIDAK DIISI' END AS gender
       , CASE WHEN mm.TglLahir IS NULL OR YEAR(mm.TglLahir) < 1930 OR CONVERT(date, mm.TglLahir) > @p_to_date THEN NULL
              ELSE DATEDIFF(year, mm.TglLahir, @p_to_date)
                   - CASE WHEN DATEADD(year, DATEDIFF(year, mm.TglLahir, @p_to_date), CONVERT(date, mm.TglLahir)) > @p_to_date THEN 1 ELSE 0 END
         END AS umur
  INTO #p
  FROM #ids AS i
  LEFT JOIN dbo.dt_member AS mm WITH (NOLOCK)
    ON mm.ID_MEMBER COLLATE DATABASE_DEFAULT = i.id_member COLLATE DATABASE_DEFAULT;

  SELECT id_member, gender
       , CASE WHEN umur IS NULL THEN 'TIDAK VALID'
              WHEN umur < 18 THEN '<18' WHEN umur <= 24 THEN '18-24' WHEN umur <= 34 THEN '25-34'
              WHEN umur <= 44 THEN '35-44' WHEN umur <= 54 THEN '45-54' ELSE '55+' END AS umur_band
       , CASE WHEN umur IS NULL THEN 9
              WHEN umur < 18 THEN 1 WHEN umur <= 24 THEN 2 WHEN umur <= 34 THEN 3
              WHEN umur <= 44 THEN 4 WHEN umur <= 54 THEN 5 ELSE 6 END AS umur_urut
  INTO #pp
  FROM #p;

  SELECT 'GENDER' AS dimensi, p.gender AS kelompok
       , CASE p.gender WHEN 'P' THEN 1 WHEN 'L' THEN 2 ELSE 9 END AS urut
       , mb.brand, CAST(0 AS int) AS is_total
       , COUNT(*) AS members, SUM(mb.trx) AS trx, SUM(mb.total) AS omzet
  FROM #mb AS mb
  INNER JOIN #pp AS p ON p.id_member = mb.id_member
  WHERE (@brand = '' OR mb.brand = @brand)
  GROUP BY p.gender, mb.brand
  UNION ALL
  SELECT 'GENDER', p.gender
       , CASE p.gender WHEN 'P' THEN 1 WHEN 'L' THEN 2 ELSE 9 END
       , 'SEMUA BRAND', 1
       , COUNT(DISTINCT mb.id_member), SUM(mb.trx), SUM(mb.total)
  FROM #mb AS mb
  INNER JOIN #pp AS p ON p.id_member = mb.id_member
  GROUP BY p.gender
  UNION ALL
  SELECT 'UMUR', p.umur_band, p.umur_urut
       , mb.brand, 0
       , COUNT(*), SUM(mb.trx), SUM(mb.total)
  FROM #mb AS mb
  INNER JOIN #pp AS p ON p.id_member = mb.id_member
  WHERE (@brand = '' OR mb.brand = @brand)
  GROUP BY p.umur_band, p.umur_urut, mb.brand
  UNION ALL
  SELECT 'UMUR', p.umur_band, p.umur_urut
       , 'SEMUA BRAND', 1
       , COUNT(DISTINCT mb.id_member), SUM(mb.trx), SUM(mb.total)
  FROM #mb AS mb
  INNER JOIN #pp AS p ON p.id_member = mb.id_member
  GROUP BY p.umur_band, p.umur_urut
  ORDER BY dimensi, urut, is_total, brand;
END
GO

/* ---------------------------------------------------------------------------
   category: kode awal deskripsi barang (kata pertama DESKRIPSI) per brand transaksi
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_category') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_category AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_category
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT id_member, brand, id_tr_sales_header
  INTO #tx
  FROM dbo.fn_marcomm_analytics_tx()
  WHERE tgl >= @p_from_date AND tgl <= @p_to_date;

  SELECT t.id_member, t.brand
       , UPPER(LEFT(x.deskripsi, CHARINDEX(' ', x.deskripsi + ' ') - 1)) AS kode
       , x.deskripsi, d.QTY AS qty, d.Net AS net
  INTO #d
  FROM #tx AS t
  INNER JOIN dbo.TR_SALES_DETAIL AS d WITH (NOLOCK) ON d.ID_TR_SALES_HEADER = t.id_tr_sales_header
  CROSS APPLY (SELECT LTRIM(RTRIM(ISNULL(d.DESKRIPSI, ''))) AS deskripsi) AS x
  WHERE d.QTY > 0;

  SELECT kode, brand, CAST(0 AS int) AS is_total
       , COUNT(*) AS baris, SUM(qty) AS qty, SUM(net) AS net, COUNT(DISTINCT id_member) AS members
       , MIN(deskripsi) AS contoh
  FROM #d
  WHERE (@brand = '' OR brand = @brand)
  GROUP BY kode, brand
  UNION ALL
  SELECT kode, 'SEMUA BRAND', 1
       , COUNT(*), SUM(qty), SUM(net), COUNT(DISTINCT id_member)
       , MIN(deskripsi)
  FROM #d
  GROUP BY kode
  ORDER BY is_total DESC, qty DESC, kode, brand;
END
GO

/* ---------------------------------------------------------------------------
   quality: catatan mutu data per brand dominan
   Akun "perlu dicek" = belanja di >= @p_min_store store ATAU >= @p_min_hari hari belanja di periode.
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_quality') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_quality AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_quality
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
  , @p_min_store int = 8
  , @p_min_hari  int = 40
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';

  SELECT id_member, brand_dominan, trx, hari_belanja, stores, total
  INTO #m
  FROM dbo.fn_marcomm_analytics_member(@p_from_date, @p_to_date);

  SELECT m.brand_dominan AS brand
       , COUNT(*) AS members, SUM(m.total) AS omzet
       , SUM(CASE WHEN m.stores >= @p_min_store OR m.hari_belanja >= @p_min_hari THEN 1 ELSE 0 END) AS akun_perlu_dicek
       , SUM(CASE WHEN m.stores >= @p_min_store OR m.hari_belanja >= @p_min_hari THEN m.total ELSE 0 END) AS omzet_akun_perlu_dicek
       , SUM(CASE WHEN m.stores >= @p_min_store OR m.hari_belanja >= @p_min_hari THEN m.trx ELSE 0 END) AS trx_akun_perlu_dicek
       , SUM(CASE WHEN mm.ID_MEMBER IS NULL THEN 1 ELSE 0 END) AS tidak_ada_di_master
       , SUM(CASE WHEN mm.ID_MEMBER IS NOT NULL AND (mm.TglLahir IS NULL OR YEAR(mm.TglLahir) < 1930 OR CONVERT(date, mm.TglLahir) > @p_to_date) THEN 1 ELSE 0 END) AS dob_tidak_valid
       , SUM(CASE WHEN mm.ID_MEMBER IS NOT NULL AND ISNULL(LTRIM(RTRIM(mm.NoTelpon)), '') = '' THEN 1 ELSE 0 END) AS tanpa_telp
       , SUM(CASE WHEN mm.ID_MEMBER IS NOT NULL AND ISNULL(LTRIM(RTRIM(mm.Kota)), '') = '' THEN 1 ELSE 0 END) AS tanpa_kota
       , SUM(CASE WHEN ISNULL(mm.validasi_email, 0) = 1 AND ISNULL(mm.validasi_data, 0) = 1 THEN 1 ELSE 0 END) AS email_tervalidasi
       , SUM(CASE WHEN ISNULL(mm.IS_SUSPEND, 0) = 1 THEN 1 ELSE 0 END) AS suspend
       , @p_min_store AS min_store, @p_min_hari AS min_hari
  FROM #m AS m
  LEFT JOIN dbo.dt_member AS mm WITH (NOLOCK)
    ON mm.ID_MEMBER COLLATE DATABASE_DEFAULT = m.id_member COLLATE DATABASE_DEFAULT
  WHERE (@brand = '' OR m.brand_dominan = @brand)
  GROUP BY m.brand_dominan
  ORDER BY m.brand_dominan;
END
GO

/* ---------------------------------------------------------------------------
   segment_members: daftar member satu segmen (brand dominan), dengan paging
--------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.xsp_marcomm_analytics_segment_members') IS NULL
  EXEC (N'CREATE PROCEDURE dbo.xsp_marcomm_analytics_segment_members AS SELECT 1 AS stub');
GO
ALTER PROCEDURE dbo.xsp_marcomm_analytics_segment_members
(
    @p_from_date date
  , @p_to_date   date
  , @p_brand     varchar(50) = ''
  , @p_segment   varchar(1) = ''
  , @p_page      int = 1
  , @p_page_size int = 50
)
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand, ''))));
  IF @brand IN ('ALL', 'SEMUA', 'SEMUA BRAND') SET @brand = '';
  DECLARE @seg varchar(1) = UPPER(LTRIM(RTRIM(ISNULL(@p_segment, ''))));
  DECLARE @size int = CASE WHEN ISNULL(@p_page_size, 0) < 1 THEN 50 WHEN @p_page_size > 20000 THEN 20000 ELSE @p_page_size END;
  DECLARE @page int = CASE WHEN ISNULL(@p_page, 0) < 1 THEN 1 ELSE @p_page END;

  SELECT id_member, trx, hari_belanja, stores, n_brand, total, first_tgl, last_tgl, hari
       , brand_dominan, brand_pertama, segmen
  INTO #m
  FROM dbo.fn_marcomm_analytics_member(@p_from_date, @p_to_date)
  WHERE (@seg = '' OR segmen = @seg)
    AND (@brand = '' OR brand_dominan = @brand);

  SELECT COUNT(*) OVER () AS total_rows
       , m.segmen, m.brand_dominan, m.brand_pertama, m.n_brand
       , mm.ID_MEMBER_APPS AS id_member_apps, mm.Nama AS nama, mm.NoTelpon AS no_telpon, mm.Email AS email
       , mm.Jenis_kelamin AS jenis_kelamin
       , m.trx, m.hari_belanja, m.stores, m.total
       , m.first_tgl, m.last_tgl, m.hari
       , m.id_member
  FROM #m AS m
  LEFT JOIN dbo.dt_member AS mm WITH (NOLOCK)
    ON mm.ID_MEMBER COLLATE DATABASE_DEFAULT = m.id_member COLLATE DATABASE_DEFAULT
  ORDER BY m.total DESC, m.id_member
  OFFSET (@page - 1) * @size ROWS FETCH NEXT @size ROWS ONLY;
END
GO
