/*
  Last Stock — last date (ASP BindTglBatchAkhir).
  Legacy: pos_server.dbo.xsp_rpt_last_tanggal_batch_getrow
    SELECT format(DATEADD(day,1,MAX(TGL)),'yyyy-MM-dd') AS TANGGAL_BATCH
    FROM DT_BATCH WHERE STORE_ID = @p_xidstore
  REG2: GET /regional/rpt/inv/last-stock/{storeId}/batch-date
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_last_stock_batch_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_last_stock_batch_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_last_stock_batch_getrow
(
      @p_id varchar(80)
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_id, ''))));
        IF @store IN ('', '0', 'ALL')
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'store_id wajib (pilih store, bukan ALL).' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @tgl varchar(10) = NULL;
        SELECT @tgl = FORMAT(DATEADD(DAY, 1, MAX(b.TGL)), 'yyyy-MM-dd')
        FROM pos_server.dbo.DT_BATCH AS b WITH (NOLOCK)
        WHERE b.STORE_ID = @store;

        IF @tgl IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'Batch date tidak ditemukan untuk store ' + @store AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT @store AS STORE_ID,
                              @tgl AS TANGGAL_BATCH
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT '4002500' AS responseCode,
                   ERROR_MESSAGE() AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH
END
GO
