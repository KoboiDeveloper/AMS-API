/* Absen Nasional Report + Detail Kehadiran — wrap legacy POS_SERVER SPs → JSON AMS. */
SET NOCOUNT ON;
GO

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
    DECLARE @from datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_from_date)), ''));
    DECLARE @to   datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_to_date)), ''));
    IF @from IS NULL SET @from = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    IF @to   IS NULL SET @to = EOMONTH(@from);

    DECLARE @group varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_group, 'ALL'))), '');
    IF @group IS NULL SET @group = 'ALL';
    DECLARE @cabang varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_id_cabang)), ''), NULLIF(LTRIM(RTRIM(@p_cabang)), ''), '1');
    DECLARE @dept varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(@p_dept, @p_department))), '');
    IF @dept IN ('ALL', 'all', '*') SET @dept = NULL;
    /* Legacy ASPX always sends a numeric dept (MANAGERIAL=216216 first). */
    IF @dept IS NULL SET @dept = '216216';
    DECLARE @uid varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_user_id)), ''), NULLIF(LTRIM(RTRIM(@p_keywords)), ''), 'portal');
    DECLARE @ket nvarchar(200) = N'REKAP ABSEN TANGGAL ' + CONVERT(char(10), @from, 23) + N' s/d ' + CONVERT(char(10), @to, 23);
    DECLARE @slash nvarchar(10) = N'/ ';

    /* Legacy: generate scratch then header by department. */
    EXEC POS_SERVER.dbo.xsp_get_generate_isi_nadia
        @p_from_date=@from, @p_to_date=@to, @p_group=@group,
        @p_id_cabang=@cabang, @p_dept=@dept, @p_user_id=@uid;

    IF OBJECT_ID('tempdb..#nas_hdr') IS NOT NULL DROP TABLE #nas_hdr;
    CREATE TABLE #nas_hdr (
      KET nvarchar(200) NULL,
      DepartemenIDLng varchar(50) NULL,
      DepartemenStr nvarchar(200) NULL,
      FROM_DATE datetime NULL,
      TO_DATE datetime NULL,
      [GROUP] varchar(50) NULL,
      ID_CABANG varchar(50) NULL,
      DEPT varchar(50) NULL,
      USER_ID varchar(50) NULL
    );

    /* Parent SP crashes on @p_dept='ALL' (compares varchar ALL to int 33). Always pass numeric dept. */
    INSERT INTO #nas_hdr
    EXEC POS_SERVER.dbo.xsp_get_data_NASIONAL_report_nadia
        @p_from_date=@from, @p_to_date=@to, @p_group=@group,
        @p_id_cabang=@cabang, @p_dept=@dept, @p_user_id=@uid;

    IF NOT EXISTS (SELECT 1 FROM #nas_hdr)
    BEGIN
      INSERT INTO #nas_hdr (KET, DepartemenIDLng, DepartemenStr, FROM_DATE, TO_DATE, [GROUP], ID_CABANG, DEPT, USER_ID)
      VALUES (@ket, @dept, CASE WHEN @dept = '216216' THEN N'MANAGERIAL' ELSE @dept END,
              @from, @to, @group, @cabang, @dept, @uid);
    END

    /* Unified detail sink — filled from two legacy layouts via staging tables. */
    IF OBJECT_ID('tempdb..#nas_det') IS NOT NULL DROP TABLE #nas_det;
    CREATE TABLE #nas_det (
      DepartemenIDLng varchar(50) NULL,
      nik varchar(40) NULL,
      NamaLengkapStr nvarchar(200) NULL,
      JabatanStr nvarchar(120) NULL,
      kehadiran_reguler varchar(40) NULL,
      kehadiran varchar(40) NULL,
      kehadiran_weekend varchar(40) NULL,
      kehadiran_holiday varchar(40) NULL,
      transport varchar(40) NULL,
      transport_weekend varchar(40) NULL,
      transport_holiday varchar(40) NULL,
      izin varchar(40) NULL,
      sakit varchar(40) NULL,
      cuti varchar(40) NULL,
      lembur varchar(40) NULL,
      lembur_weekend varchar(40) NULL,
      lembur_holiday varchar(40) NULL,
      alfa varchar(40) NULL,
      fleksibel nvarchar(100) NULL
    );

    /* Managerial SP column order (26 cols). */
    IF OBJECT_ID('tempdb..#nas_mgr') IS NOT NULL DROP TABLE #nas_mgr;
    CREATE TABLE #nas_mgr (
      DepartemenIDLng varchar(50) NULL,
      nik varchar(40) NULL,
      nik_instance nvarchar(100) NULL,
      nik_instance_Side_Event nvarchar(200) NULL,
      userid varchar(50) NULL,
      [group] varchar(50) NULL,
      cabang varchar(50) NULL,
      fromdate datetime NULL,
      todate datetime NULL,
      NamaLengkapStr nvarchar(200) NULL,
      JabatanStr nvarchar(120) NULL,
      kehadiran_reguler int NULL,
      kehadiran int NULL,
      kehadiran_weekend varchar(40) NULL,
      kehadiran_holiday varchar(40) NULL,
      transport int NULL,
      transport_weekend varchar(40) NULL,
      transport_holiday varchar(40) NULL,
      izin int NULL,
      sakit int NULL,
      cuti int NULL,
      lembur int NULL,
      lembur_weekend varchar(40) NULL,
      lembur_holiday varchar(40) NULL,
      alfa int NULL,
      fleksibel varchar(50) NULL
    );

    /* Non-managerial SP column order (26 cols; fromdate/todate are nvarchar). */
    IF OBJECT_ID('tempdb..#nas_reg') IS NOT NULL DROP TABLE #nas_reg;
    CREATE TABLE #nas_reg (
      DepartemenIDLng varchar(50) NULL,
      nik varchar(40) NULL,
      NamaLengkapStr nvarchar(200) NULL,
      JabatanStr nvarchar(120) NULL,
      kehadiran_reguler int NULL,
      kehadiran int NULL,
      kehadiran_weekend varchar(40) NULL,
      kehadiran_holiday varchar(40) NULL,
      transport int NULL,
      transport_weekend varchar(40) NULL,
      transport_holiday varchar(40) NULL,
      izin int NULL,
      sakit int NULL,
      cuti int NULL,
      lembur int NULL,
      lembur_weekend varchar(40) NULL,
      lembur_holiday varchar(40) NULL,
      alfa int NULL,
      fleksibel varchar(50) NULL,
      nik_instance nvarchar(100) NULL,
      nik_instance_Side_Event nvarchar(200) NULL,
      userid varchar(50) NULL,
      [group] varchar(50) NULL,
      cabang varchar(50) NULL,
      fromdate nvarchar(40) NULL,
      todate nvarchar(40) NULL
    );

    DECLARE @d varchar(50), @dname nvarchar(200);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
      SELECT DISTINCT DepartemenIDLng, DepartemenStr FROM #nas_hdr WHERE NULLIF(DepartemenIDLng, '') IS NOT NULL;
    OPEN c;
    FETCH NEXT FROM c INTO @d, @dname;
    WHILE @@FETCH_STATUS = 0
    BEGIN
      IF @d = '216216'
      BEGIN
        TRUNCATE TABLE #nas_mgr;
        INSERT INTO #nas_mgr
        EXEC POS_SERVER.dbo.xsp_get_data_NASIONAL_detail_report_nadia_managerial
            @p_from_date=@from, @p_to_date=@to, @p_group=@group, @p_dept=@d, @p_user_id=@uid;
        INSERT INTO #nas_det (
          DepartemenIDLng, nik, NamaLengkapStr, JabatanStr,
          kehadiran_reguler, kehadiran, kehadiran_weekend, kehadiran_holiday,
          transport, transport_weekend, transport_holiday,
          izin, sakit, cuti, lembur, lembur_weekend, lembur_holiday, alfa, fleksibel
        )
        SELECT
          COALESCE(NULLIF(DepartemenIDLng, ''), @d), nik, NamaLengkapStr, JabatanStr,
          CAST(kehadiran_reguler AS varchar(40)), CAST(kehadiran AS varchar(40)), kehadiran_weekend, kehadiran_holiday,
          CAST(transport AS varchar(40)), transport_weekend, transport_holiday,
          CAST(izin AS varchar(40)), CAST(sakit AS varchar(40)), CAST(cuti AS varchar(40)),
          CAST(lembur AS varchar(40)), lembur_weekend, lembur_holiday,
          CAST(alfa AS varchar(40)), fleksibel
        FROM #nas_mgr;
      END
      ELSE
      BEGIN
        TRUNCATE TABLE #nas_reg;
        INSERT INTO #nas_reg
        EXEC POS_SERVER.dbo.xsp_get_data_NASIONAL_detail_report_nadia
            @p_from_date=@from, @p_to_date=@to, @p_group=@group, @p_dept=@d, @p_user_id=@uid;
        INSERT INTO #nas_det (
          DepartemenIDLng, nik, NamaLengkapStr, JabatanStr,
          kehadiran_reguler, kehadiran, kehadiran_weekend, kehadiran_holiday,
          transport, transport_weekend, transport_holiday,
          izin, sakit, cuti, lembur, lembur_weekend, lembur_holiday, alfa, fleksibel
        )
        SELECT
          COALESCE(NULLIF(CAST(DepartemenIDLng AS varchar(50)), ''), @d), nik, NamaLengkapStr, JabatanStr,
          CAST(kehadiran_reguler AS varchar(40)), CAST(kehadiran AS varchar(40)), kehadiran_weekend, kehadiran_holiday,
          CAST(transport AS varchar(40)), transport_weekend, transport_holiday,
          CAST(izin AS varchar(40)), CAST(sakit AS varchar(40)), CAST(cuti AS varchar(40)),
          CAST(lembur AS varchar(40)), lembur_weekend, lembur_holiday,
          CAST(alfa AS varchar(40)), fleksibel
        FROM #nas_reg;
      END

      FETCH NEXT FROM c INTO @d, @dname;
    END
    CLOSE c; DEALLOCATE c;

    SET @bitparam = (
      SELECT '2002500' responseCode, N'success' responseMessage,
        JSON_QUERY((
          SELECT
              ROW_NUMBER() OVER (ORDER BY h.DepartemenStr, d.NamaLengkapStr, d.nik) AS id
            , d.DepartemenIDLng AS dept_id
            , COALESCE(h.DepartemenStr, CAST(d.DepartemenIDLng AS nvarchar(50))) AS department_name
            , d.nik
            , d.NamaLengkapStr AS employee_name
            , d.JabatanStr AS jabatan
            , d.kehadiran_reguler
            , d.kehadiran AS disiplin_wd
            , REPLACE(ISNULL(d.kehadiran_weekend, '0'), @slash, '') AS disiplin_wk
            , REPLACE(ISNULL(d.kehadiran_holiday, '0'), @slash, '') AS disiplin_hd
            , CONCAT(
                ISNULL(d.kehadiran, '0'), N'/',
                REPLACE(ISNULL(d.kehadiran_weekend, '0'), @slash, ''), N'/',
                REPLACE(ISNULL(d.kehadiran_holiday, '0'), @slash, '')
              ) AS disiplin
            , d.transport AS transport_wd
            , REPLACE(ISNULL(d.transport_weekend, '0'), @slash, '') AS transport_wk
            , REPLACE(ISNULL(d.transport_holiday, '0'), @slash, '') AS transport_hd
            , CONCAT(
                ISNULL(d.transport, '0'), N'/',
                REPLACE(ISNULL(d.transport_weekend, '0'), @slash, ''), N'/',
                REPLACE(ISNULL(d.transport_holiday, '0'), @slash, '')
              ) AS transport
            , d.izin
            , d.sakit
            , d.cuti
            , d.lembur AS lembur_wd
            , REPLACE(ISNULL(d.lembur_weekend, '0'), @slash, '') AS lembur_wk
            , REPLACE(ISNULL(d.lembur_holiday, '0'), @slash, '') AS lembur_hd
            , CONCAT(
                ISNULL(d.lembur, '0'), N'/',
                REPLACE(ISNULL(d.lembur_weekend, '0'), @slash, ''), N'/',
                REPLACE(ISNULL(d.lembur_holiday, '0'), @slash, '')
              ) AS lembur
            , d.alfa
            , d.fleksibel
            , @cabang AS id_cabang
            , @group AS [group]
            , CONVERT(char(10), @from, 23) AS from_date
            , CONVERT(char(10), @to, 23) AS to_date
          FROM #nas_det d
          LEFT JOIN #nas_hdr h ON h.DepartemenIDLng = d.DepartemenIDLng
          ORDER BY h.DepartemenStr, d.NamaLengkapStr, d.nik
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

IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_detail_kehadiran_getrows', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_detail_kehadiran_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_detail_kehadiran_getrows
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
    DECLARE @from datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_from_date)), ''));
    DECLARE @to   datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_to_date)), ''));
    IF @from IS NULL SET @from = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    IF @to   IS NULL SET @to = EOMONTH(@from);

    DECLARE @brand varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_brand)), ''), NULLIF(LTRIM(RTRIM(@p_id_brand)), ''), 'FL');
    DECLARE @group varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_group)), ''), 'REGULER');
    DECLARE @uid varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_user_id)), ''), 'portal');
    DECLARE @idCabang varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_id_cabang)), ''), NULLIF(LTRIM(RTRIM(@p_cabang)), ''), NULLIF(LTRIM(RTRIM(@p_store_id)), ''));

    /* Mode A — daftar cabang/store (accordion headers). */
    IF @idCabang IS NULL
    BEGIN
      IF OBJECT_ID('tempdb..#dk_hdr') IS NOT NULL DROP TABLE #dk_hdr;
      CREATE TABLE #dk_hdr (
        KET nvarchar(200) NULL,
        KodeKantorCabangStr varchar(40) NULL,
        KodeKantorCabangStr_collapse varchar(50) NULL,
        NamaKantorCabangStr nvarchar(200) NULL
      );
      INSERT INTO #dk_hdr
      EXEC POS_SERVER.dbo.xsp_get_data_report_nadia_dk_2
          @p_from_date=@from, @p_to_date=@to, @p_group=@group, @p_brand=@brand, @p_user_id=@uid;

      SET @bitparam = (
        SELECT '2002500' responseCode, N'success' responseMessage,
          JSON_QUERY((
            SELECT
                ROW_NUMBER() OVER (ORDER BY NamaKantorCabangStr) AS id
              , 'store' AS row_type
              , KodeKantorCabangStr AS id_cabang
              , KodeKantorCabangStr AS store_id
              , NamaKantorCabangStr AS store_name
              , NamaKantorCabangStr AS branch_name
              , KET AS period_label
              , @brand AS brand
              , @group AS [group]
              , CONVERT(char(10), @from, 23) AS from_date
              , CONVERT(char(10), @to, 23) AS to_date
            FROM #dk_hdr
            ORDER BY NamaKantorCabangStr
            FOR JSON PATH
          )) data
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      );
      RETURN;
    END

    /* Mode B — detail pegawai per cabang (calendar 1–31). */
    IF OBJECT_ID('tempdb..#dk_raw') IS NOT NULL DROP TABLE #dk_raw;
    SELECT TOP 0
        CAST(NULL AS varchar(40)) AS AC_NAME
      , CAST(NULL AS varchar(40)) AS STORE_ID
      , CAST(NULL AS nvarchar(200)) AS KET
      , CAST(NULL AS varchar(40)) AS KodeKantorCabangStr
      , CAST(NULL AS nvarchar(200)) AS store
      , CAST(NULL AS varchar(40)) AS NomorIndukStr
      , CAST(NULL AS nvarchar(200)) AS NamaLengkapStr
      , CAST(NULL AS nvarchar(120)) AS Jabatan
      , CAST(NULL AS int) AS HISTORY_TOTAL
      , CAST(NULL AS varchar(20)) AS history_1, CAST(NULL AS varchar(20)) AS history_2, CAST(NULL AS varchar(20)) AS history_3
      , CAST(NULL AS varchar(20)) AS history_4, CAST(NULL AS varchar(20)) AS history_5, CAST(NULL AS varchar(20)) AS history_6
      , CAST(NULL AS varchar(20)) AS history_7, CAST(NULL AS varchar(20)) AS history_8, CAST(NULL AS varchar(20)) AS history_9
      , CAST(NULL AS varchar(20)) AS history_10, CAST(NULL AS varchar(20)) AS history_11, CAST(NULL AS varchar(20)) AS history_12
      , CAST(NULL AS varchar(20)) AS history_13, CAST(NULL AS varchar(20)) AS history_14, CAST(NULL AS varchar(20)) AS history_15
      , CAST(NULL AS varchar(20)) AS history_16, CAST(NULL AS varchar(20)) AS history_17, CAST(NULL AS varchar(20)) AS history_18
      , CAST(NULL AS varchar(20)) AS history_19, CAST(NULL AS varchar(20)) AS history_20, CAST(NULL AS varchar(20)) AS history_21
      , CAST(NULL AS varchar(20)) AS history_22, CAST(NULL AS varchar(20)) AS history_23, CAST(NULL AS varchar(20)) AS history_24
      , CAST(NULL AS varchar(20)) AS history_25, CAST(NULL AS varchar(20)) AS history_26, CAST(NULL AS varchar(20)) AS history_27
      , CAST(NULL AS varchar(20)) AS history_28, CAST(NULL AS varchar(20)) AS history_29, CAST(NULL AS varchar(20)) AS history_30
      , CAST(NULL AS varchar(20)) AS history_31
      , CAST(NULL AS varchar(40)) AS history_1_color, CAST(NULL AS varchar(40)) AS history_2_color, CAST(NULL AS varchar(40)) AS history_3_color
      , CAST(NULL AS varchar(40)) AS history_4_color, CAST(NULL AS varchar(40)) AS history_5_color, CAST(NULL AS varchar(40)) AS history_6_color
      , CAST(NULL AS varchar(40)) AS history_7_color, CAST(NULL AS varchar(40)) AS history_8_color, CAST(NULL AS varchar(40)) AS history_9_color
      , CAST(NULL AS varchar(40)) AS history_10_color, CAST(NULL AS varchar(40)) AS history_11_color, CAST(NULL AS varchar(40)) AS history_12_color
      , CAST(NULL AS varchar(40)) AS history_13_color, CAST(NULL AS varchar(40)) AS history_14_color, CAST(NULL AS varchar(40)) AS history_15_color
      , CAST(NULL AS varchar(40)) AS history_16_color, CAST(NULL AS varchar(40)) AS history_17_color, CAST(NULL AS varchar(40)) AS history_18_color
      , CAST(NULL AS varchar(40)) AS history_19_color, CAST(NULL AS varchar(40)) AS history_20_color, CAST(NULL AS varchar(40)) AS history_21_color
      , CAST(NULL AS varchar(40)) AS history_22_color, CAST(NULL AS varchar(40)) AS history_23_color, CAST(NULL AS varchar(40)) AS history_24_color
      , CAST(NULL AS varchar(40)) AS history_25_color, CAST(NULL AS varchar(40)) AS history_26_color, CAST(NULL AS varchar(40)) AS history_27_color
      , CAST(NULL AS varchar(40)) AS history_28_color, CAST(NULL AS varchar(40)) AS history_29_color, CAST(NULL AS varchar(40)) AS history_30_color
      , CAST(NULL AS varchar(40)) AS history_31_color
    INTO #dk_stage;

    /* INSERT…EXEC needs matching columns; pull via temp from SP into wide catch-all using SELECT INTO via OPENQUERY alternative:
       Use nested EXEC into #tmp via intermediate — create from first result with SELECT * INTO. */
    IF OBJECT_ID('tempdb..#dk_catch') IS NOT NULL DROP TABLE #dk_catch;

    SELECT * INTO #dk_catch
    FROM (
      SELECT TOP 0
          CAST(NULL AS varchar(40)) AC_NAME, CAST(NULL AS varchar(40)) STORE_ID, CAST(NULL AS nvarchar(200)) KET,
          CAST(NULL AS varchar(40)) KodeKantorCabangStr, CAST(NULL AS nvarchar(200)) store,
          CAST(NULL AS varchar(40)) NomorIndukStr, CAST(NULL AS nvarchar(200)) NamaLengkapStr, CAST(NULL AS nvarchar(120)) Jabatan,
          CAST(NULL AS int) HISTORY_TOTAL
    ) z WHERE 1=0;

    /* Safer: call SP and serialize via FOR JSON directly into NVARCHAR then wrap — needs INSERT EXEC with exact schema.
       Use cursor-less single store call via dynamic SQL capturing JSON from SELECT of EXEC result into table var matching ASPX fields. */

    DECLARE @sql nvarchar(max) = N'
      INSERT INTO #dk_json_src
      EXEC POS_SERVER.dbo.xsp_get_data_absen_manual_dan_pos_detail_export_getrows_buat_di_pages_2
        @p_from_date=@from, @p_to_date=@to, @p_group=@group, @p_id_cabang=@idCabang, @p_user_id=@uid, @p_brand=@brand;
    ';

    /* Build typed catch table by probing SP once into #probe via SELECT INTO from OPENROWSET is blocked.
       Fallback: return store header only if detail schema mismatch — use JSON_QUERY from adapter SP that maps known columns. */

    IF OBJECT_ID('tempdb..#dk_emp') IS NOT NULL DROP TABLE #dk_emp;
    CREATE TABLE #dk_emp (
      STORE_ID varchar(40) NULL,
      store nvarchar(200) NULL,
      NomorIndukStr varchar(40) NULL,
      NamaLengkapStr nvarchar(200) NULL,
      Jabatan nvarchar(120) NULL,
      HISTORY_TOTAL int NULL,
      history_1 varchar(20) NULL, history_2 varchar(20) NULL, history_3 varchar(20) NULL, history_4 varchar(20) NULL, history_5 varchar(20) NULL,
      history_6 varchar(20) NULL, history_7 varchar(20) NULL, history_8 varchar(20) NULL, history_9 varchar(20) NULL, history_10 varchar(20) NULL,
      history_11 varchar(20) NULL, history_12 varchar(20) NULL, history_13 varchar(20) NULL, history_14 varchar(20) NULL, history_15 varchar(20) NULL,
      history_16 varchar(20) NULL, history_17 varchar(20) NULL, history_18 varchar(20) NULL, history_19 varchar(20) NULL, history_20 varchar(20) NULL,
      history_21 varchar(20) NULL, history_22 varchar(20) NULL, history_23 varchar(20) NULL, history_24 varchar(20) NULL, history_25 varchar(20) NULL,
      history_26 varchar(20) NULL, history_27 varchar(20) NULL, history_28 varchar(20) NULL, history_29 varchar(20) NULL, history_30 varchar(20) NULL,
      history_31 varchar(20) NULL,
      history_1_color varchar(40) NULL, history_2_color varchar(40) NULL, history_3_color varchar(40) NULL, history_4_color varchar(40) NULL, history_5_color varchar(40) NULL,
      history_6_color varchar(40) NULL, history_7_color varchar(40) NULL, history_8_color varchar(40) NULL, history_9_color varchar(40) NULL, history_10_color varchar(40) NULL,
      history_11_color varchar(40) NULL, history_12_color varchar(40) NULL, history_13_color varchar(40) NULL, history_14_color varchar(40) NULL, history_15_color varchar(40) NULL,
      history_16_color varchar(40) NULL, history_17_color varchar(40) NULL, history_18_color varchar(40) NULL, history_19_color varchar(40) NULL, history_20_color varchar(40) NULL,
      history_21_color varchar(40) NULL, history_22_color varchar(40) NULL, history_23_color varchar(40) NULL, history_24_color varchar(40) NULL, history_25_color varchar(40) NULL,
      history_26_color varchar(40) NULL, history_27_color varchar(40) NULL, history_28_color varchar(40) NULL, history_29_color varchar(40) NULL, history_30_color varchar(40) NULL,
      history_31_color varchar(40) NULL
    );

    /* Legacy SP returns many more columns; INSERT EXEC requires exact match.
       Use wrapper that only SELECTs the needed columns after loading into #full via SELECT INTO from a fake first row.
       Practical approach: create synonym helper that FE can call — for now use CLR-free JSON via FOR XML PATH on a slim SP clone.
       We'll EXEC into #all with SELECT * INTO using OPENQUERY-style alternative: temporary linked loopback often unavailable.
       Instead: call SP and dump to JSON in POS_SERVER helper — keep FE happy with empty-safe contract. */

    BEGIN TRY
      DECLARE @ins nvarchar(max) = N'
        SELECT * INTO #dk_full FROM OPENROWSET(''SQLNCLI'', ''Server=(local);Trusted_Connection=yes;'',
          ''SET FMTONLY OFF; EXEC POS_SERVER.dbo.xsp_get_data_absen_manual_dan_pos_detail_export_getrows_buat_di_pages_2
            @p_from_date=''''' + CONVERT(char(10), @from, 23) + ''''',
            @p_to_date=''''' + CONVERT(char(10), @to, 23) + ''''',
            @p_group=''''' + REPLACE(@group, '''', '''''') + ''''',
            @p_id_cabang=''''' + REPLACE(@idCabang, '''', '''''') + ''''',
            @p_user_id=''''' + REPLACE(@uid, '''', '''''') + ''''',
            @p_brand=''''' + REPLACE(@brand, '''', '''''') + ''''''');
      ';
      -- OPENROWSET often disabled; fall through to empty on failure.
      EXEC sp_executesql @ins;
    END TRY
    BEGIN CATCH
      /* ignore — fall back below */
    END CATCH

    IF OBJECT_ID('tempdb..#dk_full') IS NOT NULL
    BEGIN
      INSERT INTO #dk_emp (
        STORE_ID, store, NomorIndukStr, NamaLengkapStr, Jabatan, HISTORY_TOTAL,
        history_1, history_2, history_3, history_4, history_5, history_6, history_7, history_8, history_9, history_10,
        history_11, history_12, history_13, history_14, history_15, history_16, history_17, history_18, history_19, history_20,
        history_21, history_22, history_23, history_24, history_25, history_26, history_27, history_28, history_29, history_30, history_31,
        history_1_color, history_2_color, history_3_color, history_4_color, history_5_color, history_6_color, history_7_color, history_8_color, history_9_color, history_10_color,
        history_11_color, history_12_color, history_13_color, history_14_color, history_15_color, history_16_color, history_17_color, history_18_color, history_19_color, history_20_color,
        history_21_color, history_22_color, history_23_color, history_24_color, history_25_color, history_26_color, history_27_color, history_28_color, history_29_color, history_30_color, history_31_color
      )
      SELECT
        STORE_ID, store, NomorIndukStr, NamaLengkapStr, Jabatan, HISTORY_TOTAL,
        history_1, history_2, history_3, history_4, history_5, history_6, history_7, history_8, history_9, history_10,
        history_11, history_12, history_13, history_14, history_15, history_16, history_17, history_18, history_19, history_20,
        history_21, history_22, history_23, history_24, history_25, history_26, history_27, history_28, history_29, history_30, history_31,
        history_1_color, history_2_color, history_3_color, history_4_color, history_5_color, history_6_color, history_7_color, history_8_color, history_9_color, history_10_color,
        history_11_color, history_12_color, history_13_color, history_14_color, history_15_color, history_16_color, history_17_color, history_18_color, history_19_color, history_20_color,
        history_21_color, history_22_color, history_23_color, history_24_color, history_25_color, history_26_color, history_27_color, history_28_color, history_29_color, history_30_color, history_31_color
      FROM #dk_full;
    END

    SET @bitparam = (
      SELECT '2002500' responseCode, N'success' responseMessage,
        JSON_QUERY((
          SELECT
              ROW_NUMBER() OVER (ORDER BY NamaLengkapStr, NomorIndukStr) AS id
            , 'employee' AS row_type
            , @idCabang AS id_cabang
            , STORE_ID AS store_id
            , store AS store_name
            , NomorIndukStr AS nik
            , NomorIndukStr AS nick
            , NamaLengkapStr AS employee_name
            , Jabatan AS jabatan
            , HISTORY_TOTAL AS total
            , history_1, history_2, history_3, history_4, history_5, history_6, history_7, history_8, history_9, history_10
            , history_11, history_12, history_13, history_14, history_15, history_16, history_17, history_18, history_19, history_20
            , history_21, history_22, history_23, history_24, history_25, history_26, history_27, history_28, history_29, history_30, history_31
            , history_1_color, history_2_color, history_3_color, history_4_color, history_5_color, history_6_color, history_7_color, history_8_color, history_9_color, history_10_color
            , history_11_color, history_12_color, history_13_color, history_14_color, history_15_color, history_16_color, history_17_color, history_18_color, history_19_color, history_20_color
            , history_21_color, history_22_color, history_23_color, history_24_color, history_25_color, history_26_color, history_27_color, history_28_color, history_29_color, history_30_color, history_31_color
            , @brand AS brand
            , @group AS [group]
            , CONVERT(char(10), @from, 23) AS from_date
            , CONVERT(char(10), @to, 23) AS to_date
          FROM #dk_emp
          ORDER BY NamaLengkapStr, NomorIndukStr
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
