/*
  So Adjustment (REG2) — ASP parity module/Rpt/Rpt_SO_Adjusment.aspx
  Legacy:
    PLU   → pos_server.dbo.xsp_rpt_tr_so_adjust_getrows
    CLASS → pos_server.dbo.xsp_rpt_tr_so_adjust_CLASS_getrows
  Params: from_date, to_date, brand, store, id_gh, tipe (plu|class)
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_so_adj_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_so_adj_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_so_adj_getrows
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

        DECLARE @tipe varchar(20) = LOWER(LTRIM(RTRIM(ISNULL(@p_tipe, 'plu'))));
        IF @tipe IN ('','full','all','1') SET @tipe = 'plu';
        IF @tipe IN ('3','cls') SET @tipe = 'class';

        DECLARE @fromS varchar(20) = CONVERT(varchar(10), @from, 111);
        DECLARE @toS varchar(20) = CONVERT(varchar(10), @to, 111);

        IF @tipe = 'class'
        BEGIN
            CREATE TABLE #c (
                PLU varchar(13) NULL,
                QTY int NULL,
                TOTAL_PRICE money NULL
            );
            INSERT INTO #c
            EXEC pos_server.dbo.xsp_rpt_tr_so_adjust_CLASS_getrows
                @p_from_date = @fromS,
                @p_to_date = @toS,
                @p_brand_id = @brand,
                @p_store_id = @store,
                @p_id_gh = @gh;

            SELECT @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT
                               c.PLU AS PLU,
                               CAST(ISNULL(c.QTY, 0) AS float) AS QTY,
                               CAST(ISNULL(c.TOTAL_PRICE, 0) AS float) AS TOTAL_PRICE
                           FROM #c c
                           ORDER BY c.PLU
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        CREATE TABLE #p (
            NO_URUT bigint NULL,
            WAKTU_URUT datetime NULL,
            ID_TR_SO_ADJUST varchar(32) NULL,
            ID_TR_SO_SELISIH varchar(32) NULL,
            NO_TR_SO_HEADER varchar(32) NULL,
            STORE_ID varchar(50) NULL,
            PLU varchar(13) NULL,
            QTY int NULL,
            HPP money NULL,
            PRICE money NULL,
            TOTAL_HPP money NULL,
            TOTAL_PRICE money NULL,
            TGL_REAL nvarchar(4000) NULL,
            TGL_ADJUST nvarchar(4000) NULL
        );
        INSERT INTO #p
        EXEC pos_server.dbo.xsp_rpt_tr_so_adjust_getrows
            @p_from_date = @fromS,
            @p_to_date = @toS,
            @p_brand_id = @brand,
            @p_store_id = @store,
            @p_id_gh = @gh;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           p.STORE_ID AS STORE_ID,
                           p.PLU AS PLU,
                           CAST(ISNULL(p.QTY, 0) AS float) AS QTY,
                           CAST(ISNULL(p.HPP, 0) AS float) AS HPP,
                           CAST(ISNULL(p.PRICE, 0) AS float) AS PRICE,
                           CAST(ISNULL(p.TOTAL_HPP, 0) AS float) AS TOTAL_HPP,
                           CAST(ISNULL(p.TOTAL_PRICE, 0) AS float) AS TOTAL_PRICE,
                           p.TGL_ADJUST AS TGL_ADJUST,
                           p.NO_TR_SO_HEADER AS NO_TR_SO_HEADER,
                           p.ID_TR_SO_ADJUST AS ID_TR_SO_ADJUST
                       FROM #p p
                       ORDER BY p.WAKTU_URUT DESC, p.NO_URUT DESC
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
