--exec [XSP_BON_MANUAL_SALES_NAME_GETROWS] 'RC071'
CREATE PROCEDURE [dbo].[XSP_SALES_BY_MAN_POWER_GETROWS] 

(	 
	@p_store_id					varchar(10) 
	 
)
AS
BEGIN
 
 SELECT DISTINCT UPPER(User_NIK) AS USER_NIK
				,UPPER(USER_NAME) + ' - ' + UPPER(User_NIK) AS USER_NAME  FROM DT_User 
 WHERE STORE_ID = @p_store_id
 --  AND User_Level_ID = 2
 AND  Status_Active = 1
 
 ORDER BY USER_NAME asc
			
END

