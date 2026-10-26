/*
  Marketplace AR List (view-only) — RBACESS wrappers around POS_SERVER legacy SPs.
  Legacy ASP: module/MARKETPLACE/Ar_List.aspx

  SPs:
    xsp_ams_new_reg_ar_list_by_store_getrows   ← xsp_get_ar_marketplace[_02e…_11e]
    xsp_ams_new_reg_ar_total_getrows           ← xsp_get_total_ar
    xsp_ams_new_reg_ar_detail_realisasi_getrows← xsp_get_detail_realisasi
    xsp_ams_new_reg_ar_plu_summary_getrows     ← xsp_get_plu_sumarry
    xsp_ams_new_reg_ar_transaksi_detail_getrows← xsp_get_detail_brackdown_ar

  Pattern: describe first result set → CREATE #t → INSERT EXEC pos_server.dbo.* → FOR JSON PATH
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* ---------- shared signature macro via copy (regional convention) ---------- */

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_list_by_store_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_list_by_store_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_list_by_store_getrows
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
        DECLARE @store varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(
            NULLIF(@p_id_store,''), NULLIF(@p_store_id,''), NULLIF(@p_cabang,''), NULLIF(@p_id_cabang,'')
        ), ''))));
        DECLARE @from_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_from_date, '')));
        DECLARE @to_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_to_date, '')));
        DECLARE @mp varchar(80) = LTRIM(RTRIM(ISNULL(@p_marketplace, '')));
        DECLARE @status varchar(50) = LTRIM(RTRIM(ISNULL(@p_status, 'ALL')));
        DECLARE @invoice varchar(80) = LTRIM(RTRIM(ISNULL(@p_invoice, '-')));
        DECLARE @user_id varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(
            NULLIF(@p_actor_nik,''), NULLIF(@p_gh_id,''), NULLIF(@p_id_gh,'')
        ), '')));

        /* Legacy xsp_get_ar_marketplace*: blank marketplace returns 0 rows; ASP defaults to selected MP / ALL */
        IF @mp = '' SET @mp = 'ALL';
        IF @status = '' SET @status = 'ALL';
        IF @invoice = '' SET @invoice = '-';

        IF @store = '' OR @store NOT IN ('01E','02E','03E','04E','06E','07E','08E','09E','10E','11E')
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'Store wajib (01E–04E, 06E–11E).' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        IF @from_date = '' OR @to_date = ''
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'from_date dan to_date wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @legacy_sp sysname =
            CASE @store
                WHEN '01E' THEN N'xsp_get_ar_marketplace'
                WHEN '02E' THEN N'xsp_get_ar_marketplace_02e'
                WHEN '03E' THEN N'xsp_get_ar_marketplace_03e'
                WHEN '04E' THEN N'xsp_get_ar_marketplace_04e'
                WHEN '06E' THEN N'xsp_get_ar_marketplace_06e'
                WHEN '07E' THEN N'xsp_get_ar_marketplace_07e'
                WHEN '08E' THEN N'xsp_get_ar_marketplace_08e'
                WHEN '09E' THEN N'xsp_get_ar_marketplace_09e'
                WHEN '10E' THEN N'xsp_get_ar_marketplace_10e'
                WHEN '11E' THEN N'xsp_get_ar_marketplace_11e'
            END;

        DECLARE @probe nvarchar(max) = N'EXEC pos_server.dbo.' + QUOTENAME(@legacy_sp) + N'
            @p_from_date=N''' + REPLACE(@from_date, '''', '''''') + N''',
            @p_to_date=N''' + REPLACE(@to_date, '''', '''''') + N''',
            @p_marketplace=N''' + REPLACE(@mp, '''', '''''') + N''',
            @p_status=N''' + REPLACE(@status, '''', '''''') + N''',
            @p_user_id=N''' + REPLACE(@user_id, '''', '''''') + N''',
            @p_invoice=N''' + REPLACE(@invoice, '''', '''''') + N'''';

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
                       CONCAT('Tidak bisa mendeskripsikan hasil ', @legacy_sp, '.') AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @json nvarchar(max);
        DECLARE @sql nvarchar(max) = N'
            CREATE TABLE #t (' + @cols + N');
            INSERT INTO #t
            EXEC pos_server.dbo.' + QUOTENAME(@legacy_sp) + N'
                @p_from_date=@f, @p_to_date=@t, @p_marketplace=@m,
                @p_status=@s, @p_user_id=@u, @p_invoice=@i;
            SELECT @j = (SELECT * FROM #t FOR JSON PATH, INCLUDE_NULL_VALUES);
        ';
        EXEC sp_executesql @sql,
            N'@f varchar(30), @t varchar(30), @m varchar(80), @s varchar(50), @u varchar(50), @i varchar(80), @j nvarchar(max) OUTPUT',
            @f=@from_date, @t=@to_date, @m=@mp, @s=@status, @u=@user_id, @i=@invoice, @j=@json OUTPUT;

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

/* ===================== TOTAL ===================== */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_total_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_total_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_total_getrows
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
        DECLARE @from_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_from_date, '')));
        DECLARE @to_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_to_date, '')));
        IF @from_date = '' OR @to_date = ''
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'from_date dan to_date wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @probe nvarchar(max) = N'EXEC pos_server.dbo.xsp_get_total_ar @p_from_date=N'''
            + REPLACE(@from_date, '''', '''''') + N''', @p_to_date=N'''
            + REPLACE(@to_date, '''', '''''') + N'''';

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
                       'Tidak bisa mendeskripsikan hasil xsp_get_total_ar.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @json nvarchar(max);
        DECLARE @sql nvarchar(max) = N'
            CREATE TABLE #t (' + @cols + N');
            INSERT INTO #t EXEC pos_server.dbo.xsp_get_total_ar @p_from_date=@f, @p_to_date=@t;
            SELECT @j = (SELECT * FROM #t FOR JSON PATH, INCLUDE_NULL_VALUES);
        ';
        EXEC sp_executesql @sql,
            N'@f varchar(30), @t varchar(30), @j nvarchar(max) OUTPUT',
            @f=@from_date, @t=@to_date, @j=@json OUTPUT;

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

/* ===================== DETAIL REALISASI ===================== */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_detail_realisasi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_detail_realisasi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_detail_realisasi_getrows
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
        DECLARE @from_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_from_date, '')));
        DECLARE @to_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_to_date, '')));
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(
            NULLIF(@p_id_store,''), NULLIF(@p_store_id,''), NULLIF(@p_cabang,''), NULLIF(@p_id_cabang,''), 'ALL'
        ), 'ALL')));
        DECLARE @mp varchar(80) = LTRIM(RTRIM(ISNULL(@p_marketplace, '')));
        DECLARE @tipe varchar(50) = LTRIM(RTRIM(ISNULL(@p_tipe, 'tgl_sampai')));
        DECLARE @invoice varchar(80) = LTRIM(RTRIM(ISNULL(@p_invoice, '')));

        IF @store = '' SET @store = 'ALL';
        IF @mp = '' SET @mp = 'ALL';
        IF @tipe = '' SET @tipe = 'tgl_sampai';

        IF @from_date = '' OR @to_date = ''
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'from_date dan to_date wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @probe nvarchar(max) = N'EXEC pos_server.dbo.xsp_get_detail_realisasi
            @p_store=N''' + REPLACE(@store, '''', '''''') + N''',
            @p_mp=N''' + REPLACE(@mp, '''', '''''') + N''',
            @p_tipe=N''' + REPLACE(@tipe, '''', '''''') + N''',
            @p_from_date=N''' + REPLACE(@from_date, '''', '''''') + N''',
            @p_to_date=N''' + REPLACE(@to_date, '''', '''''') + N''',
            @p_invoice=N''' + REPLACE(@invoice, '''', '''''') + N'''';

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
                       'Tidak bisa mendeskripsikan hasil xsp_get_detail_realisasi.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @json nvarchar(max);
        DECLARE @sql nvarchar(max) = N'
            CREATE TABLE #t (' + @cols + N');
            INSERT INTO #t
            EXEC pos_server.dbo.xsp_get_detail_realisasi
                @p_store=@st, @p_mp=@m, @p_tipe=@tp, @p_from_date=@f, @p_to_date=@t, @p_invoice=@i;
            SELECT @j = (SELECT * FROM #t FOR JSON PATH, INCLUDE_NULL_VALUES);
        ';
        EXEC sp_executesql @sql,
            N'@st varchar(50), @m varchar(80), @tp varchar(50), @f varchar(30), @t varchar(30), @i varchar(80), @j nvarchar(max) OUTPUT',
            @st=@store, @m=@mp, @tp=@tipe, @f=@from_date, @t=@to_date, @i=@invoice, @j=@json OUTPUT;

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

/* ===================== PLU SUMMARY ===================== */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_plu_summary_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_plu_summary_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_plu_summary_getrows
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
        DECLARE @from_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_from_date, '')));
        DECLARE @to_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_to_date, '')));
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(
            NULLIF(@p_id_store,''), NULLIF(@p_store_id,''), NULLIF(@p_cabang,''), NULLIF(@p_id_cabang,''), 'ALL'
        ), 'ALL')));
        DECLARE @mp varchar(80) = LTRIM(RTRIM(ISNULL(@p_marketplace, '')));
        DECLARE @tipe varchar(50) = LTRIM(RTRIM(ISNULL(@p_tipe, 'tgl_sampai')));

        IF @store = '' SET @store = 'ALL';
        IF @mp = '' SET @mp = 'ALL';
        IF @tipe = '' SET @tipe = 'tgl_sampai';

        IF @from_date = '' OR @to_date = ''
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'from_date dan to_date wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @probe nvarchar(max) = N'EXEC pos_server.dbo.xsp_get_plu_sumarry
            @p_store=N''' + REPLACE(@store, '''', '''''') + N''',
            @p_mp=N''' + REPLACE(@mp, '''', '''''') + N''',
            @p_tipe=N''' + REPLACE(@tipe, '''', '''''') + N''',
            @p_from_date=N''' + REPLACE(@from_date, '''', '''''') + N''',
            @p_to_date=N''' + REPLACE(@to_date, '''', '''''') + N'''';

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
                       'Tidak bisa mendeskripsikan hasil xsp_get_plu_sumarry.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @json nvarchar(max);
        DECLARE @sql nvarchar(max) = N'
            CREATE TABLE #t (' + @cols + N');
            INSERT INTO #t
            EXEC pos_server.dbo.xsp_get_plu_sumarry
                @p_store=@st, @p_mp=@m, @p_tipe=@tp, @p_from_date=@f, @p_to_date=@t;
            SELECT @j = (SELECT * FROM #t FOR JSON PATH, INCLUDE_NULL_VALUES);
        ';
        EXEC sp_executesql @sql,
            N'@st varchar(50), @m varchar(80), @tp varchar(50), @f varchar(30), @t varchar(30), @j nvarchar(max) OUTPUT',
            @st=@store, @m=@mp, @tp=@tipe, @f=@from_date, @t=@to_date, @j=@json OUTPUT;

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

/* ===================== TRANSAKSI DETAIL ===================== */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_ar_transaksi_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_ar_transaksi_detail_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_ar_transaksi_detail_getrows
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
        DECLARE @from_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_from_date, '')));
        DECLARE @to_date varchar(30) = LTRIM(RTRIM(ISNULL(@p_to_date, '')));
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(
            NULLIF(@p_id_store,''), NULLIF(@p_store_id,''), NULLIF(@p_cabang,''), NULLIF(@p_id_cabang,''), 'ALL'
        ), 'ALL')));
        DECLARE @mp varchar(80) = LTRIM(RTRIM(ISNULL(@p_marketplace, '')));

        IF @store = '' SET @store = 'ALL';
        IF @mp = '' SET @mp = 'ALL';

        IF @from_date = '' OR @to_date = ''
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'from_date dan to_date wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @probe nvarchar(max) = N'EXEC pos_server.dbo.xsp_get_detail_brackdown_ar
            @p_store=N''' + REPLACE(@store, '''', '''''') + N''',
            @p_mp=N''' + REPLACE(@mp, '''', '''''') + N''',
            @p_from_date=N''' + REPLACE(@from_date, '''', '''''') + N''',
            @p_to_date=N''' + REPLACE(@to_date, '''', '''''') + N'''';

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
                       'Tidak bisa mendeskripsikan hasil xsp_get_detail_brackdown_ar.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @json nvarchar(max);
        DECLARE @sql nvarchar(max) = N'
            CREATE TABLE #t (' + @cols + N');
            INSERT INTO #t
            EXEC pos_server.dbo.xsp_get_detail_brackdown_ar
                @p_store=@st, @p_mp=@m, @p_from_date=@f, @p_to_date=@t;
            SELECT @j = (SELECT * FROM #t FOR JSON PATH, INCLUDE_NULL_VALUES);
        ';
        EXEC sp_executesql @sql,
            N'@st varchar(50), @m varchar(80), @f varchar(30), @t varchar(30), @j nvarchar(max) OUTPUT',
            @st=@store, @m=@mp, @f=@from_date, @t=@to_date, @j=@json OUTPUT;

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
