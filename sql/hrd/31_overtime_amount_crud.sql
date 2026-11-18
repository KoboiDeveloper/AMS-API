/* Overtime Amount — ASP Absen_Online/overtime_amount.aspx → hris.dbo.WEB_OVERTIME_AMOUNT */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* Lookups khusus OT: LEVEL = PangkatStr (+ NON STAFF), JABATAN = KodeJabatanStr (+ ALL) */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_lookup_getrows', N'P') IS NOT NULL
BEGIN
  DECLARE @def nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.xsp_ams_new_hrd_lookup_getrows'));
  IF @def IS NOT NULL AND @def NOT LIKE N'%overtime_level%'
  BEGIN
    /* inject sebelum ELSE Unknown lookup */
    SET @def = REPLACE(@def,
N'ELSE IF @t IN (''ya_tidak'',''yes_no'')
      SET @rows=(SELECT * FROM (SELECT ''1'' AS value, ''Ya'' AS label UNION ALL SELECT ''0'',''Tidak'') x FOR JSON PATH);
    ELSE
    BEGIN
      SET @bitparam=(SELECT ''4002500'' responseCode, N''Unknown lookup type: ''+ISNULL(@p_type,'''') responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
      RETURN;
    END',
N'ELSE IF @t IN (''ya_tidak'',''yes_no'')
      SET @rows=(SELECT * FROM (SELECT ''1'' AS value, ''Ya'' AS label UNION ALL SELECT ''0'',''Tidak'') x FOR JSON PATH);
    ELSE IF @t IN (''overtime_level'',''ot_level'')
      SET @rows=(
        SELECT value, label FROM (
          SELECT CAST(N''NON STAFF'' AS varchar(50)) AS value, CAST(N''NON STAFF'' AS varchar(200)) AS label, 0 AS ord
          UNION ALL
          SELECT CAST(PangkatStr AS varchar(50)), CAST(PangkatStr AS varchar(200)), 1
          FROM hris.dbo.tblpangkat WITH (NOLOCK)
          WHERE (@kw='''' OR PangkatStr LIKE ''%''+@kw+''%'')
            AND ISNULL(PangkatStr,'''') <> ''''
            AND UPPER(PangkatStr) <> N''NON STAFF''
        ) x
        ORDER BY ord, label
        FOR JSON PATH
      );
    ELSE IF @t IN (''overtime_jabatan'',''ot_jabatan'')
      SET @rows=(
        SELECT value, label FROM (
          SELECT CAST(N''ALL'' AS varchar(50)) AS value, CAST(N''ALL'' AS varchar(200)) AS label, 0 AS ord
          UNION ALL
          SELECT CAST(KodeJabatanStr AS varchar(50)), CAST(JabatanStr AS varchar(200)), 1
          FROM hris.dbo.tbljabatan WITH (NOLOCK)
          WHERE (@kw='''' OR JabatanStr LIKE ''%''+@kw+''%'' OR KodeJabatanStr LIKE ''%''+@kw+''%'')
            AND ISNULL(KodeJabatanStr,'''') <> ''''
        ) x
        ORDER BY ord, label
        FOR JSON PATH
      );
    ELSE
    BEGIN
      SET @bitparam=(SELECT ''4002500'' responseCode, N''Unknown lookup type: ''+ISNULL(@p_type,'''') responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
      RETURN;
    END');
    SET @def = REPLACE(@def, N'CREATE PROCEDURE', N'ALTER PROCEDURE');
    SET @def = REPLACE(@def, N'CREATE PROC', N'ALTER PROC');
    EXEC sys.sp_executesql @def;
  END
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_getrows
(   @p_keywords varchar(200)=NULL, @p_from_date varchar(30)=NULL, @p_to_date varchar(30)=NULL, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL, @p_id_store varchar(50)=NULL, @p_brand varchar(50)=NULL, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL, @p_kategori varchar(50)=NULL, @p_group varchar(50)=NULL, @p_dept varchar(50)=NULL, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL, @p_id_cabang varchar(50)=NULL, @p_year varchar(10)=NULL, @p_month varchar(10)=NULL, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL, @p_is_pajak varchar(10)=NULL, @p_id_mesin varchar(50)=NULL, @p_currentmonth varchar(20)=NULL, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @kw varchar(200)=LTRIM(RTRIM(ISNULL(@p_keywords,'')));
  DECLARE @rows nvarchar(max);
  SELECT @rows=(
    SELECT
        CAST(a.ID AS varchar(50)) AS id
      , a.[LEVEL] AS level
      , CASE WHEN a.JABATAN = N'ALL' THEN N'ALL' ELSE ISNULL(b.JabatanStr, a.JABATAN) END AS jabatan
      , a.JABATAN AS jabatan_kode
      , CAST(a.KONSUMSI_AMOUNT AS decimal(18,2)) AS konsumsi_amount
      , FORMAT(a.KONSUMSI_AMOUNT, N'N0', N'id-ID') AS konsumsi
      , CAST(a.INSENTIF_AMOUNT AS decimal(18,2)) AS insentif_amount
      , FORMAT(a.INSENTIF_AMOUNT, N'N0', N'id-ID') AS insentif
      , CAST(a.INSENTIF_WEEKEND_AMOUNT AS decimal(18,2)) AS insentif_weekend_amount
      , FORMAT(a.INSENTIF_WEEKEND_AMOUNT, N'N0', N'id-ID') AS weekend
      , a.TIPE_INSENTIF AS tipe_insentif
      , CASE
          WHEN LOWER(ISNULL(a.LEBIH_5_JAM,'false')) IN ('1','true','y','ya') THEN N'YA'
          ELSE N'TIDAK'
        END AS lebih_5_jam
    FROM hris.dbo.WEB_OVERTIME_AMOUNT a WITH (NOLOCK)
    LEFT JOIN hris.dbo.tbljabatan b WITH (NOLOCK) ON b.KodeJabatanStr = a.JABATAN
    WHERE (
      @kw=''
      OR a.[LEVEL] LIKE '%'+@kw+'%'
      OR a.JABATAN LIKE '%'+@kw+'%'
      OR ISNULL(b.JabatanStr,'') LIKE '%'+@kw+'%'
      OR a.TIPE_INSENTIF LIKE '%'+@kw+'%'
    )
    ORDER BY a.[LEVEL], ISNULL(b.JabatanStr, a.JABATAN), a.ID
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_getrow
( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @row nvarchar(max);
  SELECT TOP 1 @row=(
    SELECT
        CAST(a.ID AS varchar(50)) AS id
      , a.[LEVEL] AS level
      , a.JABATAN AS jabatan
      , CAST(a.KONSUMSI_AMOUNT AS decimal(18,2)) AS konsumsi_amount
      , CAST(a.INSENTIF_AMOUNT AS decimal(18,2)) AS insentif_amount
      , CAST(a.INSENTIF_WEEKEND_AMOUNT AS decimal(18,2)) AS insentif_weekend_amount
      , a.TIPE_INSENTIF AS tipe_insentif
      , CASE WHEN LOWER(ISNULL(a.LEBIH_5_JAM,'false')) IN ('1','true','y','ya') THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS lebih_5_jam
    FROM hris.dbo.WEB_OVERTIME_AMOUNT a WITH (NOLOCK)
    WHERE a.ID=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
  IF @row IS NULL THROW 50001, 'Overtime amount tidak ditemukan', 1;
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(@row) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_insert
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @level nvarchar(50)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.level'))),'');
  DECLARE @jabatan nvarchar(50)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.jabatan'))),'');
  IF @level IS NULL THROW 50001, 'LEVEL wajib', 1;
  IF @jabatan IS NULL SET @jabatan=N'ALL';

  DECLARE @konsumsi decimal(18,2)=TRY_CAST(REPLACE(ISNULL(JSON_VALUE(@j,'$.konsumsi_amount'),'0'),',','') AS decimal(18,2));
  DECLARE @insentif decimal(18,2)=TRY_CAST(REPLACE(ISNULL(JSON_VALUE(@j,'$.insentif_amount'),'0'),',','') AS decimal(18,2));
  DECLARE @weekend decimal(18,2)=TRY_CAST(REPLACE(ISNULL(JSON_VALUE(@j,'$.insentif_weekend_amount'),'0'),',','') AS decimal(18,2));
  IF @konsumsi IS NULL THROW 50002, 'KONSUMSI AMOUNT wajib', 1;
  IF @insentif IS NULL THROW 50003, 'INSENTIF AMOUNT wajib', 1;

  DECLARE @tipe nvarchar(20)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.tipe_insentif'))),'');
  IF @tipe IS NULL SET @tipe=N'TETAP';
  DECLARE @lebih nvarchar(10)=CASE WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.lebih_5_jam'),'false')) IN ('1','true','y') THEN N'True' ELSE N'False' END;

  INSERT INTO hris.dbo.WEB_OVERTIME_AMOUNT (
    [LEVEL], JABATAN, KONSUMSI_AMOUNT, INSENTIF_AMOUNT, INSENTIF_WEEKEND_AMOUNT, TIPE_INSENTIF, LEBIH_5_JAM
  ) VALUES (
    @level, @jabatan, @konsumsi, @insentif, ISNULL(@weekend,0), @tipe, @lebih
  );
  DECLARE @newId int=SCOPE_IDENTITY();
  SET @bitparam=(SELECT '2002500' responseCode, N'Overtime amount tersimpan' responseMessage,
    JSON_QUERY((SELECT CAST(@newId AS varchar(50)) AS id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_update
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  IF @rid IS NULL THROW 50001, 'ID wajib', 1;
  IF NOT EXISTS (SELECT 1 FROM hris.dbo.WEB_OVERTIME_AMOUNT WHERE ID=@rid) THROW 50002, 'Overtime amount tidak ditemukan', 1;

  DECLARE @level nvarchar(50)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.level'))),'');
  DECLARE @jabatan nvarchar(50)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.jabatan'))),'');
  DECLARE @konsumsi decimal(18,2)=TRY_CAST(REPLACE(JSON_VALUE(@j,'$.konsumsi_amount'),',','') AS decimal(18,2));
  DECLARE @insentif decimal(18,2)=TRY_CAST(REPLACE(JSON_VALUE(@j,'$.insentif_amount'),',','') AS decimal(18,2));
  DECLARE @weekend decimal(18,2)=TRY_CAST(REPLACE(JSON_VALUE(@j,'$.insentif_weekend_amount'),',','') AS decimal(18,2));
  DECLARE @tipe nvarchar(20)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.tipe_insentif'))),'');
  DECLARE @lebih nvarchar(10)=CASE WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.lebih_5_jam'),'false')) IN ('1','true','y') THEN N'True' ELSE N'False' END;

  UPDATE hris.dbo.WEB_OVERTIME_AMOUNT SET
      [LEVEL] = COALESCE(@level, [LEVEL])
    , JABATAN = COALESCE(@jabatan, JABATAN)
    , KONSUMSI_AMOUNT = COALESCE(@konsumsi, KONSUMSI_AMOUNT)
    , INSENTIF_AMOUNT = COALESCE(@insentif, INSENTIF_AMOUNT)
    , INSENTIF_WEEKEND_AMOUNT = COALESCE(@weekend, INSENTIF_WEEKEND_AMOUNT)
    , TIPE_INSENTIF = COALESCE(@tipe, TIPE_INSENTIF)
    , LEBIH_5_JAM = @lebih
  WHERE ID=@rid;

  SET @bitparam=(SELECT '2002500' responseCode, N'Overtime amount diperbarui' responseMessage,
    JSON_QUERY((SELECT CAST(@rid AS varchar(50)) AS id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_overtime_amount_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_overtime_amount_delete
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  IF @rid IS NULL THROW 50001, 'ID wajib', 1;
  DELETE FROM hris.dbo.WEB_OVERTIME_AMOUNT WHERE ID=@rid;
  IF @@ROWCOUNT=0 THROW 50002, 'Overtime amount tidak ditemukan', 1;
  SET @bitparam=(SELECT '2002500' responseCode, N'Overtime amount dihapus' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
