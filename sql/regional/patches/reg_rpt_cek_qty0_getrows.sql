/*
  Cek Qty 0 (REG2) — port XSP_search_qty_nol_GETROWS (Chk_qty_nol.aspx).
  NEW SP only on RBACESS; queries pos_server.dbo.*; never EXEC legacy.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_cek_qty0_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_cek_qty0_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_cek_qty0_getrows
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
        IF @from IS NULL OR @to IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'from_date dan to_date wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @toX date = DATEADD(DAY, 1, @to);
        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand IN ('','0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store IN ('','0') SET @store = 'ALL';

        DECLARE @gh varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,''), NULLIF(@p_actor_nik,'')),''))),'');
        DECLARE @scoped bit = 0;
        CREATE TABLE #sc (store varchar(50) COLLATE Latin1_General_CI_AS NOT NULL PRIMARY KEY);
        IF @gh IS NOT NULL AND (
               EXISTS (SELECT 1 FROM pos_server.dbo.MASTER_GH_DETAIL WITH (NOLOCK) WHERE ID_GROUP_HEAD = @gh)
            OR EXISTS (SELECT 1 FROM pos_server.dbo.MASTER_REGIONAL_DETAIL WITH (NOLOCK) WHERE ID_REGIONAL = @gh))
        BEGIN
            SET @scoped = 1;
            INSERT INTO #sc (store)
            SELECT DISTINCT STORE COLLATE Latin1_General_CI_AS
            FROM (
                SELECT STORE FROM pos_server.dbo.MASTER_GH_DETAIL WITH (NOLOCK) WHERE ID_GROUP_HEAD = @gh
                UNION
                SELECT mgd.STORE FROM pos_server.dbo.MASTER_REGIONAL_DETAIL mrd WITH (NOLOCK)
                  INNER JOIN pos_server.dbo.MASTER_GH_DETAIL mgd WITH (NOLOCK) ON mgd.ID_GROUP_HEAD = mrd.ID_GROUP_HEAD
                 WHERE mrd.ID_REGIONAL = @gh
            ) s WHERE STORE IS NOT NULL;
        END;

        ;WITH base AS (
            SELECT
                TSH.NO_URUT,
                TSH.WAKTU_URUT,
                TSH.ID_TR_SALES_HEADER,
                LEFT(TSH.ID_TR_SALES_HEADER, 6) + RIGHT(TSH.ID_TR_SALES_HEADER, 6) AS BILLING_CODE,
                TSH.ID_Store,
                TSH.Status_Transaksi,
                CONVERT(varchar(16), TSH.Tanggal_Transaksi, 120) AS TANGGAL_TRANSAKSI,
                TSH.Total_HPP,
                TSH.PPN,
                TSH.Sub_Total,
                TSH.Total_Discount,
                TSH.Personal_Discount_Persen,
                TSH.Personal_Discount,
                CASE WHEN tspd.TIPE_BAYAR = 'Nilai Refund' THEN TSH.Grand_Total - tspd.BAYAR ELSE TSH.Grand_Total END AS Grand_Total,
                TSH.ID_User,
                CASE WHEN TSH.Bon_Manual = 0 OR TSH.Bon_Manual IS NULL THEN 'POS' ELSE 'BON MANUAL' END AS bon_manual,
                TSH.No_Bon_Manual,
                TSH.Status_Manual,
                TSH.Waktu_Manual,
                TSH.Status_Kirim,
                TSH.Waktu_Kirim,
                TSH.Last_Position,
                DS.Store_Brand_ID,
                SUM(ISNULL(TSD.QTY, 0)) AS QTY
            FROM pos_server.dbo.TR_SALES_HEADER TSH WITH (NOLOCK)
            LEFT JOIN pos_server.dbo.DT_STORE DS WITH (NOLOCK) ON DS.Store_ID = TSH.ID_Store
            LEFT JOIN pos_server.dbo.TR_SALES_DETAIL TSD WITH (NOLOCK) ON TSD.ID_TR_SALES_HEADER = TSH.ID_TR_SALES_HEADER
            LEFT JOIN (
                SELECT ID_TR_SALES_HEADER, TIPE_BAYAR, BAYAR
                FROM pos_server.dbo.TR_SALES_PAYMENT_DETAIL WITH (NOLOCK)
                WHERE TIPE_BAYAR = 'NILAI REFUND'
            ) tspd ON tspd.ID_TR_SALES_HEADER = TSH.ID_TR_SALES_HEADER
            WHERE TSH.Tanggal_Transaksi >= @from AND TSH.Tanggal_Transaksi < @toX
              AND TSH.Status_Transaksi = 1
              AND ISNULL(TSD.QTY, 0) = 0
              AND (@store = 'ALL' OR TSH.ID_Store = @store)
              AND (@brand = 'ALL' OR DS.Store_Brand_ID = @brand)
              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = TSH.ID_Store COLLATE Latin1_General_CI_AS))
            GROUP BY
                TSH.NO_URUT, TSH.WAKTU_URUT, TSH.ID_TR_SALES_HEADER, TSH.ID_Store, TSH.Status_Transaksi,
                TSH.Tanggal_Transaksi, TSH.ID_User, TSH.Bon_Manual, TSH.No_Bon_Manual, TSH.Status_Manual,
                TSH.Waktu_Manual, TSH.Status_Kirim, TSH.Waktu_Kirim, TSH.Last_Position, DS.Store_Brand_ID,
                TSH.Total_HPP, TSH.PPN, TSH.Sub_Total, TSH.Total_Discount, TSH.Personal_Discount_Persen,
                TSH.Personal_Discount, TSH.Grand_Total, tspd.TIPE_BAYAR, tspd.BAYAR
        )
        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           NO_URUT, WAKTU_URUT, ID_TR_SALES_HEADER, BILLING_CODE, ID_Store,
                           Status_Transaksi, TANGGAL_TRANSAKSI, Total_HPP, PPN, Sub_Total,
                           Total_Discount, Personal_Discount_Persen, Personal_Discount,
                           CASE WHEN Grand_Total <= 0 THEN 0 ELSE Grand_Total END AS GRAND_TOTAL,
                           ID_User, bon_manual, No_Bon_Manual, Status_Manual, Waktu_Manual,
                           Status_Kirim, Waktu_Kirim, Last_Position, Store_Brand_ID, QTY
                       FROM base
                       ORDER BY TANGGAL_TRANSAKSI DESC
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        DROP TABLE #sc;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#sc') IS NOT NULL DROP TABLE #sc;
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
