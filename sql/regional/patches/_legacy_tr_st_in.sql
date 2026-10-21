-- exec [xsp_rpt_tr_st_in_header_getrows] '2019-01-01','2020-01-01','celcius','rc097','GH17'
CREATE PROCEDURE [dbo].[xsp_rpt_tr_st_in_header_getrows] 
(	 
	@p_from_date					VARCHAR(20)
	,@p_to_date						VARCHAR(20)
	,@p_brand_id					varchar(30)
	,@p_store_id					varchar(10) 
	,@p_id_gh						 varchar(20) 
)
AS
begin


declare   @table varchar(100)
	 if  @p_brand_id = 'mississippi' or @p_brand_id = 'queensland'
	begin
	 set @table  =   'AMS_DC_DB.dbo.TR_FromDC_RM'
	end
	 if  @p_brand_id = 'celcius'
	begin
	 set @table  =   'AMS_DC_DB.dbo.TR_FromDC_RC'
	end
	 if  @p_brand_id = 'iwan fashion' or @p_brand_id = 'flies'
	begin
	 set @table  =   'AMS_DC_DB.dbo.TR_FromDC_RF'
	end
	 
IF (@p_brand_id = 'ALL' AND @p_store_id = 'ALL')
BEGIN
SELECT  TSH.[NO_URUT]
         ,case when @p_brand_id = 'mississippi' or @p_brand_id = 'queensland' THEN  RM.Nomor
			when @p_brand_id = 'celcius' THEN  RC.Nomor
			when @p_brand_id = 'iwan fashion' or @p_brand_id = 'flies' THEN RF.Nomor
		  END  'nomor'
     ,TSH.[Brand_OUT]
      ,TSH.[ID_Store_OUT]
      ,TSH.[Grade_OUT]
		,TSH.[Brand_IN]
      ,TSH.[ID_Store_IN]
      ,TSH.[Grade_IN]
      ,TSH.[WAKTU_URUT]
      ,TSH.[NO_TR_ST_HEADER]
      ,TSH.[QTY_REAL]
      ,TSH.[HPP_REAL]
      ,TSH.[PRICE_REAL]
      ,format(TSH.[Tgl_Closed_Real],'yyyy-MM-dd') as tgl_closed_real
      ,TSH.[Status_Real]
      
  FROM [POS_SERVER].[dbo].[TR_ST_HEADER] TSH
    inner join   AMS_DC_DB.dbo.TR_FromDC_RC RC ON TSH.NO_TR_ST_HEADER = RC.ID_Out  collate SQL_Latin1_General_CP1_CI_AS
  inner join   AMS_DC_DB.dbo.TR_FromDC_RM RM ON TSH.NO_TR_ST_HEADER = RM.ID_Out collate SQL_Latin1_General_CP1_CI_AS
  inner join   AMS_DC_DB.dbo.TR_FromDC_RIF RF ON TSH.NO_TR_ST_HEADER = RF.ID_Out collate SQL_Latin1_General_CP1_CI_AS
    LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSH.[ID_Store_IN]) 
   WHERE    
     (ds.Store_Brand_ID collate Latin1_General_CI_AS in (SELECT distinct(BRAND) as brand 
						FROM MASTER_GH_DETAIL
						where id_group_head = @p_id_gh)
or ds.Store_Brand_ID collate Latin1_General_CI_AS in (SELECT  distinct(MGD.BRAND) as brand 
						FROM MASTER_GH_DETAIL MGD
						INNER JOIN MASTER_REGIONAL_DETAIL MRD ON (MRD.ID_GROUP_HEAD =  MGD.ID_GROUP_HEAD)
						where MRD.ID_REGIONAL = @p_id_gh))
and (tsh.ID_Store_IN   collate Latin1_General_CI_AS in (SELECT   STORE
						 FROM MASTER_GH_DETAIL
						 where id_group_head = @p_id_gh)
  or tsh.ID_Store_IN collate Latin1_General_CI_AS in (select  mgd.STORE from MASTER_REGIONAL_DETAIl mrd
						 inner join MASTER_GH_DETAIL mgd on (mgd.ID_GROUP_HEAD = mrd.ID_GROUP_HEAD)
						 where mrd.ID_REGIONAL = @p_id_gh)) 
   AND ( DATEDIFF(DAY,TSH.[Tgl_Closed_Real],@p_from_date)<= 0 AND DATEDIFF(DAY,TSH.[Tgl_Closed_Real] ,@p_to_date)>= 0)

   ORDER BY TSH.[Tgl_Closed_Real] DESC
  end 
else IF (@p_brand_id != '' and  @p_store_id = 'ALL' )
BEGIN
SELECT  TSH.[NO_URUT]
         ,case when @p_brand_id = 'mississippi' or @p_brand_id = 'queensland' THEN  RM.Nomor
			when @p_brand_id = 'celcius' THEN  RC.Nomor
			when @p_brand_id = 'iwan fashion' or @p_brand_id = 'flies' THEN RF.Nomor
		  END  'nomor'
     ,TSH.[Brand_OUT]
      ,TSH.[ID_Store_OUT]
      ,TSH.[Grade_OUT]
		,TSH.[Brand_IN]
      ,TSH.[ID_Store_IN]
      ,TSH.[Grade_IN]
      ,TSH.[WAKTU_URUT]
      ,TSH.[NO_TR_ST_HEADER]
      ,TSH.[QTY_REAL]
      ,TSH.[HPP_REAL]
      ,TSH.[PRICE_REAL]
      ,format(TSH.[Tgl_Closed_Real],'yyyy-MM-dd') as tgl_closed_real
      ,TSH.[Status_Real]
      
  FROM [POS_SERVER].[dbo].[TR_ST_HEADER] TSH
      left outer join   AMS_DC_DB.dbo.TR_FromDC_RC RC ON TSH.NO_TR_ST_HEADER = RC.ID_Out collate SQL_Latin1_General_CP1_CI_AS
	  left outer join   AMS_DC_DB.dbo.TR_FromDC_RM RM ON TSH.NO_TR_ST_HEADER = RM.ID_Out collate SQL_Latin1_General_CP1_CI_AS
	  left outer join   AMS_DC_DB.dbo.TR_FromDC_RIF RF ON TSH.NO_TR_ST_HEADER = RF.ID_Out collate SQL_Latin1_General_CP1_CI_AS
    LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSH.[ID_Store_IN]) 
   WHERE  ds.Store_Brand_ID = @p_brand_id
   AND ( DATEDIFF(DAY,TSH.[Tgl_Closed_Real],@p_from_date)<= 0 AND DATEDIFF(DAY,TSH.[Tgl_Closed_Real] ,@p_to_date)>= 0)
    ORDER BY TSH.[Tgl_Closed_Real] DESC
  end 
IF (@p_brand_id != '' and @p_store_id != '')
BEGIN
select * from (
SELECT   TSH.[Brand_OUT]
      ,TSH.[ID_Store_OUT]
      ,TSH.[Grade_OUT]
	   ,TSH.[NO_URUT]
	  ,isnull(case when @p_brand_id = 'mississippi'  THEN  RM.Nomor
				when @p_brand_id = 'celcius' THEN  RC.Nomor
				when @p_brand_id = 'iwan fashion' or @p_brand_id = 'flies' THEN RF.Nomor
		  END,0)  'nomor'
		,TSH.[Brand_IN]
      ,TSH.[ID_Store_IN]
      ,TSH.[Grade_IN]
      ,TSH.[WAKTU_URUT]
      ,TSH.[NO_TR_ST_HEADER]
      ,TSH.[QTY_REAL]
      ,TSH.[HPP_REAL]
      ,TSH.[PRICE_REAL]
      ,format(TSH.[Tgl_Closed_Real],'yyyy-MM-dd') as tgl_closed_real
      ,TSH.[Status_Real]
      
  FROM [POS_SERVER].[dbo].[TR_ST_HEADER] TSH
   left outer join   (select nomor,ID_Out from AMS_DC_DB.dbo.TR_FromDC_RC  where Status = 2) RC ON TSH.NO_TR_ST_HEADER = RC.ID_Out collate SQL_Latin1_General_CP1_CI_AS
   left outer join     (select nomor,ID_Out from AMS_DC_DB.dbo.TR_FromDC_RM  where Status = 2)RM ON TSH.NO_TR_ST_HEADER = RM.ID_Out collate SQL_Latin1_General_CP1_CI_AS
   left outer join    (select nomor,ID_Out from AMS_DC_DB.dbo.TR_FromDC_RIF  where Status = 2)RF ON TSH.NO_TR_ST_HEADER = RF.ID_Out collate SQL_Latin1_General_CP1_CI_AS
      LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSH.[ID_Store_IN]) 
   WHERE   TSH.[ID_Store_IN]	= @p_store_id
         AND DS.Store_Brand_ID	= @p_brand_id  
   AND ( DATEDIFF(DAY,TSH.[Tgl_Closed_Real],@p_from_date)<= 0 AND DATEDIFF(DAY,TSH.[Tgl_Closed_Real] ,@p_to_date)>= 0)
   
   union all

   
SELECT   a.[Brand_OUT]
      ,a.[ID_Store_OUT]
      ,a.[Grade_OUT]
	   ,a.[NO_URUT]
	  ,0 'nomor'
		,a.[Brand_IN]
      ,a.[ID_Store_IN]
      ,a.[Grade_IN]
      ,a.[WAKTU_URUT]
      ,a.NO_TR_ST_HEADER_SHOPPING_BAG
      ,a.[QTY_REAL]
      ,a.[HPP_REAL]
      ,a.[PRICE_REAL]
      ,format(a.[Tgl_Closed_Real],'yyyy-MM-dd') as tgl_closed_real
      ,a.[Status_Real]
      
  FROM [POS_SERVER].[dbo].[TR_ST_HEADER_SHOPPING_BAG] a
  -- left outer join   [POS_SERVER].[dbo].[TR_ST_DETAIL_SHOPPING_BAG] b ON a.NO_TR_ST_HEADER_SHOPPING_BAG = b.NO_TR_ST_HEADER_SHOPPING_BAG collate SQL_Latin1_General_CP1_CI_AS
     --  LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = a.[ID_Store_IN]) 
   WHERE   a.[ID_Store_IN]	= @p_store_id
        -- AND DS.Store_Brand_ID	= @p_brand_id  
   AND ( DATEDIFF(DAY,a.[Tgl_Closed_Real],@p_from_date)<= 0 AND DATEDIFF(DAY,a.[Tgl_Closed_Real] ,@p_to_date)>= 0)
   -- ORDER BY a.[Tgl_Closed_Real] DESC
   
   
   ) as x ORDER BY x.[Tgl_Closed_Real] DESC



	
END
END