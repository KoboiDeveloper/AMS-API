 --- EXEC XSP_RPT_SALES_DETAIL_WOMAN_GETROWS '2022-12-01','2022-12-31'
CREATE PROCEDURE [dbo].[XSP_RPT_SALES_DETAIL_WOMAN_GETROWS] 

(
	 @p_from_date					VARCHAR(20)
	,@p_to_date						VARCHAR(20)
)
AS
BEGIN 


with cte
as
(
SELECT   [KODE]  FROM [SPACEX].[dbo].[master_class] WITH (NOLOCK)  where GENDER = 'female'
)

SELECT  
      ROW_NUMBER() OVER ( 
    ORDER BY DS.Store_ID ASC ) as NO
	, DS.Store_ID + ' - ' + DS.Store_Kota AS ID_STORE
      ,TSD.[PLU]
	  ,format(TSh.Tanggal_Transaksi,'yyyy-MM-dd HH:mm:ss') as TGL 
      ,TSD.[ARTICLE]
      ,TSD.[DESKRIPSI] 
      ,TSD.[HPP]
      ,TSD.[PPN]
      ,TSD.[Harga_Jual]
      ,TSD.[QTY]
      ,TSD.[Net]  
  FROM [POS_SERVER].[dbo].[TR_SALES_DETAIL] TSD WITH (NOLOCK)
  LEFT OUTER JOIN DT_STORE DS ON (DS.Store_ID = TSD.ID_Store) 
  INNER JOIN TR_SALES_HEADER   TSH ON TSH.ID_TR_SALES_HEADER = TSD.ID_TR_SALES_HEADER 
  WHERE 
   (DATEDIFF(DAY,TSH.Tanggal_Transaksi,@p_from_date) <=0 AND DATEDIFF(DAY,TSH.Tanggal_Transaksi,@p_to_date) >=0 ) 
	AND LEFT(TSD.PLU,3) IN (select * from cte ) 
 
	   
END










