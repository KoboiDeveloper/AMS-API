/*
  Outstanding Stock detail (REG2) — port xsp_detail_tr_sales_header_outstanding_getrows
  (outSstockDetail.aspx). Param @p_id = NO_TR_ST_HEADER (CB), despite legacy name.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_outstanding_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_outstanding_detail_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_outstanding_detail_getrows
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
                           PLU,
                           QTY_OUT,
                           HPP_OUT,
                           Price_OUT AS PRICE_OUT,
                           Total_HPP_OUT,
                           Total_Price_OUT AS TOTAL_PRICE_OUT
                       FROM pos_server.dbo.TR_ST_DETAIL WITH (NOLOCK)
                       WHERE NO_TR_ST_HEADER = @hdr
                       ORDER BY QTY_OUT ASC
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
