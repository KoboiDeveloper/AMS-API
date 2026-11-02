/*
  Outstanding Stock Print (REG2) — ASP parity module/Rpt/InvStockOut.aspx
  Legacy (no params):
    DETAIL  → pos_server.dbo.xsp_pak_woro_detail_st_out_getrows
    SUMMARY → pos_server.dbo.xsp_pak_woro_summary_st_out_getrows
  FE passes @p_tipe = detail | summary
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_print_outstanding_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_print_outstanding_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_print_outstanding_getrows
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
        DECLARE @tipe varchar(20) = LOWER(LTRIM(RTRIM(ISNULL(@p_tipe, 'detail'))));
        IF @tipe IN ('', '1', 'full', 'all', 'det') SET @tipe = 'detail';
        IF @tipe IN ('2', 'sum', 'summarry') SET @tipe = 'summary';

        IF @tipe = 'summary'
        BEGIN
            CREATE TABLE #s (
                PENGIRIM varchar(50) NULL,
                PENERIMA varchar(50) NULL,
                DEPT varchar(1) NULL,
                QTY int NULL,
                HPP money NULL,
                PRICE money NULL
            );
            INSERT INTO #s
            EXEC pos_server.dbo.xsp_pak_woro_summary_st_out_getrows;

            SELECT @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT
                               s.PENGIRIM AS PENGIRIM,
                               s.PENERIMA AS PENERIMA,
                               s.DEPT AS DEPT,
                               CAST(ISNULL(s.QTY, 0) AS float) AS QTY,
                               CAST(ISNULL(s.HPP, 0) AS float) AS HPP,
                               CAST(ISNULL(s.PRICE, 0) AS float) AS PRICE
                           FROM #s s
                           ORDER BY s.PENGIRIM, s.PENERIMA, s.DEPT
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        CREATE TABLE #d (
            PENGIRIM varchar(50) NULL,
            PENERIMA varchar(50) NULL,
            PLU varchar(50) NULL,
            QTY int NULL,
            HPP money NULL,
            PRICE money NULL
        );
        INSERT INTO #d
        EXEC pos_server.dbo.xsp_pak_woro_detail_st_out_getrows;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           d.PENGIRIM AS PENGIRIM,
                           d.PENERIMA AS PENERIMA,
                           d.PLU AS PLU,
                           CAST(ISNULL(d.QTY, 0) AS float) AS QTY,
                           CAST(ISNULL(d.HPP, 0) AS float) AS HPP,
                           CAST(ISNULL(d.PRICE, 0) AS float) AS PRICE
                       FROM #d d
                       ORDER BY d.PENGIRIM, d.PENERIMA, d.PLU
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
