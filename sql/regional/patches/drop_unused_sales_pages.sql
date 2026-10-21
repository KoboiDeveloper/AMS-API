/*
  Drop unused Sales REG2 SPs (Batch, Slip Setoran Sales, Dcr Summary).
  Menu already deactivated; React pages/routes removed.
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_batch_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_batch_getrows;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_slip_setoran_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_slip_setoran_getrows;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_dcr_summary_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_dcr_summary_getrows;
GO
