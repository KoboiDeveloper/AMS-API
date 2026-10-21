CREATE PROCEDURE[dbo].[XSP_TR_SO_ADJUST_LAIN_LAIN_REG_GETROWS]
 (
 @p_store_id   varchar(10)
 ,@p_brand_id	varchar(20)
 ,@p_from_date	datetime
 ,@p_to_date		datetime
 )
AS
BEGIN
if (@p_brand_id = 'ALL' AND @p_store_id = 'ALL' )
BEGIN
SELECT
	WAKTU_URUT
      ,ID_TR_SO_ADJUST_LAIN_LAIN 
      ,STORE_ID
      ,PLU
      ,QTY
      ,HPP
      ,PRICE
      ,TOTAL_HPP
      ,TOTAL_PRICE
      ,TGL_REAL
      ,FORMAT(TGL_ADJUST,'yyyy-MM-dd') as tgl_adjust
 FROM TR_SO_LAIN_LAIN
 WHERE  datediff(day,TGL_ADJUST,@p_from_date) <=0 and datediff(day,TGL_ADJUST,@p_to_date)>=0

END
else if (@p_brand_id != 'ALL' AND @p_store_id != 'ALL' )
 SELECT
	WAKTU_URUT
      ,ID_TR_SO_ADJUST_LAIN_LAIN 
      ,STORE_ID
      ,PLU
      ,QTY
      ,HPP
      ,PRICE
      ,TOTAL_HPP
      ,TOTAL_PRICE
      ,TGL_REAL
      ,FORMAT(TGL_ADJUST,'yyyy-MM-dd') as tgl_adjust
 FROM TR_SO_LAIN_LAIN
 WHERE STORE_ID = @p_store_id
 and datediff(day,TGL_ADJUST,@p_from_date) <=0 and datediff(day,TGL_ADJUST,@p_to_date)>=0
END
