/*
  Store List (REG Tools) — STORE_ACTIVE.aspx parity
  - list: brand + status + keywords
  - update status via xsp_update_status_store (AKTIFKAN / NONAKTIFKAN)
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_store_list_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_store_list_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_store_list_getrows
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
        DECLARE @kw varchar(200) = NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'');
        DECLARE @brand varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(NULLIF(@p_id_brand,''), NULLIF(@p_brand,''), NULLIF(@p_brand_filter,'')))), '');
        IF UPPER(ISNULL(@brand,'')) IN ('ALL','') SET @brand = NULL;

        DECLARE @st varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_status,''), NULLIF(@p_is_active,'')), 'ALL'))));
        /* ACTIVE / 1 / AKTIF → aktif; INACTIVE / 0 / TIDAK → nonaktif */
        DECLARE @wantActive bit = NULL;
        IF @st IN ('1','ACTIVE','AKTIF','YA','YES','TRUE') SET @wantActive = 1;
        ELSE IF @st IN ('0','INACTIVE','TIDAK AKTIF','NONAKTIF','NO','FALSE','TIDAK') SET @wantActive = 0;

        IF OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NULL
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
                       SELECT TOP (2000)
                              s.Store_ID AS id,
                              s.Store_ID AS store_id,
                              s.Store_Brand_ID AS brand_id,
                              s.STORE_KOTA AS kota,
                              s.STORE_PULAU AS pulau,
                              CAST(s.Status_Active AS int) AS is_active,
                              CASE WHEN CAST(s.Status_Active AS int) = 1 THEN 'AKTIF' ELSE 'TIDAK AKTIF' END AS status,
                              CASE WHEN CAST(s.Status_Active AS int) = 1 THEN 'NONAKTIFKAN' ELSE 'AKTIFKAN' END AS confirm_status,
                              s.Store_ID + CASE
                                  WHEN ISNULL(NULLIF(LTRIM(RTRIM(s.STORE_KOTA)), ''), '') <> ''
                                      THEN ' - ' + LTRIM(RTRIM(s.STORE_KOTA))
                                  ELSE ''
                              END AS store_desc
                       FROM pos_server.dbo.DT_Store AS s WITH (NOLOCK)
                       WHERE s.Store_ID NOT IN (
                                '000-rc','000-rif','000-rm','DEMO888','888','888-RC','888-RIF','888-RM',
                                '777','7777','BZR01','999-RC','999-RIF','999-RM','DC000','DC111','DC222',
                                'DC888','DC999','DEMO888'
                             )
                         AND (
                                @brand IS NULL
                             OR s.Store_Brand_ID = @brand
                             OR (@brand = 'CELCIUS' AND s.Store_Brand_ID IN ('CELCIUS','CELCIUS KIDS'))
                         )
                         AND (@wantActive IS NULL OR CAST(s.Status_Active AS int) = @wantActive)
                         AND (
                                @kw IS NULL
                             OR s.Store_ID LIKE '%'+@kw+'%'
                             OR s.STORE_KOTA LIKE '%'+@kw+'%'
                             OR s.Store_Brand_ID LIKE '%'+@kw+'%'
                         )
                       ORDER BY s.Store_Brand_ID, s.Store_ID
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

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_store_list_update', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_store_list_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_store_list_update
(
      @p_id varchar(80)
    , @p_payload varchar(max) = NULL
    , @p_updated_by varchar(50) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        DECLARE @action varchar(40) = LOWER(LTRIM(RTRIM(ISNULL(COALESCE(
            JSON_VALUE(@p_payload, '$.confirm_status'),
            JSON_VALUE(@p_payload, '$.action'),
            JSON_VALUE(@p_payload, '$.ngapain'),
            JSON_VALUE(@p_payload, '$.status')
        ), ''))));

        IF @store = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'store_id wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        IF @action IN ('aktif','aktifkan','activate','1','active')
            SET @action = 'aktifkan';
        ELSE IF @action IN ('nonaktif','nonaktifkan','deactivate','0','inactive','tidak aktif')
            SET @action = 'nonaktifkan';
        ELSE
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'action status tidak valid.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        EXEC pos_server.dbo.xsp_update_status_store
            @p_store_id = @store,
            @p_ngapain = @action;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT @store AS id, @store AS store_id, @action AS action
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
