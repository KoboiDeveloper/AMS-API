/* Detail Kehadiran (AbsenDk) — absensi info modal + DATA AKHIR day update + enrich emp JSON. */
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* ── Modal: punch history for one NIK (legacy AbsensiStoreInfo_lookup) ── */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_detail_kehadiran_absensi_info_getrows', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_detail_kehadiran_absensi_info_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_detail_kehadiran_absensi_info_getrows
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
, @p_nik varchar(50)=NULL
, @bitparam varchar(max) OUTPUT )
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    DECLARE @nik varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(@p_nik, @p_keywords))), '');
    DECLARE @from datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_from_date)), ''));
    DECLARE @to   datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(@p_to_date)), ''));
    IF @nik IS NULL
    BEGIN
      SET @bitparam = (SELECT '4002500' responseCode, N'nik wajib' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
      RETURN;
    END
    IF @from IS NULL SET @from = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
    IF @to   IS NULL SET @to = EOMONTH(@from);

    IF OBJECT_ID('tempdb..#dk_info') IS NOT NULL DROP TABLE #dk_info;
    CREATE TABLE #dk_info (
      WAKTU datetime NULL,
      STORE_ID varchar(40) NULL
    );
    INSERT INTO #dk_info (WAKTU, STORE_ID)
    EXEC POS_SERVER.dbo.XSP_get_info_absensi_store_getrows
        @p_nik=@nik, @p_from_date=@from, @p_to_date=@to;

    SET @bitparam = (
      SELECT '2002500' responseCode, N'success' responseMessage,
        JSON_QUERY((
          SELECT
              ROW_NUMBER() OVER (ORDER BY WAKTU DESC) AS id
            , CONVERT(varchar(19), WAKTU, 120) AS waktu
            , CONVERT(varchar(10), WAKTU, 23) AS tanggal
            , STORE_ID AS store_id
          FROM #dk_info
          ORDER BY WAKTU DESC
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

/* ── DATA AKHIR day toggle: HADIR (1) / TIDAK (0) ── */
IF OBJECT_ID(N'dbo.xsp_ams_new_hrd_detail_kehadiran_akhir_update', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_ams_new_hrd_detail_kehadiran_akhir_update;
GO
CREATE PROCEDURE dbo.xsp_ams_new_hrd_detail_kehadiran_akhir_update
(   @p_payload nvarchar(max)=NULL
, @p_created_by varchar(50)=NULL
, @p_actor_nik varchar(50)=NULL
, @bitparam varchar(max) OUTPUT )
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY
    DECLARE @j nvarchar(max) = ISNULL(@p_payload, N'{}');
    DECLARE @nik varchar(20) = NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.nik'), JSON_VALUE(@j,'$.p_nik')))), '');
    DECLARE @store varchar(20) = NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.store_id'), JSON_VALUE(@j,'$.p_store_id')))), '');
    DECLARE @tgl varchar(2) = NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.tgl'), JSON_VALUE(@j,'$.p_tgl'), JSON_VALUE(@j,'$.day')))), '');
    DECLARE @typeAbsensi int = TRY_CAST(COALESCE(JSON_VALUE(@j,'$.typeAbsensi'), JSON_VALUE(@j,'$.type_absensi'), JSON_VALUE(@j,'$.value')) AS int);
    DECLARE @pDate datetime = TRY_CONVERT(datetime, NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(@j,'$.date'), JSON_VALUE(@j,'$.p_date'), JSON_VALUE(@j,'$.from_date')))), ''));

    IF @nik IS NULL OR @store IS NULL OR @tgl IS NULL OR @typeAbsensi IS NULL OR @pDate IS NULL
    BEGIN
      SET @bitparam = (SELECT '4002500' responseCode, N'nik, store_id, tgl, typeAbsensi, date wajib' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
      RETURN;
    END
    IF @typeAbsensi NOT IN (0, 1)
    BEGIN
      SET @bitparam = (SELECT '4002500' responseCode, N'typeAbsensi harus 0 atau 1' responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
      RETURN;
    END

    EXEC POS_SERVER.dbo.xsp_data_akhir_absen_store_update
        @p_store_id=@store
      , @typeAbsensi=@typeAbsensi
      , @p_nik=@nik
      , @p_tgl=@tgl
      , @p_date=@pDate;

    SET @bitparam = (
      SELECT '2002500' responseCode
           , CASE WHEN @typeAbsensi = 1 THEN N'HADIR tersimpan' ELSE N'TIDAK MASUK tersimpan' END responseMessage
           , @nik AS nik
           , @store AS store_id
           , @tgl AS tgl
           , @typeAbsensi AS typeAbsensi
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
  END TRY
  BEGIN CATCH
    SET @bitparam = (SELECT '4002500' responseCode, ERROR_MESSAGE() responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
  END CATCH
END
GO

/* ── Enrich employee JSON: include MANUAL (M_*) + DATA AKHIR (1..31) ── */
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

    DECLARE @brand varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_brand)), ''), NULLIF(LTRIM(RTRIM(@p_id_brand)), ''), 'RC');
    DECLARE @group varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_group)), ''), 'REGULER');
    DECLARE @uid varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_user_id)), ''), 'portal');
    DECLARE @idCabang varchar(50) = COALESCE(NULLIF(LTRIM(RTRIM(@p_id_cabang)), ''), NULLIF(LTRIM(RTRIM(@p_cabang)), ''), NULLIF(LTRIM(RTRIM(@p_store_id)), ''));

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

    IF OBJECT_ID('tempdb..#dk_full') IS NOT NULL DROP TABLE #dk_full;
    CREATE TABLE #dk_full (
      AC_NAME varchar(40) NULL, STORE_ID varchar(40) NULL, KET nvarchar(200) NULL,
      KodeKantorCabangStr varchar(40) NULL, store nvarchar(200) NULL,
      NomorIndukStr varchar(40) NULL, NamaLengkapStr nvarchar(200) NULL, Jabatan nvarchar(120) NULL,
      StatusPegawaiStr varchar(40) NULL, PangkatStr nvarchar(120) NULL, JabatanStr nvarchar(120) NULL,
      HISTORY_TOTAL int NULL,
      history_1 varchar(20) NULL, history_2 varchar(20) NULL, history_3 varchar(20) NULL, history_4 varchar(20) NULL, history_5 varchar(20) NULL,
      history_6 varchar(20) NULL, history_7 varchar(20) NULL, history_8 varchar(20) NULL, history_9 varchar(20) NULL, history_10 varchar(20) NULL,
      history_11 varchar(20) NULL, history_12 varchar(20) NULL, history_13 varchar(20) NULL, history_14 varchar(20) NULL, history_15 varchar(20) NULL,
      history_16 varchar(20) NULL, history_17 varchar(20) NULL, history_18 varchar(20) NULL, history_19 varchar(20) NULL, history_20 varchar(20) NULL,
      history_21 varchar(20) NULL, history_22 varchar(20) NULL, history_23 varchar(20) NULL, history_24 varchar(20) NULL, history_25 varchar(20) NULL,
      history_26 varchar(20) NULL, history_27 varchar(20) NULL, history_28 varchar(20) NULL, history_29 varchar(20) NULL, history_30 varchar(20) NULL, history_31 varchar(20) NULL,
      history_1_color varchar(40) NULL, history_2_color varchar(40) NULL, history_3_color varchar(40) NULL, history_4_color varchar(40) NULL, history_5_color varchar(40) NULL,
      history_6_color varchar(40) NULL, history_7_color varchar(40) NULL, history_8_color varchar(40) NULL, history_9_color varchar(40) NULL, history_10_color varchar(40) NULL,
      history_11_color varchar(40) NULL, history_12_color varchar(40) NULL, history_13_color varchar(40) NULL, history_14_color varchar(40) NULL, history_15_color varchar(40) NULL,
      history_16_color varchar(40) NULL, history_17_color varchar(40) NULL, history_18_color varchar(40) NULL, history_19_color varchar(40) NULL, history_20_color varchar(40) NULL,
      history_21_color varchar(40) NULL, history_22_color varchar(40) NULL, history_23_color varchar(40) NULL, history_24_color varchar(40) NULL, history_25_color varchar(40) NULL,
      history_26_color varchar(40) NULL, history_27_color varchar(40) NULL, history_28_color varchar(40) NULL, history_29_color varchar(40) NULL, history_30_color varchar(40) NULL, history_31_color varchar(40) NULL,
      M_TOTAL int NULL,
      M_1 varchar(20) NULL, M_2 varchar(20) NULL, M_3 varchar(20) NULL, M_4 varchar(20) NULL, M_5 varchar(20) NULL,
      M_6 varchar(20) NULL, M_7 varchar(20) NULL, M_8 varchar(20) NULL, M_9 varchar(20) NULL, M_10 varchar(20) NULL,
      M_11 varchar(20) NULL, M_12 varchar(20) NULL, M_13 varchar(20) NULL, M_14 varchar(20) NULL, M_15 varchar(20) NULL,
      M_16 varchar(20) NULL, M_17 varchar(20) NULL, M_18 varchar(20) NULL, M_19 varchar(20) NULL, M_20 varchar(20) NULL,
      M_21 varchar(20) NULL, M_22 varchar(20) NULL, M_23 varchar(20) NULL, M_24 varchar(20) NULL, M_25 varchar(20) NULL,
      M_26 varchar(20) NULL, M_27 varchar(20) NULL, M_28 varchar(20) NULL, M_29 varchar(20) NULL, M_30 varchar(20) NULL, M_31 varchar(20) NULL,
      M_1_color varchar(40) NULL, M_2_color varchar(40) NULL, M_3_color varchar(40) NULL, M_4_color varchar(40) NULL, M_5_color varchar(40) NULL,
      M_6_color varchar(40) NULL, M_7_color varchar(40) NULL, M_8_color varchar(40) NULL, M_9_color varchar(40) NULL, M_10_color varchar(40) NULL,
      M_11_color varchar(40) NULL, M_12_color varchar(40) NULL, M_13_color varchar(40) NULL, M_14_color varchar(40) NULL, M_15_color varchar(40) NULL,
      M_16_color varchar(40) NULL, M_17_color varchar(40) NULL, M_18_color varchar(40) NULL, M_19_color varchar(40) NULL, M_20_color varchar(40) NULL,
      M_21_color varchar(40) NULL, M_22_color varchar(40) NULL, M_23_color varchar(40) NULL, M_24_color varchar(40) NULL, M_25_color varchar(40) NULL,
      M_26_color varchar(40) NULL, M_27_color varchar(40) NULL, M_28_color varchar(40) NULL, M_29_color varchar(40) NULL, M_30_color varchar(40) NULL, M_31_color varchar(40) NULL,
      TOTAL int NULL,
      [1] int NULL, [2] int NULL, [3] int NULL, [4] int NULL, [5] int NULL, [6] int NULL, [7] int NULL, [8] int NULL, [9] int NULL, [10] int NULL,
      [11] int NULL, [12] int NULL, [13] int NULL, [14] int NULL, [15] int NULL, [16] int NULL, [17] int NULL, [18] int NULL, [19] int NULL, [20] int NULL,
      [21] int NULL, [22] int NULL, [23] int NULL, [24] int NULL, [25] int NULL, [26] int NULL, [27] int NULL, [28] int NULL, [29] int NULL, [30] int NULL, [31] int NULL,
      [1_color] varchar(40) NULL, [2_color] varchar(40) NULL, [3_color] varchar(40) NULL, [4_color] varchar(40) NULL, [5_color] varchar(40) NULL,
      [6_color] varchar(40) NULL, [7_color] varchar(40) NULL, [8_color] varchar(40) NULL, [9_color] varchar(40) NULL, [10_color] varchar(40) NULL,
      [11_color] varchar(40) NULL, [12_color] varchar(40) NULL, [13_color] varchar(40) NULL, [14_color] varchar(40) NULL, [15_color] varchar(40) NULL,
      [16_color] varchar(40) NULL, [17_color] varchar(40) NULL, [18_color] varchar(40) NULL, [19_color] varchar(40) NULL, [20_color] varchar(40) NULL,
      [21_color] varchar(40) NULL, [22_color] varchar(40) NULL, [23_color] varchar(40) NULL, [24_color] varchar(40) NULL, [25_color] varchar(40) NULL,
      [26_color] varchar(40) NULL, [27_color] varchar(40) NULL, [28_color] varchar(40) NULL, [29_color] varchar(40) NULL, [30_color] varchar(40) NULL, [31_color] varchar(40) NULL
    );

    INSERT INTO #dk_full
    EXEC POS_SERVER.dbo.xsp_get_data_absen_manual_dan_pos_detail_export_getrows_buat_di_pages_2
        @p_from_date=@from, @p_to_date=@to, @p_group=@group,
        @p_id_cabang=@idCabang, @p_user_id=@uid, @p_brand=@brand;

    SET @bitparam = (
      SELECT '2002500' responseCode, N'success' responseMessage,
        JSON_QUERY((
          SELECT
              ROW_NUMBER() OVER (ORDER BY NamaLengkapStr, NomorIndukStr) AS id
            , 'employee' AS row_type
            , @idCabang AS id_cabang
            , STORE_ID AS store_id
            , store AS store_name
            , AC_NAME AS ac_name
            , NomorIndukStr AS nik
            , NomorIndukStr AS nick
            , NamaLengkapStr AS employee_name
            , Jabatan AS jabatan
            , HISTORY_TOTAL AS total
            , HISTORY_TOTAL AS total_history
            , M_TOTAL AS m_total
            , TOTAL AS total_akhir
            , history_1, history_2, history_3, history_4, history_5, history_6, history_7, history_8, history_9, history_10
            , history_11, history_12, history_13, history_14, history_15, history_16, history_17, history_18, history_19, history_20
            , history_21, history_22, history_23, history_24, history_25, history_26, history_27, history_28, history_29, history_30, history_31
            , history_1_color, history_2_color, history_3_color, history_4_color, history_5_color, history_6_color, history_7_color, history_8_color, history_9_color, history_10_color
            , history_11_color, history_12_color, history_13_color, history_14_color, history_15_color, history_16_color, history_17_color, history_18_color, history_19_color, history_20_color
            , history_21_color, history_22_color, history_23_color, history_24_color, history_25_color, history_26_color, history_27_color, history_28_color, history_29_color, history_30_color, history_31_color
            , M_1 AS m_1, M_2 AS m_2, M_3 AS m_3, M_4 AS m_4, M_5 AS m_5, M_6 AS m_6, M_7 AS m_7, M_8 AS m_8, M_9 AS m_9, M_10 AS m_10
            , M_11 AS m_11, M_12 AS m_12, M_13 AS m_13, M_14 AS m_14, M_15 AS m_15, M_16 AS m_16, M_17 AS m_17, M_18 AS m_18, M_19 AS m_19, M_20 AS m_20
            , M_21 AS m_21, M_22 AS m_22, M_23 AS m_23, M_24 AS m_24, M_25 AS m_25, M_26 AS m_26, M_27 AS m_27, M_28 AS m_28, M_29 AS m_29, M_30 AS m_30, M_31 AS m_31
            , M_1_color AS m_1_color, M_2_color AS m_2_color, M_3_color AS m_3_color, M_4_color AS m_4_color, M_5_color AS m_5_color
            , M_6_color AS m_6_color, M_7_color AS m_7_color, M_8_color AS m_8_color, M_9_color AS m_9_color, M_10_color AS m_10_color
            , M_11_color AS m_11_color, M_12_color AS m_12_color, M_13_color AS m_13_color, M_14_color AS m_14_color, M_15_color AS m_15_color
            , M_16_color AS m_16_color, M_17_color AS m_17_color, M_18_color AS m_18_color, M_19_color AS m_19_color, M_20_color AS m_20_color
            , M_21_color AS m_21_color, M_22_color AS m_22_color, M_23_color AS m_23_color, M_24_color AS m_24_color, M_25_color AS m_25_color
            , M_26_color AS m_26_color, M_27_color AS m_27_color, M_28_color AS m_28_color, M_29_color AS m_29_color, M_30_color AS m_30_color, M_31_color AS m_31_color
            , [1] AS akhir_1, [2] AS akhir_2, [3] AS akhir_3, [4] AS akhir_4, [5] AS akhir_5, [6] AS akhir_6, [7] AS akhir_7, [8] AS akhir_8, [9] AS akhir_9, [10] AS akhir_10
            , [11] AS akhir_11, [12] AS akhir_12, [13] AS akhir_13, [14] AS akhir_14, [15] AS akhir_15, [16] AS akhir_16, [17] AS akhir_17, [18] AS akhir_18, [19] AS akhir_19, [20] AS akhir_20
            , [21] AS akhir_21, [22] AS akhir_22, [23] AS akhir_23, [24] AS akhir_24, [25] AS akhir_25, [26] AS akhir_26, [27] AS akhir_27, [28] AS akhir_28, [29] AS akhir_29, [30] AS akhir_30, [31] AS akhir_31
            , [1_color] AS akhir_1_color, [2_color] AS akhir_2_color, [3_color] AS akhir_3_color, [4_color] AS akhir_4_color, [5_color] AS akhir_5_color
            , [6_color] AS akhir_6_color, [7_color] AS akhir_7_color, [8_color] AS akhir_8_color, [9_color] AS akhir_9_color, [10_color] AS akhir_10_color
            , [11_color] AS akhir_11_color, [12_color] AS akhir_12_color, [13_color] AS akhir_13_color, [14_color] AS akhir_14_color, [15_color] AS akhir_15_color
            , [16_color] AS akhir_16_color, [17_color] AS akhir_17_color, [18_color] AS akhir_18_color, [19_color] AS akhir_19_color, [20_color] AS akhir_20_color
            , [21_color] AS akhir_21_color, [22_color] AS akhir_22_color, [23_color] AS akhir_23_color, [24_color] AS akhir_24_color, [25_color] AS akhir_25_color
            , [26_color] AS akhir_26_color, [27_color] AS akhir_27_color, [28_color] AS akhir_28_color, [29_color] AS akhir_29_color, [30_color] AS akhir_30_color, [31_color] AS akhir_31_color
            , @brand AS brand
            , @group AS [group]
            , CONVERT(char(10), @from, 23) AS from_date
            , CONVERT(char(10), @to, 23) AS to_date
          FROM #dk_full
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
