IF OBJECT_ID(N'dbo.XSP_GENERATE_VOUCHER_ULTAH_EMAIL', N'P') IS NOT NULL
    DROP PROCEDURE dbo.XSP_GENERATE_VOUCHER_ULTAH_EMAIL;
GO

CREATE PROCEDURE [dbo].[XSP_GENERATE_VOUCHER_ULTAH_EMAIL]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @mm        int      = MONTH(GETDATE());
    DECLARE @dd        int      = DAY(GETDATE());
    DECLARE @dayStart  datetime = CAST(GETDATE() AS date);
    DECLARE @dayEnd    datetime = DATEADD(day, 1, @dayStart);
    DECLARE @now       datetime = GETDATE();
    DECLARE @expire    datetime = DATEADD(month, 1, @now);

    ;WITH birthday_members AS (
        SELECT
            m.ID_MEMBER,
            m.TglLahir
        FROM dbo.dt_member m
        WHERE m.validasi_email = 1
          AND m.validasi_data  = 1
          AND MONTH(m.TglLahir) = @mm
          AND DAY(m.TglLahir)   = @dd
    ),
    brand_sales AS (
        SELECT
            bm.ID_MEMBER,
            bm.TglLahir,
            SUM(CASE WHEN s.Store_Brand_ID = 'celcius'       THEN t.GRAND_TOTAL ELSE 0 END) AS celcius,
            SUM(CASE WHEN s.Store_Brand_ID = 'celcius woman' THEN t.GRAND_TOTAL ELSE 0 END) AS celcius_woman,
            SUM(CASE WHEN s.Store_Brand_ID = 'mississippi'   THEN t.GRAND_TOTAL ELSE 0 END) AS mississippi,
            SUM(CASE WHEN s.Store_Brand_ID = 'queensland'    THEN t.GRAND_TOTAL ELSE 0 END) AS queensland
        FROM birthday_members bm
        INNER JOIN SYS_MEMBER.dbo.DT_POS_TRANSACTION_LOG t
            ON t.ID_MEMBER = bm.ID_MEMBER
        INNER JOIN dbo.DT_Store s
            ON s.Store_ID = t.ID_STORE
        GROUP BY bm.ID_MEMBER, bm.TglLahir
        HAVING
            SUM(CASE
                    WHEN s.Store_Brand_ID IN ('celcius', 'celcius woman', 'mississippi', 'queensland')
                    THEN t.GRAND_TOTAL ELSE 0
                END) > 0
    ),
    latest_tier AS (
        SELECT
            t.ID_MEMBER,
            t.ID_TIER,
            ROW_NUMBER() OVER (PARTITION BY t.ID_MEMBER ORDER BY t.ID DESC) AS rn
        FROM SYS_MEMBER.dbo.DT_MEMBER_TIER t
        INNER JOIN brand_sales bs
            ON bs.ID_MEMBER = t.ID_MEMBER
    ),
    to_insert AS (
        SELECT
            bs.ID_MEMBER,
            CASE
                WHEN ISNULL(lt.ID_TIER, 0) = 0 THEN CAST(25000 AS decimal(18, 0))
                WHEN lt.ID_TIER IN (1, 2, 3, 4) THEN CAST(50000 AS decimal(18, 0))
                WHEN lt.ID_TIER IN (5, 6, 7) THEN CAST(100000 AS decimal(18, 0))
                ELSE CAST(25000 AS decimal(18, 0))
            END AS NilaiVoucher,
            'BIRTHDAY' + CAST(
                DATEDIFF(YEAR, bs.TglLahir, @now)
                - CASE
                      WHEN DATEADD(YEAR, DATEDIFF(YEAR, bs.TglLahir, @now), bs.TglLahir) > @now
                      THEN 1 ELSE 0
                  END
                AS varchar(10)
            ) AS promocode
        FROM brand_sales bs
        LEFT JOIN latest_tier lt
            ON lt.ID_MEMBER = bs.ID_MEMBER
           AND lt.rn = 1
        WHERE NOT EXISTS (
            SELECT 1
            FROM SYS_MEMBER.dbo.DT_MEMBER_VOUCHER v
            WHERE v.ID_MEMBER = bs.ID_MEMBER COLLATE Latin1_General_CI_AS
              AND v.CATEGORY = 'HBD'
              AND v.Tanggal_Buat >= @dayStart
              AND v.Tanggal_Buat <  @dayEnd
        )
    )
    INSERT INTO SYS_MEMBER.dbo.DT_MEMBER_VOUCHER
    (
        ID_VOUCHER,
        ID_MEMBER,
        Tanggal_Buat,
        Store_ID,
        NilaiVoucher,
        PointVoucher,
        Tanggal_Expired,
        BILLING_CODE_ID,
        Status_Penggunaan,
        Store_ID_Penggunaan,
        Tanggal_Penggunaan,
        promocode,
        CATEGORY
    )
    SELECT
        REPLACE(CONVERT(varchar(255), NEWID()), '-', ''),
        i.ID_MEMBER,
        @now,
        'mobileApp',
        i.NilaiVoucher,
        0,
        @expire,
        NULL,
        0,
        NULL,
        NULL,
        i.promocode,
        'HBD'
    FROM to_insert i;
END
GO
