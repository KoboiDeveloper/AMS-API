/*
  Outstanding Stock Transfer (REG2) — port xsp_outstanding_stock__ghreg_transfer_getrows.
  NEW SP only on RBACESS; queries pos_server.dbo.*; never EXEC legacy.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_outstanding_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_outstanding_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_outstanding_getrows
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
        DECLARE @brandTo varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_brand_to, 'ALL'))));
        IF @brandTo IN ('','0') SET @brandTo = 'ALL';
        DECLARE @storeTo varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_store_to, 'ALL'))));
        IF @storeTo IN ('','0') SET @storeTo = 'ALL';

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
                           tsh.NO_URUT,
                           tsh.NO_TR_ST_HEADER,
                           CONVERT(varchar(10), tsh.Tgl_Out, 23) AS tgl_out,
                           CONVERT(varchar(10), tsh.Tgl_Closed_Real, 23) AS tgl_in,
                           tsh.ID_Store_OUT,
                           CONCAT(tsh.Brand_OUT, ' ', tsh.ID_Store_OUT, ' ', tsh.Grade_OUT) AS DARI,
                           CONCAT(tsh.Brand_IN, ' ', tsh.ID_Store_IN, ' ', tsh.Grade_IN, ' ', tsh.Distinct_IN) AS TOss,
                           DATEDIFF(day, tsh.Tgl_Out, GETDATE()) AS EGGING,
                           CASE
                               WHEN DATEDIFF(day, tsh.Tgl_Out, GETDATE()) <= 7 THEN 'WHITE'
                               WHEN DATEDIFF(day, tsh.Tgl_Out, GETDATE()) <= 14 THEN 'YELLOW'
                               WHEN DATEDIFF(day, tsh.Tgl_Out, GETDATE()) <= 28 THEN 'ORANGE'
                               ELSE 'RED'
                           END AS EGGING_WARNA,
                           nm.nomor
                       FROM pos_server.dbo.TR_ST_HEADER tsh WITH (NOLOCK)
                       LEFT JOIN (
                           SELECT nomor, ID_Out FROM AMS_DC_DB.dbo.TR_FromDC_RC WITH (NOLOCK) WHERE Status = 2
                           UNION ALL
                           SELECT nomor, ID_Out FROM AMS_DC_DB.dbo.TR_FromDC_RM WITH (NOLOCK) WHERE Status = 2
                           UNION ALL
                           SELECT nomor, ID_Out FROM AMS_DC_DB.dbo.TR_FromDC_RIF WITH (NOLOCK)
                       ) nm ON tsh.NO_TR_ST_HEADER = nm.ID_Out COLLATE SQL_Latin1_General_CP1_CI_AS
                       WHERE tsh.Tgl_Out >= @from AND tsh.Tgl_Out < @toX
                         AND (tsh.Status_OUT = 1 OR CAST(tsh.Status_OUT AS varchar(10)) = 'true')
                         AND ISNULL(tsh.Status_Real, 0) <> 1
                         AND (@brand = 'ALL' OR UPPER(tsh.Brand_OUT) = @brand)
                         AND (@store = 'ALL' OR tsh.ID_Store_OUT = @store)
                         AND (@brandTo = 'ALL' OR UPPER(tsh.Brand_IN) = @brandTo)
                         AND (@storeTo = 'ALL' OR tsh.ID_Store_IN = @storeTo)
                         AND (@scoped = 0 OR EXISTS (SELECT 1 FROM #sc sc WHERE sc.store = tsh.ID_Store_OUT COLLATE Latin1_General_CI_AS))
                       ORDER BY EGGING DESC
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
