/*
  Tr So (REG2) — ASP parity module/Rpt/Rpt_Tr_So.aspx
  List: pos_server.dbo.xsp_rpt_tr_so_header_detail_getrows
  Params: from_date, to_date, brand, store, id_gh (actor)
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_so_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_getrows
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

        DECLARE @brand varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
        IF @brand IN ('','0') SET @brand = 'ALL';
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), 'ALL'))));
        IF @store IN ('','0') SET @store = 'ALL';
        DECLARE @gh varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,''), NULLIF(@p_actor_nik,'')), '0')));
        IF @gh = '' SET @gh = '0';

        DECLARE @fromS varchar(20) = CONVERT(varchar(10), @from, 111);
        DECLARE @toS varchar(20) = CONVERT(varchar(10), @to, 111);

        CREATE TABLE #h (
            NO_URUT bigint NULL,
            WAKTU_URUT datetime NULL,
            NO_TR_SO_HEADER varchar(32) NULL,
            tgl_so nvarchar(4000) NULL,
            Brand_SO varchar(max) NULL,
            ID_Store_SO varchar(max) NULL,
            Class_SO varchar(3) NULL,
            Grade_SO varchar(1) NULL,
            Distinct_A int NULL,
            Qty_A int NULL,
            HPP_A money NULL,
            Price_A money NULL,
            Distinct_REAL int NULL,
            QTY_REAL int NULL,
            HPP_REAL money NULL,
            Price_REAL money NULL,
            tgl_status_so nvarchar(4000) NULL,
            Status_SO bit NULL,
            tgl_closing nvarchar(4000) NULL,
            Status_Closing bit NULL,
            qty_selisih int NULL,
            HPP_SELISIH money NULL,
            price_selisih money NULL,
            tgl_download nvarchar(4000) NULL,
            Status_Download bit NULL
        );

        INSERT INTO #h
        EXEC pos_server.dbo.xsp_rpt_tr_so_header_detail_getrows
            @p_from_date = @fromS,
            @p_to_date = @toS,
            @p_brand_id = @brand,
            @p_store_id = @store,
            @p_id_gh = @gh;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           h.NO_URUT AS NO_URUT,
                           h.NO_TR_SO_HEADER AS NO_TR_SO_HEADER,
                           h.tgl_so AS TGL_SO,
                           h.Brand_SO AS BRAND_SO,
                           h.ID_Store_SO AS ID_STORE_SO,
                           h.Class_SO AS CLASS_SO,
                           h.Grade_SO AS GRADE_SO,
                           CAST(ISNULL(h.Qty_A, 0) AS float) AS QTY_A,
                           CAST(ISNULL(h.HPP_A, 0) AS float) AS HPP_A,
                           CAST(ISNULL(h.Price_A, 0) AS float) AS PRICE_A,
                           CAST(ISNULL(h.QTY_REAL, 0) AS float) AS QTY_REAL,
                           CAST(ISNULL(h.HPP_REAL, 0) AS float) AS HPP_REAL,
                           CAST(ISNULL(h.Price_REAL, 0) AS float) AS PRICE_REAL,
                           h.tgl_status_so AS TGL_STATUS_SO,
                           CAST(ISNULL(h.Status_SO, 0) AS int) AS STATUS_SO,
                           h.tgl_closing AS TGL_CLOSING,
                           CAST(ISNULL(h.Status_Closing, 0) AS int) AS STATUS_CLOSING,
                           CAST(ISNULL(h.qty_selisih, 0) AS float) AS QTY_SELISIH,
                           CAST(ISNULL(h.HPP_SELISIH, 0) AS float) AS HPP_SELISIH,
                           CAST(ISNULL(h.price_selisih, 0) AS float) AS PRICE_SELISIH
                       FROM #h h
                       ORDER BY h.WAKTU_URUT DESC, h.NO_URUT DESC
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
