/*
  Remove Last Stock By Article — Article filter already on Last Stock page.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

DELETE rp
FROM dbo.RBAC_RolePermission rp
INNER JOIN dbo.RBAC_Module m ON m.module_id = rp.module_id
WHERE m.module_code = 'REG_RPT_LAST_STOCK_ARTICLE';
GO

DELETE FROM dbo.RBAC_Module
WHERE module_code = 'REG_RPT_LAST_STOCK_ARTICLE';
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_last_stock_article_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_last_stock_article_getrows;
GO

SELECT module_code, module_name, is_active
FROM dbo.RBAC_Module
WHERE module_code LIKE 'REG_RPT_LAST_STOCK%';
GO
