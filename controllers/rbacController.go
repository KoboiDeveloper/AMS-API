package controllers

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
)

// --- Branch ---

func CreateRbacBranch(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC branch insert: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_branch_insert",
		sql.Named("p_branch_id", rbcaParam(r, "branch_id")),
		sql.Named("p_branch_name", rbcaParam(r, "branch_name")),
		sql.Named("p_branch_type", rbcaParam(r, "branch_type")),
		sql.Named("p_parent_branch_id", parseOptionalString(rbcaParam(r, "parent_branch_id"))),
		sql.Named("p_created_by", rbcaParam(r, "created_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_branch_insert")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_branch_insert")
}

func UpdateRbacBranch(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC branch update: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_branch_update",
		sql.Named("p_branch_id", mux.Vars(r)["branch_id"]),
		sql.Named("p_branch_name", rbcaParam(r, "branch_name")),
		sql.Named("p_branch_type", rbcaParam(r, "branch_type")),
		sql.Named("p_parent_branch_id", parseOptionalString(rbcaParam(r, "parent_branch_id"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_branch_update")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_branch_update")
}

func DeleteRbacBranch(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC branch delete: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_branch_delete",
		sql.Named("p_branch_id", mux.Vars(r)["branch_id"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_branch_delete")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_branch_delete")
}

func GetRbacBranches(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC branch getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_branch_getrows",
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalString(rbcaParam(r, "is_active"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_branch_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_branch_getrows")
}

func GetRbacBranchByID(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC branch getrow: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_branch_getrow",
		sql.Named("p_branch_id", mux.Vars(r)["branch_id"]))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_branch_getrow")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_branch_getrow")
}

// --- Store ---

func CreateRbacStore(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC store insert: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_store_insert",
		sql.Named("p_store_id", rbcaParam(r, "store_id")),
		sql.Named("p_store_name", rbcaParam(r, "store_name")),
		sql.Named("p_branch_id", rbcaParam(r, "branch_id")),
		sql.Named("p_store_city", rbcaParam(r, "store_city")),
		sql.Named("p_store_province", rbcaParam(r, "store_province")),
		sql.Named("p_store_island", rbcaParam(r, "store_island")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_store_insert")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_store_insert")
}

func UpdateRbacStore(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC store update: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_store_update",
		sql.Named("p_store_id", mux.Vars(r)["store_id"]),
		sql.Named("p_store_name", rbcaParam(r, "store_name")),
		sql.Named("p_branch_id", rbcaParam(r, "branch_id")),
		sql.Named("p_store_city", rbcaParam(r, "store_city")),
		sql.Named("p_store_province", rbcaParam(r, "store_province")),
		sql.Named("p_store_island", rbcaParam(r, "store_island")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_store_update")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_store_update")
}

func DeleteRbacStore(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC store delete: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_store_delete",
		sql.Named("p_store_id", mux.Vars(r)["store_id"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_store_delete")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_store_delete")
}

func GetRbacStores(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC store getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_store_getrows",
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalString(rbcaParam(r, "is_active"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_store_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_store_getrows")
}

func GetRbacStoreByID(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC store getrow: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_store_getrow",
		sql.Named("p_store_id", mux.Vars(r)["store_id"]))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_store_getrow")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_store_getrow")
}

// --- Employee ---

func CreateRbacEmployee(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC employee insert: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_employee_insert",
		sql.Named("p_nik", rbcaParam(r, "nik")),
		sql.Named("p_employee_name", rbcaParam(r, "employee_name")),
		sql.Named("p_employee_type", rbcaParam(r, "employee_type")),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_job_title", rbcaParam(r, "job_title")),
		sql.Named("p_email", rbcaParam(r, "email")),
		sql.Named("p_phone", rbcaParam(r, "phone")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_employee_insert")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_employee_insert")
}

func UpdateRbacEmployee(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC employee update: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_employee_update",
		sql.Named("p_nik", mux.Vars(r)["nik"]),
		sql.Named("p_employee_name", rbcaParam(r, "employee_name")),
		sql.Named("p_employee_type", rbcaParam(r, "employee_type")),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_job_title", rbcaParam(r, "job_title")),
		sql.Named("p_email", rbcaParam(r, "email")),
		sql.Named("p_phone", rbcaParam(r, "phone")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_employee_update")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_employee_update")
}

func DeleteRbacEmployee(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC employee delete: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_employee_delete",
		sql.Named("p_nik", mux.Vars(r)["nik"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_employee_delete")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_employee_delete")
}

func GetRbacEmployees(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC employee getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_employee_getrows",
		sql.Named("p_employee_type", parseOptionalString(rbcaParam(r, "employee_type"))),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalString(rbcaParam(r, "is_active"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_employee_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_employee_getrows")
}

func GetRbacEmployeeByNik(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC employee getrow: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_employee_getrow",
		sql.Named("p_nik", mux.Vars(r)["nik"]))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_employee_getrow")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_employee_getrow")
}

// --- Role ---

func CreateRbacRole(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC role insert: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_role_insert",
		sql.Named("p_role_code", rbcaParam(r, "role_code")),
		sql.Named("p_role_name", rbcaParam(r, "role_name")),
		sql.Named("p_scope_level", rbcaParam(r, "scope_level")),
		sql.Named("p_description", rbcaParam(r, "description")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_role_insert")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_role_insert")
}

func UpdateRbacRole(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC role update: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_role_update",
		sql.Named("p_role_code", mux.Vars(r)["role_code"]),
		sql.Named("p_role_name", rbcaParam(r, "role_name")),
		sql.Named("p_scope_level", rbcaParam(r, "scope_level")),
		sql.Named("p_description", rbcaParam(r, "description")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_role_update")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_role_update")
}

func DeleteRbacRole(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC role delete: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_role_delete",
		sql.Named("p_role_code", mux.Vars(r)["role_code"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_role_delete")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_role_delete")
}

func GetRbacRoles(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC role getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_role_getrows",
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalString(rbcaParam(r, "is_active"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_role_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_role_getrows")
}

// --- Module ---

func CreateRbacModule(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC module insert: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_module_insert",
		sql.Named("p_module_code", rbcaParam(r, "module_code")),
		sql.Named("p_module_name", rbcaParam(r, "module_name")),
		sql.Named("p_parent_module_code", parseOptionalString(rbcaParam(r, "parent_module_code"))),
		sql.Named("p_endpoint_path", rbcaParam(r, "endpoint_path")),
		sql.Named("p_sort_no", rbcaParam(r, "sort_no")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_module_insert")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_module_insert")
}

func UpdateRbacModule(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC module update: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_module_update",
		sql.Named("p_module_code", mux.Vars(r)["module_code"]),
		sql.Named("p_module_name", rbcaParam(r, "module_name")),
		sql.Named("p_parent_module_code", parseOptionalString(rbcaParam(r, "parent_module_code"))),
		sql.Named("p_endpoint_path", rbcaParam(r, "endpoint_path")),
		sql.Named("p_sort_no", rbcaParam(r, "sort_no")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_module_update")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_module_update")
}

func DeleteRbacModule(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC module delete: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_module_delete",
		sql.Named("p_module_code", mux.Vars(r)["module_code"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_module_delete")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_module_delete")
}

func GetRbacModules(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC module getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_module_getrows",
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalString(rbcaParam(r, "is_active"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_module_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_module_getrows")
}

// --- Permission ---

func CreateRbacPermission(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC permission insert: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_permission_insert",
		sql.Named("p_permission_code", rbcaParam(r, "permission_code")),
		sql.Named("p_permission_name", rbcaParam(r, "permission_name")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_permission_insert")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_permission_insert")
}

func UpdateRbacPermission(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC permission update: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_permission_update",
		sql.Named("p_permission_code", mux.Vars(r)["permission_code"]),
		sql.Named("p_permission_name", rbcaParam(r, "permission_name")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_permission_update")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_permission_update")
}

func DeleteRbacPermission(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC permission delete: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_permission_delete",
		sql.Named("p_permission_code", mux.Vars(r)["permission_code"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_permission_delete")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_permission_delete")
}

func GetRbacPermissions(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC permission getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_permission_getrows",
		sql.Named("p_search", parseOptionalString(rbcaParam(r, "search"))),
		sql.Named("p_is_active", parseOptionalString(rbcaParam(r, "is_active"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_permission_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_permission_getrows")
}

// --- Role Permission ---

func SaveRbacRolePermission(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC role permission save: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_role_permission_save",
		sql.Named("p_role_code", rbcaParam(r, "role_code")),
		sql.Named("p_module_code", rbcaParam(r, "module_code")),
		sql.Named("p_permission_code", rbcaParam(r, "permission_code")),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_created_by", rbcaParam(r, "created_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_role_permission_save")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_role_permission_save")
}

func DeleteRbacRolePermission(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC role permission delete: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_role_permission_delete",
		sql.Named("p_role_code", rbcaParam(r, "role_code")),
		sql.Named("p_module_code", rbcaParam(r, "module_code")),
		sql.Named("p_permission_code", rbcaParam(r, "permission_code")),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_role_permission_delete")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_role_permission_delete")
}

func GetRbacRolePermissions(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC role permission getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_role_permission_getrows",
		sql.Named("p_role_code", parseOptionalString(rbcaParam(r, "role_code"))),
		sql.Named("p_module_code", parseOptionalString(rbcaParam(r, "module_code"))),
		sql.Named("p_is_active", parseOptionalString(rbcaParam(r, "is_active"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_role_permission_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_role_permission_getrows")
}

// --- User Role ---

func CreateRbacUserRole(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC user role insert: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_user_role_insert",
		sql.Named("p_nik", rbcaParam(r, "nik")),
		sql.Named("p_role_code", rbcaParam(r, "role_code")),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_start_date", parseOptionalString(rbcaParam(r, "start_date"))),
		sql.Named("p_end_date", parseOptionalString(rbcaParam(r, "end_date"))),
		sql.Named("p_created_by", rbcaParam(r, "created_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_user_role_insert")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_user_role_insert")
}

func UpdateRbacUserRole(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC user role update: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_user_role_update",
		sql.Named("p_user_role_id", mux.Vars(r)["user_role_id"]),
		sql.Named("p_role_code", rbcaParam(r, "role_code")),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_start_date", parseOptionalString(rbcaParam(r, "start_date"))),
		sql.Named("p_end_date", parseOptionalString(rbcaParam(r, "end_date"))),
		sql.Named("p_is_active", parseOptionalBool(rbcaParam(r, "is_active"))),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_user_role_update")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_user_role_update")
}

func DeleteRbacUserRole(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC user role delete: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_user_role_delete",
		sql.Named("p_user_role_id", mux.Vars(r)["user_role_id"]),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_user_role_delete")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_user_role_delete")
}

func GetRbacUserRoles(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC user role getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_user_role_getrows",
		sql.Named("p_nik", parseOptionalString(rbcaParam(r, "nik"))),
		sql.Named("p_role_code", parseOptionalString(rbcaParam(r, "role_code"))),
		sql.Named("p_is_effective", parseOptionalString(rbcaParam(r, "is_effective"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_user_role_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_user_role_getrows")
}

// --- Area Store ---

func CreateRbacAreaStore(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC area store insert: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_area_store_insert",
		sql.Named("p_area_manager_nik", rbcaParam(r, "area_manager_nik")),
		sql.Named("p_store_id", rbcaParam(r, "store_id")),
		sql.Named("p_created_by", rbcaParam(r, "created_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_area_store_insert")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_area_store_insert")
}

func DeleteRbacAreaStore(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC area store delete: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_area_store_delete",
		sql.Named("p_area_manager_nik", rbcaParam(r, "area_manager_nik")),
		sql.Named("p_store_id", rbcaParam(r, "store_id")),
		sql.Named("p_updated_by", rbcaParam(r, "updated_by")))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_area_store_delete")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_area_store_delete")
}

func GetRbacAreaStores(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC area store getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_area_store_getrows",
		sql.Named("p_area_manager_nik", parseOptionalString(rbcaParam(r, "area_manager_nik"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		sql.Named("p_is_active", parseOptionalString(rbcaParam(r, "is_active"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_area_store_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_area_store_getrows")
}

// --- Access, Menu, Scope ---

func RbacAccessCheck(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC access check: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_access_check",
		sql.Named("p_nik", rbcaParam(r, "nik")),
		sql.Named("p_module_code", rbcaParam(r, "module_code")),
		sql.Named("p_permission_code", rbcaParam(r, "permission_code")),
		sql.Named("p_branch_id", parseOptionalString(rbcaParam(r, "branch_id"))),
		sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_access_check")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_access_check")
}

func GetRbacUserMenu(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC user menu getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_user_menu_getrows",
		sql.Named("p_nik", mux.Vars(r)["nik"]))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_user_menu_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_user_menu_getrows")
}

func GetRbacUserStoreScope(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC user store scope getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_user_store_scope_getrows",
		sql.Named("p_nik", mux.Vars(r)["nik"]))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_user_store_scope_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_user_store_scope_getrows")
}

func GetRbacEffectiveAccess(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBAC effective access getrows: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_ams_new_rbac_effective_access_getrows",
		sql.Named("p_nik", parseOptionalString(rbcaParam(r, "nik"))),
		sql.Named("p_role_code", parseOptionalString(rbcaParam(r, "role_code"))),
		sql.Named("p_module_code", parseOptionalString(rbcaParam(r, "module_code"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_rbac_effective_access_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_rbac_effective_access_getrows")
}
