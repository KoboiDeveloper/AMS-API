package controllers

import (
	"GOamsAPI/database"
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
)

func writeRbcaJSON(w http.ResponseWriter, jsonResult string) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprint(w, jsonResult)
}

func pingDatabase(ctx context.Context) error {
	return database.Instance.PingContext(ctx)
}

func parseOptionalBool(value string) interface{} {
	if strings.TrimSpace(value) == "" {
		return nil
	}

	lower := strings.ToLower(strings.TrimSpace(value))
	switch lower {
	case "1", "true", "yes", "y":
		return true
	case "0", "false", "no", "n":
		return false
	default:
		return nil
	}
}

func parseRequiredBool(value string) bool {
	parsed := parseOptionalBool(value)
	if b, ok := parsed.(bool); ok {
		return b
	}
	return false
}

func CreateRbcaEmployee(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBCA employee insert: ", err.Error())
	}

	var jsonResultData string
	database.Instance.QueryContext(ctx, "xsp_ams_new_employee_insert",
		sql.Named("p_nik", r.FormValue("nik")),
		sql.Named("p_employee_name", r.FormValue("employee_name")),
		sql.Named("p_branch_id", r.FormValue("branch_id")),
		sql.Named("p_employee_type", r.FormValue("employee_type")),
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("p_job_title", r.FormValue("job_title")),
		sql.Named("p_department", r.FormValue("department")),
		sql.Named("p_email", r.FormValue("email")),
		sql.Named("p_phone", r.FormValue("phone")),
		sql.Named("p_status", r.FormValue("status")),
		sql.Named("p_is_active", parseRequiredBool(r.FormValue("is_active"))),
		sql.Named("p_created_by", r.FormValue("created_by")),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))

	writeRbcaJSON(w, jsonResultData)
}

func UpdateRbcaEmployee(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	nik := mux.Vars(r)["nik"]

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBCA employee update: ", err.Error())
	}

	var jsonResultData string
	database.Instance.QueryContext(ctx, "xsp_ams_new_employee_update",
		sql.Named("p_nik", nik),
		sql.Named("p_employee_name", r.FormValue("employee_name")),
		sql.Named("p_branch_id", r.FormValue("branch_id")),
		sql.Named("p_employee_type", r.FormValue("employee_type")),
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("p_job_title", r.FormValue("job_title")),
		sql.Named("p_department", r.FormValue("department")),
		sql.Named("p_email", r.FormValue("email")),
		sql.Named("p_phone", r.FormValue("phone")),
		sql.Named("p_status", r.FormValue("status")),
		sql.Named("p_is_active", parseRequiredBool(r.FormValue("is_active"))),
		sql.Named("p_updated_by", r.FormValue("updated_by")),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))

	writeRbcaJSON(w, jsonResultData)
}

func DeleteRbcaEmployee(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	nik := mux.Vars(r)["nik"]

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBCA employee delete: ", err.Error())
	}

	var jsonResultData string
	database.Instance.QueryContext(ctx, "xsp_ams_new_employee_delete",
		sql.Named("p_nik", nik),
		sql.Named("p_deleted_by", r.FormValue("deleted_by")),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))

	writeRbcaJSON(w, jsonResultData)
}

func GetRbcaEmployeeByNik(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	nik := mux.Vars(r)["nik"]

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBCA employee getrow: ", err.Error())
	}

	var jsonResultData string
	database.Instance.QueryContext(ctx, "xsp_ams_new_employee_getrow",
		sql.Named("p_nik", nik),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))

	writeRbcaJSON(w, jsonResultData)
}

func GetRbcaEmployees(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBCA employee getrows: ", err.Error())
	}

	var jsonResultData string
	database.Instance.QueryContext(ctx, "xsp_ams_new_employee_getrows",
		sql.Named("p_search", r.FormValue("search")),
		sql.Named("p_is_active", parseOptionalBool(r.FormValue("is_active"))),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))

	writeRbcaJSON(w, jsonResultData)
}

func RbcaAuthLogin(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBCA auth login: ", err.Error())
	}

	var jsonResultData string
	database.Instance.QueryContext(ctx, "xsp_ams_new_auth_login",
		sql.Named("p_nik", r.FormValue("nik")),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))

	writeRbcaJSON(w, jsonResultData)
}

func RbcaAuthCheckPermission(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBCA auth check permission: ", err.Error())
	}

	actionCode := r.FormValue("action_code")
	if actionCode == "" {
		actionCode = "VIEW"
	}

	var jsonResultData string
	database.Instance.QueryContext(ctx, "xsp_ams_new_auth_check_permission",
		sql.Named("p_nik", r.FormValue("nik")),
		sql.Named("p_page_path", r.FormValue("page_path")),
		sql.Named("p_action_code", actionCode),
		sql.Named("p_branch_id", r.FormValue("branch_id")),
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))

	writeRbcaJSON(w, jsonResultData)
}

func RbcaAuthMenu(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading RBCA auth menu: ", err.Error())
	}

	var jsonResultData string
	database.Instance.QueryContext(ctx, "xsp_ams_new_v_user_menu_getrows",
		sql.Named("p_nik", r.FormValue("nik")),
		sql.Named("p_app_id", r.FormValue("app_id")),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))

	writeRbcaJSON(w, jsonResultData)
}
