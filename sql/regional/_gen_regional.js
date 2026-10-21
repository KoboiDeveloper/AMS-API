const fs = require("fs");
const path = require("path");

const leaves = [
  ["REG_DASHBOARD", "Dashboard", null, "/admin/regional/dashboard", 1, "dashboard", false],

  ["REG_RPT", "Laporan", null, "#", 100, null, false],
  ["REG_COMMERCE", "Commerce", null, "#", 150, null, false],
  ["REG_MP", "Marketplace", "REG_COMMERCE", "#", 10, null, false],
  ["REG_MP_AR_LIST", "Ar List", "REG_MP", "/admin/regional/mp/ar-list", 10, "ar_list", true],
  ["REG_MP_AR_REALISASI", "Ar Realisasi", "REG_MP", "/admin/regional/mp/ar-realisasi", 20, "ar_realisasi", true],
  ["REG_MP_RETUR", "Retur", "REG_MP", "/admin/regional/mp/retur", 30, "mp_retur", true],

  ["REG_GRP_OFFICE", "Office", "REG_RPT", "#", 10, null, false],
  ["REG_GRP_SALES", "Sales", "REG_RPT", "#", 20, null, false],
  ["REG_GRP_INV", "Inventory", "REG_RPT", "#", 30, null, false],
  ["REG_GRP_SO", "Stock Opname", "REG_RPT", "#", 35, null, false],
  ["REG_GRP_VOUCHER", "Voucher", "REG_COMMERCE", "#", 20, null, false],
  ["REG_GRP_OMNI", "Omnichannel", "REG_COMMERCE", "#", 30, null, false],
  ["REG_GRP_MEMBER", "Member", "REG_COMMERCE", "#", 40, null, false],

  ["REG_ABSEN_LIST", "Absen List", "REG_GRP_OFFICE", "/admin/regional/absen/list", 5, "absen_list", false],
  ["REG_SLIP_DCR", "Slip Setoran Bank", "REG_GRP_OFFICE", "/admin/regional/slip/dcr", 30, "slip_dcr", false],

  /* Laporan → Sales (full REG2 parity) */
  ["REG_MOBILE_TOT_SALES", "Total Sales", "REG_GRP_SALES", "/admin/regional/rpt/sales/total-sales", 5, "total_sales", false],
  ["REG_RPT_SALES_ARTICLE", "Sales By Article", "REG_GRP_SALES", "/admin/regional/rpt/sales/sales-article", 6, "rpt_sales_article", false],
  ["REG_RPT_SALES_ISLAND", "Sales By Island", "REG_GRP_SALES", "/admin/regional/rpt/sales/sales-island", 7, "rpt_sales_island", false],
  ["REG_RPT_GROSS_MARGIN", "Gross Margin", "REG_GRP_SALES", "/admin/regional/rpt/sales/gross-margin", 8, "rpt_gross_margin", false],
  ["REG_RPT_DAILY_SALES", "Daily Sales Summary", "REG_GRP_SALES", "/admin/regional/rpt/sales/daily-sales", 20, "rpt_daily_sales", false],
  ["REG_RPT_DCR", "Daily Collection Report", "REG_GRP_SALES", "/admin/regional/rpt/sales/dcr", 25, "rpt_dcr", false],
  ["REG_RPT_SALES_DETAIL", "Sales Detail", "REG_GRP_SALES", "/admin/regional/rpt/sales/sales-detail", 35, "rpt_sales_detail", false],
  ["REG_RPT_PAYMENT", "Payment Detail", "REG_GRP_SALES", "/admin/regional/rpt/sales/payment-detail", 40, "rpt_payment_detail", false],
  ["REG_RPT_AR_DETAIL", "Ar Detail", "REG_GRP_SALES", "/admin/regional/rpt/sales/ar-detail", 45, "rpt_ar_detail", false],
  ["REG_RPT_PROMOSI", "Promosi", "REG_GRP_SALES", "/admin/regional/rpt/sales/promosi", 50, "rpt_promosi", false],
  ["REG_RPT_SALES_KOL", "Sales By Kol", "REG_GRP_SALES", "/admin/regional/rpt/sales/sales-kol", 55, "rpt_sales_kol", false],
  ["REG_RPT_STORE_DISKON", "Store Diskon", "REG_GRP_SALES", "/admin/regional/rpt/sales/store-diskon", 60, "rpt_store_diskon", false],
  ["REG_RPT_ASBC_QTY", "Asbc Qty", "REG_GRP_SALES", "/admin/regional/rpt/sales/asbc-qty", 65, "rpt_asbc_qty", false],
  ["REG_RPT_KOLEKSI", "Koleksi", "REG_GRP_SALES", "/admin/regional/rpt/sales/koleksi", 75, "rpt_koleksi", false],
  ["REG_RPT_SALES_MANPOWER", "Sales By Man Power", "REG_GRP_SALES", "/admin/regional/rpt/sales/sales-manpower", 80, "rpt_sales_manpower", false],

  ["REG_RPT_TR_ST_IN", "Tr St In", "REG_GRP_INV", "/admin/regional/rpt/inv/tr-st-in", 10, "rpt_tr_st_in", false],
  ["REG_RPT_OUTSTANDING", "Outstanding Stock", "REG_GRP_INV", "/admin/regional/rpt/inv/outstanding", 20, "rpt_outstanding", false],
  ["REG_RPT_TR_ST_OUT", "Tr St Out", "REG_GRP_INV", "/admin/regional/rpt/inv/tr-st-out", 60, "rpt_tr_st_out", false],
  ["REG_RPT_ST_LIST", "St List", "REG_GRP_INV", "/admin/regional/rpt/inv/st-list", 70, "rpt_st_list", false],
  ["REG_RPT_SALES_REFUND", "Sales Refund", "REG_GRP_INV", "/admin/regional/rpt/inv/sales-refund", 80, "rpt_sales_refund", false],
  ["REG_RPT_LBPP", "Lbpp", "REG_GRP_INV", "/admin/regional/rpt/inv/lbpp", 90, "rpt_lbpp", false],
  ["REG_RPT_LBPP_BRAND", "Lbpp By Brand", "REG_GRP_INV", "/admin/regional/rpt/inv/lbpp-brand", 100, "rpt_lbpp_brand", false],
  ["REG_RPT_LAST_STOCK", "Last Stock", "REG_GRP_INV", "/admin/regional/rpt/inv/last-stock", 110, "rpt_last_stock", false],
  ["REG_RPT_LAST_STOCK_ALL", "Last Stock All Store", "REG_GRP_INV", "/admin/regional/rpt/inv/last-stock-all", 140, "rpt_last_stock_all", false],
  ["REG_RPT_DAILY_STOCK", "Daily Stock Summary", "REG_GRP_INV", "/admin/regional/rpt/inv/daily-stock", 150, "rpt_daily_stock", false],
  ["REG_RPT_CEK_MUTASI", "Cek Mutasi", "REG_GRP_INV", "/admin/regional/rpt/inv/cek-mutasi", 170, "rpt_cek_mutasi", false],
  ["REG_RPT_MUTASI_HARIAN", "Mutasi Harian", "REG_GRP_INV", "/admin/regional/rpt/inv/mutasi-harian", 180, "rpt_mutasi_harian", false],
  ["REG_RPT_CEK_QTY0", "Cek Qty 0", "REG_GRP_INV", "/admin/regional/rpt/inv/cek-qty0", 190, "rpt_cek_qty0", false],

  ["REG_RPT_TR_SO", "Tr So", "REG_GRP_SO", "/admin/regional/rpt/so/tr-so", 10, "rpt_tr_so", false],
  ["REG_RPT_SO_DIFF", "So Different", "REG_GRP_SO", "/admin/regional/rpt/so/so-diff", 20, "rpt_so_diff", false],
  ["REG_RPT_SO_ADJ", "So Adjustment", "REG_GRP_SO", "/admin/regional/rpt/so/so-adj", 30, "rpt_so_adj", false],
  ["REG_RPT_TR_SO_PARTIAL", "Tr So Partial", "REG_GRP_SO", "/admin/regional/rpt/so/tr-so-partial", 40, "rpt_tr_so_partial", false],
  ["REG_RPT_SO_DIFF_PARTIAL", "So Different Partial", "REG_GRP_SO", "/admin/regional/rpt/so/so-diff-partial", 50, "rpt_so_diff_partial", false],
  ["REG_RPT_SO_ADJ_PARTIAL", "So Adjustment Partial", "REG_GRP_SO", "/admin/regional/rpt/so/so-adj-partial", 60, "rpt_so_adj_partial", false],

  ["REG_RPT_VOUCHER_FISIK", "Voucher Fisik", "REG_GRP_VOUCHER", "/admin/regional/rpt/voucher/fisik", 10, "rpt_voucher_fisik", false],
  ["REG_RPT_VOUCHER_IMLEK", "Voucher Imlek", "REG_GRP_VOUCHER", "/admin/regional/rpt/voucher/imlek", 20, "rpt_voucher_imlek", false],

  ["REG_RPT_OMNI_RT", "Realtime Stock", "REG_GRP_OMNI", "/admin/regional/rpt/omni/realtime-stock", 10, "rpt_omni_rt", false],
  ["REG_RPT_OMNI_VARIAN", "Varian Stock", "REG_GRP_OMNI", "/admin/regional/rpt/omni/varian-stock", 20, "rpt_omni_varian", false],
  ["REG_RPT_OMNI_ORDER", "Order Online", "REG_GRP_OMNI", "/admin/regional/rpt/omni/order-online", 30, "rpt_omni_order", false],

  ["REG_RPT_MEMBER", "Member", "REG_GRP_MEMBER", "/admin/regional/rpt/member/list", 10, "rpt_member", false],
  ["REG_RPT_MEMBER_INFO", "Member Info", "REG_GRP_MEMBER", "/admin/regional/rpt/member/info", 20, "rpt_member_info", false],

  ["REG_UTIL", "Utility", null, "#", 400, null, false],
  ["REG_GRP_SCAN", "Scan Selisih Harga", "REG_UTIL", "#", 10, null, false],
  ["REG_GRP_TOOLS", "Tools", "REG_UTIL", "#", 20, null, false],
  ["REG_GRP_PRINT", "Print", "REG_UTIL", "#", 30, null, false],

  ["REG_SCAN_SELISIH", "Tools Scan Selisih", "REG_GRP_SCAN", "/admin/regional/util/scan-selisih", 10, "scan_selisih", true],
  ["REG_PLU_SCAN", "Scan Plu", "REG_GRP_TOOLS", "/admin/regional/util/scan-plu", 5, "plu_scan", false],
  ["REG_TOOLS_ADJ_SO", "Adj So Parsial", "REG_GRP_TOOLS", "/admin/regional/util/adj-so-partial", 10, "adj_so_partial", true],
  ["REG_TOOLS_GH", "Group Head", "REG_GRP_TOOLS", "/admin/regional/util/group-head", 20, "group_head", true],
  ["REG_TOOLS_STORE", "Store List", "REG_GRP_TOOLS", "/admin/regional/util/store-list", 30, "store_list", false],
  ["REG_PRINT_OUTSTANDING", "Outstanding Stock Print", "REG_GRP_PRINT", "/admin/regional/util/print-outstanding", 10, "print_outstanding", false],
];

const sqlDir = __dirname;
const reactDir = path.join(
  "D:/BODO/KANTOR/REACT/POS_React/src/pages/admin/regional"
);

const getrowsParams = `(
      @p_keywords varchar(200) = NULL
    , @p_from_date varchar(30) = NULL
    , @p_to_date varchar(30) = NULL
    , @p_is_active varchar(10) = NULL
    , @p_id_brand varchar(50) = NULL
    , @p_id_store varchar(50) = NULL
    , @p_brand varchar(50) = NULL
    , @p_store_id varchar(50) = NULL
    , @p_status varchar(50) = NULL
    , @p_kategori varchar(50) = NULL
    , @p_group varchar(50) = NULL
    , @p_dept varchar(50) = NULL
    , @p_department varchar(50) = NULL
    , @p_cabang varchar(50) = NULL
    , @p_id_cabang varchar(50) = NULL
    , @p_year varchar(10) = NULL
    , @p_month varchar(10) = NULL
    , @p_period varchar(20) = NULL
    , @p_tipe varchar(50) = NULL
    , @p_is_pajak varchar(10) = NULL
    , @p_id_mesin varchar(50) = NULL
    , @p_currentmonth varchar(10) = NULL
    , @p_tahun varchar(10) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @p_plu varchar(80) = NULL
    , @p_article varchar(80) = NULL
    , @p_voucher varchar(80) = NULL
    , @p_invoice varchar(80) = NULL
    , @p_marketplace varchar(80) = NULL
    , @p_multi_store varchar(max) = NULL
    , @p_brand_filter varchar(80) = NULL
    , @p_brand_to varchar(50) = NULL
    , @p_store_to varchar(50) = NULL
    , @p_tgl varchar(30) = NULL
    , @p_provinsi varchar(80) = NULL
    , @p_kota varchar(80) = NULL
    , @p_id_member varchar(80) = NULL
    , @p_confirm_status varchar(50) = NULL
    , @p_gh_id varchar(50) = NULL
    , @p_id_gh varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)`;

function stubGetrows(entity) {
  return `IF OBJECT_ID(N'dbo.xsp_ams_new_reg_${entity}_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_${entity}_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_${entity}_getrows
${getrowsParams}
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0 FOR JSON PATH)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO`;
}

function stubCrud(entity, op) {
  let params = "@p_id varchar(80), @p_payload varchar(max)=NULL, @p_updated_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT";
  if (op === "insert") {
    params =
      "@p_payload varchar(max), @p_created_by varchar(50)=NULL, @p_actor_nik varchar(50)=NULL, @bitparam varchar(max) OUTPUT";
  } else if (op === "getrow") {
    params = "@p_id varchar(80), @bitparam varchar(max) OUTPUT";
  }
  return `IF OBJECT_ID(N'dbo.xsp_ams_new_reg_${entity}_${op}', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_${entity}_${op};
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_${entity}_${op}
( ${params} )
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0 FOR JSON PATH)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO`;
}

function esc(s) {
  return String(s).replace(/'/g, "''");
}

// ---------- seed ----------
const seedLines = [];
seedLines.push("USE RBACESS;");
seedLines.push("GO");
seedLines.push("SET NOCOUNT ON;");
seedLines.push("GO");
seedLines.push("IF NOT EXISTS (SELECT 1 FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL')");
seedLines.push("BEGIN");
seedLines.push(
  "    INSERT INTO dbo.RBAC_Role (role_code, role_name, scope_level, description, is_system, is_active, created_by)"
);
seedLines.push(
  "    VALUES ('REGIONAL', 'Regional', 'AREA', 'Migrated from WEB_USER_MAIN roll_code 5', 0, 1, 'REG_MIGRATION');"
);
seedLines.push("END;");
seedLines.push("GO");
seedLines.push("DECLARE @mods TABLE (");
seedLines.push("      module_code varchar(80) NOT NULL PRIMARY KEY");
seedLines.push("    , module_name varchar(150) NOT NULL");
seedLines.push("    , parent_module_code varchar(80) NULL");
seedLines.push("    , endpoint_path varchar(250) NULL");
seedLines.push("    , sort_no int NOT NULL");
seedLines.push(");");
seedLines.push(
  "INSERT INTO @mods (module_code, module_name, parent_module_code, endpoint_path, sort_no) VALUES"
);
seedLines.push(
  leaves
    .map(([code, name, parent, ep, sort]) => {
      const p = parent == null ? "NULL" : `'${parent}'`;
      return `    ('${code}', '${esc(name)}', ${p}, '${ep}', ${sort})`;
    })
    .join(",\n") + ";"
);
seedLines.push(
  "INSERT INTO dbo.RBAC_Module (module_code, module_name, parent_module_code, endpoint_path, sort_no, is_active, created_by)"
);
seedLines.push(
  "SELECT m.module_code, m.module_name, m.parent_module_code, m.endpoint_path, m.sort_no, 1, 'REG_MIGRATION'"
);
seedLines.push("FROM @mods AS m");
seedLines.push(
  "WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Module AS x WHERE x.module_code = m.module_code);"
);
seedLines.push(
  "UPDATE m SET m.module_name = t.module_name, m.parent_module_code = t.parent_module_code,"
);
seedLines.push(
  "    m.endpoint_path = t.endpoint_path, m.sort_no = t.sort_no, m.is_active = 1,"
);
seedLines.push(
  "    m.updated_by = 'REG_MIGRATION', m.updated_at = SYSUTCDATETIME()"
);
seedLines.push(
  "FROM dbo.RBAC_Module AS m INNER JOIN @mods AS t ON t.module_code = m.module_code;"
);
seedLines.push("GO");
seedLines.push(
  "DECLARE @role_id int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL');"
);
seedLines.push(
  "INSERT INTO dbo.RBAC_RolePermission (role_id, module_id, permission_id, is_active, created_by)"
);
seedLines.push(
  "SELECT @role_id, m.module_id, p.permission_id, 1, 'REG_MIGRATION'"
);
seedLines.push(
  "FROM dbo.RBAC_Module AS m CROSS JOIN dbo.RBAC_Permission AS p"
);
seedLines.push("WHERE m.module_code LIKE 'REG[_]%'");
seedLines.push(
  "  AND p.permission_code IN ('VIEW','CREATE','UPDATE','DELETE','EXPORT')"
);
seedLines.push("  AND @role_id IS NOT NULL");
seedLines.push(
  "  AND NOT EXISTS (SELECT 1 FROM dbo.RBAC_RolePermission rp WHERE rp.role_id=@role_id AND rp.module_id=m.module_id AND rp.permission_id=p.permission_id);"
);
seedLines.push("GO");
seedLines.push(
  "DECLARE @users TABLE (nik varchar(30) NOT NULL PRIMARY KEY, nama varchar(150));"
);
seedLines.push("INSERT INTO @users (nik, nama) VALUES");
seedLines.push(
  "    ('REG2','REG 2'),('REG1','REG 1'),('REGX','REG X'),('ARIS','ARIS'),"
);
seedLines.push(
  "    ('BARMAN','BARMAN'),('BASKORO','BASKORO'),('JEFRI','JEFRI');"
);
seedLines.push(
  "IF OBJECT_ID(N'pos_server.dbo.WEB_USER_MAIN', N'U') IS NOT NULL"
);
seedLines.push("BEGIN");
seedLines.push("    INSERT INTO @users (nik, nama)");
seedLines.push(
  "    SELECT DISTINCT u.ID_USER, ISNULL(NULLIF(LTRIM(RTRIM(u.FULL_NAME)), ''), u.ID_USER)"
);
seedLines.push("    FROM pos_server.dbo.WEB_USER_MAIN AS u");
seedLines.push("    WHERE CONVERT(varchar(20), u.ROLL_CODE) = '5'");
seedLines.push(
  "      AND NOT EXISTS (SELECT 1 FROM @users x WHERE x.nik = u.ID_USER);"
);
seedLines.push("END;");
seedLines.push(
  "DECLARE @salt varchar(80) = 'b2c3d4e5f6478990ab12cd34ef567890a1';"
);
seedLines.push("DECLARE @pwd varchar(200) = 'Reg@2026!';");
seedLines.push(
  "DECLARE @hash varchar(64) = CONVERT(varchar(64), HASHBYTES('SHA2_256', CONVERT(varbinary(max), @salt + @pwd)), 2);"
);
seedLines.push(
  "INSERT INTO dbo.RBAC_Employee (nik, employee_name, employee_type, job_title, is_active, created_by)"
);
seedLines.push(
  "SELECT u.nik, u.nama, 'OFFICE', 'REGIONAL', 1, 'REG_MIGRATION' FROM @users u"
);
seedLines.push(
  "WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_Employee e WHERE e.nik = u.nik);"
);
seedLines.push(
  "INSERT INTO dbo.RBAC_AuthUser (username, nik, password_salt, password_hash, is_active, failed_login_count, force_change_password, created_by)"
);
seedLines.push(
  "SELECT LOWER(u.nik), u.nik, @salt, @hash, 1, 0, 0, 'REG_MIGRATION' FROM @users u"
);
seedLines.push(
  "WHERE NOT EXISTS (SELECT 1 FROM dbo.RBAC_AuthUser a WHERE a.nik = u.nik OR a.username = LOWER(u.nik));"
);
seedLines.push(
  "DECLARE @rid int = (SELECT role_id FROM dbo.RBAC_Role WHERE role_code = 'REGIONAL');"
);
seedLines.push(
  "INSERT INTO dbo.RBAC_UserRole (nik, role_id, start_date, is_active, created_by)"
);
seedLines.push(
  "SELECT u.nik, @rid, CAST(GETDATE() AS date), 1, 'REG_MIGRATION' FROM @users u"
);
seedLines.push("WHERE @rid IS NOT NULL AND NOT EXISTS (");
seedLines.push(
  "  SELECT 1 FROM dbo.RBAC_UserRole ur WHERE ur.nik = u.nik AND ur.role_id = @rid AND ur.is_active = 1"
);
seedLines.push(");");
seedLines.push("GO");
seedLines.push("PRINT '01_reg_rbac_seed.sql completed.';");
seedLines.push("GO");
fs.writeFileSync(path.join(sqlDir, "01_reg_rbac_seed.sql"), seedLines.join("\n"));

// ---------- procedures ----------
const uniqueEntities = [
  ...new Map(
    leaves
      .filter((x) => x[5] && x[5] !== "dashboard")
      .map((x) => [x[5], { entity: x[5], crud: x[6] }])
  ).values(),
];

const procs = [];
procs.push("USE RBACESS;");
procs.push("GO");
procs.push("SET ANSI_NULLS ON;");
procs.push("GO");
procs.push("SET QUOTED_IDENTIFIER ON;");
procs.push("GO");

procs.push(`IF OBJECT_ID(N'dbo.xsp_ams_new_reg_lookup_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_lookup_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_lookup_getrows
(
      @p_type varchar(50)
    , @p_keywords varchar(200) = NULL
    , @p_parent_id varchar(80) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @t varchar(50) = LOWER(LTRIM(RTRIM(ISNULL(@p_type,''))));
        DECLARE @kw varchar(200) = NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'');
        DECLARE @parent varchar(80) = NULLIF(LTRIM(RTRIM(ISNULL(@p_parent_id,''))),'');
        DECLARE @gh varchar(50) = NULLIF(LTRIM(RTRIM(ISNULL(@p_actor_nik,''))),'');

        /* Legacy Shared.BindRegbrand → xsp_brand_filter_REG_getrows(@p_gh_id) */
        IF @t IN ('brand','brands') AND OBJECT_ID(N'pos_server.dbo.xsp_brand_filter_REG_getrows', N'P') IS NOT NULL
        BEGIN
            CREATE TABLE #brand (brand varchar(100));
            INSERT INTO #brand (brand)
            EXEC pos_server.dbo.xsp_brand_filter_REG_getrows @p_gh_id = @gh;

            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT DISTINCT b.brand AS value, b.brand AS label
                           FROM #brand AS b
                           WHERE b.brand IS NOT NULL
                             AND (@kw IS NULL OR b.brand LIKE '%'+@kw+'%')
                           ORDER BY 1
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            DROP TABLE #brand;
            RETURN;
        END;

        /* Legacy Shared.BindRegStore → xsp_brand_reg_filter_getrows(@p_gh_id) */
        IF @t IN ('store','stores') AND OBJECT_ID(N'pos_server.dbo.xsp_brand_reg_filter_getrows', N'P') IS NOT NULL
        BEGIN
            CREATE TABLE #store (Store_desc varchar(200), Store varchar(50));
            INSERT INTO #store (Store_desc, Store)
            EXEC pos_server.dbo.xsp_brand_reg_filter_getrows @p_gh_id = @gh;

            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (800)
                                  s.Store AS value,
                                  ISNULL(s.Store_desc, s.Store) AS label
                           FROM #store AS s
                           WHERE s.Store IS NOT NULL
                             AND (@kw IS NULL OR s.Store LIKE '%'+@kw+'%' OR s.Store_desc LIKE '%'+@kw+'%')
                             AND (
                                   @parent IS NULL
                                OR EXISTS (
                                       SELECT 1 FROM pos_server.dbo.DT_Store ds WITH (NOLOCK)
                                       WHERE ds.Store_ID = s.Store
                                         AND (
                                              ds.Store_Brand_ID = @parent
                                           OR (@parent = 'CELCIUS' AND ds.Store_Brand_ID IN ('CELCIUS','CELCIUS KIDS'))
                                         )
                                   )
                             )
                           ORDER BY s.Store
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            DROP TABLE #store;
            RETURN;
        END;

        IF @t IN ('cabang','branch') AND OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT DISTINCT ISNULL(s.STORE_PULAU, s.STORE_KOTA) AS value,
                                  ISNULL(s.STORE_PULAU, s.STORE_KOTA) AS label
                           FROM pos_server.dbo.DT_Store AS s WITH (NOLOCK)
                           WHERE s.Status_Active = 1
                             AND ISNULL(s.STORE_PULAU, s.STORE_KOTA) IS NOT NULL
                           ORDER BY 1
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0 FOR JSON PATH)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO`);

procs.push(`IF OBJECT_ID(N'dbo.xsp_ams_new_reg_dashboard_summary_getrow', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_dashboard_summary_getrow;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_dashboard_summary_getrow
(
      @p_id_brand varchar(50) = NULL
    , @p_id_cabang varchar(50) = NULL
    , @p_actor_nik varchar(50) = NULL
    , @bitparam varchar(max) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @today date = CAST(GETDATE() AS date);
        DECLARE @store_count int = 0;
        IF OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
            SELECT @store_count = COUNT(1) FROM pos_server.dbo.DT_Store WITH (NOLOCK) WHERE Status_Active = 1;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((
                       SELECT
                              CONVERT(varchar(10), @today, 23) AS as_of,
                              @store_count AS active_store_count,
                              CAST(0 AS money) AS sales_today,
                              0 AS pending_ar,
                              0 AS kas_open,
                              0 AS absen_missing
                       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                   )) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO`);

procs.push(`IF OBJECT_ID(N'dbo.xsp_ams_new_reg_absen_list_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_absen_list_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_absen_list_getrows
${getrowsParams}
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @kw varchar(200) = NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'');
        DECLARE @store varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(NULLIF(@p_id_store,''), NULLIF(@p_store_id,'')))), '');
        DECLARE @brand varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(NULLIF(@p_id_brand,''), NULLIF(@p_brand,'')))), '');
        DECLARE @from date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_from_date,''))),'') AS date);
        DECLARE @to date = TRY_CAST(NULLIF(LTRIM(RTRIM(ISNULL(@p_to_date,''))),'') AS date);
        IF @from IS NULL SET @from = DATEADD(day, -7, CAST(GETDATE() AS date));
        IF @to IS NULL SET @to = CAST(GETDATE() AS date);

        IF OBJECT_ID(N'pos_server.dbo.DT_ABSENSI', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (500)
                                  a.ID_ABSENSI AS id,
                                  a.User_NIK AS nik,
                                  a.Store_ID AS store_id,
                                  a.BRAND_ID AS brand_id,
                                  a.Jenis AS jenis,
                                  CONVERT(varchar(19), a.Waktu, 120) AS waktu,
                                  a.Status_Approve AS status
                           FROM pos_server.dbo.DT_ABSENSI AS a WITH (NOLOCK)
                           WHERE CONVERT(date, a.Waktu) BETWEEN @from AND @to
                             AND (@store IS NULL OR a.Store_ID = @store)
                             AND (@brand IS NULL OR a.BRAND_ID = @brand)
                             AND (@kw IS NULL OR a.User_NIK LIKE '%'+@kw+'%' OR a.Store_ID LIKE '%'+@kw+'%')
                           ORDER BY a.Waktu DESC
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;

        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0 FOR JSON PATH)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO`);

procs.push(`IF OBJECT_ID(N'dbo.xsp_ams_new_reg_store_list_getrows', N'P') IS NOT NULL
    DROP PROCEDURE dbo.xsp_ams_new_reg_store_list_getrows;
GO
CREATE PROCEDURE dbo.xsp_ams_new_reg_store_list_getrows
${getrowsParams}
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @kw varchar(200) = NULLIF(LTRIM(RTRIM(ISNULL(@p_keywords,''))),'');
        DECLARE @brand varchar(50) = NULLIF(LTRIM(RTRIM(COALESCE(NULLIF(@p_id_brand,''), NULLIF(@p_brand,'')))), '');
        IF OBJECT_ID(N'pos_server.dbo.DT_Store', N'U') IS NOT NULL
        BEGIN
            SET @bitparam = (
                SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                       JSON_QUERY((
                           SELECT TOP (1000)
                                  s.Store_ID AS id,
                                  s.Store_ID AS store_id,
                                  s.Store_Brand_ID AS brand_id,
                                  s.STORE_KOTA AS kota,
                                  s.STORE_PULAU AS pulau,
                                  s.Status_Active AS is_active
                           FROM pos_server.dbo.DT_Store AS s WITH (NOLOCK)
                           WHERE (@brand IS NULL OR s.Store_Brand_ID = @brand OR (@brand='CELCIUS' AND s.Store_Brand_ID IN ('CELCIUS','CELCIUS KIDS')))
                             AND (@kw IS NULL OR s.Store_ID LIKE '%'+@kw+'%' OR s.STORE_KOTA LIKE '%'+@kw+'%')
                           ORDER BY s.Store_ID
                           FOR JSON PATH
                       )) AS data
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );
            RETURN;
        END;
        SET @bitparam = (
            SELECT '2002500' AS responseCode, 'success' AS responseMessage,
                   JSON_QUERY((SELECT CAST(NULL AS int) AS _stub WHERE 1 = 0 FOR JSON PATH)) AS data
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END TRY
    BEGIN CATCH
        SET @bitparam = (SELECT '4002500' AS responseCode, ERROR_MESSAGE() AS responseMessage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
    END CATCH
END
GO`);

for (const e of uniqueEntities) {
  if (e.entity === "absen_list" || e.entity === "store_list") continue;
  procs.push(stubGetrows(e.entity));
  if (e.crud) {
    for (const op of ["getrow", "insert", "update", "delete"]) {
      procs.push(stubCrud(e.entity, op));
    }
  }
}

fs.writeFileSync(path.join(sqlDir, "02_reg_procedures.sql"), procs.join("\n"));
fs.writeFileSync(
  path.join(sqlDir, "02_reg_mega_menu.sql"),
  `-- Mega folders seeded in 01_reg_rbac_seed.sql\nPRINT '02_reg_mega_menu.sql ok';\nGO\n`
);
fs.writeFileSync(
  path.join(sqlDir, "03_reg_lookups_scope.sql"),
  `-- Lookups in 02_reg_procedures.sql\nPRINT '03_reg_lookups_scope.sql ok';\nGO\n`
);

const pageEntities = leaves
  .filter((x) => x[5] && x[5] !== "dashboard")
  .map(([code, name, , ep, , entity, crud]) => ({
    code,
    name,
    path: ep.replace("/admin/regional/", ""),
    entity,
    crud,
    exportName:
      "Reg" +
      code
        .replace(/^REG_/, "")
        .split("_")
        .map((p) => p.charAt(0) + p.slice(1).toLowerCase())
        .join("") +
      "Page",
  }));

fs.writeFileSync(
  path.join(sqlDir, "_entities.json"),
  JSON.stringify(pageEntities, null, 2)
);

// ---------- React configs + pages ----------
const dateFilters = [
  { name: "from_date", label: "From", type: "date" },
  { name: "to_date", label: "To", type: "date" },
  { name: "id_brand", label: "Brand", type: "text" },
  { name: "id_store", label: "Store", type: "text" },
];

const defaultCols = [
  { key: "id", label: "ID", size: "sm" },
  { key: "store_id", label: "Store", size: "md" },
  { key: "brand_id", label: "Brand", size: "md" },
  { key: "status", label: "Status", size: "sm", type: "badge" },
];

const specialCols = {
  absen_list: [
    { key: "nik", label: "NIK", size: "md" },
    { key: "store_id", label: "Store", size: "md" },
    { key: "brand_id", label: "Brand", size: "md" },
    { key: "jenis", label: "Jenis", size: "sm" },
    { key: "waktu", label: "Waktu", size: "lg" },
    { key: "status", label: "Status", size: "sm", type: "badge" },
  ],
  store_list: [
    { key: "store_id", label: "Store", size: "md" },
    { key: "brand_id", label: "Brand", size: "md" },
    { key: "kota", label: "Kota", size: "md" },
    { key: "pulau", label: "Pulau", size: "md" },
    { key: "is_active", label: "Active", size: "sm", type: "badge" },
  ],
};

// UI configs are owned by POS_React src/pages/admin/regional/_gen_regConfigs.js
let cfgJs = `import { createRegionalService } from "../../../services/regional/regional.service";

const col = (key, label, size = "md") => ({ key, label, size });
const badgeColumn = (key, label, size = "mb") => ({ key, label, size, type: "badge" });

const emptyForm = (fields) =>
  fields.reduce((acc, field) => {
    acc[field.name] = field.defaultValue ?? "";
    return acc;
  }, {});

const dateFilters = [
  { name: "from_date", label: "From", type: "date" },
  { name: "to_date", label: "To", type: "date" },
  { name: "id_brand", label: "Brand", type: "text" },
  { name: "id_store", label: "Store", type: "text" },
];

const cfg = ({ title, moduleCode, path, crud = false, columns, fields = [], filterDefs = dateFilters }) => {
  const initialForm = emptyForm(fields);
  return {
    title,
    moduleCode,
    idField: "id",
    pageSize: 25,
    hideStatusFilter: true,
    columns,
    fields,
    filterDefs,
    initialForm,
    service: createRegionalService(path, { crud }),
  };
};

`;

for (const p of pageEntities) {
  const cols = specialCols[p.entity] || defaultCols;
  const colsLit = JSON.stringify(cols, null, 2);
  const exportKey = p.code
    .replace(/^REG_/, "reg")
    .split("_")
    .map((s, i) => (i === 0 ? s.toLowerCase() : s.charAt(0) + s.slice(1).toLowerCase()))
    .join("")
    .replace(/^reg/, "reg");
  // better key: camelCase from entity
  const key =
    "reg" +
    p.entity
      .split("_")
      .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
      .join("");
  cfgJs += `export const ${key} = cfg({
  title: ${JSON.stringify(p.name)},
  moduleCode: ${JSON.stringify(p.code)},
  path: ${JSON.stringify(p.path)},
  crud: ${p.crud},
  columns: ${colsLit},
});
`;
  p.cfgKey = key;
}

// Do NOT overwrite React UI configs — owned by POS_React/_gen_regConfigs.js
fs.writeFileSync(
  path.join(sqlDir, "_pages_meta.json"),
  JSON.stringify(pageEntities, null, 2)
);

console.log(
  "Generated seed + procs + meta for",
  pageEntities.length,
  "pages,",
  uniqueEntities.length,
  "entities (UI configs skipped)"
);
