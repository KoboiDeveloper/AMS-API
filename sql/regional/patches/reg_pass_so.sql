/*
  Password SO (REG2) — ASP parity module/Tools/PassSO.aspx + PassSO_info.aspx
  Legacy pos_server:
    xsp_get_web_password_single_getrows / getrow / insert / update / single_delete
    xsp_get_web_password_detail_getrows / detail_delete
    xsp_get_web_password_add_store_insert
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* ---- list ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_pass_so_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_pass_so_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_pass_so_getrows
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
        DECLARE @kw varchar(50) = LEFT(LTRIM(RTRIM(ISNULL(@p_keywords, ''))), 50);
        DECLARE @roll varchar(5) = '5'; /* regional */
        DECLARE @uid varchar(30) = LEFT(LTRIM(RTRIM(ISNULL(@p_actor_nik, ''))), 30);

        CREATE TABLE #r (
            ID int NULL,
            [PASSWORD] int NULL,
            TIPE_SO varchar(30) NULL,
            TGL_SO datetime NULL,
            keterangan varchar(100) NULL,
            CREATE_DATE datetime NULL
        );
        INSERT INTO #r
        EXEC pos_server.dbo.xsp_get_web_password_single_getrows
            @p_keywords = @kw,
            @p_roll_code = @roll,
            @p_userid = @uid;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           r.ID AS id,
                           r.[PASSWORD] AS password,
                           r.TIPE_SO AS tipe_so,
                           CONVERT(varchar(10), r.TGL_SO, 23) AS tgl_so,
                           ISNULL(r.keterangan, '') AS keterangan,
                           CONVERT(varchar(19), r.CREATE_DATE, 120) AS create_date
                       FROM #r r
                       WHERE (@p_status IS NULL OR @p_status = '' OR UPPER(@p_status) = 'ALL' OR UPPER(r.TIPE_SO) = UPPER(@p_status))
                         AND (
                              @p_from_date IS NULL OR LTRIM(RTRIM(@p_from_date)) = ''
                              OR r.TGL_SO >= TRY_CAST(@p_from_date AS date)
                         )
                         AND (
                              @p_to_date IS NULL OR LTRIM(RTRIM(@p_to_date)) = ''
                              OR r.TGL_SO < DATEADD(day, 1, TRY_CAST(@p_to_date AS date))
                         )
                       ORDER BY r.TGL_SO DESC, r.ID DESC
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

/* ---- getrow ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_pass_so_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_pass_so_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_pass_so_getrow
( @p_id varchar(80), @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id int = TRY_CAST(@p_id AS int);
        IF @id IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'id tidak valid.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #g (
            ID int NULL,
            [PASSWORD] int NULL,
            TIPE_SO varchar(30) NULL,
            TGL_SO nvarchar(20) NULL,
            KETERANGAN varchar(100) NULL,
            CLASS varchar(30) NULL
        );
        INSERT INTO #g
        EXEC pos_server.dbo.xsp_get_web_password_single_getrow @p_id = @id;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           g.ID AS id,
                           g.[PASSWORD] AS password,
                           g.TIPE_SO AS tipe_so,
                           REPLACE(ISNULL(g.TGL_SO, ''), '/', '-') AS tgl_so,
                           ISNULL(g.KETERANGAN, '') AS keterangan,
                           ISNULL(g.CLASS, '') AS class
                       FROM #g g
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---- insert ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_pass_so_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_pass_so_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_pass_so_insert
( @p_payload varchar(max), @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @tipe varchar(30) = UPPER(LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.tipe_so'), ''))));
        DECLARE @tglS varchar(30) = LTRIM(RTRIM(ISNULL(COALESCE(JSON_VALUE(@p_payload, '$.tgl_so'), JSON_VALUE(@p_payload, '$.tgl')), '')));
        DECLARE @ket varchar(50) = LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.keterangan'), '')));
        DECLARE @class varchar(30) = LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.class'), '')));
        DECLARE @uid varchar(30) = LEFT(LTRIM(RTRIM(ISNULL(COALESCE(@p_actor_nik, @p_created_by), ''))), 30);
        DECLARE @tgl datetime = TRY_CAST(REPLACE(@tglS, '/', '-') AS datetime);

        IF @tipe NOT IN ('NASIONAL', 'PARSIAL') OR @tgl IS NULL OR @ket = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'tipe_so, tgl_so, keterangan wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        IF @tipe <> 'PARSIAL' SET @class = '';

        DECLARE @newId int;
        EXEC pos_server.dbo.xsp_get_web_password_single_insert
            @p_id = @newId OUTPUT,
            @p_tipe_so = @tipe,
            @p_tgl_so = @tgl,
            @p_keterangan = @ket,
            @p_class = @class,
            @p_userid = @uid;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((SELECT @newId AS id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---- update ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_pass_so_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_pass_so_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_pass_so_update
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id int = TRY_CAST(@p_id AS int);
        DECLARE @tipe varchar(30) = UPPER(LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.tipe_so'), ''))));
        DECLARE @tglS varchar(30) = LTRIM(RTRIM(ISNULL(COALESCE(JSON_VALUE(@p_payload, '$.tgl_so'), JSON_VALUE(@p_payload, '$.tgl')), '')));
        DECLARE @ket varchar(50) = LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.keterangan'), '')));
        DECLARE @class varchar(30) = LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.class'), '')));
        DECLARE @tgl datetime = TRY_CAST(REPLACE(@tglS, '/', '-') AS datetime);

        IF @id IS NULL OR @tipe NOT IN ('NASIONAL', 'PARSIAL') OR @tgl IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'id / tipe_so / tgl_so wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        IF @tipe <> 'PARSIAL' SET @class = '';

        EXEC pos_server.dbo.xsp_get_web_password_single_update
            @p_id = @id,
            @p_tipe_so = @tipe,
            @p_tgl_so = @tgl,
            @p_keterangan = @ket,
            @p_class = @class;

        SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---- delete header ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_pass_so_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_pass_so_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_pass_so_delete
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id int = TRY_CAST(@p_id AS int);
        IF @id IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'id tidak valid.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        EXEC pos_server.dbo.xsp_get_web_password_single_delete @p_id = @id;
        SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---- stores list (detail) ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_pass_so_stores_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_pass_so_stores_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_pass_so_stores_getrows
( @p_id varchar(80), @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id int = TRY_CAST(@p_id AS int);
        IF @id IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'id tidak valid.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        CREATE TABLE #d (
            ID int NULL,
            BRAND varchar(50) NULL,
            STORE_ID varchar(50) NULL,
            [PASSWORD] int NULL,
            TIPE_SO varchar(30) NULL,
            TGL_SO datetime NULL,
            CREATE_DATE datetime NULL,
            STATUS_PAKAI varchar(40) NULL
        );
        INSERT INTO #d
        EXEC pos_server.dbo.xsp_get_web_password_detail_getrows
            @p_keywords = '',
            @p_id = @id;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           d.ID AS id,
                           d.BRAND AS brand,
                           d.STORE_ID AS store_id,
                           ISNULL(NULLIF(LTRIM(RTRIM(s.STORE_KOTA)), ''), ISNULL(s.Store_Name, d.STORE_ID)) AS store_kota,
                           ISNULL(s.Store_Name, d.STORE_ID) AS store_name,
                           CASE
                               WHEN ISNULL(NULLIF(LTRIM(RTRIM(s.STORE_KOTA)), ''), '') <> ''
                                   THEN d.STORE_ID + ' - ' + LTRIM(RTRIM(s.STORE_KOTA))
                               WHEN ISNULL(s.Store_Name, '') <> '' AND s.Store_Name <> d.STORE_ID
                                   THEN d.STORE_ID + ' - ' + s.Store_Name
                               ELSE d.STORE_ID
                           END AS store_desc,
                           d.[PASSWORD] AS password,
                           d.TIPE_SO AS tipe_so,
                           CONVERT(varchar(10), d.TGL_SO, 23) AS tgl_so,
                           d.STATUS_PAKAI AS status_pakai
                       FROM #d d
                       LEFT JOIN pos_server.dbo.DT_Store s WITH (NOLOCK)
                           ON s.Store_ID = d.STORE_ID
                       ORDER BY d.STORE_ID
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

/* ---- add store ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_pass_so_store_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_pass_so_store_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_pass_so_store_insert
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id int = TRY_CAST(@p_id AS int);
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.store_id'),
            JSON_VALUE(@p_payload, '$.id_store'),
            JSON_VALUE(@p_payload, '$.store')
        ), '')));
        IF @id IS NULL OR @store = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'id dan store_id wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        EXEC pos_server.dbo.xsp_get_web_password_add_store_insert
            @p_id = @id,
            @p_store_id = @store;
        SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---- delete store detail ---- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_pass_so_store_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_pass_so_store_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_pass_so_store_delete
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id int = TRY_CAST(@p_id AS int);
        IF @id IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'id tidak valid.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        EXEC pos_server.dbo.xsp_get_web_password_detail_delete @p_id = @id;
        SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO
