/*
  Voucher Imlek detail — ASP voucher_imlek_rpt.aspx ChildRepeater
  Legacy: pos_server.dbo.xsp_header_vouchermarcomm_detail_imlek_rpt_getrows
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_voucher_imlek_detail_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_voucher_imlek_detail_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_voucher_imlek_detail_getrows
(
      @p_id varchar(80)
    , @p_id_cabang varchar(50) = NULL
    , @p_id_store varchar(50) = NULL
    , @p_store_id varchar(50) = NULL
    , @p_status varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @promo varchar(32) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        DECLARE @cabang varchar(20) = LTRIM(RTRIM(ISNULL(COALESCE(NULLIF(@p_id_cabang,''), NULLIF(@p_id_store,''), NULLIF(@p_store_id,'')), '')));
        IF @promo = '' OR @cabang = ''
        BEGIN
            SET @bitparam = (SELECT '4002500' AS responseCode, 'ID_PROMO dan STORE wajib.' AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            RETURN;
        END;

        DECLARE @status varchar(50) = UPPER(LTRIM(RTRIM(ISNULL(@p_status, 'ALL'))));
        IF @status = '' SET @status = 'ALL';
        IF @status NOT IN ('ALL', 'TERPAKAI', 'BELUM TERPAKAI', 'EXPIRED') SET @status = 'ALL';

        CREATE TABLE #d (
            ID bigint NULL,
            ID_PROMO varchar(32) NULL,
            NO_VOUCHER varchar(64) NULL,
            BRAND varchar(100) NULL,
            STORE_ID varchar(20) NULL,
            NOMINAL money NULL,
            TGL_DIGUNAKAN nvarchar(50) NULL,
            STORE_PENGGUNA nvarchar(200) NULL
        );

        INSERT INTO #d
        EXEC pos_server.dbo.xsp_header_vouchermarcomm_detail_imlek_rpt_getrows
            @p_id_promo = @promo,
            @p_id_cabang = @cabang,
            @p_status = @status;

        SELECT @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                           d.ID AS ID,
                           d.NO_VOUCHER AS NO_VOUCHER,
                           CAST(ISNULL(d.NOMINAL, 0) AS float) AS NOMINAL,
                           d.TGL_DIGUNAKAN AS TGL_DIGUNAKAN,
                           d.STORE_PENGGUNA AS STORE_PENGGUNA
                       FROM #d d
                       ORDER BY d.ID
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
