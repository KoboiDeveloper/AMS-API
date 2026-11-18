/* Marcomm — Export Data Member (Sales sheet by date range)
   Original xsp_febita_all_transacrtion_getrows left unchanged (hardcoded dates).
*/
USE POS_SERVER;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_febita_all_transacrtion_getrows_by_date', N'P') IS NOT NULL
  DROP PROCEDURE dbo.xsp_febita_all_transacrtion_getrows_by_date;
GO
CREATE PROCEDURE dbo.xsp_febita_all_transacrtion_getrows_by_date
(
  @p_from_date datetime,
  @p_to_date datetime
)
AS
BEGIN
  SET NOCOUNT ON;
  SELECT
      a.Tanggal_Transaksi
    , c.Store_Brand_ID AS brand
    , a.ID_Store AS store
    , c.Store_Kota AS kota
    , SUM(b.bayar) AS total
  FROM dbo.tr_sales_header a
  INNER JOIN dbo.DT_Store c ON c.Store_ID = a.ID_Store
  INNER JOIN dbo.TR_SALES_PAYMENT_DETAIL b ON b.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER
  WHERE DATEDIFF(day, a.Tanggal_Transaksi, @p_from_date) <= 0
    AND DATEDIFF(day, a.Tanggal_Transaksi, @p_to_date) >= 0
  GROUP BY a.Tanggal_Transaksi, c.Store_Brand_ID, a.ID_Store, c.Store_Kota
  ORDER BY brand, a.Tanggal_Transaksi;
END
GO
