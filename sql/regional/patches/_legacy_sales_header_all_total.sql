--exec  [XSP_RPT_SALES_HEADER_GETROWS] '2017-02-25', 'CELCIUS' , 'XXX', ''
CREATE PROCEDURE [dbo].[XSP_RPT_SALES_HEADER_ALL_TOTAL_GETROW] 

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
   SELECT CONVERT(DECIMAL(18, 2),SUM(TOTAL_POS)) AS TOTAL_POS, CONVERT(DECIMAL(18, 2),SUM(TOTAL_BON_MANUAL)) AS TOTAL_BON_MANUAL,CONVERT(DECIMAL(18, 2),SUM(ONLINE)) AS TOTAL_ONLINE_ORDER , (CONVERT(DECIMAL(18, 2),SUM(TOTAL_POS)) + CONVERT(DECIMAL(18, 2),SUM(TOTAL_BON_MANUAL)) + CONVERT(DECIMAL(18, 2),SUM(ONLINE))  ) AS GRAND_TOTAL FROM (
 
   
    SELECT SUM (GRAND_TOTAL1) AS TOTAL_POS, 0 AS TOTAL_BON_MANUAL,0 as ONLINE FROM (SELECT  
	      SUM (TSH.Grand_Total) AS GRAND_TOTAL1
		  FROM  [TR_SALES_HEADER] TSH
  LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSH.ID_Store)  
  WHERE  
   	 ( DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd'),@p_from_date)<= 0 AND DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd') ,@p_to_date)>= 0)
   	
	and tsh.Status_Transaksi = 1
	     AND TSH.Bon_Manual = 0
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
		  GROUP BY     TSH.Grand_Total ) AS X
		   

---------------------------------////////////////////
	UNION ALL
	
	  
 	 SELECT 0 AS TOTAL_POS, 0 AS TOTAL_BON_MANUAL, SUM (GRAND_TOTAL2) AS ONLINE FROM (SELECT    
	      SUM (TSH.Grand_Total) AS GRAND_TOTAL2
		  FROM  [TR_SALES_HEADER] TSH
  LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSH.ID_Store)  
  WHERE  
   	 ( DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd'),@p_from_date)<= 0 AND DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd') ,@p_to_date)>= 0)
   	
	and tsh.Status_Transaksi = 1
	   AND TSH.order_online  = 1
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
		  GROUP BY     TSH.Grand_Total ) AS XX
		  
		 ) AS A 
		  
		  
		  				  	  
		  				  
  end

  else if (@p_brand_id != ''  and (@p_store_id = '' OR @p_store_id = 'ALL'))
  BEGIN
  SELECT CONVERT(DECIMAL(18, 2),SUM(TOTAL_POS)) AS TOTAL_POS, CONVERT(DECIMAL(18, 2),SUM(TOTAL_BON_MANUAL)) AS TOTAL_BON_MANUAL,CONVERT(DECIMAL(18, 2),SUM(ONLINE)) AS TOTAL_ONLINE_ORDER , (CONVERT(DECIMAL(18, 2),SUM(TOTAL_POS)) + CONVERT(DECIMAL(18, 2),SUM(TOTAL_BON_MANUAL)) + CONVERT(DECIMAL(18, 2),SUM(ONLINE))  ) AS GRAND_TOTAL FROM (
 
   
   SELECT SUM (GRAND_TOTAL1) AS TOTAL_POS, 0 AS TOTAL_BON_MANUAL,0 as ONLINE FROM (SELECT  
	      SUM (TSH.Grand_Total) AS GRAND_TOTAL1
		  FROM  [TR_SALES_HEADER] TSH

  LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSH.ID_Store)  
  WHERE  
   tsh.Status_Transaksi = 1  and tsh.order_online  = 0
 and  DS.Store_Brand_ID	= @p_brand_id  AND DS.Store_ID NOT IN ('01E','02E','03E','04E','05E','06E','07E','08E','09E','10E','11E')
  and (TSH.ID_Store collate Latin1_General_CI_AS in (SELECT   STORE
						 FROM MASTER_GH_DETAIL
						 where id_group_head = @p_id_gh)
  or TSH.ID_Store collate Latin1_General_CI_AS in (select  mgd.STORE from MASTER_REGIONAL_DETAIl mrd
						 inner join MASTER_GH_DETAIL mgd on (mgd.ID_GROUP_HEAD = mrd.ID_GROUP_HEAD)
						 where mrd.ID_REGIONAL = @p_id_gh)) 
  AND	 ( DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd'),@p_from_date)<= 0 AND DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd') ,@p_to_date)>= 0)
   	

    GROUP BY     TSH.Grand_Total ) AS X

	 
	UNION ALL
	----------------------------------\\

	 
	 SELECT 0 AS TOTAL_POS, 0 AS TOTAL_BON_MANUAL, SUM (GRAND_TOTAL2) AS ONLINE FROM (SELECT  
	      SUM (TSH.Grand_Total) AS GRAND_TOTAL2
		  FROM  [TR_SALES_HEADER] TSH

  LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSH.ID_Store)  
  WHERE  
   tsh.Status_Transaksi = 1
    	   AND TSH.order_online = 1
 and  DS.Store_Brand_ID	= @p_brand_id  AND DS.Store_ID NOT IN ('01E','02E','03E','04E','05E','06E','07E','08E','09E','10E','11E')
  and (TSH.ID_Store collate Latin1_General_CI_AS in (SELECT   STORE
						 FROM MASTER_GH_DETAIL
						 where id_group_head = @p_id_gh)
  or TSH.ID_Store collate Latin1_General_CI_AS in (select  mgd.STORE from MASTER_REGIONAL_DETAIl mrd
						 inner join MASTER_GH_DETAIL mgd on (mgd.ID_GROUP_HEAD = mrd.ID_GROUP_HEAD)
						 where mrd.ID_REGIONAL = @p_id_gh)) 
  AND	 ( DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd'),@p_from_date)<= 0 AND DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd') ,@p_to_date)>= 0)
   	

    GROUP BY     TSH.Grand_Total ) AS XX

	) AS A
  END

  ELSE if(@p_brand_id != '' and @p_store_id != '' )
  begin

   
 SELECT CONVERT(DECIMAL(18, 2),SUM(TOTAL_POS)) AS TOTAL_POS, CONVERT(DECIMAL(18, 2),SUM(TOTAL_BON_MANUAL)) AS TOTAL_BON_MANUAL,CONVERT(DECIMAL(18, 2),SUM(ONLINE)) AS TOTAL_ONLINE_ORDER , (CONVERT(DECIMAL(18, 2),SUM(TOTAL_POS)) + CONVERT(DECIMAL(18, 2),SUM(TOTAL_BON_MANUAL)) + CONVERT(DECIMAL(18, 2),SUM(ONLINE))  ) AS GRAND_TOTAL FROM (
 

  SELECT SUM (GRAND_TOTAL1) AS TOTAL_POS, 0 AS TOTAL_BON_MANUAL,0 as ONLINE FROM (SELECT  
	      SUM (TSH.Grand_Total) AS GRAND_TOTAL1
		  FROM  [TR_SALES_HEADER] TSH
		  LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSH.ID_Store) 
   
		  WHERE TSH.ID_STORE		= @p_store_id
		  AND   DS.Store_Brand_ID	= @p_brand_id  AND DS.Store_ID NOT IN ('01E','02E','03E','04E','05E','06E','07E','08E','09E','10E','11E')
		  AND	 ( DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd'),@p_from_date)<= 0 AND DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd') ,@p_to_date)>= 0)
   	
		  and tsh.Status_Transaksi = 1 and tsh.order_online = 0
		   AND TSH.Bon_Manual = 0
		   GROUP BY     TSH.Grand_Total ) AS X
    
	   
   UNION ALL

          SELECT 0 AS TOTAL_POS, 0 AS TOTAL_BON_MANUAL, SUM (GRAND_TOTAL2) AS ONLINE FROM (SELECT  
		       SUM (TSH.Grand_Total) AS GRAND_TOTAL2 
		  FROM  [TR_SALES_HEADER] TSH
		  LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSH.ID_Store) 
   
		  WHERE TSH.ID_STORE		= @p_store_id
		  AND   DS.Store_Brand_ID	= @p_brand_id  AND DS.Store_ID NOT IN ('01E','02E','03E','04E','05E','06E','07E','08E','09E','10E','11E')
		  AND	 ( DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd'),@p_from_date)<= 0 AND DATEDIFF(DAY,FORMAT(TSH.Tanggal_Transaksi,'yyyy/MM/dd') ,@p_to_date)>= 0)
   	

		  and tsh.Status_Transaksi = 1 
		   AND TSH.order_online = 1
		   GROUP BY     TSH.Grand_Total ) AS XX

		   ) AS  A
  end
END


