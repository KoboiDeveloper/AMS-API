/*
  DROP wrong stubs previously created on POS_SERVER.
  REG2 getrows live on RBACESS only (xsp_ams_new_reg_*).
*/
USE POS_SERVER;
GO
SET NOCOUNT ON;
GO

DECLARE @names TABLE (sp_name sysname NOT NULL PRIMARY KEY);
INSERT INTO @names (sp_name) VALUES
    ('xsp_ams_new_reg_rpt_sales_article_getrows'),
    ('xsp_ams_new_reg_rpt_sales_island_getrows'),
    ('xsp_ams_new_reg_rpt_gross_margin_getrows'),
    ('xsp_ams_new_reg_rpt_koleksi_getrows'),
    ('xsp_ams_new_reg_rpt_sales_manpower_getrows');

DECLARE @sp sysname;
DECLARE @sql nvarchar(max);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT sp_name FROM @names;
OPEN c;
FETCH NEXT FROM c INTO @sp;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'IF OBJECT_ID(N''dbo.' + @sp + N''', N''P'') IS NOT NULL DROP PROCEDURE dbo.' + @sp + N';';
    EXEC sys.sp_executesql @sql;
    FETCH NEXT FROM c INTO @sp;
END
CLOSE c;
DEALLOCATE c;
GO
