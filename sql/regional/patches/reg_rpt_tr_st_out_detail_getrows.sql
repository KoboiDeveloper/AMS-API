/*
  Tr St Out detail + print lines (REG2) — port xsp_rpt_tr_st_header_detail_getrows
  (Rpt_Tr_St_Detail.aspx / STOUT.rpt). Param @p_id = NO_TR_ST_HEADER.
  Includes DESKRIPSI/ARTICLE from DT_PLU for print PDF.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_st_out_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_st_out_detail_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_st_out_detail_getrows
(
      @p_id varchar(80)
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @hdr varchar(80) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        IF @hdr = ''
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'NO_TR_ST_HEADER wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           x.PLU,
                           ISNULL(p.DESKRIPSI, '') AS DESKRIPSI,
                           ISNULL(p.ARTICLE, '') AS ARTICLE,
                           x.QTY_OUT,
                           x.HPP_OUT,
                           x.PRICE_OUT,
                           x.TOTAL_HPP_OUT,
                           x.TOTAL_PRICE_OUT
                       FROM (
                           SELECT
                               d.PLU,
                               d.QTY_OUT,
                               d.HPP_OUT,
                               d.Price_OUT AS PRICE_OUT,
                               d.Total_HPP_OUT AS TOTAL_HPP_OUT,
                               d.Total_Price_OUT AS TOTAL_PRICE_OUT,
                               d.NO_URUT
                           FROM pos_server.dbo.TR_ST_DETAIL d WITH (NOLOCK)
                           WHERE d.NO_TR_ST_HEADER = @hdr
                           UNION ALL
                           SELECT
                               s.PLU,
                               s.QTY_OUT,
                               s.HPP_OUT,
                               s.Price_OUT AS PRICE_OUT,
                               s.Total_HPP_OUT AS TOTAL_HPP_OUT,
                               s.Total_Price_OUT AS TOTAL_PRICE_OUT,
                               s.NO_URUT
                           FROM pos_server.dbo.TR_ST_DETAIL_SHOPPING_BAG s WITH (NOLOCK)
                           WHERE s.NO_TR_ST_HEADER_SHOPPING_BAG = @hdr
                       ) x
                       LEFT JOIN pos_server.dbo.DT_PLU p WITH (NOLOCK) ON p.PLU = x.PLU
                       ORDER BY x.NO_URUT
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
