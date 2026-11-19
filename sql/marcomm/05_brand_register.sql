/* Marcomm — kolom brand_register di dt_member (prefix saja)

   Database : POS_SERVER
   Jalankan : _sqlrun.exe -db pos -f sql/marcomm/05_brand_register.sql

   brand_register menyimpan HANYA prefix brand utama seumur hidup:
     CELCIUS → rc, CELCIUS WOMAN → rcw, MISSISSIPPI → rm, QUEENSLAND → rq
   Gabungan prefix + ID_MEMBER_APPS dilakukan di SELECT daftar Analisa Member,
   bukan di kolom ini.

   Backfill hanya mengisi baris yang masih NULL (nilai yang sudah ada tidak diubah).
*/
SET NOCOUNT ON;
GO

IF COL_LENGTH(N'dbo.dt_member', N'brand_register') IS NULL
  ALTER TABLE dbo.dt_member ADD brand_register varchar(10) NULL;
GO

/* brand utama seumur hidup = transaksi terbanyak; seri: omzet, ts terakhir, nama brand */
;WITH mb AS (
  SELECT id_member, brand, COUNT(*) AS trx, SUM(grand_total) AS total, MAX(ts) AS last_ts
  FROM dbo.fn_marcomm_analytics_tx()
  GROUP BY id_member, brand
),
u AS (
  SELECT id_member, brand,
         ROW_NUMBER() OVER (
           PARTITION BY id_member
           ORDER BY trx DESC, total DESC, last_ts DESC, brand
         ) AS rn
  FROM mb
)
UPDATE m
SET m.brand_register = CASE UPPER(u.brand)
      WHEN 'CELCIUS' THEN 'rc'
      WHEN 'CELCIUS WOMAN' THEN 'rcw'
      WHEN 'MISSISSIPPI' THEN 'rm'
      WHEN 'QUEENSLAND' THEN 'rq'
    END
FROM dbo.dt_member AS m
INNER JOIN u ON u.id_member COLLATE DATABASE_DEFAULT = m.ID_MEMBER COLLATE DATABASE_DEFAULT AND u.rn = 1
WHERE m.brand_register IS NULL
  AND UPPER(u.brand) IN ('CELCIUS', 'CELCIUS WOMAN', 'MISSISSIPPI', 'QUEENSLAND');
GO
