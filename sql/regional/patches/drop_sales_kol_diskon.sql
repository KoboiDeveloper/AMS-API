/*
  Drop unused Sales By Kol + Store Diskon REG2 SPs.
  Menu already deactivated; React pages/routes removed.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_sales_kol_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_sales_kol_getrows;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_store_diskon_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_store_diskon_getrows;
GO
