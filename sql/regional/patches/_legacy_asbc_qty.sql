--exec [dbo].[XSP_ANALISA_SALES_BY_CLASS] 'rif021','2019-03-25','iwan fashion','gh5'

 CREATE PROCEDURE [dbo].[XSP_ANALISA_SALES_BY_CLASS]
 (
 @p_store_id		varchar(2000)
 ,@p_date			datetime
 
 ,@p_brand			varchar(100)
 ,@p_kodegh			varchar(100)
 )
 AS
 SET NOCOUNT ON 
 BEGIN

 declare @year		varchar(20) = year(@p_date)-1
		,@from_date	datetime = FORMAT(@p_date,'yyyy-MM-01')
		,@to_date		datetime = FORMAT(@p_date,'yyyy-MM-dd') 
	
--akumulasi tahun berjalan 
declare @akumulasi_tahun_berjalan int
		,@jumlah_hari				int
 
  if @p_kodegh <> 'ALL' and @p_brand  <> 'ALL' and @p_store_id <> 'ALL'  
  begin  
	  select @akumulasi_tahun_berjalan =  sum(a.QTY)  from DT_SALES_SUMMARY a 
	  where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS  in 
	 ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
	  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ','))   AND Store_ID   collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_store_id, ',')) )
   end

   else if  @p_kodegh = 'ALL' and @p_brand  <> 'ALL' and @p_store_id <> 'ALL'  
  begin  
	  select @akumulasi_tahun_berjalan =  sum(a.QTY)  from DT_SALES_SUMMARY a 
	  where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS  in 
	 ( SELECT  store_id from dt_store   where Store_ID   collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_store_id, ',')) )
   end

   else if @p_kodegh <> 'ALL' and @p_brand   = 'ALL' and @p_store_id <> 'ALL' 
   begin
     select @akumulasi_tahun_berjalan =  sum(a.QTY)  from DT_SALES_SUMMARY a 
	  where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS  in 
	 ( SELECT  store_id from dt_store   where Store_ID   collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_store_id, ',')) )
   end 
	else if @p_kodegh <> 'ALL' and @p_brand   <> 'ALL' and @p_store_id = 'ALL' --ok
	begin
	  select @akumulasi_tahun_berjalan =  sum(a.QTY)  from DT_SALES_SUMMARY a 
	  where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID
	collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
	  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ',')))

	end
   

 --print @akumulasi_tahun_berjalan

 select @jumlah_hari =  DAY(@to_date)
--start  sum group per 2 kode di depan


--BRAND MULTI SELECT STORE HARUS ALL


if @p_kodegh = 'ALL' and @p_brand   <> 'ALL' and @p_store_id = 'ALL'
BEGIN
select xx.* from (
 --start sebelum sum per 2 kode di depan
select  LEFT(x.kode,2) collate Latin1_General_CI_AS as KODE_group,x.kode collate Latin1_General_CI_AS as KODE,a.DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , case when sum(isnull(x.qty_berjalan,0)) = 0 then '0'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) > 90 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) <= 90 then 'KIRIM'
		  end  as ket
from (
--CARI CLASS
select   KODE  as kode  ,0 as qty, 0 as qty_berjalan, 0 as inv
from  MASTER_CLASS  
 
union all
--CARI NET TAHUN SEBELUMNYA
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ',')))  and qty <> 0
group by  left(a.PLU,3) 

UNION ALL

select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
group by  left(a.PLU,3)   

--inv
union all
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   
  where Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by left(a.plu,3)
 ) as x 
 inner join MASTER_CLASS   a on a.KODE = x.kode
 group by x.kode,a.Deskripsi, LEFT(x.kode,2) collate Latin1_General_CI_AS
 --
  --end sebelum sum per 2 kode di depan
  union all

select  LEFT(x.kode,2) +' total' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'Sub Total:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , '' as ket
from (
--CARI CLASS
select   KODE  as kode  ,0 as qty, 0 as qty_berjalan, 0 as inv
from  MASTER_CLASS  
 
union all
--CARI NET TAHUN SEBELUMNYA
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ',')))  and qty <> 0
group by  left(a.PLU,3) 

UNION ALL

select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
group by  left(a.PLU,3)   

--inv
union all
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   
  where Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by left(a.plu,3)
 ) as x 
 inner join MASTER_CLASS   a on a.KODE = x.kode
 group by  LEFT(x.kode,2) collate Latin1_General_CI_AS
 --order by x.kode asc



 UNION ALL




 
select   '9999999999999 totalgRANDtoT' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'GRAND TOTAL:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , '' as ket
from (
--CARI CLASS
select   KODE  as kode  ,0 as qty, 0 as qty_berjalan, 0 as inv
from  MASTER_CLASS  
 
union all
--CARI NET TAHUN SEBELUMNYA
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ','))) and qty <> 0
group by  left(a.PLU,3) 

UNION ALL

select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
group by  left(a.PLU,3)   

--inv
union all
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   
  where Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (select store_id from dt_store  where store_brand_id in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by left(a.plu,3)
 ) as x  


) as xx

WHERE (xx.SALES_QTY_TAHUN_SEBELUMNYA <> 0
and	  xx.SALES_QTY_BERJALAN <> 0
and   xx.GROWTH <> 0
and   xx.PERSEN_GROWTH <> 0
and   xx.KONTRIBUSI <> 0
and   xx.inventory_stock <> 0
and   xx.stock_day <> 0 )
order by   xx.KODE_group  asc

 END

else if @p_kodegh <> 'ALL' AND @p_brand <> 'ALL' AND @p_store_id <> 'ALL' -- ok
BEGIN

 


select xx.*  from   (
 --start sebelum sum per 2 kode di depan
select  LEFT(x.kode,2) collate Latin1_General_CI_AS as KODE_group,x.kode collate Latin1_General_CI_AS as KODE,a.DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,isnull(round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0),0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,isnull(round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0),0)  as stock_day
 
 , isnull(case when sum(isnull(x.qty_berjalan,0)) = 0 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) > 90 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) <= 90 then 'KIRIM'
		  end,0)  as ket
from (

--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,ISNULL(sum(a.qty),0) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ',')) and qty <> 0
group by  a.Store_ID , left(a.PLU,3) 
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
group by   a.Store_ID   , left(a.PLU,3) 
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID ,plu  
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by Store_ID , left(a.plu,3) 
 ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------
 ) as x 

 inner join MASTER_CLASS   a on a.KODE = x.kode
 group by  x.kode,a.Deskripsi, LEFT(x.kode,2) collate Latin1_General_CI_AS
 --
  --end sebelum sum per 2 kode di depan
  union all

select  LEFT(x.kode,2) +' total' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'Sub Total:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , '' as ket
from (
--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,sum(a.qty) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ',')) and qty <> 0
group by   a.Store_ID , left(a.PLU,3) 
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
group by   left(a.PLU,3) ,  a.Store_ID  
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID , plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by   Store_ID, left(a.plu,3)
  ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------
 ) as x 
 inner join MASTER_CLASS   a on a.KODE = x.kode

 group by  LEFT(x.kode,2) collate Latin1_General_CI_AS
 --order by x.kode asc



 UNION ALL




 
select   '9999999999999 totalgRANDtoT' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'GRAND TOTAL:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
, case when sum(isnull(x.qty_berjalan,0)) = 0 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) > 90     then 'STOP'   
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) <= 90 then 'KIRIM'
		  end  as ket
from (

--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,sum(a.qty) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))and qty <> 0
group by  a.Store_ID, left(a.PLU,3)
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
group by    a.Store_ID, left(a.PLU,3)
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID, plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by Store_ID, left(a.plu,3)
   ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------ 
 ) as x  


) as xx 


--where xx.KODE in ( select distinct left(plu,3) as kodes  from dt_Stock_summary  where Store_ID in (
--SELECt element FROM  dbo.func_split(@p_store_id, ','))) 
--WHERE (xx.SALES_QTY_TAHUN_SEBELUMNYA <> 0
--and	  xx.SALES_QTY_BERJALAN <> 0
--and   xx.GROWTH <> 0
--and   xx.PERSEN_GROWTH <> 0
--and   xx.KONTRIBUSI <> 0
--and   xx.inventory_stock <> 0
--and   xx.stock_day <> 0 )
order by   xx.KODE_group  asc
END

else if @p_kodegh = 'ALL' and @p_brand  <> 'ALL' and @p_store_id <> 'ALL' --ok
BEGIN

 


select xx.*  from   (
 --start sebelum sum per 2 kode di depan
select  LEFT(x.kode,2) collate Latin1_General_CI_AS as KODE_group,x.kode collate Latin1_General_CI_AS as KODE,a.DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , case when sum(isnull(x.qty_berjalan,0)) = 0 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) > 90 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) <= 90 then 'KIRIM'
		  end  as ket
from (

--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,ISNULL(sum(a.qty),0) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ',')) and qty <> 0
group by  a.Store_ID , left(a.PLU,3) 
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
group by   a.Store_ID   , left(a.PLU,3) 
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID ,plu  
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by Store_ID , left(a.plu,3) 
 ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------
 ) as x 

 inner join MASTER_CLASS   a on a.KODE = x.kode
 group by  x.kode,a.Deskripsi, LEFT(x.kode,2) collate Latin1_General_CI_AS
 --
  --end sebelum sum per 2 kode di depan
  union all

select  LEFT(x.kode,2) +' total' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'Sub Total:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , '' as ket
from (
--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,sum(a.qty) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ',')) and qty <> 0
group by   a.Store_ID , left(a.PLU,3) 
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
group by   left(a.PLU,3) ,  a.Store_ID  
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID , plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by   Store_ID, left(a.plu,3)
  ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------
 ) as x 
 inner join MASTER_CLASS   a on a.KODE = x.kode

 group by  LEFT(x.kode,2) collate Latin1_General_CI_AS
 --order by x.kode asc



 UNION ALL




 
select   '9999999999999 totalgRANDtoT' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'GRAND TOTAL:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
, case when sum(isnull(x.qty_berjalan,0)) = 0 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) > 90     then 'STOP'   
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) <= 90 then 'KIRIM'
		  end  as ket
from (

--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,sum(a.qty) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))and qty <> 0
group by  a.Store_ID, left(a.PLU,3)
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
group by    a.Store_ID, left(a.PLU,3)
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID, plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by Store_ID, left(a.plu,3)
   ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------ 
 ) as x  


) as xx 


--where xx.KODE in ( select distinct left(plu,3) as kodes  from dt_Stock_summary  where Store_ID in (
--SELECt element FROM  dbo.func_split(@p_store_id, ','))) 
--WHERE (xx.SALES_QTY_TAHUN_SEBELUMNYA <> 0
--and	  xx.SALES_QTY_BERJALAN <> 0
--and   xx.GROWTH <> 0
--and   xx.PERSEN_GROWTH <> 0
--and   xx.KONTRIBUSI <> 0
--and   xx.inventory_stock <> 0
--and   xx.stock_day <> 0 )
order by   xx.KODE_group  asc
END
 
else if @p_kodegh <> 'ALL' and @p_brand   = 'ALL' and @p_store_id <> 'ALL'  --ok
BEGIN

 


select xx.*  from   (
 --start sebelum sum per 2 kode di depan
select  LEFT(x.kode,2) collate Latin1_General_CI_AS as KODE_group,x.kode collate Latin1_General_CI_AS as KODE,a.DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , case when sum(isnull(x.qty_berjalan,0)) = 0 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) > 90 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) <= 90 then 'KIRIM'
		  end  as ket
from (

--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,ISNULL(sum(a.qty),0) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ',')) and qty <> 0
group by  a.Store_ID , left(a.PLU,3) 
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
group by   a.Store_ID   , left(a.PLU,3) 
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID ,plu  
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by Store_ID , left(a.plu,3) 
 ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------
 ) as x 

 inner join MASTER_CLASS   a on a.KODE = x.kode
 group by  x.kode,a.Deskripsi, LEFT(x.kode,2) collate Latin1_General_CI_AS
 --
  --end sebelum sum per 2 kode di depan
  union all

select  LEFT(x.kode,2) +' total' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'Sub Total:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , '' as ket
from (
--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,sum(a.qty) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ',')) and qty <> 0
group by   a.Store_ID , left(a.PLU,3) 
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
group by   left(a.PLU,3) ,  a.Store_ID  
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID , plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by   Store_ID, left(a.plu,3)
  ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------
 ) as x 
 inner join MASTER_CLASS   a on a.KODE = x.kode

 group by  LEFT(x.kode,2) collate Latin1_General_CI_AS
 --order by x.kode asc



 UNION ALL




 
select   '9999999999999 totalgRANDtoT' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'GRAND TOTAL:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
, case when sum(isnull(x.qty_berjalan,0)) = 0 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) > 90     then 'STOP'   
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) <= 90 then 'KIRIM'
		  end  as ket
from (

--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,sum(a.qty) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))and qty <> 0
group by  a.Store_ID, left(a.PLU,3)
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
group by    a.Store_ID, left(a.PLU,3)
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID, plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID in (
SELECt element FROM  dbo.func_split(@p_store_id, ','))
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by Store_ID, left(a.plu,3)
   ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------ 
 ) as x  


) as xx 


--where xx.KODE in ( select distinct left(plu,3) as kodes  from dt_Stock_summary  where Store_ID in (
--SELECt element FROM  dbo.func_split(@p_store_id, ','))) 
--WHERE (xx.SALES_QTY_TAHUN_SEBELUMNYA <> 0
--and	  xx.SALES_QTY_BERJALAN <> 0
--and   xx.GROWTH <> 0
--and   xx.PERSEN_GROWTH <> 0
--and   xx.KONTRIBUSI <> 0
--and   xx.inventory_stock <> 0
--and   xx.stock_day <> 0 )
order by   xx.KODE_group  asc
END

else if @p_kodegh <> 'ALL' and @p_brand   <> 'ALL' and @p_store_id = 'ALL' --ok
BEGIN

 


select xx.*  from   (
 --start sebelum sum per 2 kode di depan
select  LEFT(x.kode,2) collate Latin1_General_CI_AS as KODE_group,x.kode collate Latin1_General_CI_AS as KODE,a.DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , case when sum(isnull(x.qty_berjalan,0)) = 0 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) > 90 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) <= 90 then 'KIRIM'
		  end  as ket
from (

--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,ISNULL(sum(a.qty),0) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ',')))  and qty <> 0
group by  a.Store_ID , left(a.PLU,3) 
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
group by   a.Store_ID   , left(a.PLU,3) 
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID ,plu  
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by Store_ID , left(a.plu,3) 
 ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------
 ) as x 

 inner join MASTER_CLASS   a on a.KODE = x.kode
 group by  x.kode,a.Deskripsi, LEFT(x.kode,2) collate Latin1_General_CI_AS
 --
  --end sebelum sum per 2 kode di depan
  union all

select  LEFT(x.kode,2) +' total' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'Sub Total:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , '' as ket
from (
--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,sum(a.qty) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ',')))  and qty <> 0
group by   a.Store_ID , left(a.PLU,3) 
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
group by   left(a.PLU,3) ,  a.Store_ID  
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID , plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by   Store_ID, left(a.plu,3)
  ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------
 ) as x 
 inner join MASTER_CLASS   a on a.KODE = x.kode

 group by  LEFT(x.kode,2) collate Latin1_General_CI_AS
 --order by x.kode asc



 UNION ALL




 
select   '9999999999999 totalgRANDtoT' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'GRAND TOTAL:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
, case when sum(isnull(x.qty_berjalan,0)) = 0 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) > 90     then 'STOP'   
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) <= 90 then 'KIRIM'
		  end  as ket
from (

--CARI NET TAHUN SEBELUMNYA
-------------
select  a.kode   ,sum(a.qty) as qty, a.qty_berjalan, a.inv from (
-------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ',')))  and qty <> 0
group by  a.Store_ID, left(a.PLU,3)
---------------
) a group by  a.kode   , a.qty_berjalan, a.inv
---------------
UNION ALL
--------------
select  a.kode   ,sum(a.qty) as qty, sum(a.qty_berjalan) as qty_berjalan, a.inv from (
--------------
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a WITH (NOLOCK)
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
group by    a.Store_ID, left(a.PLU,3)
--------------
) a group by  a.kode , a.inv
---------------
--inv
union all
----------------
select  a.kode   ,a.qty, a.qty_berjalan, sum(a.inv) as inv from (
---------------
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   WITH (NOLOCK)
  where Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by Store_ID, plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]  
  WHERE ID_GROUP_HEAD in  (@p_kodegh)and BRAND collate SQL_Latin1_General_CP1_CI_AS in (SELECt element FROM  dbo.func_split(@p_brand, ','))) 
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by Store_ID, left(a.plu,3)
   ------------------
 ) a group by  a.kode   ,a.qty, a.qty_berjalan
 ------------------ 
 ) as x  


) as xx 


--where xx.KODE in ( select distinct left(plu,3) as kodes  from dt_Stock_summary  where Store_ID in (
--SELECt element FROM  dbo.func_split(@p_store_id, ','))) 
--WHERE (xx.SALES_QTY_TAHUN_SEBELUMNYA <> 0
--and	  xx.SALES_QTY_BERJALAN <> 0
--and   xx.GROWTH <> 0
--and   xx.PERSEN_GROWTH <> 0
--and   xx.KONTRIBUSI <> 0
--and   xx.inventory_stock <> 0
--and   xx.stock_day <> 0 )
order by   xx.KODE_group  asc
END


else if @p_kodegh <> 'ALL' and @p_brand   = 'ALL' and @p_store_id = 'ALL'
begin

select xx.* from ( 
 --start sebelum sum per 2 kode di depan
select  LEFT(x.kode,2) collate Latin1_General_CI_AS as KODE_group,x.kode collate Latin1_General_CI_AS as KODE,a.DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , case when sum(isnull(x.qty_berjalan,0)) = 0 then '0'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) > 90 then 'STOP'
		when ((cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari) <= 90 then 'KIRIM'
		  end  as ket
from (
--CARI CLASS
select   KODE  as kode  ,0 as qty, 0 as qty_berjalan, 0 as inv
from  MASTER_CLASS  
 
union all
--CARI NET TAHUN SEBELUMNYA
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and  a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in(@p_kodegh))   and qty <> 0
group by  left(a.PLU,3) 

UNION ALL

select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in(@p_kodegh)) 
group by  left(a.PLU,3)   

--inv
union all
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   
  where Store_ID collate SQL_Latin1_General_CP1_CI_AS in ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in(@p_kodegh)) 
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in(@p_kodegh)) 
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by left(a.plu,3)
 ) as x 
 inner join MASTER_CLASS   a on a.KODE = x.kode
 group by x.kode,a.Deskripsi, LEFT(x.kode,2) collate Latin1_General_CI_AS
 --
  --end sebelum sum per 2 kode di depan
  union all

select  LEFT(x.kode,2) +' total' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'Sub Total:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , '' as ket
from (
--CARI CLASS
select   KODE  as kode  ,0 as qty, 0 as qty_berjalan, 0 as inv
from  MASTER_CLASS  
 
union all
--CARI NET TAHUN SEBELUMNYA
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in(@p_kodegh))  and qty <> 0
group by  left(a.PLU,3) 

UNION ALL

select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in (@p_kodegh)) 
group by  left(a.PLU,3)   

--inv
union all
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   
  where Store_ID collate SQL_Latin1_General_CP1_CI_AS in ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in(@p_kodegh)) 
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID collate SQL_Latin1_General_CP1_CI_AS in ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in(@p_kodegh)) 
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by left(a.plu,3)
 ) as x 
 inner join MASTER_CLASS   a on a.KODE = x.kode
 group by  LEFT(x.kode,2) collate Latin1_General_CI_AS
 --order by x.kode asc



 UNION ALL




 
select   '9999999999999 totalgRANDtoT' collate Latin1_General_CI_AS as KODE_group ,'' as KODE,'GRAND TOTAL:' as DESKRIPSI, sum(isnull(qty,0)) as SALES_QTY_TAHUN_SEBELUMNYA, sum(isnull(x.qty_berjalan,0)) as SALES_QTY_BERJALAN,

sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))AS GROWTH 
,round(case when sum(qty) = 0 then (sum(isnull(x.qty_berjalan,0)) -  sum(isnull(qty,0))) 
      when sum(qty) > 0  then  (cast(sum(isnull(x.qty_berjalan,0))as float) -  cast(sum(isnull(qty,0))as float)) / cast(sum(isnull(qty,0))as float) * 100
	  end ,0) as PERSEN_GROWTH
 ,round(sum(isnull(cast(x.qty_berjalan as float),0)) / cast(@akumulasi_tahun_berjalan as float) * 100,0) as KONTRIBUSI
 ,sum(x.inv) as inventory_stock
 ,round(case when sum(isnull(x.qty_berjalan,0)) = 0 then 0
		else (cast(sum(isnull(x.inv ,1))as float) /  cast(sum(isnull(x.qty_berjalan ,1))as float)) *  @jumlah_hari  end,0)  as stock_day
 
 , '' as ket
from (
--CARI CLASS
select   KODE  as kode  ,0 as qty, 0 as qty_berjalan, 0 as inv
from  MASTER_CLASS  
 
union all
--CARI NET TAHUN SEBELUMNYA
select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,isnull(sum(a.QTY),0) as qty, 0 as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,DATEADD(YEAR,-1, @from_date))<=0 and datediff(day,a.Tanggal,DATEADD(YEAR,-1,@to_date))>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS IN ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in(@p_kodegh))  and qty <> 0
group by  left(a.PLU,3) 

UNION ALL

select  left(a.PLU,3) collate Latin1_General_CI_AS as kode   ,0 as qty , isnull(sum(a.QTY),0)  as qty_berjalan, 0 as inv
from DT_SALES_SUMMARY a 
where (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0) and a.Store_ID collate SQL_Latin1_General_CP1_CI_AS IN ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in(@p_kodegh)) 
group by  left(a.PLU,3)   

--inv
union all
 select left(a.plu,3) as kode ,   0 as qty ,0  as qty_berjalan,sum(a.z) as inv from DT_STOCK_SUMMARY a
 inner join  (
 select    max(NO_URUT) as NO_URUT , PLU  
 from DT_STOCK_SUMMARY   
  where Store_ID collate SQL_Latin1_General_CP1_CI_AS in  ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE  ID_GROUP_HEAD in(@p_kodegh) ) 
 and (datediff(day,Tanggal,@from_date)<=0 and datediff(day,Tanggal,@to_date)>=0)
 group by plu 
 ) 
  b on b.NO_URUT = a.NO_URUT
   where a.Store_ID collate SQL_Latin1_General_CP1_CI_AS IN ( SELECT [STORE] FROM [POS_SERVER].[dbo].[MASTER_GH_DETAIL]   WHERE ID_GROUP_HEAD in(@p_kodegh)) 
 and (datediff(day,a.Tanggal,@from_date)<=0 and datediff(day,a.Tanggal,@to_date)>=0)
 group by left(a.plu,3)
 ) as x  


) as xx

WHERE (xx.SALES_QTY_TAHUN_SEBELUMNYA <> 0
and	  xx.SALES_QTY_BERJALAN <> 0
and   xx.GROWTH <> 0
and   xx.PERSEN_GROWTH <> 0
and   xx.KONTRIBUSI <> 0
and   xx.inventory_stock <> 0
and   xx.stock_day <> 0 )
order by   xx.KODE_group  asc
end
 


 




 END