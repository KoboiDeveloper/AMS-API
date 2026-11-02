/*
  Group Head (REG Tools) — MasterGH.aspx + masterlookup.aspx parity
  Wrappers around pos_server.dbo.xsp_master_gh_* / status_gh / master_sc / detail.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* ---------- list ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_getrows
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
        DECLARE @kw varchar(200) = ISNULL(LTRIM(RTRIM(@p_keywords)), '');
        DECLARE @st varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_status,''), NULLIF(@p_is_active,'')), 'ALL'))));
        DECLARE @kat varchar(50) = LOWER(LTRIM(RTRIM(ISNULL(@p_kategori, ''))));
        IF @kat IN ('all','') SET @kat = NULL;

        DECLARE @wantActive bit = NULL;
        IF @st IN ('1','ACTIVE','AKTIF','YA','YES','TRUE') SET @wantActive = 1;
        ELSE IF @st IN ('0','INACTIVE','TIDAK AKTIF','NONAKTIF','NO','FALSE','TIDAK') SET @wantActive = 0;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                              g.ID AS id,
                              g.ID_GH AS id_gh,
                              g.NAMA AS nama,
                              g.NAMA AS full_name,
                              CAST(g.STATUS AS int) AS is_active,
                              CASE WHEN CAST(g.STATUS AS int) = 1 THEN 'AKTIF' ELSE 'TIDAK AKTIF' END AS status,
                              LOWER(ISNULL(g.KATEGORI, 'gh')) AS kategori,
                              CASE LOWER(ISNULL(g.KATEGORI, 'gh'))
                                  WHEN 'ac' THEN 'AREA COORDINATOR'
                                  WHEN 'sc' THEN 'STORE COORDINATOR'
                                  ELSE 'GROUP HEAD'
                              END AS kategori_label,
                              g.EMAIL AS email,
                              g.AC_ID AS ac_id
                       FROM pos_server.dbo.MASTER_GH AS g WITH (NOLOCK)
                       WHERE (g.NAMA LIKE '%' + @kw + '%' OR g.ID_GH LIKE '%' + @kw + '%' OR ISNULL(g.EMAIL,'') LIKE '%' + @kw + '%')
                         AND (@wantActive IS NULL OR CAST(g.STATUS AS int) = @wantActive)
                         AND (@kat IS NULL OR LOWER(ISNULL(g.KATEGORI,'')) = @kat)
                       ORDER BY g.NAMA
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

/* ---------- getrow ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_getrow
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

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                              a.ID AS id,
                              a.ID_GH AS id_gh,
                              a.NAMA AS full_name,
                              a.NAMA AS nama,
                              b.NAMA_NICK AS nama_nick,
                              b.EMAIL AS email,
                              CAST(a.STATUS AS int) AS is_active,
                              CASE WHEN CAST(a.STATUS AS int) = 1 THEN 'AKTIF' ELSE 'TIDAK AKTIF' END AS status,
                              CASE WHEN CAST(a.STATUS AS int) = 1 THEN 'NONAKTIFKAN' ELSE 'AKTIFKAN' END AS confirm_status,
                              LOWER(ISNULL(a.KATEGORI, 'gh')) AS kategori,
                              a.AC_ID AS ac_id
                       FROM pos_server.dbo.MASTER_GH AS a WITH (NOLOCK)
                       LEFT JOIN pos_server.dbo.WEB_USER_MAIN AS b WITH (NOLOCK)
                           ON b.ID_USER = a.ID_GH COLLATE SQL_Latin1_General_CP1_CI_AS
                       WHERE a.ID = @id
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

/* ---------- insert ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_insert
( @p_payload varchar(max), @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id_gh varchar(20) = LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.id_gh'),
            JSON_VALUE(@p_payload, '$.ID_GH'),
            JSON_VALUE(@p_payload, '$.code')
        ), '')));
        DECLARE @full_name varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.full_name'),
            JSON_VALUE(@p_payload, '$.nama'),
            JSON_VALUE(@p_payload, '$.NAMA')
        ), '')));
        DECLARE @kategori varchar(50) = LOWER(LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.kategori'),
            JSON_VALUE(@p_payload, '$.KATEGORI')
        ), 'gh'))));
        IF @kategori NOT IN ('gh','ac','sc') SET @kategori = 'gh';

        IF @id_gh = '' OR @full_name = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'CODE dan FULL NAME wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @new_id int;
        EXEC pos_server.dbo.xsp_master_gh_insert
            @p_id = @new_id OUTPUT,
            @p_id_gh = @id_gh,
            @p_full_name = @full_name,
            @p_kategori = @kategori;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT @new_id AS id, @id_gh AS id_gh, @full_name AS full_name, @kategori AS kategori
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

/* ---------- update (nama/kategori OR status toggle) ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_update
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

        DECLARE @action varchar(40) = LOWER(LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.confirm_status'),
            JSON_VALUE(@p_payload, '$.action'),
            JSON_VALUE(@p_payload, '$.ngapain')
        ), ''))));
        DECLARE @status_raw varchar(10) = LTRIM(RTRIM(ISNULL(JSON_VALUE(@p_payload, '$.status'), '')));

        IF @action IN ('aktif','aktifkan','activate','1','active') OR @status_raw = '1'
        BEGIN
            EXEC pos_server.dbo.xsp_status_gh_update @p_status = '1', @p_id = @id;
            SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                                   JSON_QUERY((SELECT @id AS id, 1 AS is_active FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS data
                             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        IF @action IN ('nonaktif','nonaktifkan','deactivate','0','inactive','tidak aktif') OR @status_raw = '0'
        BEGIN
            EXEC pos_server.dbo.xsp_status_gh_update @p_status = '0', @p_id = @id;
            SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                                   JSON_QUERY((SELECT @id AS id, 0 AS is_active FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS data
                             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @full_name varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.full_name'),
            JSON_VALUE(@p_payload, '$.nama')
        ), '')));
        DECLARE @kategori varchar(50) = LOWER(LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.kategori'),
            JSON_VALUE(@p_payload, '$.KATEGORI')
        ), ''))));
        IF @kategori NOT IN ('gh','ac','sc') SET @kategori = NULL;

        IF @full_name = ''
            SELECT @full_name = NAMA FROM pos_server.dbo.MASTER_GH WITH (NOLOCK) WHERE ID = @id;
        IF @kategori IS NULL
            SELECT @kategori = LOWER(ISNULL(KATEGORI, 'gh')) FROM pos_server.dbo.MASTER_GH WITH (NOLOCK) WHERE ID = @id;

        EXEC pos_server.dbo.xsp_master_gh_update
            @p_id = @id,
            @p_full_name = @full_name,
            @p_kategori = @kategori;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((SELECT @id AS id, @full_name AS full_name, @kategori AS kategori FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- delete (inactive only; legacy SP missing) ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_delete
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

        DECLARE @st int = NULL;
        DECLARE @id_gh varchar(50) = NULL;
        SELECT @st = CAST(STATUS AS int), @id_gh = ID_GH
        FROM pos_server.dbo.MASTER_GH WITH (NOLOCK)
        WHERE ID = @id;

        IF @st IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'data tidak ditemukan.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        IF @st <> 0
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'Hanya data TIDAK AKTIF yang bisa dihapus.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DELETE FROM pos_server.dbo.MASTER_GH_DETAIL
        WHERE TRY_CAST(GH_ID AS int) = @id
           OR ID_GROUP_HEAD = @id_gh;

        DELETE FROM pos_server.dbo.MASTER_GH WHERE ID = @id AND STATUS = 0;

        SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- store list (MASTER_GH_DETAIL) ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_stores_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_stores_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_stores_getrows
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

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                              d.ID AS id,
                              d.ID_GROUP_HEAD AS id_group_head,
                              d.BRAND AS brand,
                              d.STORE AS store_id,
                              d.STORE AS store,
                              d.GH_ID AS gh_id,
                              CASE
                                  WHEN ISNULL(NULLIF(LTRIM(RTRIM(s.STORE_KOTA)), ''), '') <> ''
                                      THEN (d.STORE COLLATE Latin1_General_CI_AS) + ' - ' + (LTRIM(RTRIM(s.STORE_KOTA)) COLLATE Latin1_General_CI_AS)
                                  ELSE (d.STORE COLLATE Latin1_General_CI_AS)
                              END AS store_desc
                       FROM pos_server.dbo.MASTER_GH_DETAIL AS d WITH (NOLOCK)
                       LEFT JOIN pos_server.dbo.DT_Store AS s WITH (NOLOCK)
                           ON s.Store_ID COLLATE Latin1_General_CI_AS = d.STORE COLLATE Latin1_General_CI_AS
                       WHERE TRY_CAST(d.GH_ID AS int) = @id
                       ORDER BY d.BRAND, d.STORE
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

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_store_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_store_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_store_insert
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id int = TRY_CAST(@p_id AS int);
        DECLARE @brand varchar(30) = LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.brand'),
            JSON_VALUE(@p_payload, '$.id_brand'),
            JSON_VALUE(@p_payload, '$.brand_id')
        ), '')));
        DECLARE @store varchar(30) = LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.store_id'),
            JSON_VALUE(@p_payload, '$.store'),
            JSON_VALUE(@p_payload, '$.id_store')
        ), '')));
        IF @id IS NULL OR @brand = '' OR @store = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'id, brand, store wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @code varchar(100) = NULL;
        SELECT @code = ID_GH FROM pos_server.dbo.MASTER_GH WITH (NOLOCK) WHERE ID = @id;
        IF @code IS NULL SET @code = '';

        IF EXISTS (
            SELECT 1 FROM pos_server.dbo.MASTER_GH_DETAIL WITH (NOLOCK)
            WHERE TRY_CAST(GH_ID AS int) = @id AND STORE = @store
        )
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'Store sudah ada.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        EXEC pos_server.dbo.xsp_master_gh_detail_insert
            @p_brand = @brand,
            @p_store = @store,
            @p_id = @id,
            @p_code = @code;

        SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_store_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_store_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_store_delete
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
        EXEC pos_server.dbo.xsp_master_gh_detail_delete @p_id = @id;
        SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- store coordinators under AC ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_sc_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_sc_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_sc_getrows
( @p_id varchar(80), @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id_ac varchar(50) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        /* allow numeric MASTER_GH.ID → resolve to ID_GH */
        IF TRY_CAST(@id_ac AS int) IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM pos_server.dbo.MASTER_GH WITH (NOLOCK) WHERE ID_GH = @id_ac
        )
            SELECT @id_ac = ID_GH FROM pos_server.dbo.MASTER_GH WITH (NOLOCK) WHERE ID = TRY_CAST(@id_ac AS int);

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                              g.ID AS id,
                              g.ID_GH AS id_gh,
                              g.NAMA AS nama,
                              CAST(g.STATUS AS int) AS is_active,
                              CASE WHEN CAST(g.STATUS AS int) = 1 THEN 'AKTIF' ELSE 'TIDAK AKTIF' END AS status
                       FROM pos_server.dbo.MASTER_GH AS g WITH (NOLOCK)
                       WHERE LOWER(ISNULL(g.KATEGORI,'')) = 'sc'
                         AND g.AC_ID = @id_ac
                       ORDER BY g.NAMA
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

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_sc_insert', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_sc_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_sc_insert
( @p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @id_gh varchar(20) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        IF TRY_CAST(@id_gh AS int) IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM pos_server.dbo.MASTER_GH WITH (NOLOCK) WHERE ID_GH = @id_gh
        )
            SELECT @id_gh = ID_GH FROM pos_server.dbo.MASTER_GH WITH (NOLOCK) WHERE ID = TRY_CAST(@id_gh AS int);

        DECLARE @id_sc varchar(20) = LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.id_sc'),
            JSON_VALUE(@p_payload, '$.id_gh'),
            JSON_VALUE(@p_payload, '$.store_coordinator')
        ), '')));

        IF @id_gh = '' OR @id_sc = '' OR UPPER(@id_sc) IN ('PILIH','PILIH SC')
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'Pilih Store Coordinator.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        EXEC pos_server.dbo.xsp_master_sc_update @p_id_sc = @id_sc, @p_id_gh = @id_gh;
        SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_sc_delete', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_sc_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_sc_delete
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
        EXEC pos_server.dbo.xsp_master_sc_delete @p_id = @id;
        SET @bitparam = (SELECT '2002500' AS responseCode, 'success' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO

/* ---------- GH user picker (GTGHD / xsp_get_gh_id_getrows) ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_users_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_users_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_users_getrows
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
        DECLARE @kw varchar(50) = ISNULL(LTRIM(RTRIM(@p_keywords)), '');
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT TOP (200)
                              u.ID_USER AS id,
                              u.ID_USER AS id_user,
                              u.ID_USER AS id_gh,
                              u.ID_USER AS value,
                              ISNULL(NULLIF(LTRIM(RTRIM(u.FULL_NAME)), ''), u.NAMA_NICK) AS label,
                              u.NAMA_NICK AS nama_nick,
                              u.FULL_NAME AS full_name,
                              u.EMAIL AS email
                       FROM pos_server.dbo.WEB_USER_MAIN AS u WITH (NOLOCK)
                       WHERE u.ROLL_CODE = 4
                         AND (
                                @kw = ''
                             OR u.ID_USER LIKE '%' + @kw + '%'
                             OR u.NAMA_NICK LIKE '%' + @kw + '%'
                             OR u.FULL_NAME LIKE '%' + @kw + '%'
                             OR u.EMAIL LIKE '%' + @kw + '%'
                         )
                       ORDER BY u.ID_USER
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

/* ---------- SC filter options (active SC for dropdown) ---------- */
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_group_head_sc_options_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_group_head_sc_options_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_group_head_sc_options_getrows
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
        DECLARE @kw varchar(200) = ISNULL(LTRIM(RTRIM(@p_keywords)), '');
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                              g.ID_GH AS value,
                              g.NAMA AS label,
                              g.ID AS id,
                              g.ID_GH AS id_gh,
                              g.NAMA AS nama
                       FROM pos_server.dbo.MASTER_GH AS g WITH (NOLOCK)
                       WHERE LOWER(ISNULL(g.KATEGORI,'')) = 'sc'
                         AND CAST(g.STATUS AS int) = 1
                         AND (@kw = '' OR g.NAMA LIKE '%' + @kw + '%' OR g.ID_GH LIKE '%' + @kw + '%')
                       ORDER BY g.NAMA
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
