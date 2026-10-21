/*
  Tr St Out (REG2) — mirror of Tr St In; filter by ID_Store_OUT / Brand_OUT.
  NEW SP only on RBACESS; queries pos_server.dbo.*; never EXEC legacy.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_st_out_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_st_out_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_st_out_getrows
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
        DECLARE @brand varchar(50) = LOWER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), 'ALL'))));
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

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           TSH.NO_URUT,
                           COALESCE(RC.Nomor, RM.Nomor, RF.Nomor) AS nomor,
                           TSH.Brand_OUT,
                           TSH.ID_Store_OUT,
                           TSH.Grade_OUT,
                           TSH.Brand_IN,
                           TSH.ID_Store_IN,
                           TSH.Grade_IN,
                           TSH.WAKTU_URUT,
                           TSH.NO_TR_ST_HEADER,
                           TSH.QTY_OUT,
                           TSH.HPP_OUT,
                           TSH.Price_OUT AS PRICE_OUT,
                           TSH.QTY_REAL,
                           TSH.HPP_REAL,
                           TSH.PRICE_REAL,
                           CONVERT(varchar(10), TSH.Tgl_Out, 23) AS tgl_out,
                           CONVERT(varchar(10), TSH.Tgl_Closed_Real, 23) AS tgl_closed_real,
                           TSH.Status_OUT,
                           TSH.Status_Real
                       FROM pos_server.dbo.TR_ST_HEADER TSH WITH (NOLOCK)
                       LEFT JOIN pos_server.dbo.DT_STORE DS WITH (NOLOCK) ON DS.Store_ID = TSH.ID_Store_OUT
                       LEFT JOIN AMS_DC_DB.dbo.TR_FromDC_RC RC WITH (NOLOCK)
                         ON TSH.NO_TR_ST_HEADER = RC.ID_Out COLLATE SQL_Latin1_General_CP1_CI_AS
                       LEFT JOIN AMS_DC_DB.dbo.TR_FromDC_RM RM WITH (NOLOCK)
                         ON TSH.NO_TR_ST_HEADER = RM.ID_Out COLLATE SQL_Latin1_General_CP1_CI_AS
                       LEFT JOIN AMS_DC_DB.dbo.TR_FromDC_RIF RF WITH (NOLOCK)
                         ON TSH.NO_TR_ST_HEADER = RF.ID_Out COLLATE SQL_Latin1_General_CP1_CI_AS
                       WHERE TSH.Tgl_Out >= @from AND TSH.Tgl_Out < @toX
                         AND (@brand = 'ALL' OR LOWER(DS.Store_Brand_ID) = @brand OR LOWER(TSH.Brand_OUT) = @brand)
                         AND (@store = 'ALL' OR TSH.ID_Store_OUT = @store)
                         AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = TSH.ID_Store_OUT COLLATE Latin1_General_CI_AS))
                       ORDER BY TSH.Tgl_Out DESC
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
