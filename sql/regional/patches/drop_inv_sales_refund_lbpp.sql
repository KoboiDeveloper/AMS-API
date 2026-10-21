/*
  Permanently remove REG Inventory Sales Refund + Lbpp (pages/routes already gone).
  Lbpp By Brand remains.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

DELETE rp
FROM dbo.RBAC_RolePermission rp
INNER JOIN dbo.RBAC_Module m ON m.module_id = rp.module_id
WHERE m.module_code IN ('REG_RPT_SALES_REFUND', 'REG_RPT_LBPP');
GO

DELETE FROM dbo.RBAC_Module
WHERE module_code IN ('REG_RPT_SALES_REFUND', 'REG_RPT_LBPP');
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_sales_refund_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_refund_getrows;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_lbpp_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_lbpp_getrows;
GO

SELECT module_code, module_name, is_active
FROM dbo.RBAC_Module
WHERE module_code IN ('REG_RPT_SALES_REFUND', 'REG_RPT_LBPP', 'REG_RPT_LBPP_BRAND');
GO
