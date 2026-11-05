/* Absen Nasional (POS React) — no stamp/cache.
   List: emp list + per-nik calc (Go parallelizes).
   Detail: skip zero UDFs (Go can also parallelize sections). */
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.ams_hrd_nasional_gen_stamp', N'U') IS NOT NULL
  DROP TABLE dbo.ams_hrd_nasional_gen_stamp;
GO

/* Employee roster for filters (same rules as xsp_generate_transport_ro_table). */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_report_nasional_emp_getrows', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_emp_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_emp_getrows
(   @p_id_cabang varchar(20)=NULL
, @p_dept varchar(20)=NULL
, @p_group varchar(20)=NULL
, @bitparam varchar(max) OUTPUT )
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    DECLARE @cabang varchar(20) = COALESCE(NULLIF(LTRIM(RTRIM(@p_id_cabang)), ''), '1');
    DECLARE @dept varchar(20) = NULLIF(LTRIM(RTRIM(@p_dept)), '');
    IF @dept IS NULL OR @dept IN ('ALL','all','*') SET @dept = '216216';
    DECLARE @group varchar(20) = NULLIF(LTRIM(RTRIM(@p_group)), '');
    IF @group IS NULL SET @group = 'ALL';
    DECLARE @lokasi varchar(20) = CASE WHEN @cabang = '1' AND @dept = '33' THEN '4' ELSE @cabang END;
    DECLARE @mgr bit = CASE WHEN @dept = '216216' THEN 1 ELSE 0 END;

    SET @bitparam = (
      SELECT '2002500' responseCode, N'success' responseMessage,
        JSON_QUERY((
          SELECT
              a.NomorIndukStr AS nik
            , a.NamaLengkapStr AS employee_name
            , f.JabatanStr AS jabatan
            , CAST(c.DepartemenIDLng AS varchar(50)) AS dept_id
            , c.DepartemenStr AS department_name
          FROM hris.dbo.tblpegawai a WITH (NOLOCK)
          LEFT JOIN hris.dbo.tblpegawaijabatan b WITH (NOLOCK) ON b.PegawaiIDLng = a.PegawaiIDLng
          LEFT JOIN hris.dbo.tbldepartemen c WITH (NOLOCK) ON c.DepartemenIDLng = b.DepartemenIDLng
          LEFT JOIN hris.dbo.tbljabatan f WITH (NOLOCK) ON f.JabatanIDLng = b.JabatanIDLng
          LEFT JOIN hris.dbo.tblstatuspegawai e WITH (NOLOCK) ON e.StatusPegawaiIDLng = b.StatusPegawaiIDLng
          WHERE a.PegawaiNonAktifInt = 0
            AND a.LokasiAbsensiIDLng = @lokasi
            AND (
              (@mgr = 1 AND f.JabatanIDLng IN (3,4,5,6,7,16))
              OR (@mgr = 0 AND f.JabatanIDLng NOT IN (3,4,5,6,7,16) AND c.DepartemenIDLng = TRY_CONVERT(int, @dept))
            )
            AND (
              @group = 'ALL'
              OR e.StatusPegawaiStr = @group
              OR (@group = 'Kontrak' AND e.StatusPegawaiStr = 'Kontrak')
              OR (@group = 'Temporer' AND e.StatusPegawaiStr = 'Temporer')
              OR (@group = 'Tetap' AND e.StatusPegawaiStr = 'tetap')
            )
          ORDER BY a.NamaLengkapStr, a.NomorIndukStr
          FOR JSON PATH
        )) data
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
  END TRY
  BEGIN CATCH
    SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END CATCH
END
GO

/* Per-nik totals → scratch knr + one result row (for Go fan-out). */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_report_nasional_calc_nik', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_calc_nik;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_calc_nik
(   @p_from_date varchar(30)=NULL
, @p_to_date varchar(30)=NULL
, @p_nik varchar(30)=NULL
, @p_user_id varchar(50)=NULL
, @p_dept varchar(50)=NULL
, @p_employee_name nvarchar(200)=NULL
, @p_jabatan nvarchar(120)=NULL
, @p_department_name nvarchar(200)=NULL
, @bitparam varchar(max) OUTPUT )
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    DECLARE @from datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_from_date)), ''));
    DECLARE @to   datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_to_date)), ''));
    DECLARE @nik varchar(30) = NULLIF(LTRIM(RTRIM(@p_nik)), '');
    DECLARE @uid varchar(50) = ISNULL(NULLIF(LTRIM(RTRIM(@p_user_id)), ''), 'portal');
    DECLARE @dept varchar(50) = NULLIF(LTRIM(RTRIM(@p_dept)), '');

    IF @from IS NULL OR @to IS NULL OR @nik IS NULL
    BEGIN
      SET @bitparam = (SELECT '4002500' responseCode, N'from_date, to_date, nik required' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
      RETURN;
    END

    DECLARE @kehadiran_reguler int =
      ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_reguler(@from,@to,@nik),0);
    DECLARE @kehadiran int =
      ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran(@from,@to,@nik),0)
      + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas(@from,@to,@nik),0)
      + ISNULL(POS_SERVER.dbo.fn_calculate_day_transport_lembur_absen_in_nextday(@from,@to,@nik),0);
    DECLARE @kehadiran_weekend int =
      ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_kehadiran(@from,@to,@nik),0)
      + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas_wk(@from,@to,@nik),0);
    DECLARE @kehadiran_holiday int =
      ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_kehadiran(@from,@to,@nik),0)
      + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas_hd(@from,@to,@nik),0);
    DECLARE @transport int =
      ISNULL(POS_SERVER.dbo.fn_calculate_all_day_transport(@from,@to,@nik),0)
      + ISNULL(POS_SERVER.dbo.fn_calculate_rekap_izin_transport(@from,@to,@nik),0)
      + ISNULL(POS_SERVER.dbo.fn_calculate_day_transport_lembur_absen_in_nextday(@from,@to,@nik),0);
    DECLARE @transport2 int = ISNULL(POS_SERVER.dbo.fn_calculate_cuma_absen_masuk(@from,@to,@nik),0);
    DECLARE @transport3 int = ISNULL(POS_SERVER.dbo.fn_calculate_special_day_pulang_cepet_transport(@from,@to,@nik),0);
    DECLARE @transport_weekend int =
      ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_transport(@from,@to,@nik),0)
      + ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_transport_dinas(@from,@to,@nik),0);
    DECLARE @transport_holiday int =
      ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_transport(@from,@to,@nik),0)
      + ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_transport_dinas(@from,@to,@nik),0);
    DECLARE @izin int =
      ISNULL(POS_SERVER.dbo.fn_calculate_total_izin_day(@from,@to,@nik),0)
      + ISNULL(POS_SERVER.dbo.fn_calculate_total_izin_tiggal_ruangan_dan_telat_masuk_day(@from,@to,@nik),0);
    DECLARE @sakit int = ISNULL(POS_SERVER.dbo.fn_calculate_total_sick_day(@from,@to,@nik),0);
    DECLARE @cuti int = ISNULL(POS_SERVER.dbo.fn_calculate_total_cuti_day(@from,@to,@nik),0);
    DECLARE @lembur int = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_day(@from,@to,@nik),0);
    DECLARE @lembur_weekend int = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_weekend_day(@from,@to,@nik),0);
    DECLARE @lembur_holiday int = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_holiday_day(@from,@to,@nik),0);
    DECLARE @alfa int = ISNULL(POS_SERVER.dbo.fn_calculate_alfa_coy(@from,@to,@nik),0);

    DELETE FROM POS_SERVER.dbo.kehadiran_nasional_report WHERE user_id = @uid AND nik = @nik;
    INSERT INTO POS_SERVER.dbo.kehadiran_nasional_report (
      nik, kehadiran_reguler, kehadiran, kehadiran_weekend, kehadiran_holiday,
      transport, transport2, transport3, transport_weekend, transport_holiday,
      izin, sakit, cuti, lembur, lembur_weekend, lembur_holiday, alfa, user_id
    ) VALUES (
      @nik, @kehadiran_reguler, @kehadiran, @kehadiran_weekend, @kehadiran_holiday,
      @transport, @transport2, @transport3, @transport_weekend, @transport_holiday,
      @izin, @sakit, @cuti, @lembur, @lembur_weekend, @lembur_holiday, @alfa, @uid
    );

    DECLARE @nama nvarchar(200) = @p_employee_name;
    DECLARE @jabatan nvarchar(120) = @p_jabatan;
    DECLARE @deptName nvarchar(200) = @p_department_name;
    IF @nama IS NULL OR @jabatan IS NULL
    BEGIN
      SELECT TOP 1
          @nama = COALESCE(@nama, a.NamaLengkapStr)
        , @jabatan = COALESCE(@jabatan, f.JabatanStr)
        , @dept = COALESCE(@dept, CAST(c.DepartemenIDLng AS varchar(50)))
        , @deptName = COALESCE(@deptName, c.DepartemenStr)
      FROM hris.dbo.tblpegawai a WITH (NOLOCK)
      LEFT JOIN hris.dbo.tblpegawaijabatan b WITH (NOLOCK) ON b.PegawaiIDLng = a.PegawaiIDLng
      LEFT JOIN hris.dbo.tbldepartemen c WITH (NOLOCK) ON c.DepartemenIDLng = b.DepartemenIDLng
      LEFT JOIN hris.dbo.tbljabatan f WITH (NOLOCK) ON f.JabatanIDLng = b.JabatanIDLng
      WHERE a.NomorIndukStr = @nik;
    END

    SET @bitparam = (
      SELECT '2002500' responseCode, N'success' responseMessage,
        JSON_QUERY((
          SELECT
              @dept AS dept_id
            , COALESCE(@deptName, @dept) AS department_name
            , @nik AS nik
            , @nama AS employee_name
            , @jabatan AS jabatan
            , @kehadiran_reguler AS kehadiran_reguler
            , @kehadiran AS disiplin_wd
            , @kehadiran_weekend AS disiplin_wk
            , @kehadiran_holiday AS disiplin_hd
            , CONCAT(@kehadiran, N'/', @kehadiran_weekend, N'/', @kehadiran_holiday) AS disiplin
            , (@transport + @transport2 + @transport3) AS transport_wd
            , @transport_weekend AS transport_wk
            , @transport_holiday AS transport_hd
            , CONCAT((@transport + @transport2 + @transport3), N'/', @transport_weekend, N'/', @transport_holiday) AS transport
            , @izin AS izin
            , @sakit AS sakit
            , @cuti AS cuti
            , @lembur AS lembur_wd
            , @lembur_weekend AS lembur_wk
            , @lembur_holiday AS lembur_hd
            , CONCAT(@lembur, N'/', @lembur_weekend, N'/', @lembur_holiday) AS lembur
            , @alfa AS alfa
          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) data
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
  END TRY
  BEGIN CATCH
    SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END CATCH
END
GO

/* List SP kept for compatibility — clears scratch then returns empty hint;
   React uses Go parallel handler. Fallback: sequential calc via emp list. */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_report_nasional_getrows', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_getrows
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
, @p_user_id varchar(50)=NULL
, @bitparam varchar(max) OUTPUT )
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    /* Prefer Go parallel path; this SP remains a safe sequential fallback. */
    DECLARE @from datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_from_date)), ''));
    DECLARE @to   datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_to_date)), ''));
    IF @from IS NULL SET @from = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    IF @to   IS NULL SET @to = EOMONTH(@from);
    DECLARE @group varchar(50) = ISNULL(NULLIF(LTRIM(RTRIM(@p_group)), ''), 'ALL');
    DECLARE @cabang varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_id_cabang)), ''), NULLIF(LTRIM(RTRIM(@p_cabang)), ''), '1');
    DECLARE @dept varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(@p_dept, @p_department))), '');
    IF @dept IN ('ALL', 'all', '*') OR @dept IS NULL SET @dept = '216216';
    DECLARE @uid varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_user_id)), ''), NULLIF(LTRIM(RTRIM(@p_keywords)), ''), 'portal');

    DELETE FROM POS_SERVER.dbo.kehadiran_nasional_report WHERE user_id = @uid;

    DECLARE @emp nvarchar(max);
    EXEC dbo.xsp_ams_new_hrd_absen_report_nasional_emp_getrows
      @p_id_cabang=@cabang, @p_dept=@dept, @p_group=@group, @bitparam=@emp OUTPUT;

    IF ISJSON(@emp) = 0 OR JSON_VALUE(@emp,'$.responseCode') <> '2002500'
    BEGIN
      SET @bitparam = @emp;
      RETURN;
    END

    DECLARE @rows nvarchar(max) = N'[]';
    DECLARE @nik varchar(30), @nama nvarchar(200), @jab nvarchar(120), @did varchar(50), @dname nvarchar(200);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
      SELECT
          JSON_VALUE(j.value,'$.nik')
        , JSON_VALUE(j.value,'$.employee_name')
        , JSON_VALUE(j.value,'$.jabatan')
        , JSON_VALUE(j.value,'$.dept_id')
        , JSON_VALUE(j.value,'$.department_name')
      FROM OPENJSON(@emp, '$.data') j;
    OPEN c;
    FETCH NEXT FROM c INTO @nik, @nama, @jab, @did, @dname;
    WHILE @@FETCH_STATUS = 0
    BEGIN
      DECLARE @one nvarchar(max);
      EXEC dbo.xsp_ams_new_hrd_absen_report_nasional_calc_nik
        @p_from_date=@p_from_date, @p_to_date=@p_to_date, @p_nik=@nik, @p_user_id=@uid,
        @p_dept=@did, @p_employee_name=@nama, @p_jabatan=@jab, @p_department_name=@dname,
        @bitparam=@one OUTPUT;
      IF ISJSON(@one)=1 AND JSON_VALUE(@one,'$.responseCode')='2002500' AND JSON_QUERY(@one,'$.data') IS NOT NULL
        SET @rows = JSON_MODIFY(@rows, 'append $', JSON_QUERY(@one, '$.data'));
      FETCH NEXT FROM c INTO @nik, @nama, @jab, @did, @dname;
    END
    CLOSE c; DEALLOCATE c;

    SET @bitparam = (
      SELECT '2002500' responseCode, N'success' responseMessage,
        JSON_QUERY(@rows) data
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
  END TRY
  BEGIN CATCH
    SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END CATCH
END
GO

/* Fast popup detail: skip UDF when scratch totals are 0. */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_report_nasional_detail_getrow', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_detail_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_detail_getrow
(   @p_from_date varchar(30)=NULL
, @p_to_date varchar(30)=NULL
, @p_group varchar(50)=NULL
, @p_dept varchar(50)=NULL
, @p_nik varchar(30)=NULL
, @p_user_id varchar(50)=NULL
, @bitparam varchar(max) OUTPUT )
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    DECLARE @from datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_from_date)), ''));
    DECLARE @to   datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_to_date)), ''));
    DECLARE @group varchar(50) = ISNULL(NULLIF(LTRIM(RTRIM(@p_group)), ''), 'ALL');
    DECLARE @dept varchar(50) = NULLIF(LTRIM(RTRIM(@p_dept)), '');
    DECLARE @nik varchar(30) = NULLIF(LTRIM(RTRIM(@p_nik)), '');
    DECLARE @uid varchar(50) = ISNULL(NULLIF(LTRIM(RTRIM(@p_user_id)), ''), 'portal');

    IF @from IS NULL OR @to IS NULL OR @nik IS NULL OR @dept IS NULL
    BEGIN
      SET @bitparam = (SELECT '4002500' responseCode, N'from_date, to_date, dept, nik required' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
      RETURN;
    END

    DECLARE @kr int=0, @kd int=0, @kw int=0, @kh int=0;
    DECLARE @tr int=0, @tw int=0, @th int=0, @tr2 int=0;
    DECLARE @izin int=0, @sakit int=0, @cuti int=0, @alfa int=0;
    DECLARE @lw int=0, @lwk int=0, @lhd int=0;

    SELECT TOP 1
        @kr  = ISNULL(kehadiran_reguler,0)
      , @kd  = ISNULL(kehadiran,0)
      , @kw  = ISNULL(kehadiran_weekend,0)
      , @kh  = ISNULL(kehadiran_holiday,0)
      , @tr  = ISNULL(transport,0) + ISNULL(transport2,0) + ISNULL(transport3,0)
      , @tw  = ISNULL(transport_weekend,0)
      , @th  = ISNULL(transport_holiday,0)
      , @tr2 = ISNULL(transport2,0)
      , @izin = ISNULL(izin,0)
      , @sakit= ISNULL(sakit,0)
      , @cuti = ISNULL(cuti,0)
      , @alfa = ISNULL(alfa,0)
      , @lw  = ISNULL(lembur,0)
      , @lwk = ISNULL(lembur_weekend,0)
      , @lhd = ISNULL(lembur_holiday,0)
    FROM POS_SERVER.dbo.kehadiran_nasional_report WITH (NOLOCK)
    WHERE user_id = @uid AND nik = @nik;

    /* Scratch miss (e.g. detail before list) — compute counts only for gate. */
    IF @@ROWCOUNT = 0
    BEGIN
      SET @kr = ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_reguler(@from,@to,@nik),0);
      SET @kd = ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran(@from,@to,@nik),0)
              + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas(@from,@to,@nik),0);
      SET @kw = ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_kehadiran(@from,@to,@nik),0)
              + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas_wk(@from,@to,@nik),0);
      SET @kh = ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_kehadiran(@from,@to,@nik),0)
              + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas_hd(@from,@to,@nik),0);
      SET @tr = ISNULL(POS_SERVER.dbo.fn_calculate_all_day_transport(@from,@to,@nik),0)
              + ISNULL(POS_SERVER.dbo.fn_calculate_cuma_absen_masuk(@from,@to,@nik),0)
              + ISNULL(POS_SERVER.dbo.fn_calculate_special_day_pulang_cepet_transport(@from,@to,@nik),0);
      SET @tr2 = ISNULL(POS_SERVER.dbo.fn_calculate_cuma_absen_masuk(@from,@to,@nik),0);
      SET @tw = ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_transport(@from,@to,@nik),0);
      SET @th = ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_transport(@from,@to,@nik),0);
      SET @izin = ISNULL(POS_SERVER.dbo.fn_calculate_total_izin_day(@from,@to,@nik),0)
               + ISNULL(POS_SERVER.dbo.fn_calculate_total_izin_tiggal_ruangan_dan_telat_masuk_day(@from,@to,@nik),0);
      SET @sakit = ISNULL(POS_SERVER.dbo.fn_calculate_total_sick_day(@from,@to,@nik),0);
      SET @cuti = ISNULL(POS_SERVER.dbo.fn_calculate_total_cuti_day(@from,@to,@nik),0);
      SET @lw = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_day(@from,@to,@nik),0);
      SET @lwk = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_weekend_day(@from,@to,@nik),0);
      SET @lhd = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_holiday_day(@from,@to,@nik),0);
      SET @alfa = ISNULL(POS_SERVER.dbo.fn_calculate_alfa_coy(@from,@to,@nik),0);
    END

    DECLARE @nama nvarchar(150) = NULL, @jabatan nvarchar(80) = NULL;
    SELECT TOP 1
        @nama = a.NamaLengkapStr
      , @jabatan = f.JabatanStr
    FROM hris.dbo.tblpegawai a WITH (NOLOCK)
    LEFT JOIN hris.dbo.tblpegawaijabatan b WITH (NOLOCK) ON b.PegawaiIDLng = a.PegawaiIDLng
    LEFT JOIN hris.dbo.tbljabatan f WITH (NOLOCK) ON f.JabatanIDLng = b.JabatanIDLng
    WHERE a.NomorIndukStr = @nik;

    DECLARE @c_kr varchar(max) = '-'
          , @c_d_wd varchar(max) = '-'
          , @c_d_wk varchar(max) = '-'
          , @c_d_hd varchar(max) = '-'
          , @c_t_wd varchar(max) = '-'
          , @c_t_wk varchar(max) = '-'
          , @c_t_hd varchar(max) = '-'
          , @c_izin varchar(max) = '-'
          , @c_sakit varchar(max) = '-'
          , @c_cuti varchar(max) = '-'
          , @c_l_wd varchar(max) = '-'
          , @c_l_wk varchar(max) = '-'
          , @c_l_hd varchar(max) = '-'
          , @c_alfa varchar(max) = '-';

    IF @kr > 0
      SET @c_kr = ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_reguler_detail(@from, @to, @nik), '-');

    IF @kd > 0 OR @tr2 > 0
      SET @c_d_wd =
          ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_detail(@from, @to, @nik), '-')
        + '<br/> <hr class="divider">Special Activity <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_special_day_pulang_cepet_transport_detail(@from, @to, @nik, 0), '-')
        + '<br/> <hr class="divider">Dinas Weekday <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas_detail(@from, @to, @nik), '-')
        + '<p/>';
    ELSE
      SET @c_d_wd = '-<br/> <hr class="divider">Special Activity <hr class="divider">-<br/> <hr class="divider">Dinas Weekday <hr class="divider">-<p/>';

    IF @kw > 0
      SET @c_d_wk =
          ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_kehadiran_detail(@from, @to, @nik), '-')
        + '<br/> <hr class="divider">Dinas Weekend <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas_wk_detail(@from, @to, @nik), '-')
        + '<p/>';
    ELSE
      SET @c_d_wk = '-<br/> <hr class="divider">Dinas Weekend <hr class="divider">-<p/>';

    IF @kh > 0
      SET @c_d_hd =
          ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_kehadiran_detail(@from, @to, @nik), '-')
        + '<br/> <hr class="divider">Dinas Holiday <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas_hd_detail(@from, @to, @nik), '-')
        + '<p/>';
    ELSE
      SET @c_d_hd = '-<br/> <hr class="divider">Dinas Holiday <hr class="divider">-<p/>';

    IF @tr > 0
      SET @c_t_wd =
          '<p> Reguler<hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_transport_detail(@from, @to, @nik), '-')
        + ' <hr class="divider">   (In = Out) <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_cuma_absen_masuk_detail(@from, @to, @nik, @tr), '-')
        + '<br/> <hr class="divider">Special Activity <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_special_day_pulang_cepet_transport_detail(@from, @to, @nik, @tr), '-')
        + '<br/> <hr class="divider">Dinas Weekday <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_transport_dinas_detail(@from, @to, @nik), '-')
        + '<p/>';
    ELSE
      SET @c_t_wd = '<p> Reguler<hr class="divider">- <hr class="divider">   (In = Out) <hr class="divider">-<br/> <hr class="divider">Special Activity <hr class="divider">-<br/> <hr class="divider">Dinas Weekday <hr class="divider">-<p/>';

    IF @tw > 0
      SET @c_t_wk =
          ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_transport_detail(@from, @to, @nik), '-')
        + '<br/> <hr class="divider">Dinas Weekend <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_transport_dinas_detail(@from, @to, @nik), '-')
        + '<p/>';
    ELSE
      SET @c_t_wk = '-<br/> <hr class="divider">Dinas Weekend <hr class="divider">-<p/>';

    IF @th > 0
      SET @c_t_hd =
          ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_transport_detail(@from, @to, @nik), '-')
        + '<br/> <hr class="divider">Dinas Holiday <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_transport_dinas_detail(@from, @to, @nik), '-')
        + '<p/>';
    ELSE
      SET @c_t_hd = '-<br/> <hr class="divider">Dinas Holiday <hr class="divider">-<p/>';

    IF @izin > 0
      SET @c_izin =
          '<p> Tidak Masuk Kerja<hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_total_izin_day_detail(@from, @to, @nik), '-')
        + '<br/> <hr class="divider">Telat/Meninggalkan Ruangan <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_total_izin_tiggal_ruangan_dan_telat_masuk_day_detail(@from, @to, @nik), '-')
        + '<p/>';
    ELSE
      SET @c_izin = '<p> Tidak Masuk Kerja<hr class="divider">-<br/> <hr class="divider">Telat/Meninggalkan Ruangan <hr class="divider">-<p/>';

    IF @sakit > 0
      SET @c_sakit = ISNULL(POS_SERVER.dbo.fn_calculate_total_sick_day_detail(@from, @to, @nik), '-');

    IF @cuti > 0
      SET @c_cuti =
          ISNULL(POS_SERVER.dbo.fn_calculate_total_cuti_day_detail(@from, @to, @nik), '-')
        + '<br/> <hr class="divider">Cuti Melahirkan <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_total_cuti_melahirkan_detail(@from, @to, @nik), '-')
        + '<br/> <hr class="divider">Cuti Khusus <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_total_cuti_khusus_detail(@from, @to, @nik), '-');
    ELSE
      SET @c_cuti = '-<br/> <hr class="divider">Cuti Melahirkan <hr class="divider">-<br/> <hr class="divider">Cuti Khusus <hr class="divider">-';

    IF @lw > 0
      SET @c_l_wd = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_day_detail(@from, @to, @nik), '-');
    IF @lwk > 0
      SET @c_l_wk = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_weekend_day_detail(@from, @to, @nik), '-');
    IF @lhd > 0
      SET @c_l_hd = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_holiday_day_detail(@from, @to, @nik), '-');

    IF @alfa > 0
      SET @c_alfa = ISNULL(POS_SERVER.dbo.fn_calculate_total_Alfa_detail(@from, @to, @nik), '-');

    SET @bitparam = (
      SELECT '2002500' responseCode, N'success' responseMessage,
        JSON_QUERY((
          SELECT
              @dept AS dept_id
            , @nik AS nik
            , @nama AS employee_name
            , @jabatan AS jabatan
            , @c_kr AS content_kehadiran_reguler
            , @c_d_wd AS content_disiplin_wd
            , @c_d_wk AS content_disiplin_wk
            , @c_d_hd AS content_disiplin_hd
            , @c_t_wd AS content_transport_wd
            , @c_t_wk AS content_transport_wk
            , @c_t_hd AS content_transport_hd
            , @c_izin AS content_izin
            , @c_sakit AS content_sakit
            , @c_cuti AS content_cuti
            , @c_l_wd AS content_lembur_wd
            , @c_l_wk AS content_lembur_wk
            , @c_l_hd AS content_lembur_hd
            , @c_alfa AS content_alfa
            , CONVERT(char(10), @from, 23) AS from_date
            , CONVERT(char(10), @to, 23) AS to_date
            , @group AS [group]
          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) data
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
  END TRY
  BEGIN CATCH
    SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END CATCH
END
GO

/* One detail section — Go runs these in parallel. */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_absen_report_nasional_detail_section', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_detail_section;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_absen_report_nasional_detail_section
(   @p_from_date varchar(30)=NULL
, @p_to_date varchar(30)=NULL
, @p_nik varchar(30)=NULL
, @p_section varchar(30)=NULL
, @p_tr int=0
, @bitparam varchar(max) OUTPUT )
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    DECLARE @from datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_from_date)), ''));
    DECLARE @to   datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_to_date)), ''));
    DECLARE @nik varchar(30) = NULLIF(LTRIM(RTRIM(@p_nik)), '');
    DECLARE @sec varchar(30) = LOWER(ISNULL(@p_section,''));
    DECLARE @html varchar(max) = '-';

    IF @sec = 'kr'
      SET @html = ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_reguler_detail(@from,@to,@nik), '-');
    ELSE IF @sec = 'd_wd'
      SET @html =
          ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_detail(@from,@to,@nik), '-')
        + '<br/> <hr class="divider">Special Activity <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_special_day_pulang_cepet_transport_detail(@from,@to,@nik,0), '-')
        + '<br/> <hr class="divider">Dinas Weekday <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas_detail(@from,@to,@nik), '-')
        + '<p/>';
    ELSE IF @sec = 'd_wk'
      SET @html =
          ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_kehadiran_detail(@from,@to,@nik), '-')
        + '<br/> <hr class="divider">Dinas Weekend <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas_wk_detail(@from,@to,@nik), '-')
        + '<p/>';
    ELSE IF @sec = 'd_hd'
      SET @html =
          ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_kehadiran_detail(@from,@to,@nik), '-')
        + '<br/> <hr class="divider">Dinas Holiday <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_kehadiran_dinas_hd_detail(@from,@to,@nik), '-')
        + '<p/>';
    ELSE IF @sec = 't_wd'
      SET @html =
          '<p> Reguler<hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_transport_detail(@from,@to,@nik), '-')
        + ' <hr class="divider">   (In = Out) <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_cuma_absen_masuk_detail(@from,@to,@nik,@p_tr), '-')
        + '<br/> <hr class="divider">Special Activity <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_special_day_pulang_cepet_transport_detail(@from,@to,@nik,@p_tr), '-')
        + '<br/> <hr class="divider">Dinas Weekday <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_all_day_transport_dinas_detail(@from,@to,@nik), '-')
        + '<p/>';
    ELSE IF @sec = 't_wk'
      SET @html =
          ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_transport_detail(@from,@to,@nik), '-')
        + '<br/> <hr class="divider">Dinas Weekend <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_weekend_transport_dinas_detail(@from,@to,@nik), '-')
        + '<p/>';
    ELSE IF @sec = 't_hd'
      SET @html =
          ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_transport_detail(@from,@to,@nik), '-')
        + '<br/> <hr class="divider">Dinas Holiday <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_rekap_lembur_holiday_transport_dinas_detail(@from,@to,@nik), '-')
        + '<p/>';
    ELSE IF @sec = 'izin'
      SET @html =
          '<p> Tidak Masuk Kerja<hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_total_izin_day_detail(@from,@to,@nik), '-')
        + '<br/> <hr class="divider">Telat/Meninggalkan Ruangan <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_total_izin_tiggal_ruangan_dan_telat_masuk_day_detail(@from,@to,@nik), '-')
        + '<p/>';
    ELSE IF @sec = 'sakit'
      SET @html = ISNULL(POS_SERVER.dbo.fn_calculate_total_sick_day_detail(@from,@to,@nik), '-');
    ELSE IF @sec = 'cuti'
      SET @html =
          ISNULL(POS_SERVER.dbo.fn_calculate_total_cuti_day_detail(@from,@to,@nik), '-')
        + '<br/> <hr class="divider">Cuti Melahirkan <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_total_cuti_melahirkan_detail(@from,@to,@nik), '-')
        + '<br/> <hr class="divider">Cuti Khusus <hr class="divider">'
        + ISNULL(POS_SERVER.dbo.fn_calculate_total_cuti_khusus_detail(@from,@to,@nik), '-');
    ELSE IF @sec = 'l_wd'
      SET @html = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_day_detail(@from,@to,@nik), '-');
    ELSE IF @sec = 'l_wk'
      SET @html = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_weekend_day_detail(@from,@to,@nik), '-');
    ELSE IF @sec = 'l_hd'
      SET @html = ISNULL(POS_SERVER.dbo.fn_calculate_total_lembur_holiday_day_detail(@from,@to,@nik), '-');
    ELSE IF @sec = 'alfa'
      SET @html = ISNULL(POS_SERVER.dbo.fn_calculate_total_Alfa_detail(@from,@to,@nik), '-');

    SET @bitparam = (
      SELECT '2002500' responseCode, N'success' responseMessage,
        @sec AS section, @html AS html
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
  END TRY
  BEGIN CATCH
    SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END CATCH
END
GO
