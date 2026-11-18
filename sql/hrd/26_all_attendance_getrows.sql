/* List absen Store — legacy Rpt_Attendance.aspx / xsp_rpt_dt_absensi_ghreg_getrows */
USE RBACESS;
GO
SET NOCOUNT ON;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_all_attendance_getrows', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_all_attendance_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_all_attendance_getrows
(   @p_keywords varchar(200)=NULL
, @p_from_date varchar(30)=NULL
, @p_to_date varchar(30)=NULL
, @p_is_active varchar(10)=NULL
, @p_id_brand varchar(50)=NULL
, @p_id_store varchar(50)=NULL
, @p_brand varchar(50)=NULL
, @p_store_id varchar(50)=NULL
, @p_status varchar(50)=NULL
, @p_kategori varchar(50)=NULL
, @p_group varchar(50)=NULL
, @p_dept varchar(50)=NULL
, @p_department varchar(100)=NULL
, @p_cabang varchar(50)=NULL
, @p_id_cabang varchar(50)=NULL
, @p_year varchar(10)=NULL
, @p_month varchar(10)=NULL
, @p_period varchar(30)=NULL
, @p_tipe varchar(30)=NULL
, @p_is_pajak varchar(10)=NULL
, @p_id_mesin varchar(50)=NULL
, @p_currentmonth varchar(20)=NULL
, @p_tahun varchar(10)=NULL
, @bitparam varchar(max) OUTPUT )
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    DECLARE @from datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_from_date)), ''));
    DECLARE @to   datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_to_date)), ''));
    DECLARE @brand varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(@p_id_brand, @p_brand))), '');
    DECLARE @store varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(@p_id_store, @p_store_id))), '');
    DECLARE @kw varchar(200) = LTRIM(RTRIM(ISNULL(@p_keywords, '')));

    IF @from IS NULL SET @from = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    IF @to   IS NULL SET @to = CAST(GETDATE() AS date);
    IF UPPER(ISNULL(@brand, '')) IN ('', 'ALL', 'PILIH') SET @brand = NULL;
    IF UPPER(ISNULL(@store, '')) IN ('', 'ALL', 'PILIH') SET @store = NULL;

    ;WITH raw AS (
      SELECT
          DA.Store_ID
        , DA.User_NIK
        , DS.USER_NAME
        , DATENAME(DW, DA.Waktu) AS Hari
        , CONVERT(varchar(10), DA.Waktu, 23) AS Tanggal
        , CONVERT(nvarchar(8), CAST(MIN(DA.Waktu) AS time), 108) AS Masuk
        , CONVERT(nvarchar(8), CAST(MAX(DA.Waktu) AS time), 108) AS Keluar
      FROM POS_SERVER.dbo.DT_ABSENSI DA WITH (NOLOCK)
      INNER JOIN POS_SERVER.dbo.DT_User DS WITH (NOLOCK) ON DS.User_NIK = DA.User_NIK
      WHERE DA.Waktu >= @from
        AND DA.Waktu < DATEADD(DAY, 1, CAST(@to AS date))
        AND (@store IS NULL OR DA.Store_ID = @store)
        AND (
              @brand IS NULL
           OR EXISTS (
                SELECT 1
                FROM POS_SERVER.dbo.DT_Store S WITH (NOLOCK)
                WHERE S.Store_ID = DA.Store_ID
                  AND (
                       S.Brand_ACCT = @brand
                    OR S.Store_Brand_ID = @brand
                    OR S.Store_Brand_ID_2 = @brand
                    OR DA.Store_ID LIKE @brand + '%'
                  )
              )
            )
        AND (
              @kw = ''
           OR DA.User_NIK LIKE '%' + @kw + '%'
           OR DS.USER_NAME LIKE '%' + @kw + '%'
           OR DA.Store_ID LIKE '%' + @kw + '%'
            )
      GROUP BY
          DATENAME(DW, DA.Waktu)
        , DA.Store_ID
        , DA.User_NIK
        , DS.USER_NAME
        , CONVERT(varchar(10), DA.Waktu, 23)
    )
    SELECT @bitparam = (
      SELECT '2002500' responseCode, N'success' responseMessage,
        JSON_QUERY((
          SELECT
              ROW_NUMBER() OVER (ORDER BY USER_NAME, User_NIK, Tanggal) AS id
            , Store_ID AS store
            , Store_ID AS store_id
            , User_NIK AS nik
            , User_NIK AS user_nik
            , USER_NAME AS employee_name
            , USER_NAME AS user_name
            , Hari AS hari
            , Tanggal AS tanggal
            , CASE WHEN Masuk = Keluar THEN Masuk ELSE Masuk END AS jam_masuk
            , CASE WHEN Masuk = Keluar THEN NULL ELSE Keluar END AS jam_keluar
            , Masuk AS time_in
            , CASE WHEN Masuk = Keluar THEN NULL ELSE Keluar END AS time_out
          FROM raw
          ORDER BY USER_NAME, User_NIK, Tanggal
          FOR JSON PATH
        )) data
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
    IF @bitparam IS NULL
      SET @bitparam = (SELECT '2002500' responseCode, N'success' responseMessage, JSON_QUERY('[]') data FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END TRY
  BEGIN CATCH
    SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END CATCH
END
GO
