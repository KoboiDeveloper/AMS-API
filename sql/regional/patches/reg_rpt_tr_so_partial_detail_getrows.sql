/*
  Tr So Partial detail modal — ASP parity Rpt_Tr_So_Partial_Detail2.aspx
  Legacy: pos_server.dbo.xsp_rpt_tr_so_detail_parsial_getrows @p_tr_so_header
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_tr_so_partial_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_partial_detail_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_tr_so_partial_detail_getrows
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
                SELECT '4002500' AS responseCode, 'NO_TR_SO_HEADER wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        CREATE TABLE #d (
            brand varchar(20) NULL,
            store varchar(20) NULL,
            NO_URUT bigint NULL,
            WAKTU_URUT datetime NULL,
            NO_TR_SO_HEADER varchar(32) NULL,
            ID_TR_SO_DETAIL varchar(32) NULL,
            PLU varchar(13) NULL,
            Deskripsi varchar(max) NULL,
            QTY_A int NULL,
            HPP_A money NULL,
            PRICE_A money NULL,
            TOTAL_HPP_A money NULL,
            TOTAL_PRICE_A money NULL,
            QTY_REAL int NULL,
            HPP_REAL money NULL,
            PRICE_REAL money NULL,
            TOTAL_HPP_REAL money NULL,
            TOTAL_PRICE_REAL money NULL,
            QTY_SELISIH int NULL,
            TOTAL_HPP_SELISIH money NULL,
            TOTAL_PRICE_SELISIH money NULL
        );

        INSERT INTO #d
        EXEC pos_server.dbo.xsp_rpt_tr_so_detail_parsial_getrows @p_tr_so_header = @hdr;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           d.PLU AS PLU,
                           d.Deskripsi AS DESKRIPSI,
                           CAST(ISNULL(d.QTY_A, 0) AS float) AS QTY_A,
                           CAST(ISNULL(d.HPP_A, 0) AS float) AS HPP_A,
                           CAST(ISNULL(d.PRICE_A, 0) AS float) AS PRICE_A,
                           CAST(ISNULL(d.TOTAL_HPP_A, 0) AS float) AS TOTAL_HPP_A,
                           CAST(ISNULL(d.TOTAL_PRICE_A, 0) AS float) AS TOTAL_PRICE_A,
                           CAST(ISNULL(d.QTY_REAL, 0) AS float) AS QTY_REAL,
                           CAST(ISNULL(d.HPP_REAL, 0) AS float) AS HPP_REAL,
                           CAST(ISNULL(d.PRICE_REAL, 0) AS float) AS PRICE_REAL,
                           CAST(ISNULL(d.TOTAL_HPP_REAL, 0) AS float) AS TOTAL_HPP_REAL,
                           CAST(ISNULL(d.TOTAL_PRICE_REAL, 0) AS float) AS TOTAL_PRICE_REAL,
                           CAST(ISNULL(d.QTY_SELISIH, 0) AS float) AS QTY_SELISIH,
                           CAST(ISNULL(d.TOTAL_HPP_SELISIH, 0) AS float) AS TOTAL_HPP_SELISIH,
                           CAST(ISNULL(d.TOTAL_PRICE_SELISIH, 0) AS float) AS TOTAL_PRICE_SELISIH
                       FROM #d d
                       ORDER BY d.PLU
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
