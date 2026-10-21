/*
  Sales By Man Power (REG2) — NEW SP on RBACESS.
  Logic parity with XSP_SALES_BY_MAN_POWER_gvw_GETROWS (Seles_byM.aspx).
  Does NOT EXEC that SP — queries pos_server tables.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_sales_manpower_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_manpower_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_manpower_getrows
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
        DECLARE @store varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id),''))),'');
        /* NIK from filter (id_member) — do NOT use JWT actor_nik (that is GH scope elsewhere) */
        DECLARE @nik varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_member,''), NULLIF(@p_keywords,'')),''))),'');
        IF @nik IN ('PILIH','ALL','0') SET @nik = NULL;
        DECLARE @from date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date,''))),'') AS date);
        DECLARE @to date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date,''))),'') AS date);
        IF @from IS NULL OR @to IS NULL OR @store IS NULL OR @nik IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'from_date, to_date, id_store, dan Nama/NIK wajib diisi.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @nama varchar(100), @jabatan varchar(100), @nik_found varchar(50);
        SELECT @nik_found = du.User_NIK, @nama = du.User_Name, @jabatan = dl.User_Level
        FROM pos_server.dbo.dt_user du WITH (NOLOCK)
        INNER JOIN pos_server.dbo.DT_User_Level dl WITH (NOLOCK) ON dl.User_Level_ID = du.User_Level_ID
        WHERE du.User_NIK = @nik;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                              tsp.id_sales AS USER_NIK,
                              @nama AS USER_NAME,
                              @jabatan AS JABATAN,
                              SUM(tsd.QTY) AS TOTAL_QTY,
                              SUM(tsd.Net) AS NILAI_SALES,
                              FORMAT(tsh.Tanggal_Transaksi, 'yyyy-MM-dd') AS TANGGAL_TRANSAKSI
                       FROM pos_server.dbo.tr_sales_header tsh WITH (NOLOCK)
                       LEFT OUTER JOIN pos_server.dbo.TR_SALES_DETAIL tsd WITH (NOLOCK)
                           ON tsd.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
                       LEFT OUTER JOIN pos_server.dbo.TR_SALES_PAYMENT tsp WITH (NOLOCK)
                           ON tsp.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER
                       WHERE DATEDIFF(DAY, tsh.Tanggal_Transaksi, @from) <= 0
                         AND DATEDIFF(DAY, tsh.Tanggal_Transaksi, @to) >= 0
                         AND tsh.ID_Store = @store
                         AND tsp.ID_SALES = @nik_found
                       GROUP BY FORMAT(tsh.Tanggal_Transaksi, 'yyyy-MM-dd'), tsp.id_sales
                       ORDER BY 6 DESC
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH
END
GO
