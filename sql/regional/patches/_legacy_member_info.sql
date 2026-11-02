-- ===== xsp_app_dashboard_member_Info_getrow


CREATE procedure [dbo].[xsp_app_dashboard_member_Info_getrow]
(
	@p_id_member   varchar(32)
)
as 
begin
select ID_MEMBER_APPS as member_id
		,a.Nama
		,a.Alamat1 as alamat
		,isnull(b.prov_id,0) as provinsi
		,isnull(c.city_id,0) as kota
		,format(a.TglLahir,'yyyy/MM/dd') as TglLahir 
		,a.NoTelpon
		,a.email
		,a.Password
		,format(a.TglMember,'yyyy/MM/dd') as TglMember
		,a.Store_ID 
		,UPPER(a.Jenis_kelamin) AS Jenis_kelamin 
		,(select CAST(D.ID_TIER AS VARCHAR) +'-'+E.TIER_NAME from SYS_MEMBER.dbo.DT_MEMBER_TIER d  
		inner join  SYS_MEMBER.dbo.DT_MEMBER_TIER_HEADER  e on e.ID = d.ID_TIER 
		where d.ID_MEMBER = a.ID_MEMBER AND d.STATUS = 1) as TIER
	from dt_member a
	left outer join master_wilayah.dbo.provinces b on b.prov_id = a.provinsi
	left outer join master_wilayah.dbo.cities c on c.city_id= a.Kota
	where a.ID_MEMBER = @p_id_member
end
-- ===== xsp_app_dashboard_member_info_total_point_getrow



---   exec xsp_app_dashboard_member_info_total_point_getrow '7B0792985D584A5C9BDA85469662C58E'

CREATE procedure [dbo].[xsp_app_dashboard_member_info_total_point_getrow]
(
	@p_id_member  varchar(32)
)
as
begin

--select a.ID_MEMBER ,b.Nama,  isnull(sum((a.Point_Reward + a.Bonus_Point_Reward + a.Bonus_Tanggal_Bagus)),0)  as total_point from DT_MEMBER_TRANSAKSI a
--left outer join dt_member b on b.ID_MEMBER = a.ID_MEMBER  where a.Store_ID = 'RC116'
--group by a.ID_MEMBER ,b.Nama
--order by 3 desc
  
declare @point_used int

set @point_used = (select  isnull(sum(a.PointVoucher),0) as point from  SYS_MEMBER.dbo.DT_MEMBER_VOUCHER a  where a.ID_MEMBER =@p_id_member )

select  format(isnull(sum((a.REWARD_POINT + a.BONUS_POINT  + a.BIG_DAY_POINT + a.BIRTHDAY_POINT)),0),'N0') as TOTAL_POINT 
		,format(@point_used,'N0') as Point_used
		,format(isnull(sum((a.REWARD_POINT + a.BONUS_POINT + a.BIG_DAY_POINT + a.BIRTHDAY_POINT)),0)-@point_used ,'N0')as Sisa_point
from SYS_MEMBER.dbo.DT_MEMBER_TRANSAKSI a 
where a.ID_MEMBER = @p_id_member


end
-- ===== xsp_get_member_detail_ver2_getrows
 


-- EXEC  xsp_get_member_detail_ver2_getrows  '8FF52F19C05C4B35BE72706E3EF6E415','01/05/2025','05/05/2025'

CREATE PROCEDURE [dbo].[xsp_get_member_detail_ver2_getrows]
 (
	 @p_id_member  varchar(200)
	,@p_from_date  varchar(20)
	,@p_to_date    varchar(20)
 )
AS
BEGIN


 
 declare @from_date		    datetime  = CONVERT(varchar, CONVERT(date, @p_from_date, 103), 111)
		,@to_date			datetime  = CONVERT(varchar, CONVERT(date, @p_to_date, 103), 111)

  
  select  CATEGORY,format(TANGGAL,'dd/MM/yyyy HH:mm') as TANGGAL, A,REDEEM,REWARD,BIRTHDAY,BIGDAY,Z,ID_STORE from SYS_MEMBER.dbo.[DT_MEMBER_POINT_SUMMARY]  where id_member = @p_id_member 
  and datediff(day,TANGGAL,@from_date)<=0 and datediff(day,TANGGAL,@to_date)>=0  ORDER BY   TANGGAL DESC, ID_TR_SALES_HEADER, CASE WHEN CATEGORY = 'TRANSAKSI' THEN 2
													  WHEN CATEGORY = 'REDEEM' THEN 1
													  ELSE 3 end

    
END
  
-- ===== xsp_app_dashboard_member_Activity_frequency_chart_getrow
 
 --- exec xsp_app_dashboard_member_Activity_frequency_chart_getrow '','',''

CREATE procedure [dbo].[xsp_app_dashboard_member_Activity_frequency_chart_getrow]
 (
	@p_from_date   varchar(20)  
	,@p_to_date   varchar(20)  
	,@p_id_member	varchar(32) 
 )
as 
begin


 declare @from_date		    datetime  = CONVERT(varchar, CONVERT(date, @p_from_date, 103), 111)
		,@to_date			datetime  = CONVERT(varchar, CONVERT(date, @p_to_date, 103), 111)



 declare @bitparam   varchar(max) 
select @bitparam = (
 
select  b.Store_Brand_ID as brand, count(c.ID_TR_SALES_HEADER) as total_transaction , sum(d.QTY) as total_qty
	from sys_member.dbo.DT_MEMBER_TRANSAKSI a WITH (NOLOCK)
			inner join dt_store b on b.Store_ID = a.Store_ID
			inner join TR_SALES_header c on c.ID_TR_SALES_HEADER = a.ID_BILL_CODE
			left outer join (select * from TR_SALES_DETAIL where  qty > 0) d on d.ID_TR_SALES_HEADER = a.ID_BILL_CODE
	where datediff(day,a.Tanggal,@from_date) <= 0  and datediff(day,a.Tanggal,@to_date) >= 0
	--and  b.Store_Brand_ID  = 'celcius' 
	and a.ID_MEMBER = @p_id_member
	GROUP BY   b.Store_Brand_ID 
	order by case when  b.Store_Brand_ID  = 'celcius' then 1 
				  when   b.Store_Brand_ID = 'mississippi' then 2
				  when  b.Store_Brand_ID = 'iwan fashion' then 3
				  when  b.Store_Brand_ID = 'flies' then 4
				  when  b.Store_Brand_ID = 'queensland' then 5
				  when  b.Store_Brand_ID = 'aeesha' then 6
	end asc
	 for json auto 
 )
 select @bitparam as member_activity_frequency
 end


-- ===== xsp_app_dashboard_member_Activity_all_brand_chart_getrow
 
 --- exec xsp_app_dashboard_member_Activity_all_brand_chart_getrow '','',''

CREATE procedure [dbo].[xsp_app_dashboard_member_Activity_all_brand_chart_getrow]
 (
	@p_from_date   varchar(20)  
	,@p_to_date   varchar(20)
	,@p_id_member	varchar(32) 
 )
as 
begin


 declare @from_date		    datetime  = CONVERT(varchar, CONVERT(date, @p_from_date, 103), 111)
		,@to_date			datetime  = CONVERT(varchar, CONVERT(date, @p_to_date, 103), 111)

 declare @bitparam   varchar(max) 
select @bitparam = (
 select cast(FORMAT( DateAdd( month ,  x.bulan , 0 ) - 1 ,'MMM')  as varchar) + '\n'+cast(X.tahun as varchar) AS category,* from (
 select   DATEPART(year, a.Tanggal) as tahun, DATEPART(MONTH, a.Tanggal) as bulan,count(a.ID_BILL_CODE) as total_transaction ,  sum(c.BAYAR)  as total_bayar
	from sys_member.dbo.DT_MEMBER_TRANSAKSI a WITH (NOLOCK)
			inner join dt_store b on b.Store_ID = a.Store_ID 
			inner join TR_SALES_PAYMENT_DETAIL c on c.ID_TR_SALES_HEADER = a.ID_BILL_CODE
	where datediff(day,a.Tanggal,@from_date) <= 0  and datediff(day,a.Tanggal,@to_date) >= 0
	--and  b.Store_Brand_ID  = 'celcius' 
	and a.ID_MEMBER = @p_id_member
	GROUP BY   DATEPART(MONTH, a.Tanggal),DATEPART(year, a.Tanggal)
	) as x
	order by 2 asc  ,3 asc  
	 for json auto 
 )
 select @bitparam as member_activity_all_brand
 end


-- ===== xsp_data_member_update





CREATE procedure [dbo].[xsp_data_member_update]
(
	
   @p_id_member			varchar(50) 
   ,@p_nama				varchar(50)
	,@p_tanggal_lahir	datetime
	,@p_jenis_kelamin	varchar(4)
	,@p_no_tlp		varchar(50)
	,@p_alamat		varchar(200)
	,@p_provinsi	varchar(50)
	,@p_kota		varchar(50)
	,@p_email		varchar(50)
	,@p_password	varchar(50) 
)

as
begin

update POS_SERVER.dbo.dt_member  
set   
	 Nama				= @p_nama		 
	, TglLahir			= @p_tanggal_lahir 
	,Jenis_kelamin		= UPPER(@p_jenis_kelamin)
	, NoTelpon			= @p_no_tlp 
	,Alamat1			= @p_alamat
	,provinsi			= @p_provinsi
	,Kota				= @p_kota
	,Email				= @p_email
	,Password			= @p_password
where ID_MEMBER = @p_id_member


--update AMS_STORE.dbo.dt_member  
--set    Nama				= @p_nama		 
--	, TglLahir			= @p_tanggal_lahir 
--	,Jenis_kelamin		= @p_jenis_kelamin 
--	, NoTelpon			= @p_no_tlp 
--	,Alamat1			= @p_alamat
--	,provinsi			= @p_provinsi
--	,Kota				= @p_kota
--	,Email				= @p_email
--	,Password			= @p_password
--where ID_MEMBER = @p_id_member

--delete POS_SERVER.dbo.DT_MEMBER_STATUS   where ID_Member = @p_id_member



end
