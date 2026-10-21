CREATE PROCEDURE [xsp_promosi_view_rahmat_getrows]

(@p_brand_id	varchar(20)
,@p_store_id	varchar(20)
,@p_plu			varchar(20)
,@p_from_date	datetime
,@p_to_date		datetime


)AS
BEGIN

if( @p_brand_id = 'ALL' AND @p_store_id = 'ALL')
BEGIN
select dp.NO_URUT
      ,dp.WAKTU_URUT
      ,dp.ID_DT_PROMOSI
      ,dp.ID_STORE
      ,dp.PLU
      ,dp.KETERANGAN
      ,dp.QTY
      ,dp.POT_HRG
      ,dp.KELIPATAN
      ,FORMAT(dp.START_DATE,'yyyy-MM-dd') as start_date
      ,format(dp.END_DATE,'yyyy-MM-dd') as end_date
      ,dp.Status_Manual
      ,dp.Waktu_Manual
      ,dp.Status_Kirim
      ,dp.Waktu_Kirim from DT_PROMOSI	dp
	  inner join DT_Store ds on (ds.Store_ID = dp.ID_STORE)
	  where  (   dp.PLU LIKE '%' + @p_plu + '%' ) 
	  and datediff(day,dp.START_DATE,@p_from_date) <=0 and datediff(day,dp.START_DATE,@p_to_date)>=0   
	  ORDER BY DP.ID_STORE, DP.PLU, START_DATE DESC
END

ELSE if( @p_brand_id != 'ALL' AND @p_store_id = 'ALL')
BEGIN
select dp.NO_URUT
      ,dp.WAKTU_URUT
      ,dp.ID_DT_PROMOSI
      ,dp.ID_STORE
      ,dp.PLU
      ,dp.KETERANGAN
      ,dp.QTY
      ,dp.POT_HRG
      ,dp.KELIPATAN
      ,FORMAT(dp.START_DATE,'yyyy-MM-dd') as start_date
      ,format(dp.END_DATE,'yyyy-MM-dd') as end_date
      ,dp.Status_Manual
      ,dp.Waktu_Manual
      ,dp.Status_Kirim
      ,dp.Waktu_Kirim from DT_PROMOSI	dp
	  inner join DT_Store ds on (ds.Store_ID = dp.ID_STORE)
	  where  (   dp.PLU LIKE '%' + @p_plu + '%' )
	  AND  ds.Store_Brand_ID = @p_brand_id
	  and datediff(day,dp.START_DATE,@p_from_date) <=0 and datediff(day,dp.START_DATE,@p_to_date)>=0

	  ORDER BY DP.ID_STORE, DP.PLU, START_DATE DESC
END

ELSE if( @p_brand_id != 'ALL' AND @p_store_id != 'ALL')
BEGIN
select dp.NO_URUT
      ,dp.WAKTU_URUT
      ,dp.ID_DT_PROMOSI
      ,dp.ID_STORE
      ,dp.PLU
      ,dp.KETERANGAN
      ,dp.QTY
      ,dp.POT_HRG
      ,dp.KELIPATAN
      ,FORMAT(dp.START_DATE,'yyyy-MM-dd') as start_date
      ,format(dp.END_DATE,'yyyy-MM-dd') as end_date
      ,dp.Status_Manual
      ,dp.Waktu_Manual
      ,dp.Status_Kirim
      ,dp.Waktu_Kirim from DT_PROMOSI	dp
	  inner join DT_Store ds on (ds.Store_ID = dp.ID_STORE)
	  where  (   dp.PLU LIKE '%' + @p_plu + '%' )
	  AND dp.ID_STORE = @p_store_id 
	  and	ds.Store_Brand_ID = @p_brand_id
	  and datediff(day,dp.START_DATE,@p_from_date) <=0 and datediff(day,dp.START_DATE,@p_to_date)>=0
	  ORDER BY DP.ID_STORE, DP.PLU, START_DATE DESC
END
END
