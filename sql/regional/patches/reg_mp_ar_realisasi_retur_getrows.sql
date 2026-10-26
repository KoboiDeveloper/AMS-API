/*
  Marketplace AR Realisasi + MP Retur (view-only) — RBACESS wrappers.
  Legacy ASP:
    module/MARKETPLACE/Ar_Realisasi.aspx  → xsp_get_ar_marketplace_realiasi_uang_masuk
    module/MARKETPLACE/MP_gudang.aspx     → xsp_app_gudang_retur_list_getrows
                                           + xsp_app_app_gudang_retur_badge_total_chart_getrow

  Pattern: dm_exec_describe_first_result_set → #t → INSERT EXEC pos_server → FOR JSON
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* ===================== AR REALISASI LIST ===================== */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_realisasi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_realisasi_getrows
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
        DECLARE @mp varchar(80) = LTRIM(RTRIM(ISNULL(@p_marketplace, '')));
        DECLARE @brand varchar(80) = LTRIM(RTRIM(ISNULL(COALESCE(
            NULLIF(@p_brand_filter,''), NULLIF(@p_brand,''), NULLIF(@p_id_brand,'')
        ), '')));
        DECLARE @invoice varchar(80) = LTRIM(RTRIM(ISNULL(@p_invoice, '')));
        DECLARE @from_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_from_date, '')));
        DECLARE @to_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_to_date, '')));
        DECLARE @status varchar(50) = LOWER(LTRIM(RTRIM(ISNULL(@p_status, 'belum'))));

        IF @mp = '' OR UPPER(@mp) = 'ALL' SET @mp = '';
        IF @brand = '' OR UPPER(@brand) = 'ALL' SET @brand = '';
        IF @status = '' SET @status = 'belum';
        IF @status NOT IN ('belum', 'sudah') SET @status = 'belum';

        /* ASP: date only required when status=sudah */
        IF @status = 'belum'
        BEGIN
            SET @from_date = '';
            SET @to_date = '';
        END;

        DECLARE @probe nvarchar(max) = N'EXEC pos_server.dbo.xsp_get_ar_marketplace_realiasi_uang_masuk
            @p_marketplace=N''' + REPLACE(@mp, '''', '''''') + N''',
            @p_brand=N''' + REPLACE(@brand, '''', '''''') + N''',
            @p_no_invoice=N''' + REPLACE(@invoice, '''', '''''') + N''',
            @p_tgl_dari=N''' + REPLACE(@from_date, '''', '''''') + N''',
            @p_tgl_sampai=N''' + REPLACE(@to_date, '''', '''''') + N''',
            @p_status_realisasi=N''' + REPLACE(@status, '''', '''''') + N'''';

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
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'Tidak bisa mendeskripsikan hasil xsp_get_ar_marketplace_realiasi_uang_masuk.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @json nvarchar(max);
        DECLARE @sql nvarchar(max) = N'
            CREATE TABLE #t (' + @cols + N');
            INSERT INTO #t
            EXEC pos_server.dbo.xsp_get_ar_marketplace_realiasi_uang_masuk
                @p_marketplace=@m, @p_brand=@b, @p_no_invoice=@i,
                @p_tgl_dari=@f, @p_tgl_sampai=@t, @p_status_realisasi=@s;
            SELECT @j = (SELECT * FROM #t FOR JSON PATH, INCLUDE_NULL_VALUES);
        ';
        EXEC sp_executesql @sql,
            N'@m varchar(80), @b varchar(80), @i varchar(80), @f varchar(30), @t varchar(30), @s varchar(50), @j nvarchar(max) OUTPUT',
            @m=@mp, @b=@brand, @i=@invoice, @f=@from_date, @t=@to_date, @s=@status, @j=@json OUTPUT;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL(@json, N'[]')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ===================== MP RETUR LIST ===================== */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_mp_retur_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_mp_retur_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_mp_retur_getrows
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
        DECLARE @from_raw varchar(30) = LTRIM(RTRIM(ISNULL(@p_from_date, '')));
        DECLARE @to_raw varchar(30) = LTRIM(RTRIM(ISNULL(@p_to_date, '')));
        DECLARE @mp varchar(80) = LTRIM(RTRIM(ISNULL(@p_marketplace, '0')));
        DECLARE @brand varchar(80) = LTRIM(RTRIM(ISNULL(COALESCE(
            NULLIF(@p_brand_filter,''), NULLIF(@p_brand,''), NULLIF(@p_id_brand,'')
        ), 'ALL')));
        DECLARE @date_by varchar(80) = LTRIM(RTRIM(ISNULL(@p_tipe, 'Tanggal Transaksi')));
        DECLARE @ket_gudang varchar(80) = LTRIM(RTRIM(ISNULL(@p_kategori, 'Semua Barang')));
        DECLARE @kw varchar(200) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_keywords,''), NULLIF(@p_invoice,''), NULLIF(@p_plu,'')), '')));

        IF @mp = '' OR UPPER(@mp) = 'ALL' SET @mp = '0';
        IF @brand = '' SET @brand = 'ALL';
        IF @date_by = '' SET @date_by = 'Tanggal Transaksi';
        IF @ket_gudang = '' SET @ket_gudang = 'Semua Barang';

        /* Legacy expects dd/MM/yyyy — accept yyyy-MM-dd too */
        DECLARE @from_date varchar(30) = @from_raw;
        DECLARE @to_date varchar(30) = @to_raw;
        IF @from_raw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
            SET @from_date = CONVERT(varchar(10), CONVERT(date, @from_raw, 23), 103);
        IF @to_raw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
            SET @to_date = CONVERT(varchar(10), CONVERT(date, @to_raw, 23), 103);

        IF @from_date = '' OR @to_date = ''
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'from_date dan to_date wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @probe nvarchar(max) = N'EXEC pos_server.dbo.xsp_app_gudang_retur_list_getrows
            @p_from_date=N''' + REPLACE(@from_date, '''', '''''') + N''',
            @p_to_date=N''' + REPLACE(@to_date, '''', '''''') + N''',
            @p_marketplace=N''' + REPLACE(@mp, '''', '''''') + N''',
            @p_brand=N''' + REPLACE(@brand, '''', '''''') + N''',
            @p_date_by=N''' + REPLACE(@date_by, '''', '''''') + N''',
            @p_keterangan_gudang=N''' + REPLACE(@ket_gudang, '''', '''''') + N''',
            @p_keywords=N''' + REPLACE(@kw, '''', '''''') + N'''';

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
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'Tidak bisa mendeskripsikan hasil xsp_app_gudang_retur_list_getrows.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @json nvarchar(max);
        DECLARE @sql nvarchar(max) = N'
            CREATE TABLE #t (' + @cols + N');
            INSERT INTO #t
            EXEC pos_server.dbo.xsp_app_gudang_retur_list_getrows
                @p_from_date=@f, @p_to_date=@t, @p_marketplace=@m, @p_brand=@b,
                @p_date_by=@d, @p_keterangan_gudang=@k, @p_keywords=@w;
            SELECT @j = (SELECT * FROM #t FOR JSON PATH, INCLUDE_NULL_VALUES);
        ';
        EXEC sp_executesql @sql,
            N'@f varchar(30), @t varchar(30), @m varchar(80), @b varchar(80), @d varchar(80), @k varchar(80), @w varchar(200), @j nvarchar(max) OUTPUT',
            @f=@from_date, @t=@to_date, @m=@mp, @b=@brand, @d=@date_by, @k=@ket_gudang, @w=@kw, @j=@json OUTPUT;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL(@json, N'[]')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ===================== MP RETUR BADGE ===================== */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_mp_retur_badge_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_mp_retur_badge_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_mp_retur_badge_getrow
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
        DECLARE @from_raw varchar(30) = LTRIM(RTRIM(ISNULL(@p_from_date, '')));
        DECLARE @to_raw varchar(30) = LTRIM(RTRIM(ISNULL(@p_to_date, '')));
        DECLARE @mp varchar(80) = LTRIM(RTRIM(ISNULL(@p_marketplace, '0')));
        DECLARE @brand varchar(80) = LTRIM(RTRIM(ISNULL(COALESCE(
            NULLIF(@p_brand_filter,''), NULLIF(@p_brand,''), NULLIF(@p_id_brand,'')
        ), 'ALL')));

        IF @mp = '' OR UPPER(@mp) = 'ALL' SET @mp = '0';
        IF @brand = '' SET @brand = 'ALL';

        DECLARE @from_date varchar(30) = @from_raw;
        DECLARE @to_date varchar(30) = @to_raw;
        IF @from_raw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
            SET @from_date = CONVERT(varchar(10), CONVERT(date, @from_raw, 23), 103);
        IF @to_raw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
            SET @to_date = CONVERT(varchar(10), CONVERT(date, @to_raw, 23), 103);

        DECLARE @probe nvarchar(max) = N'EXEC pos_server.dbo.xsp_app_app_gudang_retur_badge_total_chart_getrow
            @p_from_date=N''' + REPLACE(@from_date, '''', '''''') + N''',
            @p_to_date=N''' + REPLACE(@to_date, '''', '''''') + N''',
            @p_marketplace=N''' + REPLACE(@mp, '''', '''''') + N''',
            @p_brand=N''' + REPLACE(@brand, '''', '''''') + N'''';

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
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'Tidak bisa mendeskripsikan hasil badge retur.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @json nvarchar(max);
        DECLARE @sql nvarchar(max) = N'
            CREATE TABLE #t (' + @cols + N');
            INSERT INTO #t
            EXEC pos_server.dbo.xsp_app_app_gudang_retur_badge_total_chart_getrow
                @p_from_date=@f, @p_to_date=@t, @p_marketplace=@m, @p_brand=@b;
            SELECT @j = (SELECT TOP 1 * FROM #t FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        ';
        EXEC sp_executesql @sql,
            N'@f varchar(30), @t varchar(30), @m varchar(80), @b varchar(80), @j nvarchar(max) OUTPUT',
            @f=@from_date, @t=@to_date, @m=@mp, @b=@brand, @j=@json OUTPUT;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL(@json, N'{}')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
