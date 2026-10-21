/*
  Add lookup type manpower / man_power (Seles_byM.aspx ddlManPower).
  Legacy: Shared.BindManPowerSalesGH → XSP_SALES_BY_MAN_POWER_GETROWS (@p_store_id)
  parent_id = Store_ID
  value = User_NIK, label = USER_NAME - User_NIK
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_lookup_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_lookup_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_lookup_getrows
(
      @p_type varchar(50)
    , @p_keywords varchar(200) = NULL
    , @p_parent_id varchar(80) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @t varchar(50) = LOWER(LTRIM(RTRIM(ISNULL(@p_type,''))));
        DECLARE @kw varchar(200) = NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'');
        DECLARE @parent varchar(80) = NULLIF(LTRIM(RTRIM(ISNULL(@p_parent_id,''))),'');
        DECLARE @gh varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_actor_nik,''))),'');

        /* Legacy Shared.BindidbrandAll2 → xsp_brand_filter_all_getrows */
        IF @t IN ('brand_all','brand-all','brands_all') AND OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT DISTINCT a.Store_Brand_ID AS value, a.Store_Brand_ID AS label
                           FROM pos_server.dbo.DT_Store AS a WITH (NOLOCK)
                           WHERE a.Store_Brand_ID IS NOT NULL
                             AND a.Store_Brand_ID NOT IN (
                                 'AEESHA','ART VISUAL','CELCIUS KIDS','DC','DC OLD','GA',
                                 'MINISTORE','POS TES','KW2','WOL','TEST'
                             )
                             AND (@kw IS NULL OR a.Store_Brand_ID LIKE '%'+@kw+'%')
                           ORDER BY 1
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* Legacy Shared.BindRegbrand → xsp_brand_filter_REG_getrows(@p_gh_id) */
        IF @t IN ('brand','brands') AND OBJECT_ID(N'pos_server.dbo.xsp_brand_filter_REG_getrows', N'P') IS NOT NULL
        BEGIN
            CREATE TABLE #brand (brand varchar(100));
            INSERT INTO #brand (brand)
            EXEC pos_server.dbo.xsp_brand_filter_REG_getrows @p_gh_id = @gh;

            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT DISTINCT b.brand AS value, b.brand AS label
                           FROM #brand AS b
                           WHERE b.brand IS NOT NULL
                             AND (@kw IS NULL OR b.brand LIKE '%'+@kw+'%')
                           ORDER BY 1
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            DROP TABLE #brand;
            RETURN;
        END;

        /* Legacy Shared.BindRegStore → xsp_brand_reg_filter_getrows(@p_gh_id) */
        IF @t IN ('store','stores') AND OBJECT_ID(N'pos_server.dbo.xsp_brand_reg_filter_getrows', N'P') IS NOT NULL
        BEGIN
            CREATE TABLE #store (Store_desc varchar(200), Store varchar(50));
            INSERT INTO #store (Store_desc, Store)
            EXEC pos_server.dbo.xsp_brand_reg_filter_getrows @p_gh_id = @gh;

            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (800)
                                  s.Store AS value,
                                  ISNULL(s.Store_desc, s.Store) AS label
                           FROM #store AS s
                           WHERE s.Store IS NOT NULL
                             AND (@kw IS NULL OR s.Store LIKE '%'+@kw+'%' OR s.Store_desc LIKE '%'+@kw+'%')
                             AND (
                                   @parent IS NULL
                                OR EXISTS (
                                       SELECT 1 FROM pos_server.dbo.DT_Store ds WITH (NOLOCK)
                                       WHERE ds.Store_ID = s.Store
                                         AND (
                                              ds.Store_Brand_ID = @parent
                                           OR (@parent = 'CELCIUS' AND ds.Store_Brand_ID IN ('CELCIUS','CELCIUS KIDS'))
                                         )
                                   )
                             )
                           ORDER BY s.Store
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            DROP TABLE #store;
            RETURN;
        END;

        IF @t IN ('cabang','branch') AND OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT DISTINCT ISNULL(s.STORE_PULAU, s.STORE_KOTA) AS value,
                                  ISNULL(s.STORE_PULAU, s.STORE_KOTA) AS label
                           FROM pos_server.dbo.DT_Store AS s WITH (NOLOCK)
                           WHERE s.Status_Active = 1
                             AND ISNULL(s.STORE_PULAU, s.STORE_KOTA) IS NOT NULL
                           ORDER BY 1
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* Legacy Shared.BindManPowerSalesGH → XSP_SALES_BY_MAN_POWER_GETROWS (@p_store_id) */
        IF @t IN ('manpower','man_power','sales_manpower','manpower_sales')
           AND OBJECT_ID(N'pos_server.dbo.DT_User', N'U') IS NOT NULL
        BEGIN
            IF @parent IS NULL OR UPPER(@parent) IN ('ALL','0','PILIH','')
            BEGIN
                SET @bitparam = (
                    SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                           JSON_QUERY((SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0 FOR JSON PATH)) AS data
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                );
                RETURN;
            END;

            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT DISTINCT
                                  UPPER(u.User_NIK) AS value,
                                  UPPER(u.USER_NAME) + ' - ' + UPPER(u.User_NIK) AS label
                           FROM pos_server.dbo.DT_User AS u WITH (NOLOCK)
                           WHERE u.STORE_ID = @parent
                             AND u.Status_Active = 1
                             AND u.User_NIK IS NOT NULL
                             AND (
                                   @kw IS NULL
                                OR u.User_NIK LIKE '%' + @kw + '%'
                                OR u.USER_NAME LIKE '%' + @kw + '%'
                             )
                           ORDER BY 2
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0 FOR JSON PATH)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
