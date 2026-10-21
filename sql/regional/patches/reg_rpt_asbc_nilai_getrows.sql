/*
  ASBC Nilai (REG2) — simplified XSP_ANALISA_SALES_BY_CLASS_PRICE_STORE (net sales).
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_asbc_nilai_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_asbc_nilai_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_asbc_nilai_getrows
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
        DECLARE @p_date date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_from_date,''), @p_tgl),''))),'') AS date);
        IF @p_date IS NULL SET @p_date = CAST(GETDATE() AS date);
        DECLARE @from_date date = DATEFROMPARTS(YEAR(@p_date), MONTH(@p_date), 1);
        DECLARE @to_date date = @p_date;
        DECLARE @brand_id varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand_id IN ('','0') SET @brand_id = 'ALL';
        DECLARE @store_id varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store_id IN ('','0') SET @store_id = 'ALL';

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           LEFT(x.kode, 3) AS KODE,
                           mc.DESKRIPSI,
                           SUM(ISNULL(x.net_ly, 0)) AS SALES_NILAI_TAHUN_SEBELUMNYA,
                           SUM(ISNULL(x.net_mtd, 0)) AS SALES_NILAI_BERJALAN,
                           SUM(ISNULL(x.net_mtd, 0)) - SUM(ISNULL(x.net_ly, 0)) AS GROWTH
                       FROM (
                           SELECT LEFT(a.PLU, 3) AS kode,
                                  SUM(ISNULL(a.NET_SALES, 0)) AS net_mtd,
                                  CAST(0 AS float) AS net_ly
                           FROM pos_server.dbo.DT_SALES_SUMMARY AS a WITH (NOLOCK)
                           INNER JOIN pos_server.dbo.DT_Store AS ds WITH (NOLOCK) ON ds.Store_ID = a.Store_ID
                           WHERE DATEDIFF(DAY, a.Tanggal, @from_date) <= 0
                             AND DATEDIFF(DAY, a.Tanggal, @to_date) >= 0
                             AND (@store_id = 'ALL' OR a.Store_ID = @store_id)
                             AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
                           GROUP BY LEFT(a.PLU, 3)
                           UNION ALL
                           SELECT LEFT(a.PLU, 3) AS kode,
                                  CAST(0 AS float) AS net_mtd,
                                  SUM(ISNULL(a.NET_SALES, 0)) AS net_ly
                           FROM pos_server.dbo.DT_SALES_SUMMARY AS a WITH (NOLOCK)
                           INNER JOIN pos_server.dbo.DT_Store AS ds WITH (NOLOCK) ON ds.Store_ID = a.Store_ID
                           WHERE DATEDIFF(DAY, a.Tanggal, DATEADD(YEAR, -1, @from_date)) <= 0
                             AND DATEDIFF(DAY, a.Tanggal, DATEADD(YEAR, -1, @to_date)) >= 0
                             AND (@store_id = 'ALL' OR a.Store_ID = @store_id)
                             AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)
                           GROUP BY LEFT(a.PLU, 3)
                       ) AS x
                       LEFT JOIN pos_server.dbo.MASTER_CLASS AS mc WITH (NOLOCK) ON mc.KODE = LEFT(x.kode, 3)
                       GROUP BY LEFT(x.kode, 3), mc.DESKRIPSI
                       ORDER BY KODE
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
