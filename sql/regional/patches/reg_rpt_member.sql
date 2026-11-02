/*
  Member report (REG RPT) — module/rpt/member.aspx parity
  Wrappers around pos_server.dbo.xsp_app_dashboard_member_* / xsp_app_member_badge_total_chart_getrow.
  Legacy SPs expect dates as dd/MM/yyyy (style 103); wrappers accept yyyy-MM-dd too.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.fn_ams_reg_member_date103', N'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_ams_reg_member_date103;
GO
CREATE FUNCTION dbo.fn_ams_reg_member_date103 (@v varchar(30), @fallback date)
RETURNS varchar(10)
AS
BEGIN
    DECLARE @s varchar(30) = LTRIM(RTRIM(ISNULL(@v, '')));
    DECLARE @d date = NULL;
    IF @s LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%'
        SET @d = TRY_CONVERT(date, LEFT(@s, 10), 23);
    ELSE IF @s <> ''
        SET @d = TRY_CONVERT(date, @s, 103);
    RETURN CONVERT(varchar(10), ISNULL(@d, @fallback), 103);
END
GO

/* ---------- member list (normal + member-only search) ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_list_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_list_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_list_getrows
(
      @p_keywords varchar(50) = NULL
    , @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @p_provinsi varchar(40) = NULL
    , @p_kota varchar(40) = NULL
    , @p_brand varchar(40) = NULL
    , @p_age_from varchar(10) = NULL
    , @p_age_to varchar(10) = NULL
    , @p_jenis_kelamin varchar(10) = NULL
    , @p_search_member varchar(10) = NULL
    , @p_page varchar(10) = NULL
    , @p_page_size varchar(10) = NULL
    , @p_sort varchar(40) = NULL
    , @p_sort_dir varchar(4) = NULL
    , @p_export varchar(10) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @today date = CAST(GETDATE() AS date);
        DECLARE @fd varchar(10) = dbo.fn_ams_reg_member_date103(@p_from_date, DATEFROMPARTS(YEAR(@today), MONTH(@today), 1));
        DECLARE @td varchar(10) = dbo.fn_ams_reg_member_date103(@p_to_date, @today);
        DECLARE @kw varchar(50) = LTRIM(RTRIM(ISNULL(@p_keywords, '')));
        DECLARE @prov varchar(40) = ISNULL(NULLIF(NULLIF(LTRIM(RTRIM(@p_provinsi)), ''), 'ALL'), '0');
        DECLARE @kota varchar(40) = ISNULL(NULLIF(NULLIF(LTRIM(RTRIM(@p_kota)), ''), 'ALL'), '0');
        DECLARE @brand varchar(40) = ISNULL(NULLIF(NULLIF(LTRIM(RTRIM(@p_brand)), ''), 'ALL'), '0');
        DECLARE @jk varchar(10) = ISNULL(NULLIF(NULLIF(LTRIM(RTRIM(@p_jenis_kelamin)), ''), 'ALL'), '0');
        DECLARE @ageFrom int = ISNULL(TRY_CONVERT(int, @p_age_from), 0);
        DECLARE @ageTo int = ISNULL(TRY_CONVERT(int, @p_age_to), 0);
        DECLARE @memberOnly bit = CASE WHEN LOWER(ISNULL(@p_search_member, '')) IN ('1', 'true', 'yes', 'on') THEN 1 ELSE 0 END;
        DECLARE @isExport bit = CASE WHEN LOWER(ISNULL(@p_export, '')) IN ('1', 'true', 'yes') THEN 1 ELSE 0 END;
        DECLARE @page int = ISNULL(NULLIF(TRY_CONVERT(int, @p_page), 0), 1);
        DECLARE @size int = ISNULL(NULLIF(TRY_CONVERT(int, @p_page_size), 0), 20);
        IF @size > 500 SET @size = 500;
        IF @page < 1 SET @page = 1;
        DECLARE @sort varchar(40) = LOWER(LTRIM(RTRIM(ISNULL(@p_sort, ''))));
        DECLARE @desc bit = CASE WHEN UPPER(ISNULL(@p_sort_dir, '')) = 'DESC' THEN 1 ELSE 0 END;

        CREATE TABLE #m
        (
              rn int IDENTITY(1, 1) NOT NULL
            , id_member varchar(32) NULL
            , MEMBER_ID varchar(20) NULL
            , validasi_data varchar(12) NULL
            , NAME varchar(max) NULL
            , PROVINSI varchar(255) NULL
            , KOTA varchar(255) NULL
            , TOTAL_POINT int NULL
            , POINT_USED numeric(38, 0) NULL
            , JOIN_DATE nvarchar(4000) NULL
            , TOTAL_TRANSACTION int NULL
            , STATUS varchar(6) NULL
            , BRAND varchar(50) NULL
            , AGE int NULL
            , GENDER varchar(6) NULL
            , logo varchar(778) NULL
            , TIER varchar(331) NULL
        );

        IF @memberOnly = 1
            INSERT INTO #m (id_member, MEMBER_ID, validasi_data, NAME, PROVINSI, KOTA, TOTAL_POINT, POINT_USED, JOIN_DATE,
                            TOTAL_TRANSACTION, STATUS, BRAND, AGE, GENDER, logo, TIER)
            EXEC pos_server.dbo.xsp_app_dashboard_member_list_getrows_test_member @kw, @fd, @td;
        ELSE
            INSERT INTO #m (id_member, MEMBER_ID, validasi_data, NAME, PROVINSI, KOTA, TOTAL_POINT, POINT_USED, JOIN_DATE,
                            TOTAL_TRANSACTION, STATUS, BRAND, AGE, GENDER, logo, TIER)
            EXEC pos_server.dbo.xsp_app_dashboard_member_list_getrows_test @kw, @fd, @td, @prov, @kota, @brand, @ageFrom, @ageTo, @jk;

        DECLARE @total int = (SELECT COUNT(*) FROM #m);
        DECLARE @skip int = CASE WHEN @isExport = 1 THEN 0 ELSE (@page - 1) * @size END;
        DECLARE @take int = CASE WHEN @isExport = 1 THEN 2147483647 ELSE @size END;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   @total AS total, @page AS page, @size AS page_size,
                   @fd AS from_date, @td AS to_date,
                   JSON_QUERY(ISNULL((
                       SELECT
                              m.id_member, m.MEMBER_ID AS member_id, LTRIM(RTRIM(ISNULL(m.validasi_data, ''))) AS validasi_data,
                              m.NAME AS name, m.PROVINSI AS provinsi, m.KOTA AS kota,
                              m.TOTAL_POINT AS total_point, CAST(m.POINT_USED AS bigint) AS point_used,
                              m.JOIN_DATE AS join_date, m.TIER AS tier, m.TOTAL_TRANSACTION AS total_transaction,
                              m.STATUS AS status, LTRIM(RTRIM(m.BRAND)) AS brand, m.AGE AS age, m.GENDER AS gender,
                              m.logo
                       FROM #m AS m
                       ORDER BY
                              CASE WHEN @desc = 0 AND @sort = 'member_id' THEN m.MEMBER_ID END ASC,
                              CASE WHEN @desc = 1 AND @sort = 'member_id' THEN m.MEMBER_ID END DESC,
                              CASE WHEN @desc = 0 AND @sort = 'name' THEN m.NAME END ASC,
                              CASE WHEN @desc = 1 AND @sort = 'name' THEN m.NAME END DESC,
                              CASE WHEN @desc = 0 AND @sort = 'provinsi' THEN m.PROVINSI END ASC,
                              CASE WHEN @desc = 1 AND @sort = 'provinsi' THEN m.PROVINSI END DESC,
                              CASE WHEN @desc = 0 AND @sort = 'kota' THEN m.KOTA END ASC,
                              CASE WHEN @desc = 1 AND @sort = 'kota' THEN m.KOTA END DESC,
                              CASE WHEN @desc = 0 AND @sort = 'tier' THEN m.TIER END ASC,
                              CASE WHEN @desc = 1 AND @sort = 'tier' THEN m.TIER END DESC,
                              CASE WHEN @desc = 0 AND @sort = 'gender' THEN m.GENDER END ASC,
                              CASE WHEN @desc = 1 AND @sort = 'gender' THEN m.GENDER END DESC,
                              CASE WHEN @desc = 0 AND @sort = 'total_point' THEN m.TOTAL_POINT END ASC,
                              CASE WHEN @desc = 1 AND @sort = 'total_point' THEN m.TOTAL_POINT END DESC,
                              CASE WHEN @desc = 0 AND @sort = 'point_used' THEN m.POINT_USED END ASC,
                              CASE WHEN @desc = 1 AND @sort = 'point_used' THEN m.POINT_USED END DESC,
                              CASE WHEN @desc = 0 AND @sort = 'total_transaction' THEN m.TOTAL_TRANSACTION END ASC,
                              CASE WHEN @desc = 1 AND @sort = 'total_transaction' THEN m.TOTAL_TRANSACTION END DESC,
                              CASE WHEN @desc = 0 AND @sort = 'age' THEN m.AGE END ASC,
                              CASE WHEN @desc = 1 AND @sort = 'age' THEN m.AGE END DESC,
                              CASE WHEN @desc = 0 AND @sort = 'join_date' THEN m.rn END DESC,
                              CASE WHEN @desc = 1 AND @sort = 'join_date' THEN m.rn END ASC,
                              m.rn ASC
                       OFFSET @skip ROWS FETCH NEXT @take ROWS ONLY
                       FOR JSON PATH, INCLUDE_NULL_VALUES
                   ), '[]')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- badge cards ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_badge_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_badge_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_badge_getrow
(
      @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @today date = CAST(GETDATE() AS date);
        DECLARE @fd varchar(10) = dbo.fn_ams_reg_member_date103(@p_from_date, DATEFROMPARTS(YEAR(@today), MONTH(@today), 1));
        DECLARE @td varchar(10) = dbo.fn_ams_reg_member_date103(@p_to_date, @today);

        CREATE TABLE #b
        (
              member_total nvarchar(50) NULL
            , active_member_total nvarchar(50) NULL
            , inactive_member_total nvarchar(50) NULL
            , new_member_today nvarchar(50) NULL
            , prev_member_total nvarchar(50) NULL
            , prev_active_member_total nvarchar(50) NULL
            , prev_inactive_member_total nvarchar(50) NULL
            , prev_new_member_today nvarchar(50) NULL
            , prev_member_total_presentase varchar(30) NULL
            , prev_active_member_total_presentase varchar(30) NULL
            , prev_inactive_member_total_presentase varchar(30) NULL
            , prev_member_total_today_presentase varchar(30) NULL
        );
        INSERT INTO #b
        EXEC pos_server.dbo.xsp_app_member_badge_total_chart_getrow @fd, @td;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL((SELECT TOP 1 * FROM #b FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), '{}')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- members location ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_location_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_location_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_location_getrows
(
      @p_provinsi varchar(40) = NULL
    , @p_kota varchar(40) = NULL
    , @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @today date = CAST(GETDATE() AS date);
        DECLARE @fd varchar(10) = dbo.fn_ams_reg_member_date103(@p_from_date, DATEFROMPARTS(YEAR(@today), MONTH(@today), 1));
        DECLARE @td varchar(10) = dbo.fn_ams_reg_member_date103(@p_to_date, @today);
        DECLARE @prov varchar(40) = ISNULL(NULLIF(NULLIF(LTRIM(RTRIM(@p_provinsi)), ''), 'ALL'), '0');
        DECLARE @kota varchar(40) = ISNULL(NULLIF(NULLIF(LTRIM(RTRIM(@p_kota)), ''), 'ALL'), '0');

        CREATE TABLE #l
        (
              PROVINSI varchar(255) NULL
            , KOTA varchar(255) NULL
            , TOTAL_MEMBER int NULL
            , TOTAL_MEMBER_ACTIVE int NULL
            , TOTAL_MEMBER_NONACTIVE int NULL
        );
        INSERT INTO #l
        EXEC pos_server.dbo.xsp_app_dashboard_member_location_list_getrows @prov, @kota, @fd, @td;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL((
                       SELECT PROVINSI AS provinsi, KOTA AS kota, TOTAL_MEMBER AS total_member,
                              TOTAL_MEMBER_ACTIVE AS total_member_active, TOTAL_MEMBER_NONACTIVE AS total_member_nonactive
                       FROM #l
                       FOR JSON PATH, INCLUDE_NULL_VALUES
                   ), '[]')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- birthday member ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_birthday_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_birthday_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_birthday_getrows
(
      @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        CREATE TABLE #d
        (
              name varchar(max) NULL
            , Status varchar(10) NULL
            , DateofBirth nvarchar(4000) NULL
            , info int NULL
        );
        INSERT INTO #d
        EXEC pos_server.dbo.xsp_app_dashboard_member_birthday_list_getrows;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL((
                       SELECT TOP 1000 name, Status AS status, DateofBirth AS date_of_birth, info
                       FROM #d
                       ORDER BY info ASC
                       FOR JSON PATH, INCLUDE_NULL_VALUES
                   ), '[]')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- provinsi / kota dropdowns ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_provinsi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_provinsi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_provinsi_getrows
(
      @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL((
                       SELECT CAST(p.prov_id AS varchar(20)) AS value, p.prov_name AS label
                       FROM MASTER_WILAYAH.dbo.provinces AS p WITH (NOLOCK)
                       ORDER BY p.prov_name
                       FOR JSON PATH
                   ), '[]')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_member_kota_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_member_kota_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_member_kota_getrows
(
      @p_provinsi varchar(40) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @prov int = TRY_CONVERT(int, NULLIF(NULLIF(LTRIM(RTRIM(@p_provinsi)), ''), '0'));
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY(ISNULL((
                       SELECT CAST(c.city_id AS varchar(20)) AS value, c.city_name AS label, CAST(c.prov_id AS varchar(20)) AS prov_id
                       FROM MASTER_WILAYAH.dbo.cities AS c WITH (NOLOCK)
                       WHERE @prov IS NULL OR c.prov_id = @prov
                       ORDER BY c.city_name
                       FOR JSON PATH
                   ), '[]')) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
