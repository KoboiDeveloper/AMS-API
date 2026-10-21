/*
  Gross Margin (REG2) — NEW SP on RBACESS.
  Logic ported from pos_server.dbo.XSP_RPT_DAILY_S_SALES_S_PLU_GROUP_BRAND_GRAD_CUSTOM_TOTAL_GETROWS
  (legacy gross_margin.aspx). Does NOT EXEC that SP — queries pos_server tables.
  Filters: from_date, to_date only.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_gross_margin_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_gross_margin_getrows;
GO

CREATE PROCEDURE dbo.xsp_ams_new_reg_rpt_gross_margin_getrows
(
      @p_keywords varchar(200) = NULL
    , @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @p_is_active varchar(10) = NULL
    , @p_id_brand varchar(50) = NULL
    , @p_id_store varchar(50) = NULL
    , @p_brand varchar(50) = NULL
    , @p_store_id varchar(50) = NULL
    , @p_status varchar(50) = NULL
    , @p_kategori varchar(50) = NULL
    , @p_group varchar(50) = NULL
    , @p_dept varchar(50) = NULL
    , @p_department varchar(50) = NULL
    , @p_cabang varchar(50) = NULL
    , @p_id_cabang varchar(50) = NULL
    , @p_year varchar(10) = NULL
    , @p_month varchar(10) = NULL
    , @p_period varchar(20) = NULL
    , @p_tipe varchar(50) = NULL
    , @p_is_pajak varchar(10) = NULL
    , @p_id_mesin varchar(50) = NULL
    , @p_currentmonth varchar(10) = NULL
    , @p_tahun varchar(10) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @p_plu varchar(80) = NULL
    , @p_article varchar(80) = NULL
    , @p_voucher varchar(80) = NULL
    , @p_invoice varchar(80) = NULL
    , @p_marketplace varchar(80) = NULL
    , @p_multi_store varchar(max) = NULL
    , @p_brand_filter varchar(80) = NULL
    , @p_brand_to varchar(50) = NULL
    , @p_store_to varchar(50) = NULL
    , @p_tgl varchar(30) = NULL
    , @p_provinsi varchar(80) = NULL
    , @p_kota varchar(80) = NULL
    , @p_id_member varchar(80) = NULL
    , @p_confirm_status varchar(50) = NULL
    , @p_gh_id varchar(50) = NULL
    , @p_id_gh varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @from_raw varchar(30) = NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date, ''))), '');
        DECLARE @to_raw varchar(30) = NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date, ''))), '');
        IF @from_raw IS NULL OR @to_raw IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'fromDate dan toDate wajib diisi.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        DECLARE @p_from_date_dt datetime = TRY_CONVERT(datetime, REPLACE(@from_raw, '-', '/'), 111);
        IF @p_from_date_dt IS NULL SET @p_from_date_dt = TRY_CONVERT(datetime, @from_raw, 120);
        DECLARE @p_to_date_dt datetime = TRY_CONVERT(datetime, REPLACE(@to_raw, '-', '/'), 111);
        IF @p_to_date_dt IS NULL SET @p_to_date_dt = TRY_CONVERT(datetime, @to_raw, 120);
        IF @p_from_date_dt IS NULL OR @p_to_date_dt IS NULL
        BEGIN
            SET @bitparam = (
                SELECT '4002500' AS responseCode, 'Format tanggal tidak valid.' AS responseMessage
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        /* Legacy SP uses @p_from_date / @p_to_date as datetime — bind local aliases */
        DECLARE @gm_from datetime = @p_from_date_dt;
        DECLARE @gm_to datetime = @p_to_date_dt;

        CREATE TABLE #gm_out (
            [STATUS] varchar(20) NULL,
            BRAND varchar(80) NULL,
            QTY float NULL,
            HPP float NULL,
            [NET SALES] float NULL,
            MARGIN float NULL,
            [NET PERSENTASE] float NULL
        );

;WITH CTE
AS
(

   		--DAY 
select  'DAY' AS 'STATUS', xy.BRAND 
 
 ,SUM(xy.QTY)as QTY
 ,sum(xy.beli)as HPP
 , sum(xy.jual)as 'GROSS SALES' 
 , sum(xy.dis)as DISCOUNT
 , sum(xy.pp)as 'PRICE POINT'
 , SUM(Xy.netto)as 'NET SALES'
 ,sum(xy.jual) - sum(xy.beli) as 'MARGIN'  
 , ((sum(xy.netto) - sum(Xy.beli) )/sum(Xy.netto) )*100 as 'NET PERSENTASE'
 from 
 (
select    x.brand
,x.store_id
,x.PLU
,max(x.ARTICLE) as ARTICLE
,x.thn
,x.bulan
,max(x.day) as day
,sum(x.qty) as qty
,sum(x.beli) as beli
,sum(x.jual) as jual
,sum(x.dis) as dis
,sum(x.pp) as pp
,sum(x.netto ) + sum(x.dis) + sum(x.pp) as netto 
,max(x.class) as class
,x.status
from (

select   CASE WHEN  c.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND c.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	   WHEN  c.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when c.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE c.Store_Brand_ID END  BRAND 
       ,a.ID_Store as store_id
	   ,b.PLU
	   ,b.ARTICLE
	   ,year(a.Tanggal_Transaksi) as thn
	   ,month(a.Tanggal_Transaksi) as bulan
	   ,day(a.Tanggal_Transaksi) as 'day'
	   ,b.qty
	    ,b.hpp *  b.qty as beli
	   ,b.Harga_Jual  *  b.qty as jual 
	   ,0 as dis
	   ,0 as pp
	   ,b.Net  as netto
	   ,left(b.PLU,4) as class
	  
	   ,'sales' as status

	   
from pos_server.dbo.tr_sales_header a
inner join pos_server.dbo.tr_sales_detail b on b.id_tr_sales_header = a.id_tr_sales_header
inner join pos_server.dbo.DT_Store c on c.Store_ID = a.ID_Store
 

where DATEDIFF(DAY,Tanggal_Transaksi ,@gm_to)= 0 
	and ( left(b.DESKRIPSI,5) != 'DISC-')
	and ( left(b.DESKRIPSI,3) != 'PP-')
	--and case when @brand = 'ALL' then c.Store_Brand_ID
	--		  when @brand != 'ALL' then @brand end  = c.Store_Brand_ID
			 --order by a.ID_Store asc 

  union all

--DISC  
select    CASE WHEN  c.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND c.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	   WHEN  c.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when c.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE c.Store_Brand_ID END  BRAND 
       ,a.ID_Store as store_id
	   ,b.PLU
	   ,b.ARTICLE
	   ,year(a.Tanggal_Transaksi) as thn
	   ,month(a.Tanggal_Transaksi) as bulan
	   ,0 as 'day'
	   ,0 qty
	   ,0 as beli
	   ,0 as jual 
	   ,(-ABS(b.Net)) as dis
	   ,0 as pp
	   ,0  as netto
	   ,0 as class
	   ,'sales' as status

	   
from pos_server.dbo.tr_sales_header a
inner join pos_server.dbo.tr_sales_detail b on b.id_tr_sales_header = a.id_tr_sales_header
inner join pos_server.dbo.DT_Store c on c.Store_ID = a.ID_Store
 

where DATEDIFF(DAY,Tanggal_Transaksi ,@gm_to)= 0 
   and  left(b.DESKRIPSI,5) = 'DISC-'  
	--and case when @brand = 'ALL' then c.Store_Brand_ID
	--		  when @brand != 'ALL' then @brand end  = c.Store_Brand_ID
			 --order by a.ID_Store asc 


UNION ALL
--PP
  
select    CASE WHEN  c.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND c.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	   WHEN  c.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when c.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE c.Store_Brand_ID END  BRAND 
       ,a.ID_Store as store_id
	   ,b.PLU
	   ,b.ARTICLE
	   ,year(a.Tanggal_Transaksi) as thn
	   ,month(a.Tanggal_Transaksi) as bulan
	   ,0 as 'day'
	   ,0 qty
	   ,0 as beli
	   ,0 as jual 
	   ,0 as dis
	   ,(-ABS(b.Net)) as pp
	   ,0  as netto
	   ,0 as class
	   ,'sales' as status

	   
from pos_server.dbo.tr_sales_header a
inner join pos_server.dbo.tr_sales_detail b on b.id_tr_sales_header = a.id_tr_sales_header
inner join pos_server.dbo.DT_Store c on c.Store_ID = a.ID_Store
 

where DATEDIFF(DAY,Tanggal_Transaksi ,@gm_to)= 0 
   and    left(b.DESKRIPSI,3) = 'PP-'
	--and case when @brand = 'ALL' then c.Store_Brand_ID
	--		  when @brand != 'ALL' then @brand end  = c.Store_Brand_ID
			 --order by a.ID_Store asc 



  union all
  

	 SELECT 
	     CASE WHEN  DS.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND DS.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	  WHEN  DS.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when ds.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE DS.Store_Brand_ID END  BRAND 
      ,tsd.ID_STORE AS store_id 
	  ,TSSS.PLU
	  ,tsss.ARTICLE 
	   ,year(tsd.TGL_REFUND) as thn
	   ,month(tsd.TGL_REFUND) as bulan
	   ,day(tsd.TGL_REFUND) as 'day'  
      ,-(tsss.QTY)	AS qty
	      ,-(tsss.hpp)  * tsss.QTY    as beli
	   ,-(tsss.PRICE)  * tsss.QTY  as jual
	   ,0 as dis
	   ,0 as pp
	   ,-(tsss.NET) as netto
	   ,left(tsss.PLU,3) as class 
	   ,'refund' as status

	    
	  FROM pos_server.dbo.TR_SALES_REFUND    TSD
 LEFT OUTER JOIN pos_server.dbo.DT_Store DS ON (DS.Store_ID = TSD.ID_STORE) 
  INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL TSSS ON (TSSS.ID_TR_SALES_REFUND =  TSD.ID_TR_SALES_REFUND)
   WHERE DATEDIFF(DAY,TGL_REFUND ,@gm_to)= 0 
 
 	--and case when @brand = 'ALL' then ds.Store_Brand_ID
		--	  when @brand != 'ALL' then @brand end  = ds.Store_Brand_ID

  ) as x

   group by  x.brand,x.store_id,x.PLU,x.thn,x.bulan,x.status
   ) as xy
   
  GROUP BY   xy.BRAND 
    )

  --END DAY
  --START MTD
,CTE2 AS 
(

select  'MTD' AS 'STATUS', xy.BRAND 
 
 ,SUM(xy.QTY)as QTY
 ,sum(xy.beli)as HPP
 , sum(xy.jual)as 'GROSS SALES' 
 , sum(xy.dis)as DISCOUNT
 , sum(xy.pp)as 'PRICE POINT'
 , SUM(Xy.netto)as 'NET SALES'
 ,sum(xy.jual) - sum(xy.beli) as 'MARGIN'  
 , ((sum(xy.netto) - sum(Xy.beli) )/sum(Xy.netto) )*100 as 'NET PERSENTASE'
 from 
 (
select    x.brand
,x.store_id
,x.PLU
,max(x.ARTICLE) as ARTICLE
,x.thn
,x.bulan
,max(x.day) as day
,sum(x.qty) as qty
,sum(x.beli) as beli
,sum(x.jual) as jual
,sum(x.dis) as dis
,sum(x.pp) as pp
,sum(x.netto ) + sum(x.dis) + sum(x.pp) as netto 
,max(x.class) as class
,x.status
from (

select   CASE WHEN  c.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND c.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	   WHEN  c.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when c.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE c.Store_Brand_ID END  BRAND 
       ,a.ID_Store as store_id
	   ,b.PLU
	   ,b.ARTICLE
	   ,year(a.Tanggal_Transaksi) as thn
	   ,month(a.Tanggal_Transaksi) as bulan
	   ,day(a.Tanggal_Transaksi) as 'day'
	   ,b.qty
	     ,b.hpp *  b.qty as beli
	   ,b.Harga_Jual  *  b.qty as jual 
	   ,0 as dis
	   ,0 as pp
	   ,b.Net  as netto
	   ,left(b.PLU,4) as class
	  
	   ,'sales' as status

	   
from pos_server.dbo.tr_sales_header a
inner join pos_server.dbo.tr_sales_detail b on b.id_tr_sales_header = a.id_tr_sales_header
inner join pos_server.dbo.DT_Store c on c.Store_ID = a.ID_Store
 

where ( DATEDIFF(DAY,Tanggal_Transaksi,@gm_from)<= 0 AND DATEDIFF(DAY,Tanggal_Transaksi ,@gm_to)>= 0)
	and ( left(b.DESKRIPSI,5) != 'DISC-')
	and ( left(b.DESKRIPSI,3) != 'PP-')
	--and case when @brand = 'ALL' then c.Store_Brand_ID
	--		  when @brand != 'ALL' then @brand end  = c.Store_Brand_ID
			 --order by a.ID_Store asc 

  union all

--DISC  
select    CASE WHEN  c.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND c.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	   WHEN  c.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when c.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE c.Store_Brand_ID END  BRAND 
       ,a.ID_Store as store_id
	   ,b.PLU
	   ,b.ARTICLE
	   ,year(a.Tanggal_Transaksi) as thn
	   ,month(a.Tanggal_Transaksi) as bulan
	   ,0 as 'day'
	   ,0 qty
	   ,0 as beli
	   ,0 as jual 
	   ,(-ABS(b.Net)) as dis
	   ,0 as pp
	   ,0  as netto
	   ,0 as class
	   ,'sales' as status

	   
from pos_server.dbo.tr_sales_header a
inner join pos_server.dbo.tr_sales_detail b on b.id_tr_sales_header = a.id_tr_sales_header
inner join pos_server.dbo.DT_Store c on c.Store_ID = a.ID_Store
 

where  ( DATEDIFF(DAY,Tanggal_Transaksi,@gm_from)<= 0 AND DATEDIFF(DAY,Tanggal_Transaksi ,@gm_to)>= 0)
   and  left(b.DESKRIPSI,5) = 'DISC-'  
	--and case when @brand = 'ALL' then c.Store_Brand_ID
	--		  when @brand != 'ALL' then @brand end  = c.Store_Brand_ID
			 --order by a.ID_Store asc 


UNION ALL
--PP
  
select    CASE WHEN  c.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND c.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	   WHEN  c.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when c.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE c.Store_Brand_ID END  BRAND 
       ,a.ID_Store as store_id
	   ,b.PLU
	   ,b.ARTICLE
	   ,year(a.Tanggal_Transaksi) as thn
	   ,month(a.Tanggal_Transaksi) as bulan
	   ,0 as 'day'
	   ,0 qty
	   ,0 as beli
	   ,0 as jual 
	   ,0 as dis
	   ,(-ABS(b.Net)) as pp
	   ,0  as netto
	   ,0 as class
	   ,'sales' as status

	   
from pos_server.dbo.tr_sales_header a
inner join pos_server.dbo.tr_sales_detail b on b.id_tr_sales_header = a.id_tr_sales_header
inner join pos_server.dbo.DT_Store c on c.Store_ID = a.ID_Store
 

where  ( DATEDIFF(DAY,Tanggal_Transaksi,@gm_from)<= 0 AND DATEDIFF(DAY,Tanggal_Transaksi ,@gm_to)>= 0)
   and    left(b.DESKRIPSI,3) = 'PP-'
	--and case when @brand = 'ALL' then c.Store_Brand_ID
	--		  when @brand != 'ALL' then @brand end  = c.Store_Brand_ID
			 --order by a.ID_Store asc 



  union all
  

	 SELECT 
	     CASE WHEN  DS.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND DS.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	  WHEN  DS.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when ds.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE DS.Store_Brand_ID END  BRAND 
      ,tsd.ID_STORE AS store_id 
	  ,TSSS.PLU
	  ,tsss.ARTICLE 
	   ,year(tsd.TGL_REFUND) as thn
	   ,month(tsd.TGL_REFUND) as bulan
	   ,day(tsd.TGL_REFUND) as 'day'  
      ,-(tsss.QTY)	AS qty
	       ,-(tsss.hpp)  * tsss.QTY    as beli
	   ,-(tsss.PRICE)  * tsss.QTY  as jual
	   ,0 as dis
	   ,0 as pp
	   ,-(tsss.NET) as netto
	   ,left(tsss.PLU,3) as class 
	   ,'refund' as status

	    
	  FROM pos_server.dbo.TR_SALES_REFUND    TSD
 LEFT OUTER JOIN pos_server.dbo.DT_Store DS ON (DS.Store_ID = TSD.ID_STORE) 
  INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL TSSS ON (TSSS.ID_TR_SALES_REFUND =  TSD.ID_TR_SALES_REFUND)
   WHERE ( DATEDIFF(DAY,TGL_REFUND,@gm_from)<= 0 AND DATEDIFF(DAY,TGL_REFUND ,@gm_to)>= 0)
 
 	--and case when @brand = 'ALL' then ds.Store_Brand_ID
		--	  when @brand != 'ALL' then @brand end  = ds.Store_Brand_ID

  ) as x

   group by  x.brand,x.store_id,x.PLU,x.thn,x.bulan,x.status
   ) as xy
   
  GROUP BY   xy.BRAND 
  )
  --END MTD
  --START YEAR TO DATE
  ,CTE3 AS 
(
 
select  'YTD' AS 'STATUS', xy.BRAND 
 
 ,SUM(xy.QTY)as QTY
 ,sum(xy.beli)as HPP
 , sum(xy.jual)as 'GROSS SALES' 
 , sum(xy.dis)as DISCOUNT
 , sum(xy.pp)as 'PRICE POINT'
 , SUM(Xy.netto)as 'NET SALES'
 ,sum(xy.jual) - sum(xy.beli) as 'MARGIN'  
 , ((sum(xy.netto) - sum(Xy.beli) )/sum(Xy.netto) )*100 as 'NET PERSENTASE'
 from 
 (
select    x.brand
,x.store_id
,x.PLU
,max(x.ARTICLE) as ARTICLE
,x.thn
,x.bulan
,max(x.day) as day
,sum(x.qty) as qty
,sum(x.beli) as beli
,sum(x.jual) as jual
,sum(x.dis) as dis
,sum(x.pp) as pp
,sum(x.netto ) + sum(x.dis) + sum(x.pp) as netto 
,max(x.class) as class
,x.status
from (

select   CASE WHEN  c.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND c.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	   WHEN  c.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when c.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE c.Store_Brand_ID END  BRAND 
       ,a.ID_Store as store_id
	   ,b.PLU
	   ,b.ARTICLE
	   ,year(a.Tanggal_Transaksi) as thn
	   ,month(a.Tanggal_Transaksi) as bulan
	   ,day(a.Tanggal_Transaksi) as 'day'
	   ,b.qty
	   ,b.hpp *  b.qty as beli
	   ,b.Harga_Jual  *  b.qty as jual 
	   ,0 as dis
	   ,0 as pp
	   ,b.Net  as netto
	   ,left(b.PLU,4) as class
	  
	   ,'sales' as status

	   
from pos_server.dbo.tr_sales_header a
inner join pos_server.dbo.tr_sales_detail b on b.id_tr_sales_header = a.id_tr_sales_header
inner join pos_server.dbo.DT_Store c on c.Store_ID = a.ID_Store
 

where  ( DATEDIFF(DAY,Tanggal_Transaksi,FORMAT(@gm_from,'yyyy-01-01'))<= 0 AND DATEDIFF(DAY,Tanggal_Transaksi ,@gm_to)>= 0)
	and ( left(b.DESKRIPSI,5) != 'DISC-')
	and ( left(b.DESKRIPSI,3) != 'PP-')
	--and case when @brand = 'ALL' then c.Store_Brand_ID
	--		  when @brand != 'ALL' then @brand end  = c.Store_Brand_ID
			 --order by a.ID_Store asc 

  union all

--DISC  
select    CASE WHEN  c.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND c.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	   WHEN  c.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when c.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE c.Store_Brand_ID END  BRAND 
       ,a.ID_Store as store_id
	   ,b.PLU
	   ,b.ARTICLE
	   ,year(a.Tanggal_Transaksi) as thn
	   ,month(a.Tanggal_Transaksi) as bulan
	   ,0 as 'day'
	   ,0 qty
	   ,0 as beli
	   ,0 as jual 
	   ,(-ABS(b.Net)) as dis
	   ,0 as pp
	   ,0  as netto
	   ,0 as class
	   ,'sales' as status

	   
from pos_server.dbo.tr_sales_header a
inner join pos_server.dbo.tr_sales_detail b on b.id_tr_sales_header = a.id_tr_sales_header
inner join pos_server.dbo.DT_Store c on c.Store_ID = a.ID_Store
 

where   ( DATEDIFF(DAY,Tanggal_Transaksi,FORMAT(@gm_from,'yyyy-01-01'))<= 0 AND DATEDIFF(DAY,Tanggal_Transaksi ,@gm_to)>= 0)
   and  left(b.DESKRIPSI,5) = 'DISC-'  
	--and case when @brand = 'ALL' then c.Store_Brand_ID
	--		  when @brand != 'ALL' then @brand end  = c.Store_Brand_ID
			 --order by a.ID_Store asc 


UNION ALL
--PP
  
select    CASE WHEN  c.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND c.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	   WHEN  c.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when c.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE c.Store_Brand_ID END  BRAND 
       ,a.ID_Store as store_id
	   ,b.PLU
	   ,b.ARTICLE
	   ,year(a.Tanggal_Transaksi) as thn
	   ,month(a.Tanggal_Transaksi) as bulan
	   ,0 as 'day'
	   ,0 qty
	   ,0 as beli
	   ,0 as jual 
	   ,0 as dis
	   ,(-ABS(b.Net)) as pp
	   ,0  as netto
	   ,0 as class
	   ,'sales' as status

	   
from pos_server.dbo.tr_sales_header a
inner join pos_server.dbo.tr_sales_detail b on b.id_tr_sales_header = a.id_tr_sales_header
inner join pos_server.dbo.DT_Store c on c.Store_ID = a.ID_Store
 

where  ( DATEDIFF(DAY,Tanggal_Transaksi,FORMAT(@gm_from,'yyyy-01-01'))<= 0 AND DATEDIFF(DAY,Tanggal_Transaksi ,@gm_to)>= 0)
   and    left(b.DESKRIPSI,3) = 'PP-'
	--and case when @brand = 'ALL' then c.Store_Brand_ID
	--		  when @brand != 'ALL' then @brand end  = c.Store_Brand_ID
			 --order by a.ID_Store asc 



  union all
  

	 SELECT 
	     CASE WHEN  DS.Store_Brand_ID  IN ('FLIES','IWAN FASHION') AND DS.Store_Brand_ID_2 <> 'ONLINE' THEN 'FLIES'
	  WHEN  DS.Store_Brand_ID   = 'DS' THEN 'DISCOUNT STORE'
	         when ds.Store_Brand_ID_2 = 'ONLINE' THEN 'ONLINE'
	         ELSE DS.Store_Brand_ID END  BRAND 
      ,tsd.ID_STORE AS store_id 
	  ,TSSS.PLU
	  ,tsss.ARTICLE 
	   ,year(tsd.TGL_REFUND) as thn
	   ,month(tsd.TGL_REFUND) as bulan
	   ,day(tsd.TGL_REFUND) as 'day'  
      ,-(tsss.QTY)	AS qty
	     ,-(tsss.hpp)  * tsss.QTY    as beli
	   ,-(tsss.PRICE)  * tsss.QTY  as jual
	   ,0 as dis
	   ,0 as pp
	   ,-(tsss.NET) as netto
	   ,left(tsss.PLU,3) as class 
	   ,'refund' as status

	    
	  FROM pos_server.dbo.TR_SALES_REFUND    TSD
 LEFT OUTER JOIN pos_server.dbo.DT_Store DS ON (DS.Store_ID = TSD.ID_STORE) 
  INNER JOIN pos_server.dbo.TR_SALES_REFUND_DETAIL TSSS ON (TSSS.ID_TR_SALES_REFUND =  TSD.ID_TR_SALES_REFUND)
   WHERE  ( DATEDIFF(DAY,TGL_REFUND,FORMAT(@gm_from,'yyyy-01-01'))<= 0 AND DATEDIFF(DAY,TGL_REFUND ,@gm_to)>= 0)
 
 	--and case when @brand = 'ALL' then ds.Store_Brand_ID
		--	  when @brand != 'ALL' then @brand end  = ds.Store_Brand_ID

  ) as x

   group by  x.brand,x.store_id,x.PLU,x.thn,x.bulan,x.status
   ) as xy
   
  GROUP BY   xy.BRAND 
  --END YEAR TO DATE
  ) 
  




INSERT INTO #gm_out ([STATUS], BRAND, QTY, HPP, [NET SALES], MARGIN, [NET PERSENTASE])
SELECT STATUS,BRAND,QTY,HPP,[NET SALES],  X.[NET SALES]-   HPP as MARGIN   ,[NET PERSENTASE] FROM (
		 		  
 
 SELECT 
    X.STATUS
    ,X.BRAND
 ,X.QTY
 ,HPP
 , X.[GROSS SALES]
 , X.DISCOUNT
 , X.[PRICE POINT]
 , X.[NET SALES]
 ,X.MARGIN  
 , X.[NET PERSENTASE]
FROM (
    SELECT 
        STATUS, 
        BRAND 
       ,QTY
	 ,HPP
	 , [GROSS SALES]
	 , DISCOUNT
	 , [PRICE POINT]
	 , [NET SALES]
	 ,MARGIN  
	 , [NET PERSENTASE]
    FROM CTE
    UNION ALL
    -- Tambahkan baris ONLINE dengan nilai 0 jika tidak ada di STATUS 'DAY'
    SELECT 'DAY' AS STATUS, 'ONLINE' AS BRAND, 0 AS QTY, 0 AS HPP,0 AS 'GROSS SALES', 0 AS DISCOUNT,0 AS 'PRICE POINT', 0 AS 'NET SALES', 0 AS MARGIN, 0 AS 'NET PERSENTASE'
    WHERE NOT EXISTS (
        SELECT 1 
        FROM CTE 
        WHERE STATUS = 'DAY' AND BRAND = 'ONLINE'
    )
) AS X
 
  

UNION ALL



 SELECT 
    X.STATUS
    ,X.BRAND
 ,X.QTY
 ,HPP
 , X.[GROSS SALES]
 , X.DISCOUNT
 , X.[PRICE POINT]
 , X.[NET SALES]
 ,X.MARGIN  
 , X.[NET PERSENTASE]
FROM (
    SELECT 
        STATUS, 
        BRAND 
       ,QTY
	 ,HPP
	 , [GROSS SALES]
	 , DISCOUNT
	 , [PRICE POINT]
	 , [NET SALES]
	 ,MARGIN  
	 , [NET PERSENTASE]
    FROM CTE2
    UNION ALL
    -- Tambahkan baris ONLINE dengan nilai 0 jika tidak ada di STATUS 'DAY'
    SELECT 'MTD' AS STATUS, 'ONLINE' AS BRAND, 0 AS QTY, 0 AS HPP,0 AS 'GROSS SALES', 0 AS DISCOUNT,0 AS 'PRICE POINT', 0 AS 'NET SALES', 0 AS MARGIN, 0 AS 'NET PERSENTASE'
    WHERE NOT EXISTS (
        SELECT 1 
        FROM CTE2 
        WHERE STATUS = 'MTD' AND BRAND = 'ONLINE'
    )
) AS X



  UNION ALL

  
 SELECT 
    X.STATUS
    ,X.BRAND
 ,X.QTY
 ,HPP
 , X.[GROSS SALES]
 , X.DISCOUNT
 , X.[PRICE POINT]
 , X.[NET SALES]
 ,X.MARGIN  
 , X.[NET PERSENTASE]
FROM (
    SELECT 
        STATUS, 
        BRAND 
       ,QTY
	 ,HPP
	 , [GROSS SALES]
	 , DISCOUNT
	 , [PRICE POINT]
	 , [NET SALES]
	 ,MARGIN  
	 , [NET PERSENTASE]
    FROM CTE3
    UNION ALL
    -- Tambahkan baris ONLINE dengan nilai 0 jika tidak ada di STATUS 'DAY'
    SELECT 'YTD' AS STATUS, 'ONLINE' AS BRAND, 0 AS QTY, 0 AS HPP,0 AS 'GROSS SALES', 0 AS DISCOUNT,0 AS 'PRICE POINT', 0 AS 'NET SALES', 0 AS MARGIN, 0 AS 'NET PERSENTASE'
    WHERE NOT EXISTS (
        SELECT 1 
        FROM CTE3 
        WHERE STATUS = 'YTD' AND BRAND = 'ONLINE'
    )
) AS X

  ) AS X order by  X.STATUS ASC ,
					CASE  WHEN X.BRAND = 'CELCIUS' THEN 0 
						WHEN X.BRAND = 'CELCIUS WOMAN' THEN 1 
						WHEN X.BRAND = 'FLIES' THEN 2 
						WHEN X.BRAND = 'MISSISSIPPI' THEN 3 
					    WHEN X.BRAND = 'QUEENSLAND' THEN 4 
					    WHEN X.BRAND = 'DISCOUNT STORE' THEN 5  
					    WHEN X.BRAND = 'ONLINE' THEN 6   END


        SET @bitparam = (
            SELECT '2002500' AS responseCode,
                   'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                              o.[STATUS] AS STATUS,
                              o.BRAND AS BRAND,
                              o.QTY AS QTY,
                              o.HPP AS HPP,
                              o.[NET SALES] AS [NET SALES],
                              o.MARGIN AS MARGIN,
                              o.[NET PERSENTASE] AS [NET PERSENTASE]
                       FROM #gm_out AS o
                       ORDER BY
                              o.[STATUS] ASC,
                              CASE
                                  WHEN o.BRAND = 'CELCIUS' THEN 0
                                  WHEN o.BRAND = 'CELCIUS WOMAN' THEN 1
                                  WHEN o.BRAND = 'FLIES' THEN 2
                                  WHEN o.BRAND = 'MISSISSIPPI' THEN 3
                                  WHEN o.BRAND = 'QUEENSLAND' THEN 4
                                  WHEN o.BRAND = 'DISCOUNT STORE' THEN 5
                                  WHEN o.BRAND = 'ONLINE' THEN 6
                                  ELSE 99
                              END
                       FOR JSON PATH
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        DROP TABLE #gm_out;
    END TRY
    BEGIN CATCH
        IF OBJECT_ID('tempdb..#gm_out') IS NOT NULL DROP TABLE #gm_out;
        SET @bitparam = (
            SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END CATCH
END
GO