package controllers

import (
	"GOamsAPI/database"
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v4"
)

func extractResponseCode(jsonResult string) string {
	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(result["responseCode"]))
}

func rbcaSuccessHTTPStatus(method, spName string) int {
	if method == http.MethodPost && strings.HasSuffix(spName, "_insert") {
		return http.StatusCreated
	}
	return http.StatusOK
}

func httpStatusFromResponseCode(jsonResult string) int {
	return httpStatusFromRbcaResponse(jsonResult, "", "")
}

func httpStatusFromRbcaResponse(jsonResult, method, spName string) int {
	code := extractResponseCode(jsonResult)
	if code == "" {
		return http.StatusOK
	}

	switch code {
	case "2002500":
		if method != "" && spName != "" {
			return rbcaSuccessHTTPStatus(method, spName)
		}
		return http.StatusOK
	case "4002500", "4000001":
		return http.StatusBadRequest
	case "4012500":
		return http.StatusUnauthorized
	case "4032500":
		return http.StatusForbidden
	case "4042500":
		return http.StatusNotFound
	case "4232500":
		return http.StatusLocked
	case "5000001", "5000002", "5000003", "5000004":
		return http.StatusInternalServerError
	}

	switch {
	case strings.HasPrefix(code, "200"):
		if method != "" && spName != "" {
			return rbcaSuccessHTTPStatus(method, spName)
		}
		return http.StatusOK
	case strings.HasPrefix(code, "401"):
		return http.StatusUnauthorized
	case strings.HasPrefix(code, "403"):
		return http.StatusForbidden
	case strings.HasPrefix(code, "404"):
		return http.StatusNotFound
	case strings.HasPrefix(code, "423"):
		return http.StatusLocked
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
	writeRbcaJSONResponse(w, jsonResult, "", "")
}

func writeRbcaJSONResponse(w http.ResponseWriter, jsonResult, method, spName string) {
	w.Header().Set("Content-Type", "application/json")
	normalized := normalizeRbcaJSON(jsonResult)
	w.WriteHeader(httpStatusFromRbcaResponse(normalized, method, spName))
	fmt.Fprint(w, normalized)
}

func validateRbcaSPResponse(jsonResult string) string {
	trimmed := strings.TrimSpace(jsonResult)
	if trimmed == "" {
		return rbcaErrorJSON("5000002", "empty response from database")
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(trimmed), &result); err != nil {
		return rbcaErrorJSON("5000003", "invalid JSON response from database")
	}

	if _, ok := result["responseCode"]; !ok {
		return rbcaErrorJSON("5000004", "missing responseCode in database response")
	}

	return trimmed
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

func rbcaNikFromJWT(r *http.Request) string {
	authHeader := strings.TrimSpace(r.Header.Get("Authorization"))
	tokenString := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
	if tokenString == "" || tokenString == authHeader {
		tokenString = strings.TrimSpace(r.URL.Query().Get("access_token"))
	}
	if tokenString == "" {
		tokenString = strings.TrimSpace(r.URL.Query().Get("token"))
	}
	if tokenString == "" {
		return ""
	}

	token, err := jwt.ParseWithClaims(tokenString, &rbcaClaims{}, func(token *jwt.Token) (interface{}, error) {
		return rbcaJwtKey(), nil
	})
	if err != nil || !token.Valid {
		return ""
	}

	if claims, ok := token.Claims.(*rbcaClaims); ok {
		return strings.TrimSpace(claims.Nik)
	}
	return ""
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

func parseRbcaFilterString(value string) string {
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

type rbcaBodyKey struct{}

func RbcaBodyParser(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Body != nil && r.ContentLength != 0 &&
			strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "application/json") {
			bodyBytes, err := io.ReadAll(r.Body)
			if err == nil {
				r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
				parsed := map[string]interface{}{}
				if json.Unmarshal(bodyBytes, &parsed) == nil {
					r = r.WithContext(context.WithValue(r.Context(), rbcaBodyKey{}, parsed))
				}
			}
		}
		next.ServeHTTP(w, r)
	})
}

func rbcaBodyValues(r *http.Request) map[string]interface{} {
	if cached, ok := r.Context().Value(rbcaBodyKey{}).(map[string]interface{}); ok {
		return cached
	}
	return nil
}

func rbcaParam(r *http.Request, key string) string {
	if val := strings.TrimSpace(r.FormValue(key)); val != "" {
		return val
	}

	if r.Method == http.MethodGet || r.Method == http.MethodDelete {
		return ""
	}

	if body := rbcaBodyValues(r); body != nil {
		raw, ok := body[key]
		if !ok || raw == nil {
			return ""
		}
		return strings.TrimSpace(fmt.Sprint(raw))
	}

	return ""
}

func runRbcaSPQuery(ctx context.Context, spName string, namedArgs ...interface{}) string {
	var jsonResultData string
	args := append(namedArgs, sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))
	rows, err := database.RbcaInstance.QueryContext(ctx, spName, args...)
	if err != nil {
		log.Fatal("Error executing RBAC SP ", spName, ": ", err.Error())
	}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
		}
	}
	return jsonResultData
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
