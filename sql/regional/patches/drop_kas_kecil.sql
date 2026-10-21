/*
  Remove Regional Kas Kecil (Store Kas List / Realisasi / Petty Cash).
  Reparent Stock Opname under Laporan (REG_RPT).
*/
USE RBACESS;
GO
SET NOCOUNT ON;
GO

/* Keep SO usable after Kas group is removed */
UPDATE dbo.RBAC_Module
SET parent_module_code = 'REG_RPT',
    sort_no = 35,
    updated_by = 'REG_DROP_KAS',
    updated_at = SYSUTCDATETIME()
WHERE module_code = 'REG_GRP_SO';
GO

DELETE rp
FROM dbo.RBAC_RolePermission rp
INNER JOIN dbo.RBAC_Module m ON m.module_id = rp.module_id
WHERE m.module_code IN (
    'REG_KAS_LIST',
    'REG_KAS_REALISASI',
    'REG_KAS_PETTY',
    'REG_GRP_KAS'
);
GO

DELETE FROM dbo.RBAC_Module
WHERE module_code IN (
    'REG_KAS_LIST',
    'REG_KAS_REALISASI',
    'REG_KAS_PETTY',
    'REG_GRP_KAS'
);
GO

IF OBJECT_ID(N'dbo.xsp_ams_new_reg_kas_list_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_kas_list_getrows;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_kas_realisasi_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_kas_realisasi_getrows;
GO
IF OBJECT_ID(N'dbo.xsp_ams_new_reg_kas_petty_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_kas_petty_getrows;
GO

SELECT module_code, module_name, parent_module_code, is_active
FROM dbo.RBAC_Module
WHERE module_code LIKE 'REG_%KAS%' OR module_code = 'REG_GRP_SO'
ORDER BY module_code;
GO
