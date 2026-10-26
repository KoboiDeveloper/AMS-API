IF OBJECT_ID(N'dbo.xsp_api_app_member_email_birthday_data_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_api_app_member_email_birthday_data_getrows;
GO

CREATE PROCEDURE [dbo].[xsp_api_app_member_email_birthday_data_getrows]
(
      @token    varchar(100)
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @token <> '93564344792053024757076963936537'
    BEGIN
        SELECT @bitparam = (
            SELECT
                '4002500' AS responseCode,
                'error'   AS status
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        RETURN;
    END

    DECLARE @mm       int      = MONTH(GETDATE());
    DECLARE @dd       int      = DAY(GETDATE());
    DECLARE @dayStart datetime = CAST(GETDATE() AS date);
    DECLARE @dayEnd   datetime = DATEADD(day, 1, @dayStart);

    IF EXISTS (
        SELECT 1
        FROM dbo.dt_member m
        WHERE m.validasi_email = 1
          AND m.validasi_data  = 1
          AND MONTH(m.TglLahir) = @mm
          AND DAY(m.TglLahir)   = @dd
          AND NOT EXISTS (
              SELECT 1
              FROM SYS_MEMBER.dbo.DT_MEMBER_VOUCHER v
              WHERE v.ID_MEMBER = m.ID_MEMBER COLLATE Latin1_General_CI_AS
                AND v.CATEGORY = 'HBD'
                AND v.Tanggal_Buat >= @dayStart
                AND v.Tanggal_Buat <  @dayEnd
          )
    )
    BEGIN
        EXEC dbo.XSP_GENERATE_VOUCHER_ULTAH_EMAIL;

        ;WITH birthday_members AS (
            SELECT
                m.ID_MEMBER,
                m.ID_MEMBER_APPS,
                m.Nama,
                m.email,
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
                bm.ID_MEMBER_APPS,
                bm.Nama,
                bm.email,
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
            GROUP BY
                bm.ID_MEMBER,
                bm.ID_MEMBER_APPS,
                bm.Nama,
                bm.email,
                bm.TglLahir
            HAVING
                SUM(CASE
                        WHEN s.Store_Brand_ID IN ('celcius', 'celcius woman', 'mississippi', 'queensland')
                        THEN t.GRAND_TOTAL ELSE 0
                    END) > 0
        ),
        member_tier AS (
            SELECT
                t.ID_MEMBER,
                MAX(t.ID_TIER) AS id_tier
            FROM SYS_MEMBER.dbo.DT_MEMBER_TIER t
            INNER JOIN brand_sales bs
                ON bs.ID_MEMBER = t.ID_MEMBER
            GROUP BY t.ID_MEMBER
        )
        SELECT @bitparam = (
            SELECT
                '2002500' AS responseCode,
                'success' AS status,
                JSON_QUERY((
                    SELECT
                        c.ID_MEMBER      AS id_member,
                        c.ID_MEMBER_APPS AS idMemberApps,
                        c.Nama           AS nama,
                        c.email          AS email,
                        c.TglLahir       AS tglLahir,
                        mt.id_tier       AS tier,
                        CASE
                            WHEN c.celcius >= c.celcius_woman
                             AND c.celcius >= c.mississippi
                             AND c.celcius >= c.queensland THEN 'celcius'
                            WHEN c.celcius_woman >= c.celcius
                             AND c.celcius_woman >= c.mississippi
                             AND c.celcius_woman >= c.queensland THEN 'celcius_woman'
                            WHEN c.mississippi >= c.celcius
                             AND c.mississippi >= c.celcius_woman
                             AND c.mississippi >= c.queensland THEN 'mississippi'
                            WHEN c.queensland >= c.celcius
                             AND c.queensland >= c.celcius_woman
                             AND c.queensland >= c.mississippi THEN 'queensland'
                            ELSE 'unknown'
                        END AS brandTerbanyak,
                        v.promocode AS kodeVoucher,
                        FORMAT(v.NilaiVoucher / 1000.0, '0') + 'K' AS nominalVoucher
                    FROM brand_sales c
                    LEFT JOIN member_tier mt
                        ON mt.ID_MEMBER = c.ID_MEMBER
                    INNER JOIN SYS_MEMBER.dbo.DT_MEMBER_VOUCHER v
                        ON v.ID_MEMBER = c.ID_MEMBER COLLATE Latin1_General_CI_AS
                       AND v.CATEGORY = 'HBD'
                       AND v.Tanggal_Buat >= @dayStart
                       AND v.Tanggal_Buat <  @dayEnd
                    FOR JSON PATH
                )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        IF @bitparam IS NULL
           OR JSON_QUERY(@bitparam, '$.data') IS NULL
        BEGIN
            SELECT @bitparam = (
                SELECT
                    '2002500' AS responseCode,
                    'Tidak ada member yang ultang tahun' AS status
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
        END
    END
    ELSE
    BEGIN
        SELECT @bitparam = (
            SELECT
                '2002500' AS responseCode,
                'Tidak ada member yang ultang tahun' AS status
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END
END
GO
