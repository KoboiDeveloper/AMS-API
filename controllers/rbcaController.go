package controllers

import (
	"GOamsAPI/database"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v4"
	"github.com/gorilla/mux"
)

func httpStatusFromResponseCode(jsonResult string) int {
	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		return http.StatusOK
	}

	rawCode, ok := result["responseCode"]
	if !ok {
		return http.StatusOK
	}

	code := strings.TrimSpace(fmt.Sprint(rawCode))
	switch {
	case strings.HasPrefix(code, "200"):
		return http.StatusOK
	case strings.HasPrefix(code, "401"):
		return http.StatusUnauthorized
	case strings.HasPrefix(code, "403"):
		return http.StatusForbidden
	case strings.HasPrefix(code, "404"):
		return http.StatusNotFound
	case strings.HasPrefix(code, "400"):
		return http.StatusBadRequest
	case strings.HasPrefix(code, "500"):
		return http.StatusInternalServerError
	default:
		return http.StatusOK
	}
}

func marshalRbcaJSON(result map[string]interface{}) string {
	var buf strings.Builder
	buf.WriteString("{")

	first := true
	writeField := func(key string, value interface{}) {
		if value == nil {
			return
		}
		if !first {
			buf.WriteString(",")
		}
		keyJSON, _ := json.Marshal(key)
		valueJSON, _ := json.Marshal(value)
		buf.Write(keyJSON)
		buf.WriteString(":")
		buf.Write(valueJSON)
		first = false
	}

	if rawCode, ok := result["responseCode"]; ok {
		writeField("responseCode", rawCode)
	}
	if rawMessage, ok := result["responseMessage"]; ok {
		writeField("responseMessage", rawMessage)
	}

	for key, value := range result {
		if key == "responseCode" || key == "responseMessage" {
			continue
		}
		writeField(key, value)
	}

	buf.WriteString("}")
	return buf.String()
}

func normalizeRbcaJSON(jsonResult string) string {
	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		return jsonResult
	}
	return marshalRbcaJSON(result)
}

func writeRbcaJSON(w http.ResponseWriter, jsonResult string) {
	w.Header().Set("Content-Type", "application/json")
	normalized := normalizeRbcaJSON(jsonResult)
	w.WriteHeader(httpStatusFromResponseCode(normalized))
	fmt.Fprint(w, normalized)
}

func rbcaErrorJSON(code, message string) string {
	return marshalRbcaJSON(map[string]interface{}{
		"responseCode":    code,
		"responseMessage": message,
	})
}

type rbcaClaims struct {
	AuthUserID int64  `json:"authUserId,omitempty"`
	Username   string `json:"username"`
	Nik        string `json:"nik,omitempty"`
	jwt.RegisteredClaims
}

func rbcaJwtKey() []byte {
	return []byte(os.Getenv("JWT_KEY"))
}

func stringFromMap(data map[string]interface{}, keys ...string) string {
	for _, key := range keys {
		if raw, ok := data[key]; ok {
			value := strings.TrimSpace(fmt.Sprint(raw))
			if value != "" && value != "<nil>" {
				return value
			}
		}
	}
	return ""
}

func extractRbcaNik(result map[string]interface{}) string {
	if data, ok := result["data"].(map[string]interface{}); ok {
		if nik := stringFromMap(data, "nik", "NIK", "p_nik"); nik != "" {
			return nik
		}
	}
	return stringFromMap(result, "nik", "NIK", "p_nik")
}

func extractRbcaLoginIdentity(result map[string]interface{}, fallbackUsername string) (username, nik string, authUserID int64) {
	username = fallbackUsername
	nik = extractRbcaNik(result)

	if data, ok := result["data"].(map[string]interface{}); ok {
		if value := stringFromMap(data, "username"); value != "" {
			username = value
		}
		if rawID, ok := data["authUserId"]; ok {
			switch v := rawID.(type) {
			case float64:
				authUserID = int64(v)
			case int64:
				authUserID = v
			case int:
				authUserID = int64(v)
			case json.Number:
				if parsed, err := v.Int64(); err == nil {
					authUserID = parsed
				}
			}
		}
	}

	return username, nik, authUserID
}

func attachRbcaLoginToken(jsonResult, username string) (string, error) {
	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		return jsonResult, nil
	}

	code := strings.TrimSpace(fmt.Sprint(result["responseCode"]))
	if code != "2002500" {
		return jsonResult, nil
	}

	identityUsername, nik, authUserID := extractRbcaLoginIdentity(result, username)
	expirationTime := time.Now().Add(14 * 24 * time.Hour)
	claims := &rbcaClaims{
		AuthUserID: authUserID,
		Username:   identityUsername,
		Nik:        nik,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(rbcaJwtKey())
	if err != nil {
		return "", err
	}

	if data, ok := result["data"].(map[string]interface{}); ok {
		data["token"] = tokenString
		result["data"] = data
	}

	return marshalRbcaJSON(result), nil
}

func pingDatabase(ctx context.Context) error {
	return database.RbcaInstance.PingContext(ctx)
}

func parseOptionalString(value string) interface{} {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	return strings.TrimSpace(value)
}

func clientIPAddress(r *http.Request) string {
	if forwarded := strings.TrimSpace(r.Header.Get("X-Forwarded-For")); forwarded != "" {
		if idx := strings.Index(forwarded, ","); idx >= 0 {
			return strings.TrimSpace(forwarded[:idx])
		}
		return forwarded
	}
	if realIP := strings.TrimSpace(r.Header.Get("X-Real-IP")); realIP != "" {
		return realIP
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
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
	database.RbcaInstance.QueryContext(ctx, "xsp_ams_new_employee_insert",
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
	database.RbcaInstance.QueryContext(ctx, "xsp_ams_new_employee_update",
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
	database.RbcaInstance.QueryContext(ctx, "xsp_ams_new_employee_delete",
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
	database.RbcaInstance.QueryContext(ctx, "xsp_ams_new_employee_getrow",
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
	database.RbcaInstance.QueryContext(ctx, "xsp_ams_new_employee_getrows",
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

	username := strings.TrimSpace(r.FormValue("username"))
	password := strings.TrimSpace(r.FormValue("password"))
	if username == "" || password == "" {
		writeRbcaJSON(w, rbcaErrorJSON("4000001", "username and password are required"))
		return
	}

	ipAddress := strings.TrimSpace(r.FormValue("ip_address"))
	if ipAddress == "" {
		ipAddress = clientIPAddress(r)
	}

	userAgent := strings.TrimSpace(r.FormValue("user_agent"))
	if userAgent == "" {
		userAgent = r.UserAgent()
	}

	var jsonResultData string
	database.RbcaInstance.QueryContext(ctx, "xsp_ams_new_auth_login",
		sql.Named("p_username", username),
		sql.Named("p_password", password),
		sql.Named("p_ip_address", parseOptionalString(ipAddress)),
		sql.Named("p_user_agent", parseOptionalString(userAgent)),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSON(w, rbcaErrorJSON("5000002", "empty response from database"))
		return
	}

	jsonWithToken, err := attachRbcaLoginToken(jsonResultData, username)
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "failed to generate token"))
		return
	}

	writeRbcaJSON(w, jsonWithToken)
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
	database.RbcaInstance.QueryContext(ctx, "xsp_ams_new_auth_check_permission",
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
	database.RbcaInstance.QueryContext(ctx, "xsp_ams_new_v_user_menu_getrows",
		sql.Named("p_nik", r.FormValue("nik")),
		sql.Named("p_app_id", r.FormValue("app_id")),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))

	writeRbcaJSON(w, jsonResultData)
}
