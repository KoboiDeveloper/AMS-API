/* Policy — ASP masterpolicylist.aspx / masterpolicy.aspx → hris.dbo.MASTER_POLICY */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_getrows', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_getrows
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
        CAST(mp.ID AS varchar(50)) AS id
      , mp.PERIODE_YEAR AS periode_year
      , RIGHT('0'+LTRIM(RTRIM(ISNULL(mp.PERIODE_MONTH,''))), 2) AS periode_month
      , CONVERT(varchar(10), mp.SALARY_SCHEDULE_START_DATE, 103) AS salary_schedule_start
      , CONVERT(varchar(10), mp.SALARY_SCHEDULE_END_DATE, 103) AS salary_schedule_end
      , CONVERT(varchar(10), mp.ABSEN_SCHEDULE_START_DATE, 103) AS absent_schedule_start
      , CONVERT(varchar(10), mp.ABSEN_SCHEDULE_END_DATE, 103) AS absent_schedule_end
      , CONVERT(varchar(10), mp.SALARY_DATE, 103) AS salary_date
    FROM hris.dbo.MASTER_POLICY mp WITH (NOLOCK)
    WHERE (
      @kw=''
      OR mp.PERIODE_YEAR LIKE '%'+@kw+'%'
      OR mp.PERIODE_MONTH LIKE '%'+@kw+'%'
      OR CONVERT(varchar(10), mp.SALARY_SCHEDULE_START_DATE, 103) LIKE '%'+@kw+'%'
      OR CONVERT(varchar(10), mp.SALARY_SCHEDULE_END_DATE, 103) LIKE '%'+@kw+'%'
      OR CONVERT(varchar(10), mp.ABSEN_SCHEDULE_START_DATE, 103) LIKE '%'+@kw+'%'
      OR CONVERT(varchar(10), mp.ABSEN_SCHEDULE_END_DATE, 103) LIKE '%'+@kw+'%'
    )
    ORDER BY mp.PERIODE_YEAR DESC, mp.PERIODE_MONTH DESC, mp.ID DESC
    FOR JSON PATH
  );
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(ISNULL(@rows,'[]')) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_getrow', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_getrow
( @p_id varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @row nvarchar(max);
  SELECT TOP 1 @row=(
    SELECT
        CAST(mp.ID AS varchar(50)) AS id
      , N'HEAD OFFICE' AS branch
      , mp.PERIODE_YEAR AS periode_year
      , CAST(TRY_CAST(mp.PERIODE_MONTH AS int) AS varchar(2)) AS periode_month
      , CONVERT(varchar(10), mp.SALARY_SCHEDULE_START_DATE, 23) AS salary_schedule_start
      , CONVERT(varchar(10), mp.SALARY_SCHEDULE_END_DATE, 23) AS salary_schedule_end
      , CONVERT(varchar(10), mp.SALARY_DATE, 23) AS salary_date
      , CASE WHEN ISNULL(mp.IS_LAST_DAY_OF_THE_MONTH,'0') IN ('1','Y','true','TRUE') THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS last_day_of_month
      , CONVERT(varchar(10), mp.ABSEN_SCHEDULE_START_DATE, 23) AS absent_schedule_start
      , CONVERT(varchar(10), mp.ABSEN_SCHEDULE_END_DATE, 23) AS absent_schedule_end
      , CASE WHEN ISNULL(mp.IS_STAFF_PROBATION_THR,'0') IN ('1','Y','true','TRUE') THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS staff_probation_thr
      , CASE WHEN ISNULL(mp.IS_STAFF_PROBATION_PRORATE,'0') IN ('1','Y','true','TRUE') THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS staff_probation_prorate
      , CASE WHEN ISNULL(mp.IS_STAFF_PRORATE_THR,'0') IN ('1','Y','true','TRUE') THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS staff_prorate_thr
      , CAST(mp.BPJS_KESEHATAN_BY_EMPLOYEE AS decimal(18,6)) AS bpjs_kes_employee
      , CAST(mp.BPJS_KESEHATAN_BY_COMPANY AS decimal(18,6)) AS bpjs_kes_company
      , CAST(mp.BPJS_KETENAGAKERJAAN_BY_EMPLOYEE AS decimal(18,6)) AS jht_employee
      , CAST(mp.BPJS_KETENAGAKERJAAN_BY_COMPANY AS decimal(18,6)) AS jht_company
      , CAST(mp.BPJS_KETENAGAKERJAAN_JKK_BY_COMPANY AS decimal(18,6)) AS bpjs_jkk
      , CAST(mp.BPJS_KETENAGAKERJAAN_JKM_BY_COMPANY AS decimal(18,6)) AS bpjs_jkm
      , CAST(mp.BPJS_PENSIUN_BY_EMPLOYEE AS decimal(18,6)) AS bpjs_pensiun_employee
      , CAST(mp.BPJS_PENSIUN_BY_COMPANY AS decimal(18,6)) AS bpjs_pensiun_company
      , CAST(mp.TRESHOLD_SALARY_BPJS AS decimal(18,2)) AS threshold_salary_bpjs
      , CAST(mp.TRESHOLD_SALARY_MAX_BPJS AS decimal(18,2)) AS threshold_max_salary_bpjs
      , CAST(mp.TRESHOLD_SALARY_MAX_JP_BPJS AS decimal(18,2)) AS threshold_salary_jp
    FROM hris.dbo.MASTER_POLICY mp WITH (NOLOCK)
    WHERE mp.ID=@rid
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  );
  IF @row IS NULL THROW 50001, 'Policy tidak ditemukan', 1;
  SET @bitparam=(SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY(@row) data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

/* helper: checkbox JSON → '1'/'0' */
/* used inline in insert/update */

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_insert', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_insert;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_insert
( @p_payload nvarchar(max)=NULL, @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_created_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  DECLARE @year nvarchar(4)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.periode_year'))),'');
  DECLARE @monthRaw nvarchar(15)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.periode_month'))),'');
  DECLARE @month nvarchar(15)=CASE WHEN TRY_CAST(@monthRaw AS int) IS NULL THEN @monthRaw ELSE RIGHT('0'+CAST(TRY_CAST(@monthRaw AS int) AS varchar(2)),2) END;
  IF @year IS NULL THROW 50001, 'Period Year wajib', 1;

  DECLARE @ss datetime=TRY_CONVERT(datetime, JSON_VALUE(@j,'$.salary_schedule_start'), 23);
  DECLARE @se datetime=TRY_CONVERT(datetime, JSON_VALUE(@j,'$.salary_schedule_end'), 23);
  DECLARE @sd datetime=TRY_CONVERT(datetime, JSON_VALUE(@j,'$.salary_date'), 23);
  DECLARE @as datetime=TRY_CONVERT(datetime, JSON_VALUE(@j,'$.absent_schedule_start'), 23);
  DECLARE @ae datetime=TRY_CONVERT(datetime, JSON_VALUE(@j,'$.absent_schedule_end'), 23);
  IF @ss IS NULL OR @se IS NULL THROW 50002, 'Salary schedule date wajib', 1;
  IF @se <= @ss THROW 50003, 'Salary schedule end date must be greater than start date', 1;
  IF @as IS NULL OR @ae IS NULL THROW 50004, 'Absent schedule date wajib', 1;
  IF @ae <= @as THROW 50005, 'Absent schedule end date must be greater than start date', 1;

  DECLARE @flagLast nvarchar(1)=CASE WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.last_day_of_month'),'false')) IN ('1','true','y') THEN '1' ELSE '0' END;
  DECLARE @f1 nvarchar(1)=CASE WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.staff_probation_thr'),'false')) IN ('1','true','y') THEN '1' ELSE '0' END;
  DECLARE @f2 nvarchar(1)=CASE WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.staff_probation_prorate'),'false')) IN ('1','true','y') THEN '1' ELSE '0' END;
  DECLARE @f3 nvarchar(1)=CASE WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.staff_prorate_thr'),'false')) IN ('1','true','y') THEN '1' ELSE '0' END;

  INSERT INTO hris.dbo.MASTER_POLICY (
    PERIODE_YEAR, PERIODE_MONTH,
    SALARY_SCHEDULE_START_DATE, SALARY_SCHEDULE_END_DATE, SALARY_DATE, IS_LAST_DAY_OF_THE_MONTH,
    ABSEN_SCHEDULE_START_DATE, ABSEN_SCHEDULE_END_DATE,
    IS_STAFF_PROBATION_THR, IS_STAFF_PROBATION_PRORATE, IS_STAFF_PRORATE_THR,
    BPJS_KESEHATAN_BY_EMPLOYEE, BPJS_KESEHATAN_BY_COMPANY,
    BPJS_KETENAGAKERJAAN_BY_EMPLOYEE, BPJS_KETENAGAKERJAAN_BY_COMPANY,
    BPJS_KETENAGAKERJAAN_JKK_BY_COMPANY, BPJS_KETENAGAKERJAAN_JKM_BY_COMPANY,
    BPJS_PENSIUN_BY_EMPLOYEE, BPJS_PENSIUN_BY_COMPANY,
    TRESHOLD_SALARY_BPJS, TRESHOLD_SALARY_MAX_BPJS, TRESHOLD_SALARY_MAX_JP_BPJS,
    CRE_DATE, CRE_BY
  ) VALUES (
    @year, @month, @ss, @se, @sd, @flagLast, @as, @ae, @f1, @f2, @f3,
    TRY_CAST(JSON_VALUE(@j,'$.bpjs_kes_employee') AS decimal(18,6)),
    TRY_CAST(JSON_VALUE(@j,'$.bpjs_kes_company') AS decimal(18,6)),
    TRY_CAST(JSON_VALUE(@j,'$.jht_employee') AS decimal(18,6)),
    TRY_CAST(JSON_VALUE(@j,'$.jht_company') AS decimal(18,6)),
    TRY_CAST(JSON_VALUE(@j,'$.bpjs_jkk') AS decimal(18,6)),
    TRY_CAST(JSON_VALUE(@j,'$.bpjs_jkm') AS decimal(18,6)),
    TRY_CAST(JSON_VALUE(@j,'$.bpjs_pensiun_employee') AS decimal(18,6)),
    TRY_CAST(JSON_VALUE(@j,'$.bpjs_pensiun_company') AS decimal(18,6)),
    TRY_CAST(JSON_VALUE(@j,'$.threshold_salary_bpjs') AS decimal(18,2)),
    TRY_CAST(JSON_VALUE(@j,'$.threshold_max_salary_bpjs') AS decimal(18,2)),
    TRY_CAST(JSON_VALUE(@j,'$.threshold_salary_jp') AS decimal(18,2)),
    GETDATE(), @actor
  );
  DECLARE @newId int=SCOPE_IDENTITY();
  SET @bitparam=(SELECT '2002500' responseCode, N'Policy tersimpan' responseMessage,
    JSON_QUERY((SELECT CAST(@newId AS varchar(50)) AS id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_update', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_update
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  DECLARE @j nvarchar(max)=ISNULL(@p_payload,N'{}');
  DECLARE @actor varchar(50)=COALESCE(NULLIF(LTRIM(RTRIM(@p_updated_by)),''),NULLIF(LTRIM(RTRIM(@p_actor_nik)),''),'AMS');
  IF @rid IS NULL THROW 50001, 'ID wajib', 1;
  IF NOT EXISTS (SELECT 1 FROM hris.dbo.MASTER_POLICY WHERE ID=@rid) THROW 50002, 'Policy tidak ditemukan', 1;

  DECLARE @year nvarchar(4)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.periode_year'))),'');
  DECLARE @monthRaw nvarchar(15)=NULLIF(LTRIM(RTRIM(JSON_VALUE(@j,'$.periode_month'))),'');
  DECLARE @month nvarchar(15)=CASE WHEN TRY_CAST(@monthRaw AS int) IS NULL THEN @monthRaw ELSE RIGHT('0'+CAST(TRY_CAST(@monthRaw AS int) AS varchar(2)),2) END;
  DECLARE @ss datetime=TRY_CONVERT(datetime, JSON_VALUE(@j,'$.salary_schedule_start'), 23);
  DECLARE @se datetime=TRY_CONVERT(datetime, JSON_VALUE(@j,'$.salary_schedule_end'), 23);
  DECLARE @sd datetime=TRY_CONVERT(datetime, JSON_VALUE(@j,'$.salary_date'), 23);
  DECLARE @as datetime=TRY_CONVERT(datetime, JSON_VALUE(@j,'$.absent_schedule_start'), 23);
  DECLARE @ae datetime=TRY_CONVERT(datetime, JSON_VALUE(@j,'$.absent_schedule_end'), 23);
  IF @ss IS NOT NULL AND @se IS NOT NULL AND @se <= @ss THROW 50003, 'Salary schedule end date must be greater than start date', 1;
  IF @as IS NOT NULL AND @ae IS NOT NULL AND @ae <= @as THROW 50005, 'Absent schedule end date must be greater than start date', 1;

  DECLARE @flagLast nvarchar(1)=CASE WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.last_day_of_month'),'false')) IN ('1','true','y') THEN '1' ELSE '0' END;
  DECLARE @f1 nvarchar(1)=CASE WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.staff_probation_thr'),'false')) IN ('1','true','y') THEN '1' ELSE '0' END;
  DECLARE @f2 nvarchar(1)=CASE WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.staff_probation_prorate'),'false')) IN ('1','true','y') THEN '1' ELSE '0' END;
  DECLARE @f3 nvarchar(1)=CASE WHEN LOWER(ISNULL(JSON_VALUE(@j,'$.staff_prorate_thr'),'false')) IN ('1','true','y') THEN '1' ELSE '0' END;

  UPDATE hris.dbo.MASTER_POLICY SET
      PERIODE_YEAR = COALESCE(@year, PERIODE_YEAR)
    , PERIODE_MONTH = COALESCE(@month, PERIODE_MONTH)
    , SALARY_SCHEDULE_START_DATE = COALESCE(@ss, SALARY_SCHEDULE_START_DATE)
    , SALARY_SCHEDULE_END_DATE = COALESCE(@se, SALARY_SCHEDULE_END_DATE)
    , SALARY_DATE = COALESCE(@sd, SALARY_DATE)
    , IS_LAST_DAY_OF_THE_MONTH = @flagLast
    , ABSEN_SCHEDULE_START_DATE = COALESCE(@as, ABSEN_SCHEDULE_START_DATE)
    , ABSEN_SCHEDULE_END_DATE = COALESCE(@ae, ABSEN_SCHEDULE_END_DATE)
    , IS_STAFF_PROBATION_THR = @f1
    , IS_STAFF_PROBATION_PRORATE = @f2
    , IS_STAFF_PRORATE_THR = @f3
    , BPJS_KESEHATAN_BY_EMPLOYEE = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.bpjs_kes_employee') AS decimal(18,6)), BPJS_KESEHATAN_BY_EMPLOYEE)
    , BPJS_KESEHATAN_BY_COMPANY = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.bpjs_kes_company') AS decimal(18,6)), BPJS_KESEHATAN_BY_COMPANY)
    , BPJS_KETENAGAKERJAAN_BY_EMPLOYEE = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.jht_employee') AS decimal(18,6)), BPJS_KETENAGAKERJAAN_BY_EMPLOYEE)
    , BPJS_KETENAGAKERJAAN_BY_COMPANY = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.jht_company') AS decimal(18,6)), BPJS_KETENAGAKERJAAN_BY_COMPANY)
    , BPJS_KETENAGAKERJAAN_JKK_BY_COMPANY = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.bpjs_jkk') AS decimal(18,6)), BPJS_KETENAGAKERJAAN_JKK_BY_COMPANY)
    , BPJS_KETENAGAKERJAAN_JKM_BY_COMPANY = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.bpjs_jkm') AS decimal(18,6)), BPJS_KETENAGAKERJAAN_JKM_BY_COMPANY)
    , BPJS_PENSIUN_BY_EMPLOYEE = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.bpjs_pensiun_employee') AS decimal(18,6)), BPJS_PENSIUN_BY_EMPLOYEE)
    , BPJS_PENSIUN_BY_COMPANY = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.bpjs_pensiun_company') AS decimal(18,6)), BPJS_PENSIUN_BY_COMPANY)
    , TRESHOLD_SALARY_BPJS = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.threshold_salary_bpjs') AS decimal(18,2)), TRESHOLD_SALARY_BPJS)
    , TRESHOLD_SALARY_MAX_BPJS = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.threshold_max_salary_bpjs') AS decimal(18,2)), TRESHOLD_SALARY_MAX_BPJS)
    , TRESHOLD_SALARY_MAX_JP_BPJS = COALESCE(TRY_CAST(JSON_VALUE(@j,'$.threshold_salary_jp') AS decimal(18,2)), TRESHOLD_SALARY_MAX_JP_BPJS)
    , MOD_DATE = GETDATE()
    , MOD_BY = @actor
  WHERE ID=@rid;

  SET @bitparam=(SELECT '2002500' responseCode, N'Policy diperbarui' responseMessage,
    JSON_QUERY((SELECT CAST(@rid AS varchar(50)) AS id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) data
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_policy_delete', N'P') IS NOT NULL DROP PROCEDURE dbo.xsp_ams_new_hrd_policy_delete;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_policy_delete
( @p_id varchar(50)=NULL, @p_payload nvarchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT )
AS BEGIN SET NOCOUNT ON;
BEGIN TRY
  DECLARE @rid int=TRY_CAST(@p_id AS int);
  IF @rid IS NULL THROW 50001, 'ID wajib', 1;
  DELETE FROM hris.dbo.MASTER_POLICY WHERE ID=@rid;
  IF @@ROWCOUNT=0 THROW 50002, 'Policy tidak ditemukan', 1;
  SET @bitparam=(SELECT '2002500' responseCode, N'Policy dihapus' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END TRY BEGIN CATCH
  SET @bitparam=(SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END CATCH
END
GO
