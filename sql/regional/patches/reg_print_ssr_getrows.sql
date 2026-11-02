/*
  Sales Summary Report PU (REG2) — ASP parity module/Rpt/PrintSSRPU.aspx
  Legacy:
    header  → pos_server.dbo.XSP_RPT_SSR_HEADER_PU_GETROWS
    payment → pos_server.dbo.XSP_RPT_SSR_PAYMENT_PU_GETROWS
  Filters: Brand, Store, single date (from_date), user_id from actor
  @p_tipe = header | payment
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_print_ssr_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_print_ssr_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_print_ssr_getrows
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
        DECLARE @from date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(COALESCE(@p_from_date, @p_tgl),''))),'') AS date);
        IF @from IS NULL
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'Tanggal wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @brand varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_brand,''), @p_brand), '')));
        DECLARE @store varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_store,''), @p_store_id), '')));
        IF @brand = '' OR @store = '' OR UPPER(@brand) = 'ALL' OR UPPER(@store) = 'ALL'
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'Brand dan Store wajib (bukan ALL).' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @user varchar(50) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_actor_nik,''), NULLIF(@p_id_gh,''), NULLIF(@p_gh_id,''), @store), @store)));
        DECLARE @tipe varchar(20) = LOWER(LTRIM(RTRIM(ISNULL(@p_tipe, 'header'))));
        IF @tipe IN ('', '1', 'dept', 'department') SET @tipe = 'header';
        IF @tipe IN ('2', 'pay', 'bayar') SET @tipe = 'payment';

        IF @tipe = 'payment'
        BEGIN
            CREATE TABLE #pay (
                total_tran float NULL,
                cash nvarchar(100) NULL,
                [CHANGE] float NULL,
                card nvarchar(100) NULL,
                debit nvarchar(100) NULL,
                voucher nvarchar(100) NULL,
                refund nvarchar(100) NULL,
                OVO nvarchar(100) NULL,
                [online] nvarchar(100) NULL,
                cod nvarchar(100) NULL,
                ATOME nvarchar(100) NULL,
                INDODANA nvarchar(100) NULL,
                KQRIS nvarchar(100) NULL,
                D_QRIS_BCA nvarchar(100) NULL,
                D_QRIS_BNI nvarchar(100) NULL,
                D_QRIS_BRI nvarchar(100) NULL,
                D_QRIS_MANDIRI nvarchar(100) NULL,
                total_tran1 float NULL,
                cash1 nvarchar(100) NULL,
                card1 nvarchar(100) NULL,
                debit1 nvarchar(100) NULL,
                voucher1 nvarchar(100) NULL,
                refund1 nvarchar(100) NULL,
                OVO1 nvarchar(100) NULL,
                online1 nvarchar(100) NULL,
                cod1 nvarchar(100) NULL,
                ATOME1 nvarchar(100) NULL,
                INDODANA1 nvarchar(100) NULL,
                KQRIS1 nvarchar(100) NULL,
                D_QRIS1_BCA nvarchar(100) NULL,
                D_QRIS1_BNI nvarchar(100) NULL,
                D_QRIS1_BRI nvarchar(100) NULL,
                D_QRIS1_MANDIRI nvarchar(100) NULL
            );

            INSERT INTO #pay
            EXEC pos_server.dbo.XSP_RPT_SSR_PAYMENT_PU_GETROWS
                @p_from_date = @from,
                @p_brand_id = @brand,
                @p_store_id = @store,
                @p_user_id = @user;

            SELECT @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT
                               CAST(ISNULL(p.total_tran, 0) AS float) AS total_tran,
                               ISNULL(p.cash, '0') AS cash,
                               CAST(ISNULL(p.[CHANGE], 0) AS float) AS CHANGE,
                               ISNULL(p.card, '0') AS card,
                               ISNULL(p.debit, '0') AS debit,
                               ISNULL(p.voucher, '0') AS voucher,
                               ISNULL(p.refund, '0') AS refund,
                               ISNULL(p.OVO, '0') AS OVO,
                               ISNULL(p.[online], '0') AS [online],
                               ISNULL(p.cod, '0') AS cod,
                               ISNULL(p.ATOME, '0') AS ATOME,
                               ISNULL(p.INDODANA, '0') AS INDODANA,
                               ISNULL(p.KQRIS, '0') AS KQRIS,
                               ISNULL(p.D_QRIS_BCA, '0') AS D_QRIS_BCA,
                               ISNULL(p.D_QRIS_BNI, '0') AS D_QRIS_BNI,
                               ISNULL(p.D_QRIS_BRI, '0') AS D_QRIS_BRI,
                               ISNULL(p.D_QRIS_MANDIRI, '0') AS D_QRIS_MANDIRI,
                               CAST(ISNULL(p.total_tran1, 0) AS float) AS total_tran1,
                               ISNULL(p.cash1, '0') AS cash1,
                               ISNULL(p.card1, '0') AS card1,
                               ISNULL(p.debit1, '0') AS debit1,
                               ISNULL(p.voucher1, '0') AS voucher1,
                               ISNULL(p.refund1, '0') AS refund1,
                               ISNULL(p.OVO1, '0') AS OVO1,
                               ISNULL(p.online1, '0') AS online1,
                               ISNULL(p.cod1, '0') AS cod1,
                               ISNULL(p.ATOME1, '0') AS ATOME1,
                               ISNULL(p.INDODANA1, '0') AS INDODANA1,
                               ISNULL(p.KQRIS1, '0') AS KQRIS1,
                               ISNULL(p.D_QRIS1_BCA, '0') AS D_QRIS1_BCA,
                               ISNULL(p.D_QRIS1_BNI, '0') AS D_QRIS1_BNI,
                               ISNULL(p.D_QRIS1_BRI, '0') AS D_QRIS1_BRI,
                               ISNULL(p.D_QRIS1_MANDIRI, '0') AS D_QRIS1_MANDIRI
                           FROM #pay p
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        CREATE TABLE #h (
            NO bigint NULL,
            CODE varchar(10) NULL,
            DESKRIPSI varchar(200) NULL,
            QTY float NULL,
            GROSS_SALES nvarchar(100) NULL,
            NET_SALES nvarchar(100) NULL,
            QTY_MTD float NULL,
            NET_SALES_MTD nvarchar(100) NULL
        );

        INSERT INTO #h
        EXEC pos_server.dbo.XSP_RPT_SSR_HEADER_PU_GETROWS
            @p_from_date = @from,
            @p_brand_id = @brand,
            @p_store_id = @store,
            @p_user_id = @user;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           h.NO AS NO,
                           h.CODE AS CODE,
                           h.DESKRIPSI AS DESKRIPSI,
                           CAST(ISNULL(h.QTY, 0) AS float) AS QTY,
                           ISNULL(h.GROSS_SALES, '0') AS GROSS_SALES,
                           ISNULL(h.NET_SALES, '0') AS NET_SALES,
                           CAST(ISNULL(h.QTY_MTD, 0) AS float) AS QTY_MTD,
                           ISNULL(h.NET_SALES_MTD, '0') AS NET_SALES_MTD
                       FROM #h h
                       ORDER BY h.NO
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
