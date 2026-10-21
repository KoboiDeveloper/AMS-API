--exec  [XSP_RPT_SALES_HEADER_GETROWS] '2017-02-25', 'CELCIUS' , 'XXX', ''
CREATE PROCEDURE [dbo].[XSP_RPT_SALES_HEADER_ALL_GETROWS] 

(	---@p_id_tr_sales_header						varchar(32)
	-- @p_select_date					VARCHAR(20)
	   @p_from_date					VARCHAR(20)
	,@p_to_date						VARCHAR(20)
	 ,@p_brand_id					varchar(30)
	,@p_store_id					varchar(10)
	--,@p_multi_store					varchar(100)
	,@p_id_gh						 varchar(20)
	---,@p_priview						varchar(10)
)
AS
BEGIN


    if(@p_brand_id  = 'ALL' and @p_store_id = 'ALL' )
  begin
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
      ,xxx.STATUS
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
      ,FORMAT(TSH.[Tanggal_Transaksi],'yyyy-MM-dd HH:mm:ss') AS TANGGAL_TRANSAKSI
      --,TSH.[Total_HPP]
	   ,sum(case when tsd.qty > 0 then tsd.qty * tsd.hpp end) [Total_HPP]
      ,TSH.[PPN]
      ,TSH.[Sub_Total]
      ,TSH.[Total_Discount]
      ,TSH.[Personal_Discount_Persen]
      ,TSH.[Personal_Discount]
      --,TSH.[Grand_Total]
	  ,case when tspd.TIPE_BAYAR =  'Nilai Refund'  then    TSH.[Grand_Total] - tspd.BAYAR ELSE TSH.[Grand_Total] End 'Grand_Total'
      ,TSH.[ID_User]
        ,CASE  WHEN TSH.order_online = 0  THEN 'POS'
			WHEN TSH.order_online = 1  THEN 'ONLINE'
			end 'STATUS'
	  ,CASE   WHEN TSH.order_online = 0  THEN 'badge bg-important'
			 WHEN TSH.order_online  = 1 THEN 'badge bg-success'
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
  WHERE  
   ( DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd'),@p_from_date)<= 0 AND DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd') ,@p_to_date)>= 0)
   	 
	and tsh.Status_Transaksi = 1
	    AND 	  LEFT(TSD.PLU,2) <> 01
	 and (ds.Store_Brand_ID = @p_brand_id  AND DS.Store_ID NOT IN ('01E','02E','03E','04E','05E','06E','07E','08E','09E','10E','11E')
  or ds.Store_Brand_ID collate Latin1_General_CI_AS in (SELECT distinct(BRAND) as brand 
						FROM MASTER_GH_DETAIL
						where id_group_head = @p_id_gh)
or ds.Store_Brand_ID collate Latin1_General_CI_AS in (SELECT  distinct(MGD.BRAND) as brand 
						FROM MASTER_GH_DETAIL MGD
						INNER JOIN MASTER_REGIONAL_DETAIL MRD ON (MRD.ID_GROUP_HEAD =  MGD.ID_GROUP_HEAD)
						where MRD.ID_REGIONAL = @p_id_gh))
  and (TSH.ID_Store  = @p_store_id 
  or TSH.ID_Store   collate Latin1_General_CI_AS in (SELECT   STORE
						 FROM MASTER_GH_DETAIL
						 where id_group_head = @p_id_gh)
  or TSH.ID_Store collate Latin1_General_CI_AS in (select  mgd.STORE from MASTER_REGIONAL_DETAIl mrd
						 inner join MASTER_GH_DETAIL mgd on (mgd.ID_GROUP_HEAD = mrd.ID_GROUP_HEAD)
						 where mrd.ID_REGIONAL = @p_id_gh)) 
						 
   GROUP BY TSH.NO_URUT, TSH.WAKTU_URUT, TSH.ID_TR_SALES_HEADER, TSH.ID_Store, TSH.Status_Transaksi, TSH.Tanggal_Transaksi, TSH.ID_User, TSH.Bon_Manual, TSH.No_Bon_Manual, TSH.Status_Manual, TSH.Waktu_Manual, TSH.Status_Kirim, TSH.Waktu_Kirim, TSH.ID_TR_SALES_HEADER, TSH.Last_Position, DS.Store_Brand_ID, TSH.Total_HPP, TSH.PPN, TSH.Sub_Total, TSH.Total_Discount, TSH.Personal_Discount_Persen, TSH.Personal_Discount, TSH.Grand_Total,tspd.TIPE_BAYAR,tspd.BAYAR, TSH.order_online
 ) as xxx
 order by Tanggal_Transaksi desc
  end

  else if (@p_brand_id != ''  and (@p_store_id = '' OR @p_store_id = 'ALL'))
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
	  ,xxx.bgclass
      ,xxx.STATUS
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
      ,FORMAT(TSH.[Tanggal_Transaksi],'yyyy-MM-dd HH:mm:ss') AS TANGGAL_TRANSAKSI
      --,TSH.[Total_HPP]
	   ,sum(case when tsd.qty > 0 then tsd.qty * tsd.hpp end) [Total_HPP]
      ,TSH.[PPN]
      ,TSH.[Sub_Total]
      ,TSH.[Total_Discount]
      ,TSH.[Personal_Discount_Persen]
      ,TSH.[Personal_Discount]
      --,TSH.[Grand_Total]
	  ,case when tspd.TIPE_BAYAR =  'Nilai Refund'  then    TSH.[Grand_Total] - tspd.BAYAR ELSE TSH.[Grand_Total] End 'Grand_Total'
      ,TSH.[ID_User]
        ,CASE  WHEN TSH.order_online = 0  THEN 'POS'
			WHEN TSH.order_online = 1  THEN 'ONLINE'
			end 'STATUS'
	  ,CASE   WHEN TSH.order_online = 0  THEN 'badge bg-important'
			 WHEN TSH.order_online  = 1 THEN 'badge bg-success'
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
  WHERE --TSH.ID_STORE		= @p_store_id
   tsh.Status_Transaksi = 1
      AND 	  LEFT(TSD.PLU,2) <> 01
 and  DS.Store_Brand_ID	= @p_brand_id  AND DS.Store_ID NOT IN ('01E','02E','03E','04E','05E','06E','07E','08E','09E','10E','11E')
  and (TSH.ID_Store collate Latin1_General_CI_AS in (SELECT   STORE
						 FROM MASTER_GH_DETAIL
						 where id_group_head = @p_id_gh)
  or TSH.ID_Store collate Latin1_General_CI_AS in (select  mgd.STORE from MASTER_REGIONAL_DETAIl mrd
						 inner join MASTER_GH_DETAIL mgd on (mgd.ID_GROUP_HEAD = mrd.ID_GROUP_HEAD)
						 where mrd.ID_REGIONAL = @p_id_gh)) 
  AND	( DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd'),@p_from_date)<= 0 AND DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd') ,@p_to_date)>= 0)
   	 

   GROUP BY TSH.NO_URUT, TSH.WAKTU_URUT, TSH.ID_TR_SALES_HEADER, TSH.ID_Store, TSH.Status_Transaksi, TSH.Tanggal_Transaksi, TSH.ID_User, TSH.Bon_Manual, TSH.No_Bon_Manual, TSH.Status_Manual, TSH.Waktu_Manual, TSH.Status_Kirim, TSH.Waktu_Kirim, TSH.ID_TR_SALES_HEADER, TSH.Last_Position, DS.Store_Brand_ID, TSH.Total_HPP, TSH.PPN, TSH.Sub_Total, TSH.Total_Discount, TSH.Personal_Discount_Persen, TSH.Personal_Discount, TSH.Grand_Total,tspd.TIPE_BAYAR,tspd.BAYAR, TSH.order_online
   ) as xxx 
order by Tanggal_Transaksi desc
  END

  ELSE if(@p_brand_id != '' and @p_store_id != '' )
  begin

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
      ,0 AS [Total_Discount]
      ,xxx.[Personal_Discount_Persen]
      ,xxx.[Personal_Discount]
        ,case when xxx.Grand_Total <= 0 then 0 
			else xxx.Grand_Total end 'GRAND_TOTAL'
      ,xxx.[ID_User] 
	  ,xxx.bgclass
      ,xxx.STATUS
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
      ,FORMAT(TSH.[Tanggal_Transaksi],'yyyy-MM-dd HH:mm:ss') AS TANGGAL_TRANSAKSI
      --,TSH.[Total_HPP]
	  ,sum(case when tsd.qty > 0 then tsd.qty * tsd.hpp end) [Total_HPP]
      ,TSH.[PPN]
      ,TSH.[Sub_Total]
      ,TSH.[Total_Discount]
      ,TSH.[Personal_Discount_Persen]
      ,TSH.[Personal_Discount]
      --,TSH.[Grand_Total]
	  ,case when tspd.TIPE_BAYAR =  'Nilai Refund'  then    TSH.[Grand_Total] - tspd.BAYAR ELSE TSH.[Grand_Total] End 'Grand_Total'
      ,TSH.[ID_User]
      ,CASE  WHEN TSH.order_online = 0  THEN 'POS'
			WHEN TSH.order_online = 1  THEN 'ONLINE'
			end 'STATUS'
	  ,CASE   WHEN TSH.order_online = 0  THEN 'badge bg-important'
			 WHEN TSH.order_online  = 1 THEN 'badge bg-success'
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
AND   DS.Store_Brand_ID	= @p_brand_id  AND DS.Store_ID NOT IN ('01E','02E','03E','04E','05E','06E','07E','08E','09E','10E','11E')
  AND	( DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd'),@p_from_date)<= 0 AND DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd') ,@p_to_date)>= 0)
   	 
  and tsh.Status_Transaksi = 1
  AND 	  LEFT(TSD.PLU,2) <> 01
   
   GROUP BY TSH.NO_URUT, TSH.WAKTU_URUT, TSH.ID_TR_SALES_HEADER, TSH.ID_Store, TSH.Status_Transaksi, TSH.Tanggal_Transaksi, TSH.ID_User, TSH.Bon_Manual, TSH.No_Bon_Manual, TSH.Status_Manual, TSH.Waktu_Manual, TSH.Status_Kirim, TSH.Waktu_Kirim, TSH.ID_TR_SALES_HEADER, TSH.Last_Position, DS.Store_Brand_ID, TSH.Total_HPP, TSH.PPN, TSH.Sub_Total, TSH.Total_Discount, TSH.Personal_Discount_Persen, TSH.Personal_Discount, TSH.Grand_Total,tspd.TIPE_BAYAR,tspd.BAYAR, TSH.order_online
) as xxx 
order by Tanggal_Transaksi desc
  end
END


