/*
  Sales Detail drill-down (REG2) — parity seles_detail_info.aspx
  Legacy:
    XSP_RPT_SALES_DETAIL_GETROWS   @p_id_tr_sales_header  → line items (+ shopping bag)
    XSP_RPT_SALES_PAYMENT_GETROWS  @p_id_tr_sales_header  → payments
  NEVER EXEC / alter legacy SPs. Query pos_server.dbo.* only.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_sales_detail_info_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_detail_info_getrow;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_detail_info_getrow
(
      @p_id varchar(80)
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    BEGIN TRY
        DECLARE @hdr varchar(80) = LTRIM(RTRIM(ISNULL(@p_id, '')));
        IF @hdr = ''
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode,
                       'id_tr_sales_header wajib.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* Items: TR_SALES_DETAIL (exclude PLU prefix 01) UNION shopping bag — same order as legacy */
        DECLARE @items nvarchar(max) = (
            SELECT
                  X.ID_STORE
                , X.PLU
                , X.DESKRIPSI
                , X.KETERANGAN
                , X.HPP
                , X.PPN
                , X.HARGA_JUAL
                , X.QTY
                , X.NET
                , X.JENIS
            FROM (
                SELECT
                      TSD.ID_Store AS ID_STORE
                    , TSD.PLU
                    , TSD.DESKRIPSI
                    , TSD.Keterangan AS KETERANGAN
                    , TSD.HPP
                    , TSD.PPN
                    , TSD.Harga_Jual AS HARGA_JUAL
                    , TSD.QTY
                    , TSD.Net AS NET
                    , CAST('PRODUK' AS varchar(20)) AS JENIS
                FROM pos_server.dbo.TR_SALES_DETAIL TSD
                WHERE TSD.ID_TR_SALES_HEADER = @hdr
                  AND LEFT(TSD.PLU, 2) <> '01'

                UNION ALL

                SELECT
                      SB.ID_Store
                    , SB.PLU
                    , SB.DESKRIPSI
                    , SB.Keterangan
                    , SB.HPP
                    , SB.PPN
                    , SB.Harga_Jual
                    , SB.QTY
                    , SB.Net
                    , CAST('PAPERBAG' AS varchar(20))
                FROM pos_server.dbo.TR_SALES_SHOPPING_BAG SB
                WHERE SB.ID_TR_SALES_HEADER = @hdr
            ) AS X
            ORDER BY CASE WHEN X.JENIS = 'PRODUK' THEN 1 ELSE 2 END, X.PLU
            FOR JSON PATH
        );

        DECLARE @payments nvarchar(max) = (
            SELECT
                  TSPD.TIPE_BAYAR
                , TSPD.BAYAR
            FROM pos_server.dbo.TR_SALES_PAYMENT_DETAIL TSPD
            WHERE TSPD.ID_TR_SALES_HEADER = @hdr
            ORDER BY TSPD.NO_URUT
            FOR JSON PATH
        );

        SET @bitparam = (
            SELECT
                '2002500' AS responseCode,
                'success' AS responseMessage,
                JSON_QUERY(ISNULL(@items, '[]')) AS data,
                JSON_QUERY(ISNULL(@payments, '[]')) AS payments
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (
            SELECT '4002500' AS responseCode,
                   ERROR_MESSAGE() AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH
END
GO
