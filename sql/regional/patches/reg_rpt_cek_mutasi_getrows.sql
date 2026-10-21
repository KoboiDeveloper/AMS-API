/*
  Cek Mutasi (REG2) — ASP parity module/Rpt/Chk_Mutasi.aspx
  Legacy: pos_server.dbo.XSP_Z_GETROWS (+ XSP_ZJADI_GETROWS for running Z / STATUS)
  Params: store, from, to, plu, user_id (actor_nik)
  Columns: IDNYA, KODE, TANGGAL, PLU, A, TRANSAKSI, Z, STATUS
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_cek_mutasi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_cek_mutasi_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_cek_mutasi_getrows
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
        DECLARE @from date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date,''))),'') AS date);
        DECLARE @to date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date,''))),'') AS date);
        DECLARE @store varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), ''))));
        DECLARE @plu varchar(80) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_plu,''), @p_article), '')));
        DECLARE @user varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_actor_nik,''), NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,'')), '')));

        IF @from IS NULL OR @to IS NULL OR @store IN ('','0','ALL') OR @plu = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'Store, PLU, from_date, to_date wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;
        IF @user = '' SET @user = 'REG2';

        DECLARE @fromS varchar(20) = CONVERT(varchar(10), @from, 111);
        DECLARE @toS varchar(20) = CONVERT(varchar(10), @to, 111);

        /* Final SELECT of XSP_Z_GETROWS */
        CREATE TABLE #r (
            ID int NULL,
            ID_STORE varchar(50) NULL,
            KODE varchar(50) NULL,
            IDNYA varchar(50) NULL,
            tanggal nvarchar(50) NULL,
            PLU varchar(20) NULL,
            A int NULL,
            TRANSAKSI int NULL,
            Z int NULL,
            status varchar(50) NULL,
            color varchar(50) NULL,
            P_USER_ID varchar(50) NULL
        );

        INSERT INTO #r (ID, ID_STORE, KODE, IDNYA, tanggal, PLU, A, TRANSAKSI, Z, status, color, P_USER_ID)
        EXEC pos_server.dbo.XSP_Z_GETROWS
            @p_store_id = @store,
            @p_from_date = @fromS,
            @p_to_date = @toS,
            @p_plu = @plu,
            @p_user_id = @user;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           r.IDNYA AS IDNYA,
                           r.KODE AS KODE,
                           r.tanggal AS TANGGAL,
                           r.PLU AS PLU,
                           CAST(ISNULL(r.A, 0) AS float) AS A,
                           CAST(ISNULL(r.TRANSAKSI, 0) AS float) AS TRANSAKSI,
                           CAST(ISNULL(r.Z, 0) AS float) AS Z,
                           ISNULL(r.status, '') AS STATUS,
                           ISNULL(r.color, '') AS COLOR,
                           r.ID_STORE AS STORE_ID
                       FROM #r r
                       ORDER BY r.ID
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
