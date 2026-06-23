package controllers

import (
	"database/sql"
	"net/http"

	"github.com/gorilla/mux"
)

// --- Branch ---

func CreateRbacBranch(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_branch_insert",
		sql.Named("p_branch_id", rbcaParam(r, "branch_id")),
		sql.Named("p_branch_name", rbcaParam(r, "branch_name")),
		sql.Named("p_branch_type", rbcaParam(r, "branch_type")),
		sql.Named("p_parent_branch_id", parseOptionalString(rbcaParam(r, "parent_branch_id"))),
		sql.Named("p_created_by", rbcaParam(r, "created_by")),
	)
}

func UpdateRbacBranch(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_branch_update",
		sql.Named("p_branch_id", mux.Vars(r)["branch_id"]),
		sql.Named("p_branch_name", rbcaParam(r, "branch_name")),
		sql.Named("p_branch_type", rbcaParam(r, "branch_type")),
		sql.Named("p_parent_branch_id", parseOptionalString(rbcaParam(r, "parent_branch_id"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func DeleteRbacBranch(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_branch_delete",
		sql.Named("p_branch_id", mux.Vars(r)["branch_id"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func GetRbacBranches(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_branch_getrows",
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
	)
}

func GetRbacBranchByID(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_branch_getrow",
		sql.Named("p_branch_id", mux.Vars(r)["branch_id"]),
	)
}

// --- Store ---

func CreateRbacStore(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_store_insert",
		sql.Named("p_store_id", rbcaParam(r, "store_id")),
		sql.Named("p_store_name", rbcaParam(r, "store_name")),
		sql.Named("p_branch_id", rbcaParam(r, "branch_id")),
		sql.Named("p_store_city", rbcaParam(r, "store_city")),
		sql.Named("p_store_province", rbcaParam(r, "store_province")),
		sql.Named("p_store_island", rbcaParam(r, "store_island")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")),
	)
}

func UpdateRbacStore(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_store_update",
		sql.Named("p_store_id", mux.Vars(r)["store_id"]),
		sql.Named("p_store_name", rbcaParam(r, "store_name")),
		sql.Named("p_branch_id", rbcaParam(r, "branch_id")),
		sql.Named("p_store_city", rbcaParam(r, "store_city")),
		sql.Named("p_store_province", rbcaParam(r, "store_province")),
		sql.Named("p_store_island", rbcaParam(r, "store_island")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func DeleteRbacStore(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_store_delete",
		sql.Named("p_store_id", mux.Vars(r)["store_id"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func GetRbacStores(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_store_getrows",
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
	)
}

func GetRbacStoreByID(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_store_getrow",
		sql.Named("p_store_id", mux.Vars(r)["store_id"]),
	)
}

// --- Employee ---

func CreateRbacEmployee(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_employee_insert",
		sql.Named("p_nik", rbcaParam(r, "nik")),
		sql.Named("p_employee_name", rbcaParam(r, "employee_name")),
		sql.Named("p_employee_type", rbcaParam(r, "employee_type")),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_job_title", rbcaParam(r, "job_title")),
		sql.Named("p_email", rbcaParam(r, "email")),
		sql.Named("p_phone", rbcaParam(r, "phone")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")),
	)
}

func UpdateRbacEmployee(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_employee_update",
		sql.Named("p_nik", mux.Vars(r)["nik"]),
		sql.Named("p_employee_name", rbcaParam(r, "employee_name")),
		sql.Named("p_employee_type", rbcaParam(r, "employee_type")),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_job_title", rbcaParam(r, "job_title")),
		sql.Named("p_email", rbcaParam(r, "email")),
		sql.Named("p_phone", rbcaParam(r, "phone")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func DeleteRbacEmployee(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_employee_delete",
		sql.Named("p_nik", mux.Vars(r)["nik"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func GetRbacEmployees(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_employee_getrows",
		sql.Named("p_employee_type", parseOptionalString(rbcaParam(r, "employee_type"))),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
	)
}

func GetRbacEmployeeByNik(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_employee_getrow",
		sql.Named("p_nik", mux.Vars(r)["nik"]),
	)
}

// --- Role ---

func CreateRbacRole(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_role_insert",
		sql.Named("p_role_code", rbcaParam(r, "role_code")),
		sql.Named("p_role_name", rbcaParam(r, "role_name")),
		sql.Named("p_scope_level", rbcaParam(r, "scope_level")),
		sql.Named("p_description", rbcaParam(r, "description")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")),
	)
}

func UpdateRbacRole(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_role_update",
		sql.Named("p_role_code", mux.Vars(r)["role_code"]),
		sql.Named("p_role_name", rbcaParam(r, "role_name")),
		sql.Named("p_scope_level", rbcaParam(r, "scope_level")),
		sql.Named("p_description", rbcaParam(r, "description")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func DeleteRbacRole(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_role_delete",
		sql.Named("p_role_code", mux.Vars(r)["role_code"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func GetRbacRoles(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_role_getrows",
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
	)
}

// --- Module ---

func CreateRbacModule(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_module_insert",
		sql.Named("p_module_code", rbcaParam(r, "module_code")),
		sql.Named("p_module_name", rbcaParam(r, "module_name")),
		sql.Named("p_parent_module_code", parseOptionalString(rbcaParam(r, "parent_module_code"))),
		sql.Named("p_endpoint_path", rbcaParam(r, "endpoint_path")),
		sql.Named("p_sort_no", rbcaParam(r, "sort_no")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")),
	)
}

func UpdateRbacModule(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_module_update",
		sql.Named("p_module_code", mux.Vars(r)["module_code"]),
		sql.Named("p_module_name", rbcaParam(r, "module_name")),
		sql.Named("p_parent_module_code", parseOptionalString(rbcaParam(r, "parent_module_code"))),
		sql.Named("p_endpoint_path", rbcaParam(r, "endpoint_path")),
		sql.Named("p_sort_no", rbcaParam(r, "sort_no")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func DeleteRbacModule(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_module_delete",
		sql.Named("p_module_code", mux.Vars(r)["module_code"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func GetRbacModules(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_module_getrows",
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
	)
}

// --- Permission ---

func CreateRbacPermission(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_permission_insert",
		sql.Named("p_permission_code", rbcaParam(r, "permission_code")),
		sql.Named("p_permission_name", rbcaParam(r, "permission_name")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")),
	)
}

func UpdateRbacPermission(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_permission_update",
		sql.Named("p_permission_code", mux.Vars(r)["permission_code"]),
		sql.Named("p_permission_name", rbcaParam(r, "permission_name")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func DeleteRbacPermission(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_permission_delete",
		sql.Named("p_permission_code", mux.Vars(r)["permission_code"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func GetRbacPermissions(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_permission_getrows",
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
	)
}

// --- Role Permission ---

func SaveRbacRolePermission(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_role_permission_save",
		sql.Named("p_role_code", rbcaParam(r, "role_code")),
		sql.Named("p_module_code", rbcaParam(r, "module_code")),
		sql.Named("p_permission_code", rbcaParam(r, "permission_code")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_created_by", rbcaParam(r, "created_by")),
	)
}

func DeleteRbacRolePermission(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_role_permission_delete",
		sql.Named("p_role_code", rbcaParam(r, "role_code")),
		sql.Named("p_module_code", rbcaParam(r, "module_code")),
		sql.Named("p_permission_code", rbcaParam(r, "permission_code")),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func GetRbacRolePermissions(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_role_permission_getrows",
		sql.Named("p_role_code", parseOptionalString(rbcaParam(r, "role_code"))),
		sql.Named("p_module_code", parseOptionalString(rbcaParam(r, "module_code"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
	)
}

// --- User Role ---

func CreateRbacUserRole(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_user_role_insert",
		sql.Named("p_nik", rbcaParam(r, "nik")),
		sql.Named("p_role_code", rbcaParam(r, "role_code")),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_start_date", parseOptionalString(rbcaParam(r, "start_date"))),
		sql.Named("p_end_date", parseOptionalString(rbcaParam(r, "end_date"))),
		sql.Named("p_created_by", rbcaParam(r, "created_by")),
	)
}

func UpdateRbacUserRole(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_user_role_update",
		sql.Named("p_user_role_id", mux.Vars(r)["user_role_id"]),
		sql.Named("p_role_code", rbcaParam(r, "role_code")),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_start_date", parseOptionalString(rbcaParam(r, "start_date"))),
		sql.Named("p_end_date", parseOptionalString(rbcaParam(r, "end_date"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func DeleteRbacUserRole(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_user_role_delete",
		sql.Named("p_user_role_id", mux.Vars(r)["user_role_id"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func GetRbacUserRoles(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_user_role_getrows",
		sql.Named("p_nik", parseOptionalString(rbcaParam(r, "nik"))),
		sql.Named("p_role_code", parseOptionalString(rbcaParam(r, "role_code"))),
		sql.Named("p_is_effective", parseOptionalBool(rbcaParam(r, "is_effective"))),
	)
}

// --- Area Store ---

func CreateRbacAreaStore(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_area_store_insert",
		sql.Named("p_area_manager_nik", rbcaParam(r, "area_manager_nik")),
		sql.Named("p_store_id", rbcaParam(r, "store_id")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")),
	)
}

func DeleteRbacAreaStore(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_area_store_delete",
		sql.Named("p_area_manager_nik", rbcaParam(r, "area_manager_nik")),
		sql.Named("p_store_id", rbcaParam(r, "store_id")),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")),
	)
}

func GetRbacAreaStores(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_area_store_getrows",
		sql.Named("p_area_manager_nik", parseOptionalString(rbcaParam(r, "area_manager_nik"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
	)
}

// --- Access, Menu, Scope ---

func RbacAccessCheck(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_access_check",
		sql.Named("p_nik", rbcaParam(r, "nik")),
		sql.Named("p_module_code", rbcaParam(r, "module_code")),
		sql.Named("p_permission_code", rbcaParam(r, "permission_code")),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
	)
}

func GetRbacUserMenu(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_user_menu_getrows",
		sql.Named("p_nik", mux.Vars(r)["nik"]),
	)
}

func GetRbacUserStoreScope(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_user_store_scope_getrows",
		sql.Named("p_nik", mux.Vars(r)["nik"]),
	)
}

func GetRbacEffectiveAccess(w http.ResponseWriter, r *http.Request) {
	execRbcaSP(w, r, "xsp_ams_new_rbac_effective_access_getrows",
		sql.Named("p_nik", parseOptionalString(rbcaParam(r, "nik"))),
		sql.Named("p_role_code", parseOptionalString(rbcaParam(r, "role_code"))),
		sql.Named("p_module_code", parseOptionalString(rbcaParam(r, "module_code"))),
	)
}
