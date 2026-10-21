/*
  Tr St In detail (REG2) — port xsp_rpt_tr_st_header_detail_getrows (Rpt_Tr_St_In_Detail.aspx).
  Param @p_id = NO_TR_ST_HEADER (CB / TRSTH).
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_st_in_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_st_in_detail_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_st_in_detail_getrows
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
                           QTY_REAL,
                           HPP_REAL,
                           PRICE_REAL,
                           Total_HPP_REAL AS TOTAL_HPP_REAL,
                           Total_Price_REAL AS TOTAL_PRICE_REAL
                       FROM (
                           SELECT PLU, QTY_REAL, HPP_REAL, PRICE_REAL, Total_HPP_REAL, Total_Price_REAL, NO_URUT
                           FROM pos_server.dbo.TR_ST_DETAIL WITH (NOLOCK)
                           WHERE NO_TR_ST_HEADER = @hdr
                           UNION ALL
                           SELECT PLU, QTY_REAL, HPP_REAL, PRICE_REAL, Total_HPP_REAL, Total_Price_REAL, NO_URUT
                           FROM pos_server.dbo.TR_ST_DETAIL_SHOPPING_BAG WITH (NOLOCK)
                           WHERE NO_TR_ST_HEADER_SHOPPING_BAG = @hdr
                       ) x
                       ORDER BY NO_URUT
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
