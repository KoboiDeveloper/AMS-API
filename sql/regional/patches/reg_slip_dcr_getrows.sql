/* Regional Slip Setoran Bank (DCR) list — parity with Dcr.aspx / XSP_DT_DCR_GHREG_GETROWS */
USE RBACESS;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_slip_dcr_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_slip_dcr_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_slip_dcr_getrows
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
        IF @from IS NULL SET @from = CAST(GETDATE() AS date);
        IF @to IS NULL SET @to = @from;
        IF @from > @to BEGIN DECLARE @swap date = @from; SET @from = @to; SET @to = @swap; END;

        DECLARE @brand varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand),''))),'');
        IF @brand IN ('ALL','all','0') SET @brand = NULL;
        DECLARE @store varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id),''))),'');
        IF @store IN ('ALL','all','0') SET @store = NULL;
        DECLARE @gh varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_actor_nik,''), NULLIF(@p_gh_id,''), @p_id_gh),''))),'');

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

        IF @store IS NOT NULL
            DELETE FROM #scope WHERE Store <> @store;

        IF OBJECT_ID(N'pos_server.dbo.WEB_IMAGE_DCR', N'U') IS NULL
           OR NOT EXISTS (SELECT 1 FROM #scope)
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY('[]') AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            DROP TABLE #scope;
            RETURN;
        END;

        ;WITH src AS (
            SELECT
                ds.Store_ID,
                ISNULL(ds.Store_Kota, ds.Store_Name) AS Store_Kota,
                wid.ID,
                wid.NILAI_BNI,
                wid.NILAI_MANDIRI,
                wid.NILAI_DIRECTSELLING,
                CASE
                    WHEN RIGHT(LOWER(ISNULL(wid.IMAGE_1,'')), 4) IN ('.jpg', 'jpeg', '.png', 'webp')
                        THEN wid.IMAGE_1
                    ELSE NULL
                END AS IMAGE_1,
                CASE
                    WHEN RIGHT(LOWER(ISNULL(wid.IMAGE_2,'')), 4) IN ('.jpg', 'jpeg', '.png', 'webp')
                        THEN wid.IMAGE_2
                    ELSE NULL
                END AS IMAGE_2,
                CASE
                    WHEN RIGHT(LOWER(ISNULL(wid.IMAGE_3,'')), 4) IN ('.jpg', 'jpeg', '.png', 'webp')
                        THEN wid.IMAGE_3
                    ELSE NULL
                END AS IMAGE_3,
                CASE
                    WHEN RIGHT(LOWER(ISNULL(wid.IMAGE_4,'')), 4) IN ('.jpg', 'jpeg', '.png', 'webp')
                        THEN wid.IMAGE_4
                    ELSE NULL
                END AS IMAGE_4,
                CASE
                    WHEN RIGHT(LOWER(ISNULL(wid.IMAGE_5,'')), 4) IN ('.jpg', 'jpeg', '.png', 'webp')
                        THEN wid.IMAGE_5
                    ELSE NULL
                END AS IMAGE_5,
                CASE
                    WHEN RIGHT(LOWER(ISNULL(wid.IMAGE_6,'')), 4) IN ('.jpg', 'jpeg', '.png', 'webp')
                        THEN wid.IMAGE_6
                    ELSE NULL
                END AS IMAGE_6,
                CONVERT(date, wid.CRE_DATE) AS cre_date,
                wid.CRE_BY,
                b.Tgl,
                ROW_NUMBER() OVER (
                    PARTITION BY wid.ID, CONVERT(varchar(10), wid.CRE_DATE, 111)
                    ORDER BY wid.CRE_DATE ASC
                ) AS rn
            FROM pos_server.dbo.WEB_IMAGE_DCR AS wid WITH (NOLOCK)
            INNER JOIN #scope AS sc ON sc.Store = wid.CRE_BY COLLATE Latin1_General_CI_AS
            INNER JOIN pos_server.dbo.DT_Store AS ds WITH (NOLOCK)
                ON ds.Store_ID = wid.CRE_BY COLLATE Latin1_General_CI_AS
            LEFT JOIN pos_server.dbo.dt_batch AS b WITH (NOLOCK)
                ON b.DCR_ID = wid.ID
            WHERE CONVERT(date, wid.CRE_DATE) >= @from
              AND CONVERT(date, wid.CRE_DATE) <= @to
        ),
        agg AS (
            SELECT
                Store_ID + ' - ' + ISNULL(Store_Kota, Store_ID) AS storeId,
                ID AS id,
                IMAGE_1 AS image1,
                IMAGE_2 AS image2,
                IMAGE_3 AS image3,
                IMAGE_4 AS image4,
                IMAGE_5 AS image5,
                IMAGE_6 AS image6,
                CONVERT(varchar(10), cre_date, 23) AS creDate,
                CRE_BY AS creBy,
                NILAI_BNI AS nilaiBni,
                NILAI_MANDIRI AS nilaiMandiri,
                NILAI_DIRECTSELLING AS nilaiDirectSelling,
                CONCAT(
                    MAX(CASE WHEN rn = 1 THEN CONVERT(varchar(10), Tgl, 23) END),
                    MAX(CASE WHEN rn = 2 THEN ',' + CONVERT(varchar(10), Tgl, 23) END),
                    MAX(CASE WHEN rn = 3 THEN ',' + CONVERT(varchar(10), Tgl, 23) END),
                    MAX(CASE WHEN rn = 4 THEN ',' + CONVERT(varchar(10), Tgl, 23) END),
                    MAX(CASE WHEN rn = 5 THEN ',' + CONVERT(varchar(10), Tgl, 23) END),
                    MAX(CASE WHEN rn = 6 THEN ',' + CONVERT(varchar(10), Tgl, 23) END)
                ) AS tglBatch
            FROM src
            GROUP BY
                ID, IMAGE_1, IMAGE_2, IMAGE_3, IMAGE_4, IMAGE_5, IMAGE_6,
                cre_date, CRE_BY, NILAI_BNI, NILAI_MANDIRI, NILAI_DIRECTSELLING,
                Store_ID, Store_Kota
        )
        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           a.storeId,
                           a.id,
                           a.image1,
                           a.image2,
                           a.image3,
                           a.image4,
                           a.image5,
                           a.image6,
                           a.creDate,
                           a.creBy,
                           a.nilaiBni,
                           a.nilaiMandiri,
                           a.nilaiDirectSelling,
                           a.tglBatch
                       FROM agg AS a
                       ORDER BY a.creDate DESC, a.id DESC
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        IF @bitparam IS NULL
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY('[]') AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

        DROP TABLE #scope;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#scope') IS NOT NULL DROP TABLE #scope;
        SET @bitparam = (
            SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH
END
GO
