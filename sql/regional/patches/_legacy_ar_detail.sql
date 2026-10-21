--exec [XSP_RPT_sales_ar_GETROWS]  '2022/05/13', '2022/05/14', 'celcius', 'rc038'   
CREATE PROCEDURE [dbo].[XSP_RPT_sales_ar_GETROWS] 

(	---@p_id_tr_sales_header						varchar(32)
	 @p_from_date					datetime
	,@p_to_date						datetime
	,@p_brand_id					varchar(30)
	,@p_store_id					varchar(10)
	--,@p_multi_store					varchar(max)
	 --,@p_id_gh				 varchar(20)
)
AS
BEGIN
IF (@p_brand_id = 'ALL' and @p_store_id = 'ALL')

BEGIN
select x.id_tr_sales_header, x.ID_Store, x.tanggal_transaksi, ISNULL(sum(x.cash)+ sum(x.CHANGE),0) as cash,
 sum(x.CBCA)  + SUM(x.CBNI) + SUM(x.CMANDIRI)+sum(x.DBCA)  + SUM(x.DBNI) + SUM(x.DMANDIRI) as CARD, 
 sum(x.voucher) as voucher  ,sum(x.KOVO) as OVO ,sum(KQRIS) as KQRIS,sum(KATOME) as KATOME,  sum(x.refund) as refund, ISNULL(sum(x.SISA_Voucher),0) as SISA_VOUCHER,
ISNULL( (sum(x.cash)+ sum(x.CHANGE) ) + (sum(x.CBCA)  + SUM(x.CBNI) + SUM(x.CMANDIRI)+sum(x.DBCA)  + SUM(x.DBNI) + SUM(x.DMANDIRI) ) + sum(x.voucher)+ sum(x.SISA_Voucher),0) + sum(x.KOVO) + sum(KQRIS)  + sum(KATOME) -  sum(x.refund)    as total






from( 
------------------------------------------------CASH

-- select  tsd.ID_Store
--		,format(DB.Tgl,'yyyy-MM-dd') as tanggal_transaksi
--		 ,max(DB.PU94_CASH ) as cash
--		,0 AS 'CBCA' 
--		,0 AS 'CBNI' 
--		,0 AS 'CMANDIRI' 
--		,0 AS 'DBCA'
--		,0 AS 'DBNI'
--		,0 AS 'DMANDIRI'
--		,0 as voucher
--		,0 as Refund
--		,0 as KOVO
--from   pos_server.dbo.TR_SALES_HEADER tsd
--INNER JOIN POS_SERVER.DBO.DT_BATCH DB ON (DB.Store_ID   = tsd.Id_store) 
--	  and datediff(day,DB.Tgl,format(@p_from_date,'yyyy-MM-dd')) <= 0 and datediff(day,DB.Tgl,format(@p_to_date,'yyyy-MM-dd')) >=0 
--GROUP BY TSD.ID_Store ,DB.Tgl ,DB.PU94_CASH  


-- select  tsd.ID_Store
--		,format(tsd.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
--		,case when tpd.tipe_bayar = 'Cash' then sum(tpd.BAYAR) end 'Cash'
--		,0 as credit
--		,0 as voucher
--from  pos_serverX.dbo.TR_SALES_HEADER tsd

--inner join pos_serverX.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 

--WHERE     tpd.TIPE_BAYAR not in ('Change','Nilai Refund')
--		and tpd.TIPE_BAYAR not like '%D.%'
--		and tpd.TIPE_BAYAR not like '%K.%'
--		and tpd.TIPE_BAYAR not like '%voucher%'
--		and datediff(day,tsd.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,tsd.Tanggal_Transaksi,@p_to_date) >=0 
--		--and format(TSD.WAKTU_URUT,'yyyy-MM-dd') = '2017-08-20'
--GROUP BY TSD.ID_Store, tpd.tipe_bayar  ,tsd.Tanggal_Transaksi

--union all
----------------------------------------------------CREDIT
  
   
select a.id_tr_sales_header,
    a.id_store,CONVERT(VARCHAR(10),
    a.tanggal_transaksi, 120) as tanggal_transaksi,  
    sum(case when c.tipe_bayar='CASH' then c.bayar else 0 end) as CASH, 
   sum(case when c.tipe_bayar='K.BCA' then c.bayar else 0 end) as CBCA, 
   sum(case when c.tipe_bayar='K.BNI' then c.bayar else 0 end) as CBNI,
      sum(case when c.tipe_bayar='K.MANDIRI' then c.bayar else 0 end) as CMANDIRI,
     sum(case when c.tipe_bayar='D.BCA' then c.bayar else 0 end) as DBCA,
	   sum(case when c.tipe_bayar='D.BNI' then c.bayar else 0 end) as DBNI,
   sum(case when c.tipe_bayar='D.MANDIRI' then c.bayar else 0 end) as DMANDIRI 
  ,sum(case when c.tipe_bayar like 'Voucher%'  then c.bayar else 0 end) as Voucher
   ,sum(case when c.tipe_bayar = 'sisa_Voucher'  then c.bayar else 0 end) as SISA_Voucher
   ,sum(case when c.tipe_bayar='Nilai Refund' then c.bayar else 0 end) Refund
	    ,sum(case when c.tipe_bayar='K.OVO' then c.bayar else 0 end) KOVO
		 ,sum(case when c.tipe_bayar='change' then c.bayar else 0 end) CHANGE
		 ,sum(case when c.tipe_bayar='K.QRIS' then c.bayar else 0 end) KQRIS 
		 ,sum(case when c.tipe_bayar='K.ATOME' then c.bayar else 0 end) KATOME
   from pos_serverx.dbo.TR_SALES_HEADER a inner join  pos_serverx.dbo.TR_SALES_PAYMENT_DETAIL c on a.id_tr_sales_header=c.id_tr_sales_header
   inner join DT_Store d on a.ID_Store=d.Store_ID
   --inner join DT_STORE_CABANG e on a.ID_Store=e.store_code
   where a.status_transaksi=1  
   and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >=0 
   --and datediff(month,a.tanggal_transaksi,'2017-12-20')=0 --and left(e.Kode_Cabang,3)='02F'
   group by CONVERT(VARCHAR(6), a.tanggal_transaksi, 112),d.Store_Brand_ID,a.id_store,CONVERT(VARCHAR(10), a.tanggal_transaksi, 120),a.id_tr_sales_header


--select  tsd.ID_Store
--		,format(tsd.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
--		,0 as cash
--		,case when tpd.tipe_bayar = 'K.BCA'		then sum(tpd.BAYAR) end 'CBCA' 
--		,case when tpd.tipe_bayar = 'K.BNI'		then sum(tpd.BAYAR) end 'CBNI' 
--		,case when tpd.tipe_bayar = 'K.MANDIRI' then sum(tpd.BAYAR) end 'CMANDIRI' 
--		,case when tpd.tipe_bayar = 'D.BCA'		then sum(tpd.BAYAR) end 'DBCA'
--		,case when tpd.tipe_bayar = 'D.BNI'		then sum(tpd.BAYAR) end 'DBNI'
--		,case when tpd.tipe_bayar = 'D.MANDIRI' then sum(tpd.BAYAR) end 'DMANDIRI'
--		,0 'Voucher'
--from  pos_server.dbo.TR_SALES_HEADER tsd

--INNER  join pos_server.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 

--WHERE   
--		 datediff(day,tsd.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,tsd.Tanggal_Transaksi,@p_to_date) >=0 
--		--and format(TSD.WAKTU_URUT,'yyyy-MM-dd') = '2017-08-20'
--GROUP BY TSD.ID_Store, tpd.tipe_bayar  ,tsd.Tanggal_Transaksi
) as x
group by x.ID_Store, x.tanggal_transaksi ,x.id_tr_sales_header
order by ID_Store , x.tanggal_transaksi  ASC

END

ELSE IF(@p_store_id != 'ALL' and @p_brand_id != 'ALL')
BEGIN  
select x.ID_Store, x.tanggal_transaksi, sum(x.cash)+ sum(x.CHANGE) as cash,
 sum(x.CBCA)  + SUM(x.CBNI) + SUM(x.CMANDIRI)+sum(x.DBCA)  + SUM(x.DBNI) + SUM(x.DMANDIRI) as CARD, 
 sum(x.voucher) as voucher , sum(x.KOVO) as OVO,sum(KQRIS) as KQRIS,sum(KATOME) as KATOME, sum(x.refund) as refund,ISNULL(sum(x.SISA_Voucher),0) as SISA_VOUCHER,
 (sum(x.cash)+ sum(x.CHANGE)) + (sum(x.CBCA)  + SUM(x.CBNI) + SUM(x.CMANDIRI)+sum(x.DBCA)  + SUM(x.DBNI) + SUM(x.DMANDIRI) ) + sum(x.voucher)+ sum(x.sisa_Voucher) + sum(x.KOVO) + sum(KQRIS)  + sum(KATOME)  -  sum(x.refund)  as total
from( 
------------------------------------------------CASH

-- select  tsd.ID_Store
--		,format(DB.Tgl,'yyyy-MM-dd') as tanggal_transaksi
--		 ,max(DB.PU94_CASH ) as cash
--		,0 AS 'CBCA' 
--		,0 AS 'CBNI' 
--		,0 AS 'CMANDIRI' 
--		,0 AS 'DBCA'
--		,0 AS 'DBNI'
--		,0 AS 'DMANDIRI'
--		,0 as voucher
--		,0 as Refund
--		,0 as KOVO
--from   pos_server.dbo.TR_SALES_HEADER tsd
--INNER JOIN POS_SERVER.DBO.DT_BATCH DB ON (DB.Store_ID   = tsd.Id_store) 
--	  where  datediff(day,DB.Tgl,format(@p_from_date,'yyyy-MM-dd')) <= 0 and datediff(day,DB.Tgl,format(@p_to_date,'yyyy-MM-dd')) >=0 
--	  and tsd.ID_Store = @p_store_id 
--GROUP BY TSD.ID_Store ,DB.Tgl ,DB.PU94_CASH   

--union all 
   

  select 
   a.id_store,CONVERT(VARCHAR(10),
    a.tanggal_transaksi, 120) as tanggal_transaksi,  
   --0 AS CASH,
   sum(case when c.tipe_bayar='CASH' then c.bayar else 0 end) as CASH, 
   sum(case when c.tipe_bayar='K.BCA' then c.bayar else 0 end) as CBCA, 
   sum(case when c.tipe_bayar='K.BNI' then c.bayar else 0 end) as CBNI,
      sum(case when c.tipe_bayar='K.MANDIRI' then c.bayar else 0 end) as CMANDIRI,
     sum(case when c.tipe_bayar='D.BCA' then c.bayar else 0 end) as DBCA,
	   sum(case when c.tipe_bayar='D.BNI' then c.bayar else 0 end) as DBNI,
   sum(case when c.tipe_bayar='D.MANDIRI' then c.bayar else 0 end) as DMANDIRI 
  ,sum(case when c.tipe_bayar like 'Voucher%'  then c.bayar else 0 end) as Voucher
     ,sum(case when c.tipe_bayar = 'sisa_Voucher'  then c.bayar else 0 end) as SISA_Voucher
   ,sum(case when c.tipe_bayar='Nilai Refund' then c.bayar else 0 end) Refund
	    ,sum(case when c.tipe_bayar='K.OVO' then c.bayar else 0 end) KOVO
			 ,sum(case when c.tipe_bayar='change' then c.bayar else 0 end) CHANGE
		 ,sum(case when c.tipe_bayar='K.QRIS' then c.bayar else 0 end) KQRIS
		 ,sum(case when c.tipe_bayar='K.ATOME' then c.bayar else 0 end) KATOME
   from pos_serverX.dbo.TR_SALES_HEADER a 
   inner join  pos_serverX.dbo.TR_SALES_PAYMENT_DETAIL c on a.id_tr_sales_header=c.id_tr_sales_header
   inner join DT_Store d on a.ID_Store=d.Store_ID
   --inner join DT_STORE_CABANG e on a.ID_Store=e.store_code
   where a.status_transaksi=1 
   and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >=0 
   --  and a.ID_TR_SALES_HEADER not in 
	  --(select   ID_TR_SALES_HEADER from POS_SERVER.dbo.TR_SALES_REFUND where datediff(day,TGL_REFUND, (@p_from_date )) <= 0 and datediff(day,TGL_REFUND,  @p_to_date ) >=0 )
	  and a.ID_Store = @p_store_id 
   --and datediff(month,a.tanggal_transaksi,'2017-12-20')=0 --and left(e.Kode_Cabang,3)='02F'
   group by CONVERT(VARCHAR(6), a.tanggal_transaksi, 112),d.Store_Brand_ID,a.id_store,CONVERT(VARCHAR(10), a.tanggal_transaksi, 120)


) as x
group by x.ID_Store, x.tanggal_transaksi  
order by ID_Store , x.tanggal_transaksi  ASC


 

--select x.ID_Store, x.tanggal_transaksi, sum(x.cash) as cash, sum(x.credit) + SUM(x.DEBIT) as CARD, sum(x.voucher) as voucher ,
-- sum(x.cash) + sum(x.credit) + sum(x.voucher) as total
--from(
--------------------------------------------------CASH
-- select  tsd.ID_Store
--		,format(DB.Tgl,'yyyy-MM-dd') as tanggal_transaksi
--		 ,max(DB.PU94_CASH ) as cash
--		,0 as credit
--		,0 AS DEBIT
--		,0 as voucher
--from   pos_serverX.dbo.TR_SALES_HEADER tsd

--inner join  pos_serverX.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 
--INNER JOIN POS_SERVER.DBO.DT_BATCH DB ON (DB.Store_ID   = tsd.Id_store)
--WHERE   tsd.ID_Store = @p_store_id 
--	  and datediff(day,DB.Tgl,format(@p_from_date,'yyyy-MM-dd')) <= 0 and datediff(day,DB.Tgl,format(@p_to_date,'yyyy-MM-dd')) >=0 
--GROUP BY TSD.ID_Store ,DB.Tgl ,DB.PU94_CASH  

----jadul 1 29 2018
---- select  tsd.ID_Store
----		,format(tsd.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
----		,case when tpd.tipe_bayar = 'Cash' then sum(tpd.BAYAR) end 'Cash'
----		,0 as credit
----		,0 as voucher
----from  pos_serverX.dbo.TR_SALES_HEADER tsd

----inner join pos_serverX.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 

----WHERE   tsd.ID_Store = @p_store_id
----		AND tpd.TIPE_BAYAR not in ('Change','Nilai Refund')
----		and tpd.TIPE_BAYAR not like '%D.%'
----		and tpd.TIPE_BAYAR not like '%K.%'
----		and tpd.TIPE_BAYAR not like '%voucher%'
----		and datediff(day,tsd.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,tsd.Tanggal_Transaksi,@p_to_date) >=0 
----		--and format(TSD.WAKTU_URUT,'yyyy-MM-dd') = '2017-08-20'
----GROUP BY TSD.ID_Store, tpd.tipe_bayar  ,tsd.Tanggal_Transaksi

--union all
------------------------------------------------------CREDIT


--select  tsd.ID_Store
--		,format(tsd.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
--		,0 as cash
--		,case when tpd.tipe_bayar like '%K.%' then sum(tpd.BAYAR) end 'Credit'
--		,0 AS DEBIT
--		,0 as voucher
--from  pos_server.dbo.TR_SALES_HEADER tsd

--inner join pos_server.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 

--WHERE   tsd.ID_Store = @p_store_id
--		AND tpd.TIPE_BAYAR not in ('Change','Nilai Refund','Cash') 
--		and tpd.TIPE_BAYAR not like '%voucher%'
--		and tpd.TIPE_BAYAR not like '%D.%'
--		and datediff(day,tsd.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,tsd.Tanggal_Transaksi,@p_to_date) >=0 
--		--and format(TSD.WAKTU_URUT,'yyyy-MM-dd') = '2017-08-20'
--GROUP BY TSD.ID_Store, tpd.tipe_bayar  ,tsd.Tanggal_Transaksi


---------------------------------------------debit
--UNION ALL

--select  tsd.ID_Store
--		,format(tsd.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
--		,0 as cash
--			,0 as credit
--		,case when tpd.tipe_bayar like '%D.%' then sum(tpd.BAYAR) end 'DEBIT'
--		,0 as voucher
--from  pos_server.dbo.TR_SALES_HEADER tsd

--inner join pos_server.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 

--WHERE   tsd.ID_Store = @p_store_id
--		AND tpd.TIPE_BAYAR not in ('Change','Nilai Refund','Cash') 
--		and tpd.TIPE_BAYAR not like '%voucher%'
--		and tpd.TIPE_BAYAR not like '%K.%'
--		and datediff(day,tsd.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,tsd.Tanggal_Transaksi,@p_to_date) >=0 
--		--and format(TSD.WAKTU_URUT,'yyyy-MM-dd') = '2017-08-20'
--GROUP BY TSD.ID_Store, tpd.tipe_bayar  ,tsd.Tanggal_Transaksi

----------------------------------------------VOUCHER

--union all

--select  tsd.ID_Store
--		,format(tsd.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
--		,0 as cash
--		,0 as credit
--			,0 as debit
--		,case when tpd.tipe_bayar like '%VOUCHER%' then sum(tpd.BAYAR) end 'Voucher'
--from  pos_server.dbo.TR_SALES_HEADER tsd

--inner join pos_server.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 

--WHERE   tsd.ID_Store = @p_store_id
--		AND tpd.TIPE_BAYAR not in ('Change','Nilai Refund','Cash')
--		and tpd.TIPE_BAYAR not like '%D.%'
--		and tpd.TIPE_BAYAR not like '%K.%'
--		and datediff(day,tsd.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,tsd.Tanggal_Transaksi,@p_to_date) >=0 
--		--and format(TSD.WAKTU_URUT,'yyyy-MM-dd') = '2017-08-20'
--GROUP BY TSD.ID_Store, tpd.tipe_bayar  ,tsd.Tanggal_Transaksi
--) as x
--group by x.ID_Store, x.tanggal_transaksi
--order by ID_Store, tanggal_transaksi
--END
----PRINT @p_multi_store


end
ELSE IF(@p_store_id = 'ALL' and @p_brand_id != 'ALL')
BEGIN 




select x.ID_Store, x.tanggal_transaksi, sum(x.cash)+ sum(x.CHANGE) as cash,
 sum(x.CBCA)  + SUM(x.CBNI) + SUM(x.CMANDIRI)+sum(x.DBCA)  + SUM(x.DBNI) + SUM(x.DMANDIRI) as CARD,
  sum(x.voucher) as voucher , sum(x.KOVO) as OVO,sum(KQRIS) AS KQRIS,sum(KATOME) as KATOME, sum(x.refund) as refund,ISNULL(sum(x.SISA_Voucher),0) as SISA_VOUCHER,
  (sum(x.cash)+ sum(x.CHANGE)) + (sum(x.CBCA)  + SUM(x.CBNI) + SUM(x.CMANDIRI)+sum(x.DBCA)  + SUM(x.DBNI) + SUM(x.DMANDIRI) ) + sum(x.voucher) + sum(x.SISA_Voucher)+ sum(x.KOVO) + sum(KQRIS) + sum(KATOME)  -  sum(x.refund)   as total


from( 
------------------------------------------------CASH

-- select  tsd.ID_Store
--		,format(DB.Tgl,'yyyy-MM-dd') as tanggal_transaksi
--		 ,max(DB.PU94_CASH ) as cash
--		,0 AS 'CBCA' 
--		,0 AS 'CBNI' 
--		,0 AS 'CMANDIRI' 
--		,0 AS 'DBCA'
--		,0 AS 'DBNI'
--		,0 AS 'DMANDIRI'
--		,0 as voucher
--		,0 as Refund
--		,0 as KOVO
--from   pos_server.dbo.TR_SALES_HEADER tsd
--inner join dt_store ds on (ds.Store_ID = tsd.ID_Store)
--INNER JOIN POS_SERVER.DBO.DT_BATCH DB ON (DB.Store_ID   = tsd.Id_store) 
--	  where  datediff(day,DB.Tgl,format(@p_from_date,'yyyy-MM-dd')) <= 0 and datediff(day,DB.Tgl,format(@p_to_date,'yyyy-MM-dd')) >=0 
--	  and  ds.Store_Brand_ID = @p_brand_id
--GROUP BY TSD.ID_Store ,DB.Tgl ,DB.PU94_CASH   

--union all 
   
  select 
   a.id_store,CONVERT(VARCHAR(10),
    a.tanggal_transaksi, 120) as tanggal_transaksi,  
    sum(case when c.tipe_bayar='CASH' then c.bayar else 0 end) as CASH,
   sum(case when c.tipe_bayar='K.BCA' then c.bayar else 0 end) as CBCA, 
   sum(case when c.tipe_bayar='K.BNI' then c.bayar else 0 end) as CBNI,
      sum(case when c.tipe_bayar='K.MANDIRI' then c.bayar else 0 end) as CMANDIRI,
     sum(case when c.tipe_bayar='D.BCA' then c.bayar else 0 end) as DBCA,
	   sum(case when c.tipe_bayar='D.BNI' then c.bayar else 0 end) as DBNI,
   sum(case when c.tipe_bayar='D.MANDIRI' then c.bayar else 0 end) as DMANDIRI 
  ,sum(case when c.tipe_bayar like 'Voucher%'  then c.bayar else 0 end) as Voucher
     ,sum(case when c.tipe_bayar = 'sisa_Voucher'  then c.bayar else 0 end) as SISA_Voucher
   ,sum(case when c.tipe_bayar='Nilai Refund' then c.bayar else 0 end) Refund
	    ,sum(case when c.tipe_bayar='K.OVO' then c.bayar else 0 end) KOVO
			 ,sum(case when c.tipe_bayar='change' then c.bayar else 0 end) CHANGE
		 ,sum(case when c.tipe_bayar='K.QRIS' then c.bayar else 0 end) KQRIS
		 ,sum(case when c.tipe_bayar='K.ATOME' then c.bayar else 0 end) KATOME
   from pos_serverx.dbo.TR_SALES_HEADER a inner join  pos_serverx.dbo.TR_SALES_PAYMENT_DETAIL c on a.id_tr_sales_header=c.id_tr_sales_header
   inner join DT_Store d on a.ID_Store=d.Store_ID
   --inner join DT_STORE_CABANG e on a.ID_Store=e.store_code
   where a.status_transaksi=1  and  d.Store_Brand_ID = @p_brand_id
   and datediff(day,a.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,a.Tanggal_Transaksi,@p_to_date) >=0  
   group by CONVERT(VARCHAR(6), a.tanggal_transaksi, 112),d.Store_Brand_ID,a.id_store,CONVERT(VARCHAR(10), a.tanggal_transaksi, 120)
    
) as x
group by x.ID_Store, x.tanggal_transaksi 
order by ID_Store , x.tanggal_transaksi  ASC

 
--select x.ID_Store, x.tanggal_transaksi, sum(x.cash) as cash, sum(x.credit) + SUM(x.DEBIT) as CARD, sum(x.voucher) as voucher ,
-- sum(x.cash) + sum(x.credit) + sum(x.voucher) as total
--from(
--------------------------------------------------CASH


-- select  tsd.ID_Store
--		,format(DB.Tgl,'yyyy-MM-dd') as tanggal_transaksi
--		 ,max(DB.PU94_CASH ) as cash
--		,0 as credit
--		,0 AS DEBIT
--		,0 as voucher
--from   pos_serverX.dbo.TR_SALES_HEADER tsd
--inner join dt_store ds on (ds.Store_ID = tsd.ID_Store)
--inner join  pos_serverX.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 
--INNER JOIN POS_SERVER.DBO.DT_BATCH DB ON (DB.Store_ID   = tsd.Id_store)
--WHERE   ds.Store_Brand_ID = @p_brand_id
--	  and datediff(day,DB.Tgl,format(@p_from_date,'yyyy-MM-dd')) <= 0 and datediff(day,DB.Tgl,format(@p_to_date,'yyyy-MM-dd')) >=0 
--GROUP BY TSD.ID_Store ,DB.Tgl ,DB.PU94_CASH  


---- select  tsd.ID_Store
----		,format(tsd.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
----		,case when tpd.tipe_bayar = 'Cash' then sum(tpd.BAYAR) end 'Cash'
----		,0 as credit
----		,0 as voucher
----from  pos_serverX.dbo.TR_SALES_HEADER tsd
----inner join dt_store ds on (ds.Store_ID = tsd.ID_Store)
----inner join pos_serverX.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 

----WHERE     tpd.TIPE_BAYAR not in ('Change','Nilai Refund')
----		and tpd.TIPE_BAYAR not like '%D.%'
----		and tpd.TIPE_BAYAR not like '%K.%'
----		and tpd.TIPE_BAYAR not like '%voucher%'
----		and datediff(day,tsd.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,tsd.Tanggal_Transaksi,@p_to_date) >=0 
----		and ds.Store_Brand_ID = @p_brand_id
----		--and format(TSD.WAKTU_URUT,'yyyy-MM-dd') = '2017-08-20'
----GROUP BY TSD.ID_Store, tpd.tipe_bayar  ,tsd.Tanggal_Transaksi

--union all
------------------------------------------------------CREDIT


--select  tsd.ID_Store
--		,format(tsd.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
--		,0 as cash
--		,case when tpd.tipe_bayar like '%K.%' then sum(tpd.BAYAR) end 'Credit'
--		,0 as debit
--		,0 as voucher
--from  pos_server.dbo.TR_SALES_HEADER tsd
--inner join dt_store ds on (ds.Store_ID = tsd.ID_Store)

--inner join pos_server.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 

--WHERE    tpd.TIPE_BAYAR not in ('Change','Nilai Refund','Cash')
--		and tpd.TIPE_BAYAR not like '%D.%'
--		and tpd.TIPE_BAYAR not like '%voucher%'
--		and datediff(day,tsd.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,tsd.Tanggal_Transaksi,@p_to_date) >=0 
--		 and ds.Store_Brand_ID = @p_brand_id
--		--and format(TSD.WAKTU_URUT,'yyyy-MM-dd') = '2017-08-20'
--GROUP BY TSD.ID_Store, tpd.tipe_bayar  ,tsd.Tanggal_Transaksi





---------------------------------------------debit
--UNION ALL

--select  tsd.ID_Store
--		,format(tsd.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
--		,0 as cash
--			,0 as credit
--		,case when tpd.tipe_bayar like '%D.%' then sum(tpd.BAYAR) end 'DEBIT'
--		,0 as voucher
--from  pos_server.dbo.TR_SALES_HEADER tsd
--inner join dt_store ds on (ds.Store_ID = tsd.ID_Store)
--inner join pos_server.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 

--WHERE    ds.Store_Brand_ID = @p_brand_id
--		AND tpd.TIPE_BAYAR not in ('Change','Nilai Refund','Cash') 
--		and tpd.TIPE_BAYAR not like '%voucher%'
--		and tpd.TIPE_BAYAR not like '%K.%'
--		and datediff(day,tsd.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,tsd.Tanggal_Transaksi,@p_to_date) >=0 
--		--and format(TSD.WAKTU_URUT,'yyyy-MM-dd') = '2017-08-20'
--GROUP BY TSD.ID_Store, tpd.tipe_bayar  ,tsd.Tanggal_Transaksi

----------------------------------------------VOUCHER

--union all

--select  tsd.ID_Store
--		,format(tsd.Tanggal_Transaksi,'yyyy-MM-dd') as tanggal_transaksi
--		,0 as cash
--		,0 as credit
--		,0 as debit
--		,case when tpd.tipe_bayar like '%VOUCHER%' then sum(tpd.BAYAR) end 'Voucher'
--from  pos_server.dbo.TR_SALES_HEADER tsd
--inner join dt_store ds on (ds.Store_ID = tsd.ID_Store)

--inner join pos_server.dbo.TR_SALES_PAYMENT_DETAIL tpd on ( tpd.ID_TR_SALES_HEADER = tsd.ID_TR_SALES_HEADER) 

--WHERE     tpd.TIPE_BAYAR not in ('Change','Nilai Refund','Cash')
--		and tpd.TIPE_BAYAR not like '%D.%'
--		and tpd.TIPE_BAYAR not like '%K.%'
--		and datediff(day,tsd.Tanggal_Transaksi,@p_from_date) <= 0 and datediff(day,tsd.Tanggal_Transaksi,@p_to_date) >=0 
--			and ds.Store_Brand_ID = @p_brand_id
--		--and format(TSD.WAKTU_URUT,'yyyy-MM-dd') = '2017-08-20'
--GROUP BY TSD.ID_Store, tpd.tipe_bayar  ,tsd.Tanggal_Transaksi
--) as x
--group by x.ID_Store, x.tanggal_transaksi
--order by ID_Store, tanggal_transaksi
END
--PRINT @p_multi_store
END 
--select * from TR_SALES_HEADER WHERE ID_Store = 'RF025' AND ID_TR_SALES_HEADER = '0043D744B7194B1A84181CDDA23EAFE2'
--SELECT * FROM TR_SALES_DETAIL WHERE ID_TR_SALES_HEADER='0043D744B7194B1A84181CDDA23EAFE2'
--SELECT * FROM TR_SALES_PAYMENT WHERE ID_TR_SALES_HEADER = '0043D744B7194B1A84181CDDA23EAFE2'
--SELECT * FROM TR_SALES_PAYMENT_DETAIL WHERE ID_TR_SALES_HEADER ='0043D744B7194B1A84181CDDA23EAFE2' 
--select distinct TIPE_BAYAR from TR_SALES_PAYMENT_DETAIL
