--exec [XSP_Z_GETROWS]'','','',''
CREATE PROCEDURE [dbo].[XSP_search_qty_nol_GETROWS]
(
@p_store_id       varchar(20)
,@p_from_date	  datetime
,@p_to_date       datetime  
,@p_brand_id	varchar(20)

)
AS
BEGIN   
 
 SELECT   xxx.[NO_URUT]
      ,xxx.[WAKTU_URUT]
	  ,xxx.[ID_TR_SALES_HEADER]
      ,xxx.BILLING_CODE
      ,xxx.[ID_Store]
      ,xxx.[Status_Transaksi]
      ,xxx.TANGGAL_TRANSAKSI
      ,xxx.[Total_HPP]
      ,xxx.[PPN]
      ,xxx.[Sub_Total]
      ,xxx.[Total_Discount]
      ,xxx.[Personal_Discount_Persen]
      ,xxx.[Personal_Discount]
        ,case when xxx.Grand_Total <= 0 then 0 
			else xxx.Grand_Total end 'GRAND_TOTAL'
      ,xxx.[ID_User]
      ,xxx.bon_manual
	  ,xxx.bgclass
      ,xxx.[No_Bon_Manual]
      ,xxx.[Status_Manual]
      ,xxx.[Waktu_Manual]
      ,xxx.[Status_Kirim]
      ,xxx.[Waktu_Kirim]
      ,xxx.[Last_Position]
	  ,xxx.Store_Brand_ID
	  ,xxx.ID_User
	  ,xxx.QTY

	  from (
	   
  SELECT   TSH.[NO_URUT]
      ,TSH.[WAKTU_URUT]
	  ,TSH.[ID_TR_SALES_HEADER]
      ,LEFT(TSH.[ID_TR_SALES_HEADER],6) + RIGHT(TSH.[ID_TR_SALES_HEADER],6) AS BILLING_CODE
      ,TSH.[ID_Store]
      ,TSH.[Status_Transaksi]
      ,FORMAT(TSH.[Tanggal_Transaksi],'yyyy-MM-dd hh:mm') AS TANGGAL_TRANSAKSI
      ,TSH.[Total_HPP]
      ,TSH.[PPN]
      ,TSH.[Sub_Total]
      ,TSH.[Total_Discount]
      ,TSH.[Personal_Discount_Persen]
      ,TSH.[Personal_Discount]
      --,TSH.[Grand_Total]
	  ,case when tspd.TIPE_BAYAR =  'Nilai Refund'  then    TSH.[Grand_Total] - tspd.BAYAR ELSE TSH.[Grand_Total] End 'Grand_Total'
      ,TSH.[ID_User]
      ,CASE WHEN TSH.[Bon_Manual] = 0 OR TSH.[Bon_Manual] IS NULL THEN 'POS'
	        WHEN TSH.[Bon_Manual] = 1  THEN 'BON MANUAL'
			end 'bon_manual'
	  ,CASE WHEN TSH.[Bon_Manual] = 0 OR TSH.[Bon_Manual] IS NULL THEN 'badge bg-success'
	        WHEN TSH.[Bon_Manual] = 1  THEN 'badge bg-important'
			end 'bgclass'
      ,TSH.[No_Bon_Manual]
      ,TSH.[Status_Manual]
      ,TSH.[Waktu_Manual]
      ,TSH.[Status_Kirim]
      ,TSH.[Waktu_Kirim]
      ,TSH.[Last_Position]
	  ,DS.Store_Brand_ID
	   --,TSH.ID_User
	  ,SUM(ISNULL(TSD.QTY,0)) AS QTY
  FROM  [TR_SALES_HEADER] TSH
  LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSH.ID_Store) 
    LEFT OUTER JOIN [TR_SALES_DETAIL] TSD ON (TSD.ID_TR_SALES_HEADER = TSH.ID_TR_SALES_HEADER)
	left outer join (SELECT ID_TR_SALES_HEADER,TIPE_BAYAR,BAYAR FROM TR_SALES_PAYMENT_DETAIL WHERE TIPE_BAYAR='NILAI REFUND') AS tspd 
	   on (tspd.ID_TR_SALES_HEADER = tsh.ID_TR_SALES_HEADER)
  WHERE TSH.ID_STORE		= @p_store_id
AND   DS.Store_Brand_ID	= @p_brand_id
  AND	( DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd'),@p_from_date)<= 0 AND DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd') ,@p_to_date)>= 0)
   	 
  and tsh.Status_Transaksi = 1
   AND tsd.QTY = 0
   GROUP BY TSH.NO_URUT, TSH.WAKTU_URUT, TSH.ID_TR_SALES_HEADER, TSH.ID_Store, TSH.Status_Transaksi, TSH.Tanggal_Transaksi, TSH.ID_User, TSH.Bon_Manual, TSH.No_Bon_Manual, TSH.Status_Manual, TSH.Waktu_Manual, TSH.Status_Kirim, TSH.Waktu_Kirim, TSH.ID_TR_SALES_HEADER, TSH.Last_Position, DS.Store_Brand_ID, TSH.Total_HPP, TSH.PPN, TSH.Sub_Total, TSH.Total_Discount, TSH.Personal_Discount_Persen, TSH.Personal_Discount, TSH.Grand_Total,tspd.TIPE_BAYAR,tspd.BAYAR
) as xxx 
order by Tanggal_Transaksi desc
END
