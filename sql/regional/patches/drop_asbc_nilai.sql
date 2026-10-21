/*
  Drop REG2 Asbc Nilai SP (module removed).
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_rpt_asbc_nilai_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_rpt_asbc_nilai_getrows;
GO
