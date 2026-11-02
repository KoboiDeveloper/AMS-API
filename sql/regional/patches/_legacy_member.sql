-- ===== xsp_app_dashboard_member_list_getrows_test




 CREATE

--    exec [xsp_app_dashboard_member_list_getrows_test] ' ','2010','2024',''

   procedure [dbo].[xsp_app_dashboard_member_list_getrows_test]

  (

	@p_keywords			varchar(50) 	

    ,@p_from_date		varchar(20)

    ,@p_to_date			varchar(20)

	,@p_provinsi		varchar(40)

	,@p_kota			varchar(40)

	,@p_brand			varchar(40)

	,@p_age_from		int

	,@p_age_to			int

	,@p_jenis_kelamin    varchar(40)



	----,@p_age    varchar(40)

  )

 as

 begin

 --declare @keywords    varchar(20)

 if @p_keywords = ' '

 begin

 set @p_keywords = ''

 end

 else set @p_keywords = @p_keywords

 --declare 



	-- @p_provinsi    varchar(40) = 0

	--,@p_kota    varchar(40)= 0

	-- @p_brand    varchar(40)= 0

	--,@p_age    varchar(40)

	--,@p_jenis_kelamin    varchar(40)= 0

	-- @p_from_date		varchar(20) = '01-01-2024'

	--,@p_to_date			varchar(20) = '01-01-2024'

	--,@p_age_from		int = 0

	--,@p_age_to			int = 0



 declare @from_date		    datetime  = CONVERT(varchar, CONVERT(date, @p_from_date, 103), 111)

		,@to_date			datetime  = CONVERT(varchar, CONVERT(date, @p_to_date, 103), 111)



 

 declare  @p_bulan   datetime    = '1-january-2024'

 ;with brand_logo

 as 

 (

 select ID_MEMBER

 ,CELCIUS + MISSISSIPPI +  FLIES + QUEENSLAND + AEESHA + KIDS as logo

 from (

SELECT

    ID_MEMBER,

    case when [CELCIUS] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/celcius_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end celcius

	 ,case when [MISSISSIPPI] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/mississippi_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end mississippi

	 ,case when [FLIES] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/flies_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end flies

	 ,case when [QUEENSLAND] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/queensland_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end queensland

	 ,case when [AEESHA] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/aeesha_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end aeesha

	,case when [KIDS] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/celcius_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end kids

	

	 

FROM

    (

        SELECT DISTINCT

            a.ID_MEMBER,

            b.Store_Brand_ID,

            CASE

                WHEN b.Store_Brand_ID = 'CELCIUS' THEN 'celcius_logo.png'

                WHEN b.Store_Brand_ID = 'MISSISSIPPI' THEN 'mississippi_logo.png'

                WHEN b.Store_Brand_ID = 'FLIES' THEN 'flies_logo.png'

                WHEN b.Store_Brand_ID = 'QUEENSLAND' THEN 'queensland_logo.png'

                WHEN b.Store_Brand_ID = 'AEESHA' THEN 'aeesha_logo.png'

                WHEN b.Store_Brand_ID = 'KIDS' THEN 'celcius_logo.png'

            END AS logo

        FROM

            sys_member.dbo.DT_MEMBER_TRANSAKSI a

            left outer JOIN DT_Store b ON b.Store_ID = a.Store_ID

        WHERE (

		--case when @p_from_date = '' and @p_to_date = '' then a.Tanggal  

		--end  =  a.Tanggal

		--or 

		( datediff(day,a.Tanggal,@from_date) <=0 and  datediff(day,a.Tanggal,@to_date) >=0  )

		)

			group by ID_MEMBER,Store_Brand_ID

            --AND ID_MEMBER = '00400280C2294761AD523AAA2C3FBD86'

    ) AS SourceTable

PIVOT

(

    MAX(logo)

    FOR Store_Brand_ID IN ([CELCIUS], [MISSISSIPPI], [FLIES], [QUEENSLAND], [AEESHA], [KIDS])

) AS PivotTable

 

 

 ) as x

 )









 







select 

isnull(b.id_member,'-') as id_member,

isnull(b.ID_MEMBER_APPS,'-') as MEMBER_ID

,case when b.validasi_data = 1 then 'fa fa-check ' else '' end validasi_data

,b.Nama AS NAME

,isnull(e.prov_name,'-') as PROVINSI

,isnull(f.city_name,'-')  as KOTA

,isnull(sum((a.REWARD_POINT + a.BONUS_POINT + a.BIRTHDAY_POINT + a.BIG_DAY_POINT)),0) as TOTAL_POINT 

,ISNULL(c.point,0) as POINT_USED

,format(b.TglMember,'MMMM dd, yyyy') as JOIN_DATE

,count(a.ID_TRANSAKSI) as TOTAL_TRANSACTION

,'Active' as STATUS

,ISNULL(d.Store_Brand_ID ,' ')as BRAND

,  dbo.getAge (b.TglLahir) as AGE

,CASE WHEN b.Jenis_kelamin  = 'p' then 'Female'

      when  b.Jenis_kelamin  = 'l' then 'Male'

	  else '-' end  GENDER

,g.logo as logo 

,(SELECT cast(a.id_tier as varchar) +'-'+ bb.TIER_NAME FROM SYS_MEMBER.DBO.DT_MEMBER_TIER a inner join SYS_MEMBER.dbo.DT_MEMBER_TIER_HEADER   bb on bb.ID = a.ID_TIER  WHERE a.ID_MEMBER = B.ID_MEMBER AND status = 1) as TIER

from dt_member  b

left outer join sys_member.dbo.DT_MEMBER_TRANSAKSI A on b.ID_MEMBER = a.ID_MEMBER 

left outer join  (select ID_MEMBER , sum(PointVoucher) as point from  SYS_MEMBER.dbo.DT_MEMBER_VOUCHER group by ID_MEMBER ) c on c.ID_MEMBER = b.ID_MEMBER collate Latin1_General_CI_AS

 left outer join dt_store    d on d.Store_ID = b.Store_ID collate Latin1_General_CI_AS

left outer join MASTER_WILAYAH.dbo.provinces e on e.prov_id = b.provinsi

left outer join MASTER_WILAYAH.dbo.cities f on f.city_id = b.Kota

 left outer join brand_logo g on g.ID_MEMBER = b.ID_MEMBER

 where  

	(	 

		(case when @p_provinsi   = '0' then  isnull(b.provinsi,'-') else @p_provinsi end  = isnull(b.provinsi,'-') )

  and  (	case when @p_kota	 = '0' then isnull(b.kota,'-') else @p_kota end  = isnull(b.kota,'-')  )

 

 and  (	case when (@p_age_from	 = '0' and @p_age_to	 = '0' ) then cast(dbo.getAge (b.TglLahir)  as int)

				 else @p_age_from end  <= cast(dbo.getAge (b.TglLahir) as int)

			and 

			case when (@p_age_from	 = '0' and @p_age_to	 = '0' ) then cast(dbo.getAge (b.TglLahir)  as int)

				 else @p_age_to end  >=cast( dbo.getAge (b.TglLahir) as int)

		)



  and  	(case when @p_brand	 = '0' then isnull(d.Store_Brand_ID,'-') else @p_brand end  = isnull(d.Store_Brand_ID,'-'))

  and  (	case when @p_jenis_kelamin	  = '0' then isnull( b.Jenis_kelamin,'-') else @p_jenis_kelamin end  = isnull(b.Jenis_kelamin,'-') )





 )

 and 

 ( 

    datediff(day,b.TglMember,@from_date) < =0 and  datediff(day,b.TglMember,@to_date) > =0  

 )

 and  	(	b.Nama     like '%' +@p_keywords+ '%'

        or	b.NoTelpon     like '%' +@p_keywords+ '%' 

        or	b.Email     like '%' +@p_keywords+ '%' 

		)

 

	  

group by b.id_member,ID_MEMBER_APPS,validasi_data ,b.Nama, c.point,b.TglMember,d.Store_Brand_ID ,b.TglLahir,b.Jenis_kelamin  , e.prov_name 

,f.city_name  ,g.logo

order by b.TglMember desc



 



 end
-- ===== xsp_app_dashboard_member_list_getrows_test_member




 create

 

   procedure [dbo].[xsp_app_dashboard_member_list_getrows_test_member]

  (

	 @p_keywords		varchar(50) 	

	 ,@p_from_date		varchar(20)

    ,@p_to_date			varchar(20)

  )

 as

 begin

 --declare @keywords    varchar(20)

 if @p_keywords = ' '

 begin

 set @p_keywords = ''

 end

 else set @p_keywords = @p_keywords

 --declare 



	-- @p_provinsi    varchar(40) = 0

	--,@p_kota    varchar(40)= 0

	-- @p_brand    varchar(40)= 0

	--,@p_age    varchar(40)

	--,@p_jenis_kelamin    varchar(40)= 0

	-- @p_from_date		varchar(20) = '01-01-2024'

	--,@p_to_date			varchar(20) = '01-01-2024'

	--,@p_age_from		int = 0

	--,@p_age_to			int = 0



  declare @from_date		    datetime  = CONVERT(varchar, CONVERT(date, @p_from_date, 103), 111)

		,@to_date			datetime  = CONVERT(varchar, CONVERT(date, @p_to_date, 103), 111)



 

 declare  @p_bulan   datetime    = '1-january-2024'

 ;with brand_logo

 as 

 (

 select ID_MEMBER

 ,CELCIUS + MISSISSIPPI +  FLIES + QUEENSLAND + AEESHA + KIDS as logo

 from (

SELECT

    ID_MEMBER,

    case when [CELCIUS] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/celcius_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end celcius

	 ,case when [MISSISSIPPI] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/mississippi_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end mississippi

	 ,case when [FLIES] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/flies_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end flies

	 ,case when [QUEENSLAND] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/queensland_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end queensland

	 ,case when [AEESHA] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/aeesha_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end aeesha

	,case when [KIDS] is not null then '<image src=''https://web.amscorp.id:3060/imagestorage/brand/celcius_logo.png'' class="example-image"  Height="40px"  width="40px"/>' else '' end kids

	

	 

FROM

    (

        SELECT DISTINCT

            a.ID_MEMBER,

            b.Store_Brand_ID,

            CASE

                WHEN b.Store_Brand_ID = 'CELCIUS' THEN 'celcius_logo.png'

                WHEN b.Store_Brand_ID = 'MISSISSIPPI' THEN 'mississippi_logo.png'

                WHEN b.Store_Brand_ID = 'FLIES' THEN 'flies_logo.png'

                WHEN b.Store_Brand_ID = 'QUEENSLAND' THEN 'queensland_logo.png'

                WHEN b.Store_Brand_ID = 'AEESHA' THEN 'aeesha_logo.png'

                WHEN b.Store_Brand_ID = 'KIDS' THEN 'celcius_logo.png'

            END AS logo

        FROM

            sys_member.dbo.DT_MEMBER_TRANSAKSI a

            left outer JOIN DT_Store b ON b.Store_ID = a.Store_ID

        WHERE (

		--case when @p_from_date = '' and @p_to_date = '' then a.Tanggal  

		--end  =  a.Tanggal

		--or 

		( datediff(day,a.Tanggal,@from_date) <=0 and  datediff(day,a.Tanggal,@to_date) >=0  )

		)

			group by ID_MEMBER,Store_Brand_ID

            --AND ID_MEMBER = '00400280C2294761AD523AAA2C3FBD86'

    ) AS SourceTable

PIVOT

(

    MAX(logo)

    FOR Store_Brand_ID IN ([CELCIUS], [MISSISSIPPI], [FLIES], [QUEENSLAND], [AEESHA], [KIDS])

) AS PivotTable

 

 

 ) as x

 )









 







select 

isnull(b.id_member,'-') as id_member,

isnull(b.ID_MEMBER_APPS,'-') as MEMBER_ID

,case when b.validasi_data = 1 then 'fa fa-check ' else '' end validasi_data

,b.Nama AS NAME

,isnull(e.prov_name,'-') as PROVINSI

,isnull(f.city_name,'-')  as KOTA

,isnull(sum((a.REWARD_POINT + a.BONUS_POINT + a.BIRTHDAY_POINT + a.BIG_DAY_POINT)),0) as TOTAL_POINT 

,ISNULL(c.point,0) as POINT_USED

,format(b.TglMember,'MMMM dd, yyyy') as JOIN_DATE

,count(a.ID_TRANSAKSI) as TOTAL_TRANSACTION

,'Active' as STATUS

,ISNULL(d.Store_Brand_ID ,' ')as BRAND

,  dbo.getAge (b.TglLahir) as AGE

,CASE WHEN b.Jenis_kelamin  = 'p' then 'Female'

      when  b.Jenis_kelamin  = 'l' then 'Male'

	  else '-' end  GENDER

,g.logo as logo 

,(SELECT cast(a.id_tier as varchar) +'-'+ bb.TIER_NAME FROM SYS_MEMBER.DBO.DT_MEMBER_TIER a inner join SYS_MEMBER.dbo.DT_MEMBER_TIER_HEADER   bb on bb.ID = a.ID_TIER  WHERE a.ID_MEMBER = B.ID_MEMBER AND status = 1) as TIER

from dt_member  b

left outer join sys_member.dbo.DT_MEMBER_TRANSAKSI A on b.ID_MEMBER = a.ID_MEMBER 

left outer join  (select ID_MEMBER , sum(PointVoucher) as point from  SYS_MEMBER.dbo.DT_MEMBER_VOUCHER group by ID_MEMBER ) c on c.ID_MEMBER = b.ID_MEMBER collate Latin1_General_CI_AS

 left outer join dt_store    d on d.Store_ID = b.Store_ID collate Latin1_General_CI_AS

left outer join MASTER_WILAYAH.dbo.provinces e on e.prov_id = b.provinsi

left outer join MASTER_WILAYAH.dbo.cities f on f.city_id = b.Kota

 left outer join brand_logo g on g.ID_MEMBER = b.ID_MEMBER

 where  

	 

   	(	b.Nama     like '%' +@p_keywords+ '%'

        or	b.NoTelpon     like '%' +@p_keywords+ '%' 

        or	b.Email     like '%' +@p_keywords+ '%' 

        or	b.ID_MEMBER_APPS     like '%' +@p_keywords+ '%'

		)

 

	  

group by b.id_member,ID_MEMBER_APPS,validasi_data ,b.Nama, c.point,b.TglMember,d.Store_Brand_ID ,b.TglLahir,b.Jenis_kelamin  , e.prov_name 

,f.city_name  ,g.logo

order by b.TglMember desc



 



 end
-- ===== xsp_app_member_badge_total_chart_getrow
 





 --    exec xsp_app_member_badge_total_chart_getrow '01/04/2024','29/04/2024'



CREATE procedure [dbo].[xsp_app_member_badge_total_chart_getrow]

 (

	@p_from_date		varchar(20)

	,@p_to_date			varchar(20)

 )

as

begin



 declare @bitparam   varchar(max)

		,@total_transaction int

		,@total_product_sold  int

		,@total_member_today int 

		-------------------

		,@prev_total_member_today float 

		--,@prev_from_date   datetime  =  CONVERT(date, @p_from_date, 103) 

		--,@prev_to_date		datetime =  CONVERT(date, @p_to_date, 103) 

	     ---------------------------



		 ,@member_total				int

		 ,@active_member_total		int

		 ,@inactive_member_total	int

		 ,@new_member_today			int



		 ,@prev_member_total			float

		 ,@prev_active_member_total		float

		 ,@prev_inactive_member_total	float

		 ,@prev_new_member_today		float











 --set @total_member_today = (select isnull(count(ID_MEMBER),0)  from dt_member where datediff(day,TglMember,getdate()) = 0)

 --set @prev_total_member_today = (select isnull(count(ID_MEMBER),0)  from dt_member where datediff(day,TglMember,dateadd(day,-1,getdate())) = 0)





  



 set @total_member_today = (select isnull(count(ID_MEMBER),0)  from dt_member where datediff(day,TglMember,getdate()) = 0)

 set @prev_total_member_today = (select isnull(count(ID_MEMBER),0)  from dt_member where datediff(day,TglMember,dateadd(day,-1,getdate())) = 0)





  select    @prev_member_total				=   count(a.ID_MEMBER)  

			,@prev_active_member_total		=  count(a.ID_MEMBER) 

			,@prev_inactive_member_total	=  count(a.ID_MEMBER)   

		 

from dt_member a 

--left outer join master_wilayah.dbo.provinces b on b.prov_id		=	a.provinsi 

 where --b.prov_name is not null 

   -- and 

	(  datediff(day,a.TglMember,dateadd(month,-1,CONVERT(varchar, CONVERT(date, @p_from_date, 103), 111))) <=0 

	and  datediff(day,a.TglMember,dateadd(month,-1,CONVERT(varchar, CONVERT(date, @p_to_date, 103), 111))) >=0  ) 



	 

	 -- declare @bitparam   varchar(max)

		--,@total_transaction int

		--,@total_product_sold  int

		--,@total_member_today int 

	 



  select    format(count(a.ID_MEMBER),'N0') as member_total 

			, format(count(a.ID_MEMBER),'N0')  as active_member_total 

			, format(count(a.ID_MEMBER),'N0')  as inactive_member_total 

			, format(@total_member_today,'N0') AS new_member_today

			---------------------------------

			 

			, format(@prev_member_total,'N0') AS prev_member_total

			, format(@prev_active_member_total,'N0') AS prev_active_member_total

			, format(@prev_inactive_member_total,'N0') AS prev_inactive_member_total

			, format(@prev_total_member_today,'N0') AS prev_new_member_today

			---------------------------------

			



			,case when @prev_member_total >  count(a.ID_MEMBER)  then cast(round(( count(a.ID_MEMBER)-@prev_member_total)/ @prev_member_total * 100, 2)  as varchar(20)) + '%' 

				  when @prev_member_total <  count(a.ID_MEMBER)  then  cast(round(( count(a.ID_MEMBER)-@prev_member_total)/ @prev_member_total * 100  , 2) as varchar(20)) + '%' 

				end  prev_member_total_presentase



			,case when @prev_active_member_total >  count(a.ID_MEMBER)  then cast(round(( count(a.ID_MEMBER)-@prev_active_member_total)/ @prev_active_member_total * 100, 2)  as varchar(20)) + '%' 

				  when @prev_active_member_total <  count(a.ID_MEMBER)  then  cast(round(( count(a.ID_MEMBER)-@prev_active_member_total)/ @prev_active_member_total * 100  , 2) as varchar(20)) + '%' 

				end  prev_active_member_total_presentase



			,case when @prev_inactive_member_total >  count(a.ID_MEMBER)  then cast(round(( count(a.ID_MEMBER)-@prev_inactive_member_total)/ @prev_inactive_member_total * 100, 2)  as varchar(20)) + '%' 

				  when @prev_inactive_member_total <  count(a.ID_MEMBER)  then  cast(round(( count(a.ID_MEMBER)-@prev_inactive_member_total)/ @prev_inactive_member_total * 100  , 2) as varchar(20)) + '%' 

				end  prev_inactive_member_total_presentase	



			,case when @prev_total_member_today >  @total_member_today  then cast(round(( @total_member_today-@prev_total_member_today)/ @prev_total_member_today * 100, 2)  as varchar(20)) + '%' 

				  when @prev_total_member_today <  @total_member_today  then  cast(round(( @total_member_today-@prev_total_member_today)/ @prev_total_member_today * 100  , 2) as varchar(20)) + '%' 

				end  prev_member_total_today_presentase		  

from dt_member a 

left outer join master_wilayah.dbo.provinces b on b.prov_id		=	a.provinsi 

 where --b.prov_name is not null 

   -- and 

	(  datediff(day,a.TglMember,CONVERT(varchar, CONVERT(date, @p_from_date, 103), 111)) <=0 and  datediff(day,a.TglMember,CONVERT(varchar, CONVERT(date, @p_to_date, 103), 111)) >=0  ) 



--  select     @member_total				=  format(count(a.ID_MEMBER),'N0') 

--			,@active_member_total		=  format(count(a.ID_MEMBER),'N0') 

--			,@inactive_member_total		=  format(count(a.ID_MEMBER),'N0')   

--			,@new_member_today			=  format(@total_member_today,'N0') 

--from dt_member a 

----left outer join master_wilayah.dbo.provinces b on b.prov_id		=	a.provinsi 

-- where --b.prov_name is not null 

--   -- and 

--	(  datediff(day,a.TglMember,CONVERT(varchar, CONVERT(date, @p_from_date, 103), 111)) <=0 

--	and  datediff(day,a.TglMember,CONVERT(varchar, CONVERT(date, @p_to_date, 103), 111)) >=0  ) 

--for json auto 

		--)  



 

 --select @bitparam 







 --select  @member_total					as member_total	 

	--		,@active_member_total		as active_member_total

	--		,@inactive_member_total		as inactive_member_total 

	--		,@new_member_today			as new_member_today

			

			--,@prev_member_total				/	 @member_total * 100 as presentase_member_total

			--,@prev_active_member_total		/	@active_member_total * 100 as presentase_active_member_total

			--,@prev_inactive_member_total	/   @inactive_member_total * 100 as presentase_inactive_member_total

			--,@prev_new_member_today			/  @new_member_today  * 100 as presentase_new_member_today



 





end 

-- ===== xsp_app_dashboard_member_location_list_getrows






--exec xsp_app_dashboard_member_location_list_getrows '12','158'

CREATE procedure [dbo].[xsp_app_dashboard_member_location_list_getrows]

(

	 @p_provinsi    varchar(40)

	,@p_kota		varchar(40)

	, @p_from_date		varchar(20)

	,@p_to_date			varchar(20)

)

as

begin





--update a

--set

--a.provinsi =  c.prov_id

--,a.kota = b.city_id



--  from dt_member a 

--inner join master_wilayah.dbo.cities b on b.city_name			=	a.alamat2

--inner join master_wilayah.dbo.provinces c on c.prov_id			=	b.prov_id  

--where a.Alamat2 <> ''



 



select   isnull(b.prov_name,'TIDAK DIKETAHUI') as PROVINSI, isnull(c.city_name,'TIDAK DIKETAHUI') as KOTA, count(a.ID_MEMBER) as TOTAL_MEMBER

, count(a.ID_MEMBER) as TOTAL_MEMBER_ACTIVE, count(a.ID_MEMBER) as TOTAL_MEMBER_NONACTIVE from dt_member a 

left outer join master_wilayah.dbo.provinces b on b.prov_id		=	a.provinsi

left outer join master_wilayah.dbo.cities c on c.city_id			=	a.kota

left outer join master_wilayah.dbo.districts d on d.dis_id		=	a.kecamatan

 

 where	

     (case when @p_provinsi  = '0' then  cast(b.prov_id as  varchar) else @p_provinsi end  = cast(b.prov_id as  varchar)

  and 	case when @p_kota	 = '0' then cast(c.city_id   as varchar) else @p_kota end  = cast(c.city_id   as varchar)

  )-- OR     (b.prov_name IS NULL or  c.city_name IS NULL)

  and 	(  datediff(day,a.TglMember,dateadd(month,-1,CONVERT(varchar, CONVERT(date, @p_from_date, 103), 111))) <=0 

	and  datediff(day,a.TglMember,dateadd(month,-1,CONVERT(varchar, CONVERT(date, @p_to_date, 103), 111))) >=0  ) 

group by b.prov_name,c.city_name

order by case when isnull(b.prov_name,'TIDAK DIKETAHUI') = 'tidak diketahui' then 1 else 2 end asc--, case when isnull(c.city_name,'TIDAK DIKETAHUI') = 'tidak diketahui' then 1 else 2 end asc





end 

-- ===== xsp_app_dashboard_member_birthday_list_getrows




CREATE procedure [dbo].[xsp_app_dashboard_member_birthday_list_getrows]

as

begin

	--select  Nama as name,

	--'Active' as Status,

	--format(TglLahir,'MMMM dd, yyyy') as DateofBirth 

	--,datediff(day, getdate(),tgllahir) as info

	--from dt_member  

	--where datediff(month,getdate(),tgllahir) = 0 and datediff(day,getdate(),tgllahir) >0



	--order by info asc



		select  Nama as name,

'Active' as Status,

format(TglLahir,'MMMM dd, yyyy') as DateofBirth 

,datediff(day,getdate(), tgllahir) as info

from dt_member  

where  datediff(month,dateadd(month,5,getdate()),tgllahir) <= 0

 and  datediff(day,getdate(), tgllahir) >0

order by info asc



--	select top 10 Nama as name,

--'Active' as Status,

--format(TglLahir,'MMMM dd, yyyy') as DateofBirth 

--,datediff(day,dateadd(day,-5,getdate()),tgllahir) as info

--from dt_member  

--where datediff(month,dateadd(day,-5,getdate()),tgllahir) = 0 and datediff(day,dateadd(day,-5,getdate()),tgllahir) >0

--order by info asc

end
-- ===== xsp_app_dashboard_ddl_provinsi_getrows




CREATE procedure xsp_app_dashboard_ddl_provinsi_getrows

 

as 

begin 

select prov_id, prov_name as provinsi from master_wilayah.dbo.provinces

end
-- ===== xsp_app_dashboard_ddl_kota_getrows




create procedure [dbo].[xsp_app_dashboard_ddl_kota_getrows]

 

as 

begin 

select city_id, city_name as kota  from master_wilayah.dbo.cities

end
