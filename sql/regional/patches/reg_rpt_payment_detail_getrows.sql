/*

  Payment Detail (REG2) — port xsp_get_payment_detail_getrows (Get_Payment_detail.aspx).

  Full pivot columns; supports ALL brand/store (legacy CASE filter skipped ALL/ALL).

*/

USE RBACESS;

GO

SET NOCOUNT ON;

GO



IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_payment_detail_getrows', N'P') IS NOT NULL

    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_payment_detail_getrows;

GO



CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_payment_detail_getrows

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

                b.ID_Store AS STORE_ID,

                CONVERT(varchar(10), b.Tanggal_Transaksi, 23) AS TANGGAL,

                SUM(CASE WHEN a.TIPE_BAYAR = 'CASH' THEN a.BAYAR ELSE 0 END)

                  + SUM(CASE WHEN a.TIPE_BAYAR = 'Change' THEN a.BAYAR ELSE 0 END) AS CASH,

                SUM(CASE WHEN a.TIPE_BAYAR = 'D.BCA' THEN a.BAYAR ELSE 0 END) AS DBCA,

                SUM(CASE WHEN a.TIPE_BAYAR = 'K.BCA' THEN a.BAYAR ELSE 0 END) AS KBCA,

                SUM(CASE WHEN a.TIPE_BAYAR = 'D.MANDIRI' THEN a.BAYAR ELSE 0 END) AS DMANDIRI,

                SUM(CASE WHEN a.TIPE_BAYAR = 'K.MANDIRI' THEN a.BAYAR ELSE 0 END) AS KMANDIRI,

                SUM(CASE WHEN a.TIPE_BAYAR = 'D.BNI' THEN a.BAYAR ELSE 0 END) AS DBNI,

                SUM(CASE WHEN a.TIPE_BAYAR = 'K.BNI' THEN a.BAYAR ELSE 0 END) AS KBNI,

                SUM(CASE WHEN a.TIPE_BAYAR = 'D.BRI' THEN a.BAYAR ELSE 0 END) AS DBRI,

                SUM(CASE WHEN a.TIPE_BAYAR = 'K.BRI' THEN a.BAYAR ELSE 0 END) AS KBRI,

                SUM(CASE WHEN a.TIPE_BAYAR IN ('VOUCHER','Voucher Promosi') THEN a.BAYAR ELSE 0 END) AS VOUCHER,

                SUM(CASE WHEN a.TIPE_BAYAR = 'VOUCHER_ONLINE' THEN a.BAYAR ELSE 0 END) AS VOUCHER_ONLINE,

                SUM(CASE WHEN a.TIPE_BAYAR = 'K.OVO' THEN a.BAYAR ELSE 0 END) AS KOVO,

                SUM(CASE WHEN a.TIPE_BAYAR = 'K.ATOME' THEN a.BAYAR ELSE 0 END) AS ATOME,

                SUM(CASE WHEN a.TIPE_BAYAR = 'K.INDODANA' THEN a.BAYAR ELSE 0 END) AS KINDODANA,

                SUM(CASE WHEN a.TIPE_BAYAR = 'D.QRIS BCA' THEN a.BAYAR ELSE 0 END) AS D_QRIS_BCA,

                SUM(CASE WHEN a.TIPE_BAYAR = 'D.QRIS BNI' THEN a.BAYAR ELSE 0 END) AS D_QRIS_BNI,

                SUM(CASE WHEN a.TIPE_BAYAR = 'D.QRIS BRI' THEN a.BAYAR ELSE 0 END) AS D_QRIS_BRI,

                SUM(CASE WHEN a.TIPE_BAYAR = 'D.QRIS MDR' THEN a.BAYAR ELSE 0 END) AS D_QRIS_MANDIRI,

                SUM(CASE

                        WHEN a.TIPE_BAYAR = 'K.QRIS'

                         AND ((b.order_online = 1 AND ISNULL(b.COD,0) = 0) OR (ISNULL(b.order_online,0) = 0 AND ISNULL(b.COD,0) = 0))

                        THEN a.BAYAR ELSE 0 END) AS ONLINE,

                SUM(CASE WHEN a.TIPE_BAYAR = 'K.QRIS' AND b.order_online = 1 AND ISNULL(b.COD,0) = 1 THEN a.BAYAR ELSE 0 END) AS COD

            FROM pos_server.dbo.TR_SALES_PAYMENT_DETAIL AS a WITH (NOLOCK)

            INNER JOIN pos_server.dbo.TR_SALES_HEADER AS b WITH (NOLOCK)

                ON b.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER

            INNER JOIN pos_server.dbo.DT_Store AS x WITH (NOLOCK)

                ON x.Store_ID = b.ID_Store

            WHERE b.Tanggal_Transaksi >= @from AND b.Tanggal_Transaksi < @toX

              AND (@brand = 'ALL' OR x.Store_Brand_ID = @brand)

              AND (@store = 'ALL' OR b.ID_Store = @store)

              AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = b.ID_Store COLLATE Latin1_General_CI_AS))

            GROUP BY b.ID_Store, CONVERT(varchar(10), b.Tanggal_Transaksi, 23)

        )

        SELECT @bitparam = (

            SELECT '2002500' AS responseCode, 'success' AS responseMessage,

                   JSON_QUERY((

                       SELECT

                           STORE_ID, TANGGAL,

                           ISNULL(CASH,0) AS CASH, ISNULL(DBCA,0) AS DBCA, ISNULL(KBCA,0) AS KBCA,

                           ISNULL(DMANDIRI,0) AS DMANDIRI, ISNULL(KMANDIRI,0) AS KMANDIRI,

                           ISNULL(DBNI,0) AS DBNI, ISNULL(KBNI,0) AS KBNI,

                           ISNULL(DBRI,0) AS DBRI, ISNULL(KBRI,0) AS KBRI,

                           ISNULL(VOUCHER,0) AS VOUCHER, ISNULL(VOUCHER_ONLINE,0) AS VOUCHER_ONLINE,

                           ISNULL(KOVO,0) AS KOVO, ISNULL(ATOME,0) AS ATOME, ISNULL(KINDODANA,0) AS KINDODANA,

                           ISNULL(D_QRIS_BCA,0) AS D_QRIS_BCA, ISNULL(D_QRIS_BNI,0) AS D_QRIS_BNI,

                           ISNULL(D_QRIS_BRI,0) AS D_QRIS_BRI, ISNULL(D_QRIS_MANDIRI,0) AS D_QRIS_MANDIRI,

                           ISNULL(ONLINE,0) AS ONLINE, ISNULL(COD,0) AS COD,

                           (ISNULL(CASH,0)+ISNULL(DBCA,0)+ISNULL(KBCA,0)+ISNULL(DMANDIRI,0)+ISNULL(KMANDIRI,0)

                            +ISNULL(DBNI,0)+ISNULL(KBNI,0)+ISNULL(DBRI,0)+ISNULL(KBRI,0)

                            +ISNULL(VOUCHER,0)+ISNULL(VOUCHER_ONLINE,0)+ISNULL(KOVO,0)+ISNULL(ATOME,0)+ISNULL(KINDODANA,0)

                            +ISNULL(D_QRIS_BCA,0)+ISNULL(D_QRIS_BNI,0)+ISNULL(D_QRIS_BRI,0)+ISNULL(D_QRIS_MANDIRI,0)

                            +ISNULL(ONLINE,0)+ISNULL(COD,0)) AS totalnyaLOH

                       FROM base

                       ORDER BY STORE_ID, TANGGAL

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

