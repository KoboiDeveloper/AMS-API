/*

  AR Detail (REG2) — port XSP_RPT_sales_ar_GETROWS (Seles_ar_Detail.aspx).

  Columns: STORE, TANGGAL, CASH, CARD, VOUCHER, OVO, KQRIS, KATOME, SISA_VOUCHER, refund, TOTAL

*/

USE RBACESS;

GO

SET NOCOUNT ON;

GO



IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_ar_detail_getrows', N'P') IS NOT NULL

    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_ar_detail_getrows;

GO



CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_ar_detail_getrows

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

        DECLARE @brand_id varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));

        IF @brand_id IN ('','0') SET @brand_id = 'ALL';

        DECLARE @store_id varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));

        IF @store_id IN ('','0') SET @store_id = 'ALL';



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



        SET @bitparam = (

            SELECT '2002500' AS responseCode, 'success' AS responseMessage,

                   JSON_QUERY((

                       SELECT

                           x.id_tr_sales_header,

                           x.ID_Store,

                           x.TANGGAL_TRANSAKSI,

                           ISNULL(x.CASH, 0) AS CASH,

                           ISNULL(x.CARD, 0) AS CARD,

                           ISNULL(x.VOUCHER, 0) AS VOUCHER,

                           ISNULL(x.OVO, 0) AS OVO,

                           ISNULL(x.KQRIS, 0) AS KQRIS,

                           ISNULL(x.KATOME, 0) AS KATOME,

                           ISNULL(x.SISA_VOUCHER, 0) AS SISA_VOUCHER,

                           ISNULL(x.refund, 0) AS refund,

                           ISNULL(x.TOTAL, 0) AS TOTAL

                       FROM (

                           SELECT

                               a.ID_TR_SALES_HEADER AS id_tr_sales_header,

                               a.ID_Store,

                               CONVERT(varchar(10), a.Tanggal_Transaksi, 23) AS TANGGAL_TRANSAKSI,

                               SUM(CASE WHEN c.TIPE_BAYAR = 'CASH' THEN c.BAYAR ELSE 0 END)

                                 + SUM(CASE WHEN c.TIPE_BAYAR = 'Change' THEN c.BAYAR ELSE 0 END) AS CASH,

                               SUM(CASE WHEN c.TIPE_BAYAR IN ('K.BCA','K.BNI','K.MANDIRI','D.BCA','D.BNI','D.MANDIRI','K.BRI','D.BRI') THEN c.BAYAR ELSE 0 END) AS CARD,

                               SUM(CASE WHEN c.TIPE_BAYAR LIKE 'Voucher%' THEN c.BAYAR ELSE 0 END) AS VOUCHER,

                               SUM(CASE WHEN c.TIPE_BAYAR = 'K.OVO' THEN c.BAYAR ELSE 0 END) AS OVO,

                               SUM(CASE WHEN c.TIPE_BAYAR = 'K.QRIS' THEN c.BAYAR ELSE 0 END) AS KQRIS,

                               SUM(CASE WHEN c.TIPE_BAYAR = 'K.ATOME' THEN c.BAYAR ELSE 0 END) AS KATOME,

                               SUM(CASE WHEN c.TIPE_BAYAR = 'sisa_Voucher' THEN c.BAYAR ELSE 0 END) AS SISA_VOUCHER,

                               SUM(CASE WHEN c.TIPE_BAYAR = 'Nilai Refund' THEN c.BAYAR ELSE 0 END) AS refund,

                               (

                                   SUM(CASE WHEN c.TIPE_BAYAR = 'CASH' THEN c.BAYAR ELSE 0 END)

                                 + SUM(CASE WHEN c.TIPE_BAYAR = 'Change' THEN c.BAYAR ELSE 0 END)

                                 + SUM(CASE WHEN c.TIPE_BAYAR IN ('K.BCA','K.BNI','K.MANDIRI','D.BCA','D.BNI','D.MANDIRI','K.BRI','D.BRI') THEN c.BAYAR ELSE 0 END)

                                 + SUM(CASE WHEN c.TIPE_BAYAR LIKE 'Voucher%' THEN c.BAYAR ELSE 0 END)

                                 + SUM(CASE WHEN c.TIPE_BAYAR = 'sisa_Voucher' THEN c.BAYAR ELSE 0 END)

                                 + SUM(CASE WHEN c.TIPE_BAYAR = 'K.OVO' THEN c.BAYAR ELSE 0 END)

                                 + SUM(CASE WHEN c.TIPE_BAYAR = 'K.QRIS' THEN c.BAYAR ELSE 0 END)

                                 + SUM(CASE WHEN c.TIPE_BAYAR = 'K.ATOME' THEN c.BAYAR ELSE 0 END)

                                 - SUM(CASE WHEN c.TIPE_BAYAR = 'Nilai Refund' THEN c.BAYAR ELSE 0 END)

                               ) AS TOTAL

                           FROM pos_server.dbo.TR_SALES_HEADER AS a WITH (NOLOCK)

                           INNER JOIN pos_server.dbo.TR_SALES_PAYMENT_DETAIL AS c WITH (NOLOCK)

                               ON c.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER

                           INNER JOIN pos_server.dbo.DT_Store AS ds WITH (NOLOCK)

                               ON ds.Store_ID = a.ID_Store

                           WHERE a.Status_Transaksi = 1

                             AND a.Tanggal_Transaksi >= @from AND a.Tanggal_Transaksi < @toX

                             AND (@brand_id = 'ALL' OR ds.Store_Brand_ID = @brand_id)

                             AND (@store_id = 'ALL' OR a.ID_Store = @store_id)

                             AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = a.ID_Store COLLATE Latin1_General_CI_AS))

                           GROUP BY a.ID_TR_SALES_HEADER, a.ID_Store, CONVERT(varchar(10), a.Tanggal_Transaksi, 23)

                       ) AS x

                       ORDER BY x.ID_Store, x.TANGGAL_TRANSAKSI

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

