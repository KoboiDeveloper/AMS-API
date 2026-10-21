
--   exec [xsp_get_payment_detail_getrows] 'celcius','ALL','2022-01-1','2022-01-1'

CREATE procedure [dbo].[xsp_get_payment_detail_getrows]
(

  @p_brand		varchar(30)
 ,@p_store		varchar(20)
 ,@p_from_date  datetime
 ,@p_to_date	datetime

)

as
begin





  
SELECT 0 AS NO_URUT, X.ID_STORE AS STORE_ID,Tanggal_Transaksi AS TANGGAL,
isnull(SUM([CASH])+ SUM(Change),0) AS [CASH],
isnull(SUM( [D.BCA]),0) AS [DBCA]
,isnull(SUM( [K.BCA]),0) AS  [KBCA]
,isnull( SUM([D.MANDIRI]),0) AS [DMANDIRI]
, isnull(SUM([K.MANDIRI]),0) AS [KMANDIRI]
,isnull(SUM([D.BNI]),0) AS [DBNI]
,isnull(SUM([K.BNI]),0) AS [KBNI]
,format(isnull(SUM([D.BRI]),0) ,'##,##0')  AS [DBRI]
,format(isnull(SUM([K.BRI]),0) ,'##,##0')  AS [KBRI],
isnull(SUM([VOUCHER]),0) AS [VOUCHER],
isnull(SUM([VOUCHER_ONLINE]),0) AS [VOUCHER_ONLINE]
,isnull(SUM([K.OVO]),0) AS [KOVO],isnull(SUM([K.ATOME]),0) AS [ATOME] 
,isnull(SUM([K.INDODANA]),0) AS [KINDODANA]
,isnull(SUM([KQRIS]),0) AS [KQRIS]
,isnull(SUM([D_QRIS_BCA]),0) AS D_QRIS_BCA
,isnull(SUM([D_QRIS_BNI]),0) AS D_QRIS_BNI
,isnull(SUM([D_QRIS_BRI]),0) AS D_QRIS_BRI
,isnull(SUM([D_QRIS_MANDIRI]),0) AS D_QRIS_MANDIRI
,SUM(Change) AS CHANGE
, SUM(ONLINE) AS ONLINE
, SUM(COD) AS COD
	
	, (ISNULL(SUM([CASH]),0)+ ISNULL(SUM(Change),0)  + ISNULL(SUM( [D.BCA]),0) + ISNULL(SUM( [K.BCA]),0) + ISNULL(SUM([D.MANDIRI]),0)  + ISNULL(SUM([K.MANDIRI]),0) + ISNULL(SUM([D.BNI]),0)  + ISNULL(SUM([K.BNI]),0)  + ISNULL(SUM([D.BRI]),0)  + ISNULL(SUM([K.BRI]),0)+ISNULL(SUM([VOUCHER]),0)+ ISNULL(SUM([VOUCHER_ONLINE]),0) +ISNULL(SUM([K.OVO]),0)+ISNULL(SUM([K.ATOME]),0)+ISNULL(SUM([K.INDODANA]),0) + ISNULL(SUM(ONLINE),0) + ISNULL(SUM(COD),0)   + ISNULL(SUM(D_QRIS_BCA),0)+ ISNULL(SUM(D_QRIS_BNI),0)+ ISNULL(SUM(D_QRIS_BRI),0) + ISNULL(SUM(D_QRIS_MANDIRI),0)) as totalnyaLOH


FROM (

SELECT id_store,   
[CASH], [D.BCA], [K.BCA], [D.MANDIRI], [K.MANDIRI],[D.BNI],[K.BNI],[D.BRI],[K.BRI],ISNULL([VOUCHER],0) + ISNULL([Voucher Promosi],0) AS  VOUCHER,[VOUCHER_ONLINE],[K.OVO],[K.ATOME],[K.INDODANA],Change,sisa_voucher, 0 as ONLINE,0 AS COD,0 AS KQRIS,0 AS D_QRIS_BCA,0 AS D_QRIS_BNI,0 AS D_QRIS_BRI,0 AS D_QRIS_MANDIRI,Tanggal_Transaksi
FROM  
( 
SELECT b.id_store
		,A.[TIPE_BAYAR]
      ,A.[BAYAR] as bayar 
	  ,format(b.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
  FROM [POS_SERVER].[dbo].[TR_SALES_PAYMENT_DETAIL]  A
  INNER JOIN TR_SALES_HEADER B ON  B.[ID_TR_SALES_HEADER] = A.[ID_TR_SALES_HEADER] 
  INNER JOIN DT_Store X ON X.Store_ID = B.ID_Store  
  WHERE
   (case when @p_brand != 'ALL' AND  @p_store != 'ALL'   THEN B.id_store   END = @p_store
		OR 
	 case  WHEN @p_brand != 'ALL' AND  @p_store = 'ALL'    THEN X.Store_Brand_ID  END = @p_brand)
AND datediff(day,B.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,B.Tanggal_Transaksi,@p_to_date) >= 0  and (b.order_online = 0 or  b.order_online is null)
--group by   A.[TIPE_BAYAR] ,b.id_store
) as dt_bank

PIVOT  
(  
sum([BAYAR])  
FOR TIPE_BAYAR IN ([CASH], [D.BCA], [K.BCA], [D.MANDIRI], [K.MANDIRI],[D.BNI],[K.BNI],[D.BRI],[K.BRI],[VOUCHER],[Voucher Promosi],[VOUCHER_ONLINE],[K.OVO],[K.ATOME],[K.INDODANA],Change,sisa_voucher,KQRIS)  
) AS PivotTable  


UNION ALL
SELECT b.id_store 
		,0 AS [CASH], 0 AS [D.BCA], 0 AS [K.BCA], 0 AS [D.MANDIRI],0 AS  [K.MANDIRI],0 AS [D.BNI],0 AS [K.BNI],0 AS [D.BRI],0 AS [K.BRI],0 AS [VOUCHER],0 AS [VOUCHER_ONLINE],0 AS [K.OVO],0 AS [K.ATOME],0 AS [K.INDODANA],0 AS Change,0 AS sisa_voucher
      ,SUM(A.[BAYAR]) as ONLINE 
	  ,0 AS COD
	  ,0 AS KQRIS
	  -----DEBIT QRIS 
	  ,0 AS D_QRIS_BCA
	  ,0 AS D_QRIS_BNI
	  ,0 AS D_QRIS_BRI
	  ,0 AS D_QRIS_MANDIRI
	  -----
	  ,format(b.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
  FROM [POS_SERVER].[dbo].[TR_SALES_PAYMENT_DETAIL]  A
  INNER JOIN TR_SALES_HEADER B ON  B.[ID_TR_SALES_HEADER] = A.[ID_TR_SALES_HEADER] 
  INNER JOIN DT_Store X ON X.Store_ID = B.ID_Store  
  WHERE  (case when @p_brand != 'ALL' AND  @p_store != 'ALL'   THEN B.id_store   END = @p_store
		OR 
	 case  WHEN @p_brand != 'ALL' AND  @p_store = 'ALL'    THEN X.Store_Brand_ID  END = @p_brand)
AND datediff(day,B.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,B.Tanggal_Transaksi,@p_to_date) >= 0
  and ((b.order_online = 1   and  b.cod = 0  AND a.TIPE_BAYAR = 'K.QRIS') OR (b.order_online = 0 AND  b.cod = 0  and a.TIPE_BAYAR = 'K.QRIS'))
group by   b.id_store ,b.Tanggal_Transaksi



UNION ALL
SELECT b.id_store 
		,0 AS [CASH], 0 AS [D.BCA], 0 AS [K.BCA], 0 AS [D.MANDIRI],0 AS  [K.MANDIRI],0 AS [D.BNI],0 AS [K.BNI],0 AS [D.BRI],0 AS [K.BRI],0 AS [VOUCHER],0 AS [VOUCHER_ONLINE],0 AS [K.OVO],0 AS [K.ATOME],0 AS [K.INDODANA],0 AS Change,0 AS sisa_voucher
      ,0 as ONLINE 
	  ,SUM(A.[BAYAR])  AS COD
	  ,0 AS KQRIS
	  -----DEBIT QRIS 
	  ,0 AS D_QRIS_BCA
	  ,0 AS D_QRIS_BNI
	  ,0 AS D_QRIS_BRI
	  ,0 AS D_QRIS_MANDIRI
	  -----
	  ,format(b.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
  FROM [POS_SERVER].[dbo].[TR_SALES_PAYMENT_DETAIL]  A
  INNER JOIN TR_SALES_HEADER B ON  B.[ID_TR_SALES_HEADER] = A.[ID_TR_SALES_HEADER] 
  INNER JOIN DT_Store X ON X.Store_ID = B.ID_Store  
  WHERE (case when @p_brand != 'ALL' AND  @p_store != 'ALL'   THEN B.id_store   END = @p_store
		OR 
	 case  WHEN @p_brand != 'ALL' AND  @p_store = 'ALL'    THEN X.Store_Brand_ID  END = @p_brand) 
AND  datediff(day,B.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,B.Tanggal_Transaksi,@p_to_date) >= 0
  and (b.order_online = 1 and b.cod = 1 and a.TIPE_BAYAR = 'K.QRIS') 
group by   b.id_store ,b.Tanggal_Transaksi


UNION ALL
SELECT b.id_store 
		,0 AS [CASH], 0 AS [D.BCA], 0 AS [K.BCA], 0 AS [D.MANDIRI],0 AS  [K.MANDIRI],0 AS [D.BNI],0 AS [K.BNI],0 AS [D.BRI],0 AS [K.BRI],0 AS [VOUCHER],0 AS [VOUCHER_ONLINE],0 AS [K.OVO],0 AS [K.ATOME],0 AS [K.INDODANA],0 AS Change,0 AS sisa_voucher
      ,0 as ONLINE 
	  ,0  AS COD
	  ,SUM(A.[BAYAR]) AS KQRIS
	  -----DEBIT QRIS 
	  ,0 AS D_QRIS_BCA
	  ,0 AS D_QRIS_BNI
	  ,0 AS D_QRIS_BRI
	  ,0 AS D_QRIS_MANDIRI
	  -----
	  ,format(b.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
  FROM [POS_SERVER].[dbo].[TR_SALES_PAYMENT_DETAIL]  A
  INNER JOIN TR_SALES_HEADER B ON  B.[ID_TR_SALES_HEADER] = A.[ID_TR_SALES_HEADER]  WHERE B.id_store = @p_store
AND datediff(day,B.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,B.Tanggal_Transaksi,@p_to_date) >= 0 AND   TIPE_BAYAR = 'K.QRIS'
group by   b.id_store,b.Tanggal_Transaksi


UNION ALL
SELECT b.id_store 
		,0 AS [CASH], 0 AS [D.BCA], 0 AS [K.BCA], 0 AS [D.MANDIRI],0 AS  [K.MANDIRI],0 AS [D.BNI],0 AS [K.BNI],0 AS [D.BRI],0 AS [K.BRI],0 AS [VOUCHER],0 AS [VOUCHER_ONLINE],0 AS [K.OVO],0 AS [K.ATOME],0 AS [K.INDODANA],0 AS Change,0 AS sisa_voucher
      ,0 as ONLINE 
	  ,0  AS COD
	  ,0 AS KQRIS
	  -----DEBIT QRIS 
	  ,SUM(A.[BAYAR]) AS D_QRIS_BCA
	  ,0 AS D_QRIS_BNI
	  ,0 AS D_QRIS_BRI
	  ,0 AS D_QRIS_MANDIRI
	  -----
	  ,format(b.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
  FROM [POS_SERVER].[dbo].[TR_SALES_PAYMENT_DETAIL]  A
  INNER JOIN TR_SALES_HEADER B ON  B.[ID_TR_SALES_HEADER] = A.[ID_TR_SALES_HEADER]  WHERE B.id_store = @p_store
AND datediff(day,B.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,B.Tanggal_Transaksi,@p_to_date) >= 0 AND   TIPE_BAYAR = 'D.QRIS BCA'
group by   b.id_store,b.Tanggal_Transaksi



UNION ALL
SELECT b.id_store 
		,0 AS [CASH], 0 AS [D.BCA], 0 AS [K.BCA], 0 AS [D.MANDIRI],0 AS  [K.MANDIRI],0 AS [D.BNI],0 AS [K.BNI],0 AS [D.BRI],0 AS [K.BRI],0 AS [VOUCHER],0 AS [VOUCHER_ONLINE],0 AS [K.OVO],0 AS [K.ATOME],0 AS [K.INDODANA],0 AS Change,0 AS sisa_voucher
      ,0 as ONLINE 
	  ,0  AS COD
	  ,0 AS KQRIS
	  -----DEBIT QRIS 
	  ,0 AS D_QRIS_BCA
	  ,SUM(A.[BAYAR]) AS D_QRIS_BNI
	  ,0 AS D_QRIS_BRI
	  ,0 AS D_QRIS_MANDIRI
	  -----
	  ,format(b.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
  FROM [POS_SERVER].[dbo].[TR_SALES_PAYMENT_DETAIL]  A
  INNER JOIN TR_SALES_HEADER B ON  B.[ID_TR_SALES_HEADER] = A.[ID_TR_SALES_HEADER]  WHERE B.id_store = @p_store
AND datediff(day,B.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,B.Tanggal_Transaksi,@p_to_date) >= 0 AND   TIPE_BAYAR = 'D.QRIS BNI'
group by   b.id_store,b.Tanggal_Transaksi


UNION ALL
SELECT b.id_store 
		,0 AS [CASH], 0 AS [D.BCA], 0 AS [K.BCA], 0 AS [D.MANDIRI],0 AS  [K.MANDIRI],0 AS [D.BNI],0 AS [K.BNI],0 AS [D.BRI],0 AS [K.BRI],0 AS [VOUCHER],0 AS [VOUCHER_ONLINE],0 AS [K.OVO],0 AS [K.ATOME],0 AS [K.INDODANA],0 AS Change,0 AS sisa_voucher
      ,0 as ONLINE 
	  ,0  AS COD
	  ,0 AS KQRIS
	  -----DEBIT QRIS 
	  ,0 AS D_QRIS_BCA
	  ,0 AS D_QRIS_BNI
	  ,SUM(A.[BAYAR]) AS D_QRIS_BRI
	  ,0 AS D_QRIS_MANDIRI
	  -----
	  ,format(b.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
  FROM [POS_SERVER].[dbo].[TR_SALES_PAYMENT_DETAIL]  A
  INNER JOIN TR_SALES_HEADER B ON  B.[ID_TR_SALES_HEADER] = A.[ID_TR_SALES_HEADER]  WHERE B.id_store = @p_store
AND datediff(day,B.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,B.Tanggal_Transaksi,@p_to_date) >= 0 AND   TIPE_BAYAR = 'D.QRIS BRI'
group by   b.id_store,b.Tanggal_Transaksi


UNION ALL
SELECT b.id_store 
		,0 AS [CASH], 0 AS [D.BCA], 0 AS [K.BCA], 0 AS [D.MANDIRI],0 AS  [K.MANDIRI],0 AS [D.BNI],0 AS [K.BNI],0 AS [D.BRI],0 AS [K.BRI],0 AS [VOUCHER],0 AS [VOUCHER_ONLINE],0 AS [K.OVO],0 AS [K.ATOME],0 AS [K.INDODANA],0 AS Change,0 AS sisa_voucher
      ,0 as ONLINE 
	  ,0  AS COD
	  ,0 AS KQRIS
	  -----DEBIT QRIS 
	  ,0 AS D_QRIS_BCA
	  ,0 AS D_QRIS_BNI
	  ,0 AS D_QRIS_BRI
	  ,SUM(A.[BAYAR]) AS D_QRIS_MANDIRI
	  -----
	  ,format(b.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
  FROM [POS_SERVER].[dbo].[TR_SALES_PAYMENT_DETAIL]  A
  INNER JOIN TR_SALES_HEADER B ON  B.[ID_TR_SALES_HEADER] = A.[ID_TR_SALES_HEADER]  WHERE B.id_store = @p_store
AND datediff(day,B.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,B.Tanggal_Transaksi,@p_to_date) >= 0 AND   TIPE_BAYAR = 'D.QRIS MDR'
group by   b.id_store,b.Tanggal_Transaksi

) AS X GROUP BY X.id_store,x.Tanggal_Transaksi
 ORDER BY STORE_ID





--SELECT X.STORE as STORE_ID ,format(X.TGL_TRANSAKSI,'yyyy-MM-dd') as TANGGAL,
--						( SUM(X.Cash)  + SUM(X.Change)) + SUM(X.[D.BCA]) +
--						  SUM(X.[D.BNI])  + SUM(X.[D.MANDIRI])+
--						  SUM(X.[K.BCA]) +SUM(X.[K.BNI])+SUM(X.[K.MANDIRI])+
--						  SUM(X.[Nilai_Refund])+SUM(X.Voucher)+SUM(X.Voucher_Online)+ SUM(X.KOVO) +SUM(X.ONLINE) AS 'TOTAL'




--						 ,SUM(X.Cash) + SUM(X.Change) AS CASH,SUM(X.Change) AS CHANGE, SUM(X.[D.BCA]) AS 'DBCA'
--						 ,cast(SUM(X.[D.BNI]) as decimal(18,2)) AS 'DBNI',SUM(X.[D.MANDIRI]) AS 'DMANDIRI'
--						 ,SUM(X.[K.BCA]) AS 'kBCA' ,SUM(X.[K.BNI]) AS 'kBNI' ,SUM(X.[K.MANDIRI]) AS 'kMANDIRI'
--						 ,SUM(X.[Nilai_Refund]) AS 'Nilai_Refund' ,SUM(X.Voucher) AS 'Voucher',SUM(X.Voucher_Online) AS 'Voucher_Online',SUM(X.KOVO) AS 'KOVO',SUM(X.ONLINE) AS 'ONLINE'
--						  FROM (
 
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,B.BAYAR  AS 'Cash'
--		,0 AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0 AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store = @p_store AND B.TIPE_BAYAR = 'CASH' and  datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 

--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,B.BAYAR  AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0 AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store = @p_store AND B.TIPE_BAYAR = 'Change' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 

--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,B.BAYAR AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0 AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.order_online = 0 AND A.ID_Store = @p_store AND B.TIPE_BAYAR = 'D.BCA' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 

--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,0 AS 'D.BCA'
--		,B.BAYAR  AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0 AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store = @p_store AND B.TIPE_BAYAR = 'D.BNI' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 

--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,B.BAYAR  AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0 AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store = @p_store AND B.TIPE_BAYAR = 'D.MANDIRI' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 


--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,B.BAYAR  AS 'K.BCA'
--		,0 AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store = @p_store AND B.TIPE_BAYAR = 'K.BCA' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 

--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,B.BAYAR  AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store = @p_store AND B.TIPE_BAYAR = 'K.BNI' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 

--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0  AS 'K.BNI'
--		,B.BAYAR AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store = @p_store AND B.TIPE_BAYAR = 'K.MANDIRI' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 

--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0  AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,B.BAYAR  AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store = @p_store AND B.TIPE_BAYAR = 'Nilai Refund' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 

--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0  AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,B.BAYAR  AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store = @p_store AND B.TIPE_BAYAR = 'Voucher' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 
--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0  AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,B.BAYAR AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store  = @p_store AND B.TIPE_BAYAR = 'Voucher_Online' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 
--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0  AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,B.BAYAR AS 'KOVO'
--		,0 AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.ID_Store  = @p_store AND B.TIPE_BAYAR = 'K.OVO' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 

--UNION ALL
--select A.ID_Store AS STORE
--	    ,A.Tanggal_Transaksi AS TGL_TRANSAKSI 
--		,0 AS 'Cash'
--		,0  AS 'Change'
--		,0 AS 'D.BCA'
--		,0 AS 'D.BNI'
--		,0 AS 'D.MANDIRI'
--		,0 AS 'K.BCA'
--		,0 AS 'K.BNI'
--		,0 AS 'K.MANDIRI'
--		,0 AS 'Nilai_Refund'
--		,0 AS 'Voucher'
--		,0 AS 'Voucher_Online'
--		,0 AS 'KOVO'
--		,B.BAYAR AS 'ONLINE'
--	   from TR_SALES_HEADER A
--inner join TR_SALES_PAYMENT_DETAIL B ON A.ID_TR_SALES_HEADER = B.ID_TR_SALES_HEADER
--WHERE A.order_online = 1 AND  A.ID_Store  = @p_store AND B.TIPE_BAYAR = 'D.BCA' and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >= 0 
--) AS X
----where  datediff(day,x.TGL_TRANSAKSI,@p_from_date) <= 0 and datediff(day,x.TGL_TRANSAKSI,@p_to_date) >= 0 
--GROUP BY X.STORE, format(X.TGL_TRANSAKSI,'yyyy-MM-dd')
--ORDER BY X.STORE ASC,format(X.TGL_TRANSAKSI,'yyyy-MM-dd') ASC






end