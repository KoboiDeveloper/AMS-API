/*
  AR List detail (view-only) — parity cart.aspx checkdata
  Legacy: pos_server.dbo.xsp_get_ar_marketplace_getrow @p_id
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_list_detail_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_list_detail_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_list_detail_getrow
(
      @p_id varchar(80)
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id varchar(80) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        IF @id = ''
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'ID_TR_SALES_HEADER wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @probe nvarchar(max) = N'EXEC pos_server.dbo.xsp_get_ar_marketplace_getrow @p_id=N'''
            + REPLACE(@id, '''', '''''') + N'''';

        DECLARE @cols nvarchar(max);
        SELECT @cols = STUFF((
            SELECT N',' + QUOTENAME(name) + N' ' + system_type_name
            FROM sys.dm_exec_describe_first_result_set(@probe, NULL, 0)
            WHERE name IS NOT NULL AND is_hidden = 0
            ORDER BY column_ordinal
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 1, N'');

        IF @cols IS NULL OR @cols = N''
        BEGIN
            SELECT @bitparam = (
                SELECT '4002500' AS responseCode,
                       'Tidak bisa mendeskripsikan hasil xsp_get_ar_marketplace_getrow.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @json nvarchar(max);
        DECLARE @sql nvarchar(max) = N'
            CREATE TABLE #t (' + @cols + N');
            INSERT INTO #t EXEC pos_server.dbo.xsp_get_ar_marketplace_getrow @p_id=@id;
            SELECT @j = (SELECT TOP 1 * FROM #t FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        ';
        EXEC sp_executesql @sql,
            N'@id varchar(80), @j nvarchar(max) OUTPUT',
            @id=@id, @j=@json OUTPUT;

        IF @json IS NULL OR LTRIM(@json) = ''
        BEGIN
            SELECT @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY(N'{}') AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(@json) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
