package controllers

import (
	"GOamsAPI/database"
	"GOamsAPI/middleware"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/golang-jwt/jwt/v4"
)

var essRedisClient *redis.Client

// InitESS menyimpan redis client untuk rate limit login ESS.
func InitESS(redisClient *redis.Client) {
	essRedisClient = redisClient
}

// Nama stored procedure ESS (pola: xsp_api_ess_<modul>_<aksi>)
const (
	SPESSLogin                 = "xsp_api_ess_login"
	SPESSLoginSessionInsert       = "xsp_api_ess_login_session_insert"
	SPESSLoginSessionGetrows      = "xsp_api_ess_login_session_getrows"
	SPESSLoginSessionRevokeOthers = "xsp_api_ess_login_session_revoke_others"
	SPESSResetPassword            = "xsp_api_ess_reset_password"
	SPESSResetPasswordByEmail  = "xsp_api_ess_reset_password_by_email"
	SPESSChangePassword        = "xsp_api_ess_change_password"
	SPESSUserChangePassword    = "xsp_api_ess_user_change_password"

	SPESSDashboardInfoGetrow = "xsp_api_ess_dashboard_info_getrow"
	SPESSAttendanceGetrows   = "xsp_api_ess_attendance_getrows"
	SPESSAbsensiLog          = "xsp_api_ess_absensi_log"
	SPESSProfileGetrow = "xsp_api_ess_profile_getrow"
	SPESSProfileUpdate = "xsp_api_update_profile_ess"

	SPESSIzinGetrows = "xsp_api_ess_izin_getrows"
	SPESSIzinInsert  = "xsp_api_ess_izin_insert"
	SPESSIzinUpdate  = "xsp_api_ess_izin_update"
	SPESSIzinDelete  = "xsp_api_ess_izin_delete"

	SPESSApprovalIzinGetrows = "xsp_approval_api_ess_izin_getrows"
	SPESSApprovalIzinUpdate  = "xsp_approval_api_ess_izin_update"
	SPESSApprovalCutiGetrows = "xsp_approval_api_ess_cuti_getrows"
	SPESSApprovalCutiUpdate  = "xsp_approval_api_ess_cuti_update"
	SPESSApprovalLemburGetrows = "xsp_approval_api_ess_lembur_getrows"
	SPESSApprovalLemburUpdate  = "xsp_approval_api_ess_lembur_update"

	SPESSCutiGetrows = "xsp_api_ess_cuti_getrows"
	SPESSCutiInsert  = "xsp_api_ess_cuti_insert"
	SPESSCutiUpdate  = "xsp_api_ess_cuti_update"
	SPESSCutiDelete  = "xsp_api_ess_cuti_delete"
	SPESSCutiReportGetrows = "xsp_api_ess_cuti_report_getrows"

	SPESSLemburGetrows = "xsp_api_ess_lembur_getrows"
	SPESSLemburInsert  = "xsp_api_ess_lembur_insert"
	SPESSLemburUpdate  = "xsp_api_ess_lembur_update"
	SPESSLemburDelete  = "xsp_api_ess_lembur_delete"

	SPESSMasterHolidayGetrows = "xsp_api_ess_master_holiday_getrows"
	SPESSAssetItemGetrows     = "xsp_api_ess_asset_item_getrows"

	SPESSDinasGetrows = "xsp_api_ess_dinas_getrows"
	SPESSDinasInsert  = "xsp_api_ess_dinas_insert"
	SPESSDinasUpdate  = "xsp_api_ess_dinas_update"

	SPESSRekapAbsensiGetrows = "xsp_api_ess_rekap_absensi_getrows"
	SPESSRekapCutiGetrows    = "xsp_api_ess_rekap_cuti_getrows"

	SPESSUserOtpVerify = "xsp_api_ess_user_otp_verify"

	essResetOTPWindow = 10 * time.Minute

	// Setelah OTP terverifikasi, user punya waktu ini untuk hit change-password sekali saja.
	essOtpVerifiedWindow = 10 * time.Minute
)

type essClaims struct {
	UserID   string `json:"userId"`
	UserName string `json:"userName,omitempty"`
	jwt.RegisteredClaims
}

func essJwtKey() []byte {
	return []byte(os.Getenv("JWT_KEY"))
}

func parseESSAuthClaims(r *http.Request) (*essClaims, error) {
	authHeader := strings.TrimSpace(r.Header.Get("Authorization"))
	if authHeader == "" {
		return nil, fmt.Errorf("authorization header required")
	}
	tokenString := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
	if tokenString == "" || tokenString == authHeader {
		tokenString = strings.TrimSpace(strings.TrimPrefix(authHeader, "bearer "))
	}
	if tokenString == "" {
		return nil, fmt.Errorf("bearer token required")
	}

	claims := &essClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return essJwtKey(), nil
	})
	if err != nil || token == nil || !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}
	if strings.TrimSpace(claims.UserID) == "" {
		claims.UserID = strings.TrimSpace(claims.Subject)
	}
	return claims, nil
}

func writeESSJSON(w http.ResponseWriter, status int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeESSError(w http.ResponseWriter, status int, code, message string) {
	writeESSJSON(w, status, map[string]string{
		"responseCode":    code,
		"responseMessage": message,
	})
}

func writeESSNotImplemented(w http.ResponseWriter, endpoint, spName string) {
	writeESSJSON(w, http.StatusNotImplemented, map[string]string{
		"responseCode":    "5010001",
		"responseMessage": "ESS endpoint not implemented yet: " + endpoint,
		"storedProcedure": spName,
	})
}

func runESSSPQuery(ctx context.Context, spName string, namedArgs ...interface{}) (string, error) {
	var jsonResultData string
	args := append(namedArgs, sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))
	// Semua SP ESS/approval berada di database RBCA, bukan database utama (pos_server).
	rows, err := database.RbcaInstance.QueryContext(ctx, spName, args...)
	if err != nil {
		return "", err
	}
	if rows == nil {
		return jsonResultData, nil
	}
	defer rows.Close()

	var rowJSON string
	for {
		for rows.Next() {
			var col sql.NullString
			if scanErr := rows.Scan(&col); scanErr == nil && col.Valid && strings.TrimSpace(col.String) != "" {
				rowJSON = col.String
			}
		}
		if !rows.NextResultSet() {
			break
		}
	}

	if strings.TrimSpace(jsonResultData) != "" {
		return jsonResultData, nil
	}
	return rowJSON, nil
}

// runESSSPExec untuk SP tanpa @bitparam (mis. cuti insert/update yang hanya INSERT/UPDATE + RAISERROR).
func runESSSPExec(ctx context.Context, spName string, namedArgs ...interface{}) error {
	_, err := database.RbcaInstance.ExecContext(ctx, spName, namedArgs...)
	return err
}

func writeESSSPExecError(w http.ResponseWriter, err error, fallbackMsg string) {
	msg := strings.TrimSpace(err.Error())
	if idx := strings.Index(msg, "mssql:"); idx >= 0 {
		msg = strings.TrimSpace(msg[idx+len("mssql:"):])
	}
	upper := strings.ToUpper(msg)
	if strings.Contains(upper, "WAJIB") ||
		strings.Contains(upper, "MELEBIHI") ||
		strings.Contains(upper, "TIDAK BOLEH") ||
		strings.Contains(upper, "RAISERROR") {
		writeESSError(w, http.StatusBadRequest, "4000002", msg)
		return
	}
	writeESSError(w, http.StatusInternalServerError, "5000002", fallbackMsg)
}

func essRawToString(raw interface{}) string {
	if raw == nil {
		return ""
	}
	switch v := raw.(type) {
	case string:
		return strings.TrimSpace(v)
	case float64:
		if v == float64(int64(v)) {
			return strconv.FormatInt(int64(v), 10)
		}
		return strings.TrimSpace(strconv.FormatFloat(v, 'f', -1, 64))
	case json.Number:
		return strings.TrimSpace(v.String())
	case bool:
		if v {
			return "true"
		}
		return "false"
	default:
		return strings.TrimSpace(fmt.Sprint(v))
	}
}

func essJSONBody(r *http.Request) map[string]interface{} {
	if r.Body == nil {
		return nil
	}

	ct := strings.ToLower(r.Header.Get("Content-Type"))
	if ct != "" && !strings.Contains(ct, "application/json") {
		return nil
	}

	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil || len(bodyBytes) == 0 {
		return nil
	}
	r.Body = io.NopCloser(strings.NewReader(string(bodyBytes)))

	var body map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &body); err != nil {
		return nil
	}
	return body
}

func essDecodeParam(val string) string {
	val = strings.TrimSpace(val)
	if val == "" {
		return ""
	}

	// Query.Get biasanya sudah decode %20 → spasi.
	// Kalau frontend encode 2x (encodeURIComponent + axios params), sisa %20/%2520 harus di-decode lagi.
	for i := 0; i < 3; i++ {
		if !strings.Contains(val, "%") {
			break
		}
		decoded, err := url.QueryUnescape(val)
		if err != nil || decoded == val {
			break
		}
		val = decoded
	}

	val = strings.ReplaceAll(val, "+", " ")
	return strings.Join(strings.Fields(val), " ")
}

func essNormalizeKategori(kategori string) string {
	kategori = essDecodeParam(kategori)
	if kategori == "" {
		return ""
	}
	return strings.ToUpper(kategori)
}

func essRequestParam(r *http.Request, keys ...string) string {
	for _, key := range keys {
		if val := essDecodeParam(r.URL.Query().Get(key)); val != "" {
			return val
		}
	}

	_ = r.ParseForm()
	for _, key := range keys {
		if val := essDecodeParam(r.FormValue(key)); val != "" {
			return val
		}
	}

	body := essJSONBody(r)
	for _, key := range keys {
		if raw, ok := body[key]; ok {
			if val := essDecodeParam(essRawToString(raw)); val != "" {
				return val
			}
		}
	}
	return ""
}

func essHTTPStatusFromCode(code string) int {
	switch strings.TrimSpace(code) {
	case "", "00", "2000000", "2002500", "2002600", "2002700", "2002701", "2002702":
		return http.StatusOK
	case "01", "4040000", "4042500":
		return http.StatusNotFound
	case "4012500":
		return http.StatusUnauthorized
	case "4092600", "4092500":
		return http.StatusConflict
	default:
		if strings.HasPrefix(code, "20") {
			return http.StatusOK
		}
		if strings.HasPrefix(code, "401") {
			return http.StatusUnauthorized
		}
		if strings.HasPrefix(code, "409") {
			return http.StatusConflict
		}
		return http.StatusBadRequest
	}
}

var essJakartaLoc = func() *time.Location {
	loc, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		return time.FixedZone("WIB", 7*60*60)
	}
	return loc
}()

// Field tanggal dari SP yang sering keluar UTC (Z) — ditampilkan sebagai waktu lokal WIB.
var essLocalDateFieldNames = map[string]struct{}{
	"credate":         {},
	"cre_date":        {},
	"createdate":      {},
	"create_date":     {},
	"createdat":       {},
	"created_at":      {},
	"tanggalproses":   {},
	"tanggal_proses":  {},
}

func essIsLocalDateField(key string) bool {
	_, ok := essLocalDateFieldNames[strings.ToLower(strings.TrimSpace(key))]
	return ok
}

func essParseFlexibleTime(raw string) (time.Time, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, false
	}

	upper := strings.ToUpper(raw)
	hasZone := strings.HasSuffix(upper, "Z")
	if !hasZone && len(raw) > 10 {
		// Offset +07:00 / -05:00 setelah bagian tanggal.
		if idx := strings.LastIndexAny(raw[10:], "+-"); idx >= 0 {
			hasZone = true
		}
	}

	if hasZone {
		for _, layout := range []string{time.RFC3339Nano, time.RFC3339} {
			if t, err := time.Parse(layout, raw); err == nil {
				return t, true
			}
		}
	}

	localLayouts := []string{
		"2006-01-02T15:04:05.999999999",
		"2006-01-02T15:04:05",
		"2006-01-02 15:04:05.999999999",
		"2006-01-02 15:04:05",
		"2006-01-02",
	}
	for _, layout := range localLayouts {
		if t, err := time.ParseInLocation(layout, raw, essJakartaLoc); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

func essFormatLocalDateTime(raw string) string {
	t, ok := essParseFlexibleTime(raw)
	if !ok {
		return raw
	}
	return t.In(essJakartaLoc).Format("2006-01-02T15:04:05")
}

func essNowLocal() string {
	return time.Now().In(essJakartaLoc).Format("2006-01-02 15:04:05")
}

// essCreDateParam: selalu kirim waktu lokal WIB ke SP (bukan UTC/Z dari client).
func essCreDateParam(r *http.Request) string {
	raw := essRequestParam(r, "creDate", "cre_date", "p_cre_date")
	if raw == "" {
		return essNowLocal()
	}
	if t, ok := essParseFlexibleTime(raw); ok {
		return t.In(essJakartaLoc).Format("2006-01-02 15:04:05")
	}
	return essNowLocal()
}

func essRewriteLocalDateFields(v interface{}) interface{} {
	switch typed := v.(type) {
	case map[string]interface{}:
		for key, val := range typed {
			if s, ok := val.(string); ok && essIsLocalDateField(key) {
				typed[key] = essFormatLocalDateTime(s)
				continue
			}
			typed[key] = essRewriteLocalDateFields(val)
		}
		return typed
	case []interface{}:
		for i, item := range typed {
			typed[i] = essRewriteLocalDateFields(item)
		}
		return typed
	default:
		return v
	}
}

func writeESSSPJSON(w http.ResponseWriter, jsonResult string, emptyAsArray bool) {
	raw := strings.TrimSpace(jsonResult)
	if raw == "" {
		if emptyAsArray {
			writeESSJSON(w, http.StatusOK, []interface{}{})
			return
		}
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var payload interface{}
	if err := json.Unmarshal([]byte(raw), &payload); err != nil {
		log.Println("ESS JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	payload = essRewriteLocalDateFields(payload)

	status := http.StatusOK
	if obj, ok := payload.(map[string]interface{}); ok {
		code, _ := obj["responseCode"].(string)
		status = essHTTPStatusFromCode(code)
		// 02 selalu validasi bisnis. 01 + sisaCuti/tanggal (tanpa data[]) = insert/update gagal, bukan not found.
		if code == "02" {
			status = http.StatusBadRequest
		} else if code == "01" && (obj["sisaCuti"] != nil || (obj["tanggal"] != nil && obj["data"] == nil)) {
			status = http.StatusBadRequest
		} else if code == "01" && obj["data"] != nil {
			// List kosong: tetap 200, biar frontend baca data: []
			status = http.StatusOK
		}
	}
	writeESSJSON(w, status, payload)
}

func pingESSDB(w http.ResponseWriter, ctx context.Context, label string) bool {
	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println(label, "DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return false
	}
	return true
}

func extractESSUserFromLogin(result map[string]interface{}) (userID, userName string) {
	data, ok := result["data"].(map[string]interface{})
	if !ok {
		return "", ""
	}

	if raw, ok := data["userId"]; ok {
		userID = strings.TrimSpace(fmt.Sprint(raw))
	}
	if raw, ok := data["userName"]; ok {
		userName = strings.TrimSpace(fmt.Sprint(raw))
	}
	return userID, userName
}

func extractESSResetPasswordData(result map[string]interface{}) (idUser, email string) {
	data, ok := result["data"].(map[string]interface{})
	if !ok {
		return "", ""
	}

	if raw, ok := data["idUser"]; ok {
		idUser = strings.TrimSpace(fmt.Sprint(raw))
	}
	if raw, ok := data["email"]; ok {
		email = strings.TrimSpace(fmt.Sprint(raw))
	}
	return idUser, email
}

func sendESSEmailOTP(email, otp string) error {
	// Kirim langsung via SMTP lokal (KirimEmailOTP), jangan lewat Render —
	// Render sering sleep/lambat sehingga email tidak sampai.
	if err := KirimEmailOTP(email, otp); err != nil {
		return fmt.Errorf("send email otp failed: %w", err)
	}
	return nil
}

func storeESSResetOTP(ctx context.Context, userID, otp string) error {
	if essRedisClient == nil || strings.TrimSpace(userID) == "" || strings.TrimSpace(otp) == "" {
		return nil
	}

	key := fmt.Sprintf("ess:reset:otp:%s", userID)
	return essRedisClient.Set(ctx, key, otp, essResetOTPWindow).Err()
}

func getESSResetOTP(ctx context.Context, userID string) (string, error) {
	if essRedisClient == nil || strings.TrimSpace(userID) == "" {
		return "", nil
	}
	val, err := essRedisClient.Get(ctx, fmt.Sprintf("ess:reset:otp:%s", userID)).Result()
	if err == redis.Nil {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(val), nil
}

func clearESSResetOTP(ctx context.Context, userID string) error {
	if essRedisClient == nil || strings.TrimSpace(userID) == "" {
		return nil
	}
	return essRedisClient.Del(ctx, fmt.Sprintf("ess:reset:otp:%s", userID)).Err()
}

func essOtpVerifiedKey(userID string) string {
	return fmt.Sprintf("ess:otp:verified:%s", userID)
}

// markESSOtpVerified menandai user boleh hit change-password sekali dalam window tertentu.
func markESSOtpVerified(ctx context.Context, userID string) error {
	if essRedisClient == nil || strings.TrimSpace(userID) == "" {
		return nil
	}
	return essRedisClient.Set(ctx, essOtpVerifiedKey(userID), "1", essOtpVerifiedWindow).Err()
}

// isESSOtpVerified mengecek apakah user sudah lolos verifikasi OTP dan belum expired.
func isESSOtpVerified(ctx context.Context, userID string) (bool, error) {
	if essRedisClient == nil || strings.TrimSpace(userID) == "" {
		return false, nil
	}

	err := essRedisClient.Get(ctx, essOtpVerifiedKey(userID)).Err()
	if err == redis.Nil {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// clearESSOtpVerified menghapus tanda verifikasi agar tidak bisa dipakai ulang (one-time use).
func clearESSOtpVerified(ctx context.Context, userID string) error {
	if essRedisClient == nil || strings.TrimSpace(userID) == "" {
		return nil
	}
	return essRedisClient.Del(ctx, essOtpVerifiedKey(userID)).Err()
}

func newESSSessionID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	// UUID v4
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	hex := fmt.Sprintf("%x", b)
	return fmt.Sprintf("%s-%s-%s-%s-%s", hex[0:8], hex[8:12], hex[12:16], hex[16:20], hex[20:32]), nil
}

func essGuessClientInfo(userAgent string) string {
	ua := strings.ToLower(userAgent)
	switch {
	case strings.Contains(ua, "edg/"):
		return "Web Browser (Edge)"
	case strings.Contains(ua, "chrome/") && !strings.Contains(ua, "edg/"):
		return "Web Browser (Chrome)"
	case strings.Contains(ua, "safari/") && !strings.Contains(ua, "chrome/"):
		return "Web Browser (Safari)"
	case strings.Contains(ua, "firefox/"):
		return "Web Browser (Firefox)"
	case strings.Contains(ua, "android"):
		return "AMS ESS Mobile (Android)"
	case strings.Contains(ua, "iphone") || strings.Contains(ua, "ipad"):
		return "AMS ESS Mobile (iOS)"
	case strings.TrimSpace(userAgent) == "":
		return "Unknown client"
	default:
		if len(userAgent) > 80 {
			return userAgent[:80]
		}
		return userAgent
	}
}

// essDeviceFingerprint — fallback jika client tidak kirim device_id (kurang akurat dari device_id stabil).
func essDeviceFingerprint(deviceType, clientInfo, userAgent string) string {
	raw := strings.ToLower(strings.TrimSpace(deviceType) + "|" + strings.TrimSpace(clientInfo) + "|" + strings.TrimSpace(userAgent))
	if raw == "||" || raw == "unknown||" {
		return ""
	}
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:16]) // 32 hex chars
}

func essDetectDevice(r *http.Request) (deviceKey, deviceType, deviceName, clientInfo, userAgent string) {
	userAgent = strings.TrimSpace(r.Header.Get("User-Agent"))
	deviceKey = strings.TrimSpace(essRequestParam(r,
		"device_id", "deviceId", "device_key", "deviceKey", "p_device_key", "p_device_id",
	))
	deviceType = strings.ToUpper(strings.TrimSpace(essRequestParam(r, "device_type", "deviceType", "p_device_type")))
	deviceName = strings.TrimSpace(essRequestParam(r, "device_name", "deviceName", "p_device_name"))
	clientInfo = strings.TrimSpace(essRequestParam(r, "client_info", "clientInfo", "p_client_info"))

	if deviceType == "" {
		ua := strings.ToLower(userAgent)
		switch {
		case strings.Contains(ua, "android"),
			strings.Contains(ua, "iphone"),
			strings.Contains(ua, "ipad"),
			strings.Contains(ua, "mobile"):
			deviceType = "MOBILE"
		case userAgent != "":
			deviceType = "WEB"
		default:
			deviceType = "UNKNOWN"
		}
	}

	if deviceName == "" {
		switch deviceType {
		case "MOBILE":
			ua := strings.ToLower(userAgent)
			if strings.Contains(ua, "iphone") || strings.Contains(ua, "ipad") {
				deviceName = "AMS Mobile App (iOS)"
			} else if strings.Contains(ua, "android") {
				deviceName = "AMS Mobile App (Android)"
			} else {
				deviceName = "AMS Mobile App"
			}
		case "WEB":
			deviceName = "Web Browser"
		default:
			deviceName = "Perangkat Tidak Dikenal"
		}
	}

	if clientInfo == "" {
		clientInfo = essGuessClientInfo(userAgent)
	}

	if deviceKey == "" {
		deviceKey = essDeviceFingerprint(deviceType, clientInfo, userAgent)
	}
	if len(deviceKey) > 100 {
		deviceKey = deviceKey[:100]
	}
	return deviceKey, deviceType, deviceName, clientInfo, userAgent
}

func insertESSLoginSession(
	ctx context.Context,
	sessionID, userID, deviceKey, deviceType, deviceName, clientInfo, userAgent, ipAddress string,
	loginAt, expiresAt time.Time,
) error {
	jsonResult, err := runESSSPQuery(ctx, SPESSLoginSessionInsert,
		sql.Named("p_id", sessionID),
		sql.Named("p_user_id", userID),
		sql.Named("p_device_key", deviceKey),
		sql.Named("p_device_type", deviceType),
		sql.Named("p_device_name", deviceName),
		sql.Named("p_client_info", clientInfo),
		sql.Named("p_user_agent", userAgent),
		sql.Named("p_ip_address", ipAddress),
		sql.Named("p_location_name", ""),
		// Kirim wall-clock WIB (string) agar DATETIME2 tidak tersimpan sebagai UTC.
		sql.Named("p_login_at", loginAt.In(essJakartaLoc).Format("2006-01-02 15:04:05")),
		sql.Named("p_expires_at", expiresAt.In(essJakartaLoc).Format("2006-01-02 15:04:05")),
	)
	if err != nil {
		return err
	}
	if strings.TrimSpace(jsonResult) == "" {
		return fmt.Errorf("empty response from login session insert")
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		return err
	}
	code, _ := result["responseCode"].(string)
	if code != "2002700" && code != "2002500" && code != "2000000" {
		msg, _ := result["responseMessage"].(string)
		if msg == "" {
			msg = "login session insert failed"
		}
		return fmt.Errorf("%s (%s)", msg, code)
	}
	return nil
}

func createESSToken(userID, userName, sessionID string, expiresAt time.Time) (tokenString string, err error) {
	now := time.Now().UTC()
	if expiresAt.IsZero() {
		expiresAt = now.Add(14 * 24 * time.Hour)
	}

	claims := &essClaims{
		UserID:   userID,
		UserName: userName,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			IssuedAt:  jwt.NewNumericDate(now),
		},
	}
	if strings.TrimSpace(sessionID) != "" {
		claims.ID = strings.TrimSpace(sessionID) // jti = session id
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(essJwtKey())
}

// --- Auth ---

func ESSLogin(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	uid := strings.TrimSpace(r.FormValue("uid"))
	if uid == "" {
		uid = strings.TrimSpace(r.FormValue("user"))
	}
	password := strings.TrimSpace(r.FormValue("password"))

	if uid == "" || password == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "uid and password are required")
		return
	}

	ip := middleware.ClientIP(r)
	deviceKey, deviceType, deviceName, clientInfo, userAgent := essDetectDevice(r)

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS login DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSLogin,
		sql.Named("p_uid", uid),
		sql.Named("p_password", password),
	)
	if err != nil {
		log.Println("ESS login SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute login")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS login JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	responseCode, _ := result["responseCode"].(string)
	switch responseCode {
	case "2002500":
		_ = middleware.ClearEssLoginFailures(ctx, essRedisClient, ip, uid)

		userID, userName := extractESSUserFromLogin(result)
		if userID == "" {
			writeESSError(w, http.StatusInternalServerError, "5000005", "userId missing in login response")
			return
		}

		sessionID, err := newESSSessionID()
		if err != nil {
			writeESSError(w, http.StatusInternalServerError, "5000006", "Could not create session id")
			return
		}

		loginAt := time.Now().In(essJakartaLoc)
		expiresAt := loginAt.Add(14 * 24 * time.Hour)
		sessionOK := true
		if err := insertESSLoginSession(
			ctx,
			sessionID,
			userID,
			deviceKey,
			deviceType,
			deviceName,
			clientInfo,
			userAgent,
			ip,
			loginAt,
			expiresAt,
		); err != nil {
			// Jangan taruh jti di token jika sesi gagal disimpan — supaya middleware tidak mental ke login.
			sessionOK = false
			sessionID = ""
			log.Printf("ESS login session insert failed user=%s: %v", userID, err)
		}

		tokenString, err := createESSToken(userID, userName, sessionID, expiresAt)
		if err != nil {
			writeESSError(w, http.StatusInternalServerError, "5000006", "Could not create token")
			return
		}

		data, ok := result["data"].(map[string]interface{})
		if !ok {
			data = map[string]interface{}{}
		}
		data["token"] = tokenString
		if sessionOK && sessionID != "" {
			data["sessionId"] = sessionID
		}
		if deviceKey != "" {
			data["deviceKey"] = deviceKey
		}
		result["data"] = data

		writeESSJSON(w, http.StatusOK, result)

	case "4002500":
		_ = middleware.RecordEssLoginFailure(ctx, essRedisClient, ip, uid)
		writeESSJSON(w, http.StatusUnauthorized, result)

	default:
		writeESSJSON(w, http.StatusBadRequest, result)
	}
}

// ESSGetLoginSessions — list perangkat/sesi aktif (UI Perangkat Terhubung).
func ESSGetLoginSessions(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	claims, err := parseESSAuthClaims(r)
	if err != nil {
		writeESSError(w, http.StatusUnauthorized, "4010001", "Unauthorized")
		return
	}

	userID := strings.TrimSpace(claims.UserID)
	sessionID := strings.TrimSpace(claims.ID)
	if userID == "" {
		writeESSError(w, http.StatusUnauthorized, "4010001", "Unauthorized")
		return
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS login sessions DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	args := []interface{}{
		sql.Named("p_user_id", userID),
	}
	if sessionID != "" {
		args = append(args, sql.Named("p_current_session", sessionID))
	} else {
		args = append(args, sql.Named("p_current_session", nil))
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSLoginSessionGetrows, args...)
	if err != nil {
		log.Println("ESS login sessions SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to load login sessions")
		return
	}
	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS login sessions JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	writeESSJSON(w, essHTTPStatusFromCode(fmt.Sprint(result["responseCode"])), result)
}

// ESSRevokeOtherLoginSessions — keluar dari semua perangkat lain (keep current jti).
func ESSRevokeOtherLoginSessions(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPost && r.Method != http.MethodPut {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	claims, err := parseESSAuthClaims(r)
	if err != nil {
		writeESSError(w, http.StatusUnauthorized, "4010001", "Unauthorized")
		return
	}

	userID := strings.TrimSpace(claims.UserID)
	sessionID := strings.TrimSpace(claims.ID)
	if userID == "" {
		writeESSError(w, http.StatusUnauthorized, "4010001", "Unauthorized")
		return
	}
	if sessionID == "" {
		writeESSError(w, http.StatusBadRequest, "4002701", "Current session id missing in token (login ulang)")
		return
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS revoke other sessions DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSLoginSessionRevokeOthers,
		sql.Named("p_user_id", userID),
		sql.Named("p_current_session", sessionID),
	)
	if err != nil {
		log.Println("ESS revoke other sessions SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to revoke other sessions")
		return
	}
	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS revoke other sessions JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	code, _ := result["responseCode"].(string)
	switch code {
	case "2002702", "2002500", "2000000":
		writeESSJSON(w, http.StatusOK, result)
	default:
		writeESSJSON(w, essHTTPStatusFromCode(code), result)
	}
}

func ESSResetPassword(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	userID := strings.TrimSpace(r.FormValue("user"))

	if userID == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "user is required")
		return
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS reset password DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSResetPassword,
		sql.Named("p_user_id", userID),
	)
	if err != nil {
		log.Println("ESS reset password SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute reset password")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS reset password JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	responseCode, _ := result["responseCode"].(string)
	switch responseCode {
	case "2002500":
		idUser, email := extractESSResetPasswordData(result)
		if email == "" {
			log.Println("ESS reset password SP result missing email:", jsonResult)
			writeESSError(w, http.StatusInternalServerError, "5000005", "email missing in reset password response")
			return
		}

		// SP hanya mengembalikan data user/email. OTP digenerate di Go, lalu dikirim email
		// dan disimpan Redis. Pastikan otp-verify juga validasi ke sumber yang sama.
		otp := GenerateOTP(6)
		log.Printf("ESS reset password: sending OTP to email=%s user=%s", email, idUser)
		if err := sendESSEmailOTP(email, otp); err != nil {
			log.Println("ESS reset password send OTP error:", err.Error())
			writeESSError(w, http.StatusInternalServerError, "5000006", "Failed to send OTP email")
			return
		}
		log.Printf("ESS reset password: OTP email sent successfully to %s", email)

		if idUser == "" {
			idUser = userID
		}
		if err := storeESSResetOTP(ctx, idUser, otp); err != nil {
			log.Println("ESS reset password store OTP error:", err.Error())
		}

		writeESSJSON(w, http.StatusOK, result)

	case "4002500":
		writeESSJSON(w, http.StatusNotFound, result)

	default:
		writeESSJSON(w, http.StatusBadRequest, result)
	}
}

// ESSResetPasswordByEmail — reset password by email (endpoint terpisah).
// SP: xsp_api_ess_reset_password_by_email (@p_user_id, @p_email, @bitparam)
func ESSResetPasswordByEmail(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	userID := strings.TrimSpace(essRequestParam(r,
		"user_id", "userId", "p_user_id", "user", "uid",
	))
	email := strings.TrimSpace(essRequestParam(r, "email", "p_email"))

	if userID == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "user_id is required")
		return
	}
	if email == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "email is required")
		return
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS reset password by email DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSResetPasswordByEmail,
		sql.Named("p_user_id", userID),
		sql.Named("p_email", email),
	)
	if err != nil {
		log.Println("ESS reset password by email SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute reset password by email")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS reset password by email JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	responseCode, _ := result["responseCode"].(string)
	switch responseCode {
	case "2002500":
		idUser, emailFromSP := extractESSResetPasswordData(result)
		sendTo := emailFromSP
		if sendTo == "" {
			sendTo = email
		}
		if sendTo == "" {
			log.Println("ESS reset password by email SP result missing email:", jsonResult)
			writeESSError(w, http.StatusInternalServerError, "5000005", "email missing in reset password response")
			return
		}

		otp := GenerateOTP(6)
		log.Printf("ESS reset password by email: sending OTP to email=%s user=%s", sendTo, idUser)
		if err := sendESSEmailOTP(sendTo, otp); err != nil {
			log.Println("ESS reset password by email send OTP error:", err.Error())
			writeESSError(w, http.StatusInternalServerError, "5000006", "Failed to send OTP email")
			return
		}
		log.Printf("ESS reset password by email: OTP email sent successfully to %s", sendTo)

		if idUser == "" {
			idUser = userID
		}
		if err := storeESSResetOTP(ctx, idUser, otp); err != nil {
			log.Println("ESS reset password by email store OTP error:", err.Error())
		}

		writeESSJSON(w, http.StatusOK, result)

	case "4002500", "4002501", "4042500":
		writeESSJSON(w, http.StatusNotFound, result)

	default:
		writeESSJSON(w, http.StatusBadRequest, result)
	}
}

func ESSOtpVerify(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	userID := strings.TrimSpace(r.FormValue("user"))
	if userID == "" {
		userID = strings.TrimSpace(r.FormValue("user_id"))
	}
	if userID == "" {
		userID = strings.TrimSpace(r.FormValue("userId"))
	}
	otp := strings.TrimSpace(r.FormValue("otp"))

	if userID == "" || otp == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "user and otp are required")
		return
	}

	ip := middleware.ClientIP(r)

	// OTP disimpan Redis saat reset-password (bukan dari SP), jadi verifikasi di sini.
	storedOTP, err := getESSResetOTP(ctx, userID)
	if err != nil {
		log.Println("ESS otp verify redis error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to verify OTP")
		return
	}

	if storedOTP == "" || storedOTP != otp {
		_ = middleware.RecordEssOtpVerifyFailure(ctx, essRedisClient, ip)
		writeESSJSON(w, http.StatusUnauthorized, map[string]string{
			"responseCode":    "4002500",
			"responseMessage": "Invalid or expired OTP",
		})
		return
	}

	_ = clearESSResetOTP(ctx, userID)
	_ = middleware.ClearEssOtpVerifyFailures(ctx, essRedisClient, ip)
	if err := markESSOtpVerified(ctx, userID); err != nil {
		log.Println("ESS otp verify mark verified error:", err.Error())
	}

	writeESSJSON(w, http.StatusOK, map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "OTP valid",
		"data": map[string]string{
			"userId": userID,
		},
	})
}

func ESSChangePassword(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPost && r.Method != http.MethodPut {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	userID := strings.TrimSpace(r.FormValue("user"))
	password := strings.TrimSpace(r.FormValue("password"))

	// Wajib sudah lolos verifikasi OTP sebelum boleh mengubah password.
	// Jika user_id kosong, biarkan SP yang menolak dengan pesan resminya (4002501).
	if userID != "" {
		verified, err := isESSOtpVerified(ctx, userID)
		if err != nil {
			log.Println("ESS change password otp-verified check error:", err.Error())
			writeESSError(w, http.StatusInternalServerError, "5000007", "Failed to validate OTP verification state")
			return
		}
		if !verified {
			writeESSError(w, http.StatusForbidden, "4030001", "OTP verification is required before changing password")
			return
		}
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS change password DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSChangePassword,
		sql.Named("p_user_id", userID),
		sql.Named("p_password", password),
	)
	if err != nil {
		log.Println("ESS change password SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute change password")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS change password JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	responseCode, _ := result["responseCode"].(string)
	switch responseCode {
	case "2002500":
		// One-time use: setelah berhasil ganti password, tanda verifikasi OTP dihapus.
		if err := clearESSOtpVerified(ctx, userID); err != nil {
			log.Println("ESS change password clear otp-verified error:", err.Error())
		}
		writeESSJSON(w, http.StatusOK, result)

	case "4002501", "4002502":
		writeESSJSON(w, http.StatusBadRequest, result)

	case "4002503":
		writeESSJSON(w, http.StatusNotFound, result)

	case "4002504":
		writeESSJSON(w, http.StatusInternalServerError, result)

	default:
		writeESSJSON(w, http.StatusBadRequest, result)
	}
}

func ESSUserChangePassword(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPut && r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	userID := strings.TrimSpace(essRequestParam(r,
		"user_id", "userId", "p_user_id", "user", "uid",
	))
	currentPassword := strings.TrimSpace(essRequestParam(r,
		"current_password", "currentPassword", "p_current_password", "old_password", "oldPassword",
	))
	newPassword := strings.TrimSpace(essRequestParam(r,
		"password", "new_password", "newPassword", "p_password",
	))

	if userID == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "user_id is required")
		return
	}
	if currentPassword == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "current_password is required")
		return
	}
	if newPassword == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "password is required")
		return
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS user change password DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSUserChangePassword,
		sql.Named("p_user_id", userID),
		sql.Named("p_current_password", currentPassword),
		sql.Named("p_password", newPassword),
	)
	if err != nil {
		log.Println("ESS user change password SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute change password")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS user change password JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	responseCode, _ := result["responseCode"].(string)
	switch responseCode {
	case "2002500":
		writeESSJSON(w, http.StatusOK, result)
	case "4012500":
		writeESSJSON(w, http.StatusUnauthorized, result)
	case "4042500":
		writeESSJSON(w, http.StatusNotFound, result)
	case "4092500":
		writeESSJSON(w, http.StatusConflict, result)
	case "5002500":
		writeESSJSON(w, http.StatusInternalServerError, result)
	case "4002501", "4002502", "4002503", "4002504":
		writeESSJSON(w, http.StatusBadRequest, result)
	default:
		writeESSJSON(w, essHTTPStatusFromCode(responseCode), result)
	}
}

// --- Dashboard / Attendance / Profile ---

func ESSDashboardInfo(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	userID := strings.TrimSpace(r.FormValue("user"))
	if userID == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "user is required")
		return
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS dashboard info DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSDashboardInfoGetrow,
		sql.Named("p_user", userID),
	)
	if err != nil {
		log.Println("ESS dashboard info SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute dashboard info")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS dashboard info JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	responseCode, _ := result["responseCode"].(string)
	switch responseCode {
	case "", "00", "2002500", "2000000":
		writeESSJSON(w, http.StatusOK, result)
	case "01", "4040000", "4042500", "4002500":
		writeESSJSON(w, http.StatusNotFound, result)
	default:
		writeESSJSON(w, essHTTPStatusFromCode(responseCode), result)
	}
}

func ESSAttendance(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	userID := strings.TrimSpace(r.FormValue("user"))
	periode := strings.TrimSpace(r.FormValue("periode"))

	if userID == "" || periode == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "user and periode are required")
		return
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS attendance DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSAttendanceGetrows,
		sql.Named("p_user", userID),
		sql.Named("p_periode", periode),
	)
	if err != nil {
		log.Println("ESS attendance SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute attendance")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS attendance JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	responseCode, _ := result["responseCode"].(string)
	switch responseCode {
	case "", "00", "2002500", "2000000":
		writeESSJSON(w, http.StatusOK, result)
	case "01", "4040000", "4042500", "4002500":
		writeESSJSON(w, http.StatusNotFound, result)
	default:
		writeESSJSON(w, essHTTPStatusFromCode(responseCode), result)
	}
}

func ESSAbsensiLog(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	nik := strings.TrimSpace(r.FormValue("nik"))
	nama := strings.TrimSpace(r.FormValue("nama"))
	tanggal := strings.TrimSpace(r.FormValue("tanggal"))
	mesin := strings.TrimSpace(r.FormValue("mesin"))
	lokasi := strings.TrimSpace(r.FormValue("lokasi"))

	if nik == "" || nama == "" || tanggal == "" || mesin == "" || lokasi == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik, nama, tanggal, mesin, and lokasi are required")
		return
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS absensi log DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSAbsensiLog,
		sql.Named("p_nik", nik),
		sql.Named("p_nama", nama),
		sql.Named("p_tanggal", tanggal),
		sql.Named("p_mesin", mesin),
		sql.Named("p_lokasi", lokasi),
	)
	if err != nil {
		log.Println("ESS absensi log SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute absensi log")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS absensi log JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	responseCode, _ := result["responseCode"].(string)
	switch responseCode {
	case "", "00", "2002500", "2000000":
		writeESSJSON(w, http.StatusOK, result)
	case "4002500":
		writeESSJSON(w, http.StatusBadRequest, result)
	default:
		writeESSJSON(w, essHTTPStatusFromCode(responseCode), result)
	}
}

func ESSGetProfile(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "profile:get", SPESSProfileGetrow)
}

func ESSUpdateProfile(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPut && r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	nik := strings.TrimSpace(essRequestParam(r,
		"nik", "p_nik", "user_id", "userId", "user", "uid",
	))
	nickName := strings.TrimSpace(essRequestParam(r,
		"nick_name", "nickName", "p_nick_name", "nickname",
	))
	namaLengkap := strings.TrimSpace(essRequestParam(r,
		"nama_lengkap", "namaLengkap", "p_nama_lengkap", "full_name", "fullName", "name",
	))
	email := strings.TrimSpace(essRequestParam(r,
		"email", "p_email",
	))
	phoneNumber := strings.TrimSpace(essRequestParam(r,
		"phone_number", "phoneNumber", "p_phone_number", "phone", "p_phone",
	))

	if nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik is required")
		return
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("ESS update profile DB ping error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000001", "Database unavailable")
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSProfileUpdate,
		sql.Named("p_nik", nik),
		sql.Named("p_nick_name", nickName),
		sql.Named("p_nama_lengkap", namaLengkap),
		sql.Named("p_email", email),
		sql.Named("p_phone_number", phoneNumber),
	)
	if err != nil {
		log.Println("ESS update profile SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute update profile")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "Empty response from database")
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &result); err != nil {
		log.Println("ESS update profile JSON parse error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000004", "Invalid response from database")
		return
	}

	responseCode, _ := result["responseCode"].(string)
	switch responseCode {
	case "2002600", "2000000", "2002500":
		writeESSJSON(w, http.StatusOK, result)
	case "4092600":
		writeESSJSON(w, http.StatusConflict, result)
	case "4040000", "4042500", "4042600":
		writeESSJSON(w, http.StatusNotFound, result)
	default:
		writeESSJSON(w, essHTTPStatusFromCode(responseCode), result)
	}
}

// --- Izin ---

func essIzinWriteParams(r *http.Request) (nik, kategori, fromDate, toDate, jamDari, jamSampai, reason, creBy, creIP string) {
	nik = essRequestParam(r, "nik", "nikstr", "p_nikstr", "p_nik", "user")
	kategori = essNormalizeKategori(essRequestParam(r, "kategori", "p_kategori"))
	fromDate = essRequestParam(r, "fromDate", "from_date", "p_from_date")
	toDate = essRequestParam(r, "toDate", "to_date", "p_to_date")
	jamDari = essRequestParam(r, "jamDari", "jam_dari", "p_jam_dari")
	jamSampai = essRequestParam(r, "jamSampai", "jam_sampai", "p_jam_sampai")
	reason = essRequestParam(r, "reason", "p_reason")
	creBy = essRequestParam(r, "creBy", "cre_by", "p_cre_by")
	if creBy == "" {
		creBy = nik
	}
	creIP = essRequestParam(r, "creIpAddress", "cre_ip_address", "p_cre_ip_address")
	if creIP == "" {
		creIP = middleware.ClientIP(r)
	}
	return
}

func essIzinCreDate(r *http.Request) interface{} {
	return essCreDateParam(r)
}

func ESSGetIzin(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	fromDate := essRequestParam(r, "fromDate", "from_date", "p_from_date")
	toDate := essRequestParam(r, "toDate", "to_date", "p_to_date")
	kategori := essNormalizeKategori(essRequestParam(r, "kategori", "p_kategori"))
	nik := essRequestParam(r, "nik", "p_nik", "user")

	if fromDate == "" || toDate == "" || nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "fromDate, toDate, and nik are required")
		return
	}
	if kategori == "" {
		kategori = "ALL"
	}

	if !pingESSDB(w, ctx, "ESS izin get") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSIzinGetrows,
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
		sql.Named("p_kategori", kategori),
		sql.Named("p_nik", nik),
	)
	if err != nil {
		log.Printf("ESS izin get SP error: %s | rawQuery=%s | kategori=%q nik=%q from=%s to=%s",
			err.Error(), r.URL.RawQuery, kategori, nik, fromDate, toDate)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute izin get")
		return
	}

	writeESSSPJSON(w, jsonResult, true)
}

func ESSCreateIzin(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	nik, kategori, fromDate, toDate, jamDari, jamSampai, reason, creBy, creIP := essIzinWriteParams(r)
	if nik == "" || kategori == "" || fromDate == "" || toDate == "" || reason == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik, kategori, fromDate, toDate, and reason are required")
		return
	}

	if !pingESSDB(w, ctx, "ESS izin insert") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSIzinInsert,
		sql.Named("p_nikstr", nik),
		sql.Named("p_kategori", kategori),
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
		sql.Named("p_jam_dari", jamDari),
		sql.Named("p_jam_sampai", jamSampai),
		sql.Named("p_reason", reason),
		sql.Named("p_cre_ip_address", creIP),
		sql.Named("p_cre_by", creBy),
		sql.Named("p_cre_date", essIzinCreDate(r)),
	)
	if err != nil {
		log.Println("ESS izin insert SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute izin insert")
		return
	}

	notifyESSPengajuanFromJSON(jsonResult, "izin")
	writeESSSPJSON(w, jsonResult, false)
}

func ESSUpdateIzin(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPut {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	id := essRequestParam(r, "id", "p_id")
	nik, kategori, fromDate, toDate, jamDari, jamSampai, reason, creBy, creIP := essIzinWriteParams(r)
	if id == "" || nik == "" || kategori == "" || fromDate == "" || toDate == "" || reason == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "id, nik, kategori, fromDate, toDate, and reason are required")
		return
	}

	if !pingESSDB(w, ctx, "ESS izin update") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSIzinUpdate,
		sql.Named("p_id", id),
		sql.Named("p_nikstr", nik),
		sql.Named("p_kategori", kategori),
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
		sql.Named("p_jam_dari", jamDari),
		sql.Named("p_jam_sampai", jamSampai),
		sql.Named("p_reason", reason),
		sql.Named("p_cre_ip_address", creIP),
		sql.Named("p_cre_by", creBy),
		sql.Named("p_cre_date", essIzinCreDate(r)),
	)
	if err != nil {
		log.Println("ESS izin update SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute izin update")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSDeleteIzin(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodDelete {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	id := essRequestParam(r, "id", "p_id")
	if id == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "id is required")
		return
	}

	if !pingESSDB(w, ctx, "ESS izin delete") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSIzinDelete,
		sql.Named("p_id", id),
	)
	if err != nil {
		log.Println("ESS izin delete SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute izin delete")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSGetApprovalIzin(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	fromDate := essRequestParam(r, "fromDate", "from_date", "p_from_date")
	toDate := essRequestParam(r, "toDate", "to_date", "p_to_date")
	kategori := essNormalizeKategori(essRequestParam(r, "kategori", "p_kategori"))
	dept := essDecodeParam(essRequestParam(r, "dept", "departemen", "p_dept"))
	nik := essRequestParam(r, "nik", "p_nik", "user")

	if fromDate == "" || toDate == "" || dept == "" || nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "fromDate, toDate, dept, and nik are required")
		return
	}
	if kategori == "" {
		kategori = "ALL"
	}
	if len(kategori) > 30 {
		kategori = kategori[:30]
	}
	if len(dept) > 300 {
		dept = dept[:300]
	}

	if !pingESSDB(w, ctx, "ESS approval izin get") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSApprovalIzinGetrows,
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
		sql.Named("p_kategori", kategori),
		sql.Named("p_dept", dept),
		sql.Named("p_nik", nik),
	)
	if err != nil {
		log.Printf("ESS approval izin get SP error: %s | rawQuery=%s | kategori=%q dept=%q nik=%q from=%s to=%s",
			err.Error(), r.URL.RawQuery, kategori, dept, nik, fromDate, toDate)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute approval izin get")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSJSON(w, http.StatusOK, map[string]interface{}{
			"responseCode":    "01",
			"responseMessage": "Data tidak ditemukan",
			"data":            []interface{}{},
		})
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSUpdateApprovalIzin(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPut {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	idRaw := essRequestParam(r, "id", "p_id")
	rollRaw := essRequestParam(r, "rollCode", "roll_code", "p_roll_code")
	tipeApprove := essRequestParam(r, "tipeApprove", "tipeapprove", "tipe_approve")
	alasanPenolakan := essRequestParam(r, "alasanPenolakan", "alasan_penolakan")

	if idRaw == "" || rollRaw == "" || tipeApprove == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "id, rollCode, and tipeApprove are required")
		return
	}

	id := essParseInt(idRaw, 0)
	rollCode := essParseInt(rollRaw, 0)
	if id <= 0 {
		writeESSError(w, http.StatusBadRequest, "4000001", "id must be a valid number")
		return
	}

	if !pingESSDB(w, ctx, "ESS approval izin update") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSApprovalIzinUpdate,
		sql.Named("p_id", id),
		sql.Named("p_roll_code", rollCode),
		sql.Named("tipeapprove", tipeApprove),
		sql.Named("alasan_penolakan", alasanPenolakan),
	)
	if err != nil {
		log.Printf("ESS approval izin update SP error: %s | id=%d rollCode=%d tipe=%q",
			err.Error(), id, rollCode, tipeApprove)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute approval izin update")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSGetApprovalCuti(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	fromDate := essRequestParam(r, "fromDate", "from_date", "p_from_date")
	toDate := essRequestParam(r, "toDate", "to_date", "p_to_date")
	kategori := essNormalizeKategori(essRequestParam(r, "kategori", "p_kategori"))
	dept := essDecodeParam(essRequestParam(r, "dept", "departemen", "p_dept"))
	nik := essRequestParam(r, "nik", "p_nik", "user")

	if fromDate == "" || toDate == "" || dept == "" || nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "fromDate, toDate, dept, and nik are required")
		return
	}
	if kategori == "" {
		kategori = "ALL"
	}
	if len(kategori) > 50 {
		kategori = kategori[:50]
	}
	if len(dept) > 300 {
		dept = dept[:300]
	}

	if !pingESSDB(w, ctx, "ESS approval cuti get") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSApprovalCutiGetrows,
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
		sql.Named("p_kategori", kategori),
		sql.Named("p_dept", dept),
		sql.Named("p_nik", nik),
	)
	if err != nil {
		log.Printf("ESS approval cuti get SP error: %s | rawQuery=%s | kategori=%q dept=%q nik=%q from=%s to=%s",
			err.Error(), r.URL.RawQuery, kategori, dept, nik, fromDate, toDate)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute approval cuti get")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSJSON(w, http.StatusOK, map[string]interface{}{
			"responseCode":    "01",
			"responseMessage": "Data cuti tidak ditemukan",
			"data":            []interface{}{},
		})
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSUpdateApprovalCuti(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPut {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	idRaw := essRequestParam(r, "id", "p_id")
	rollRaw := essRequestParam(r, "rollCode", "roll_code", "p_roll_code")
	tipeApprove := essRequestParam(r, "tipeApprove", "tipeapprove", "tipe_approve")
	alasanPenolakan := essRequestParam(r, "alasanPenolakan", "alasan_penolakan")

	if idRaw == "" || rollRaw == "" || tipeApprove == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "id, rollCode, and tipeApprove are required")
		return
	}

	id := essParseInt(idRaw, 0)
	rollCode := essParseInt(rollRaw, 0)
	if id <= 0 {
		writeESSError(w, http.StatusBadRequest, "4000001", "id must be a valid number")
		return
	}

	if !pingESSDB(w, ctx, "ESS approval cuti update") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSApprovalCutiUpdate,
		sql.Named("p_id", id),
		sql.Named("p_roll_code", rollCode),
		sql.Named("tipeapprove", tipeApprove),
		sql.Named("alasan_penolakan", alasanPenolakan),
	)
	if err != nil {
		log.Printf("ESS approval cuti update SP error: %s | id=%d rollCode=%d tipe=%q",
			err.Error(), id, rollCode, tipeApprove)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute approval cuti update")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSGetApprovalLembur(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	fromDate := essRequestParam(r, "fromDate", "from_date", "p_from_date")
	toDate := essRequestParam(r, "toDate", "to_date", "p_to_date")
	dept := essDecodeParam(essRequestParam(r, "dept", "departemen", "p_dept"))
	nik := essRequestParam(r, "nik", "p_nik", "user")

	if fromDate == "" || toDate == "" || dept == "" || nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "fromDate, toDate, dept, and nik are required")
		return
	}
	if len(dept) > 300 {
		dept = dept[:300]
	}
	if len(nik) > 30 {
		nik = nik[:30]
	}

	if !pingESSDB(w, ctx, "ESS approval lembur get") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSApprovalLemburGetrows,
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
		sql.Named("p_dept", dept),
		sql.Named("p_nik", nik),
	)
	if err != nil {
		log.Printf("ESS approval lembur get SP error: %s | rawQuery=%s | dept=%q nik=%q from=%s to=%s",
			err.Error(), r.URL.RawQuery, dept, nik, fromDate, toDate)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute approval lembur get")
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeESSJSON(w, http.StatusOK, map[string]interface{}{
			"responseCode":    "01",
			"responseMessage": "Data lembur tidak ditemukan",
			"data":            []interface{}{},
		})
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSUpdateApprovalLembur(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPut {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	idRaw := essRequestParam(r, "id", "p_id")
	tipeApprove := essRequestParam(r, "tipeApprove", "tipeapprove", "tipe_approve")
	alasanPenolakan := essRequestParam(r, "alasanPenolakan", "alasan_penolakan")

	if idRaw == "" || tipeApprove == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "id and tipeApprove are required")
		return
	}

	id := essParseInt(idRaw, 0)
	if id <= 0 {
		writeESSError(w, http.StatusBadRequest, "4000001", "id must be a valid number")
		return
	}

	if !pingESSDB(w, ctx, "ESS approval lembur update") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSApprovalLemburUpdate,
		sql.Named("p_id", id),
		sql.Named("tipeapprove", tipeApprove),
		sql.Named("alasan_penolakan", alasanPenolakan),
	)
	if err != nil {
		log.Printf("ESS approval lembur update SP error: %s | id=%d tipe=%q",
			err.Error(), id, tipeApprove)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute approval lembur update")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

// --- Cuti ---

func essParseInt(raw string, fallback int) int {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return fallback
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return n
}

func essCutiCreDate(r *http.Request) interface{} {
	return essCreDateParam(r)
}

type essCutiWriteInput struct {
	nik, kategori, kategoriKhusus, tanggalDari, tanggalSampai, reason, creBy, creIP string
}

func essCutiWriteParams(r *http.Request) essCutiWriteInput {
	in := essCutiWriteInput{
		nik:            essRequestParam(r, "nik", "nikstr", "p_nikstr", "p_nik", "user"),
		kategori:       essNormalizeKategori(essRequestParam(r, "kategori", "p_kategori")),
		kategoriKhusus: essNormalizeKategori(essRequestParam(r, "kategoriKhusus", "kategori_khusus", "p_kategori_khusus")),
		tanggalDari:    essRequestParam(r, "tanggalDari", "tanggal_dari", "p_tanggal_dari", "fromDate", "from_date"),
		tanggalSampai:  essRequestParam(r, "tanggalSampai", "tanggal_sampai", "p_tanggal_sampai", "toDate", "to_date"),
		reason:         essRequestParam(r, "reason", "p_reason"),
		creBy:          essRequestParam(r, "creBy", "cre_by", "p_cre_by"),
		creIP:          essRequestParam(r, "creIpAddress", "cre_ip_address", "p_cre_ip_address"),
	}
	if in.creBy == "" {
		in.creBy = in.nik
	}
	if in.creIP == "" {
		in.creIP = middleware.ClientIP(r)
	}
	return in
}

func essCutiNamedArgs(in essCutiWriteInput, r *http.Request, id string) []interface{} {
	args := []interface{}{}
	if id != "" {
		args = append(args, sql.Named("p_id", id))
	}
	args = append(args,
		sql.Named("p_nikstr", in.nik),
		sql.Named("p_kategori", in.kategori),
		sql.Named("p_kategori_khusus", in.kategoriKhusus),
		sql.Named("p_tanggal_dari", in.tanggalDari),
		sql.Named("p_tanggal_sampai", in.tanggalSampai),
		sql.Named("p_reason", in.reason),
		sql.Named("p_cre_ip_address", in.creIP),
		sql.Named("p_cre_by", in.creBy),
		sql.Named("p_cre_date", essCutiCreDate(r)),
	)
	return args
}

func ESSGetCuti(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	fromDate := essRequestParam(r, "fromDate", "from_date", "p_from_date")
	toDate := essRequestParam(r, "toDate", "to_date", "p_to_date")
	kategori := essNormalizeKategori(essRequestParam(r, "kategori", "p_kategori"))
	nik := essRequestParam(r, "nik", "p_nik", "user")

	if fromDate == "" || toDate == "" || nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "fromDate, toDate, and nik are required")
		return
	}
	if kategori == "" {
		kategori = "ALL"
	}

	if !pingESSDB(w, ctx, "ESS cuti get") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSCutiGetrows,
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
		sql.Named("p_kategori", kategori),
		sql.Named("p_nik", nik),
	)
	if err != nil {
		log.Printf("ESS cuti get SP error: %s | rawQuery=%s | kategori=%q nik=%q from=%s to=%s",
			err.Error(), r.URL.RawQuery, kategori, nik, fromDate, toDate)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute cuti get")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSCreateCuti(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	in := essCutiWriteParams(r)
	if in.nik == "" || in.kategori == "" || in.tanggalDari == "" || in.tanggalSampai == "" || in.reason == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik, kategori, tanggalDari, tanggalSampai, and reason are required")
		return
	}

	if !pingESSDB(w, ctx, "ESS cuti insert") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSCutiInsert, essCutiNamedArgs(in, r, "")...)
	if err != nil {
		log.Printf("ESS cuti insert SP error: %s | nik=%q kategori=%q khusus=%q dari=%s sampai=%s",
			err.Error(), in.nik, in.kategori, in.kategoriKhusus, in.tanggalDari, in.tanggalSampai)
		writeESSSPExecError(w, err, "Failed to execute cuti insert")
		return
	}

	notifyESSPengajuanFromJSON(jsonResult, "cuti")
	writeESSSPJSON(w, jsonResult, false)
}

func ESSUpdateCuti(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPut {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	id := essRequestParam(r, "id", "p_id")
	in := essCutiWriteParams(r)
	if id == "" || in.nik == "" || in.kategori == "" || in.tanggalDari == "" || in.tanggalSampai == "" || in.reason == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "id, nik, kategori, tanggalDari, tanggalSampai, and reason are required")
		return
	}

	if !pingESSDB(w, ctx, "ESS cuti update") {
		return
	}

	err := runESSSPExec(ctx, SPESSCutiUpdate, essCutiNamedArgs(in, r, id)...)
	if err != nil {
		log.Printf("ESS cuti update SP error: %s | id=%s nik=%q kategori=%q dari=%s sampai=%s",
			err.Error(), id, in.nik, in.kategori, in.tanggalDari, in.tanggalSampai)
		writeESSSPExecError(w, err, "Failed to execute cuti update")
		return
	}

	writeESSJSON(w, http.StatusOK, map[string]string{
		"responseCode":    "00",
		"responseMessage": "Data cuti berhasil diperbarui",
	})
}

func ESSDeleteCuti(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodDelete {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	id := essRequestParam(r, "id", "p_id")
	if id == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "id is required")
		return
	}

	if !pingESSDB(w, ctx, "ESS cuti delete") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSCutiDelete,
		sql.Named("p_id", id),
	)
	if err != nil {
		log.Println("ESS cuti delete SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute cuti delete")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSGetCutiReport(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	nik := essRequestParam(r, "nik", "p_nik", "user")
	yearRaw := essRequestParam(r, "year", "tahun", "p_year")
	if yearRaw == "" {
		yearRaw = strconv.Itoa(time.Now().Year())
	}

	if nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik is required")
		return
	}

	year, err := strconv.Atoi(yearRaw)
	if err != nil || yearRaw != strconv.Itoa(year) || year < 1000 || year > 9999 {
		writeESSError(w, http.StatusBadRequest, "4000001", "year must be a 4-digit year")
		return
	}

	if !pingESSDB(w, ctx, "ESS cuti report get") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSCutiReportGetrows,
		sql.Named("p_nik", nik),
		sql.Named("p_year", year),
	)
	if err != nil {
		log.Printf("ESS cuti report get SP error: %s | nik=%q year=%d", err.Error(), nik, year)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute cuti report get")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

// --- Lembur ---

func essParseBit(raw string) bool {
	switch strings.TrimSpace(strings.ToLower(raw)) {
	case "1", "true", "yes", "y":
		return true
	default:
		return false
	}
}

func essLemburCreDate(r *http.Request) interface{} {
	return essCreDateParam(r)
}

type essLemburWriteInput struct {
	nik, kategori, tanggal, jamDari, jamSampai, reason, creBy, creIP string
	keluarKantor                                                     bool
}

func essLemburWriteParams(r *http.Request) essLemburWriteInput {
	in := essLemburWriteInput{
		nik:          essRequestParam(r, "nik", "nikstr", "p_nikstr", "p_nik", "user"),
		kategori:     essNormalizeKategori(essRequestParam(r, "kategori", "p_kategori", "day")),
		tanggal:      essRequestParam(r, "tanggal", "p_tanggal"),
		jamDari:      essRequestParam(r, "jamDari", "jam_dari", "p_jam_dari"),
		jamSampai:    essRequestParam(r, "jamSampai", "jam_sampai", "p_jam_sampai"),
		reason:       essRequestParam(r, "reason", "p_reason"),
		creBy:        essRequestParam(r, "creBy", "cre_by", "p_cre_by"),
		creIP:        essRequestParam(r, "creIpAddress", "cre_ip_address", "p_cre_ip_address"),
		keluarKantor: essParseBit(essRequestParam(r, "keluarKantor", "keluar_kantor", "p_keluar_kantor")),
	}
	if in.creBy == "" {
		in.creBy = in.nik
	}
	if in.creIP == "" {
		in.creIP = middleware.ClientIP(r)
	}
	return in
}

func essLemburNamedArgs(in essLemburWriteInput, r *http.Request, id string, keluarKantorLast bool) []interface{} {
	args := []interface{}{}
	if id != "" {
		args = append(args, sql.Named("p_id", id))
	}
	args = append(args,
		sql.Named("p_nikstr", in.nik),
		sql.Named("p_kategori", in.kategori),
		sql.Named("p_tanggal", in.tanggal),
		sql.Named("p_jam_dari", in.jamDari),
		sql.Named("p_jam_sampai", in.jamSampai),
		sql.Named("p_reason", in.reason),
	)
	if !keluarKantorLast {
		args = append(args, sql.Named("p_keluar_kantor", in.keluarKantor))
	}
	args = append(args,
		sql.Named("p_cre_ip_address", in.creIP),
		sql.Named("p_cre_by", in.creBy),
		sql.Named("p_cre_date", essLemburCreDate(r)),
	)
	if keluarKantorLast {
		args = append(args, sql.Named("p_keluar_kantor", in.keluarKantor))
	}
	return args
}

func ESSGetLembur(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	fromDate := essRequestParam(r, "fromDate", "from_date", "p_from_date")
	toDate := essRequestParam(r, "toDate", "to_date", "p_to_date")
	nik := essRequestParam(r, "nik", "p_nik", "user")

	if fromDate == "" || toDate == "" || nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "fromDate, toDate, and nik are required")
		return
	}

	if !pingESSDB(w, ctx, "ESS lembur get") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSLemburGetrows,
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
		sql.Named("p_nik", nik),
	)
	if err != nil {
		log.Printf("ESS lembur get SP error: %s | rawQuery=%s | nik=%q from=%s to=%s",
			err.Error(), r.URL.RawQuery, nik, fromDate, toDate)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute lembur get")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSCreateLembur(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	in := essLemburWriteParams(r)
	if in.nik == "" || in.kategori == "" || in.tanggal == "" || in.jamDari == "" || in.jamSampai == "" || in.reason == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik, kategori, tanggal, jamDari, jamSampai, and reason are required")
		return
	}

	if !pingESSDB(w, ctx, "ESS lembur insert") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSLemburInsert, essLemburNamedArgs(in, r, "", false)...)
	if err != nil {
		log.Println("ESS lembur insert SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute lembur insert")
		return
	}

	notifyESSPengajuanFromJSON(jsonResult, "lembur")
	writeESSSPJSON(w, jsonResult, false)
}

func ESSUpdateLembur(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodPut {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	id := essRequestParam(r, "id", "p_id")
	in := essLemburWriteParams(r)
	if id == "" || in.nik == "" || in.kategori == "" || in.tanggal == "" || in.jamDari == "" || in.jamSampai == "" || in.reason == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "id, nik, kategori, tanggal, jamDari, jamSampai, and reason are required")
		return
	}

	if !pingESSDB(w, ctx, "ESS lembur update") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSLemburUpdate, essLemburNamedArgs(in, r, id, true)...)
	if err != nil {
		log.Println("ESS lembur update SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute lembur update")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSDeleteLembur(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodDelete {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	id := essRequestParam(r, "id", "p_id")
	if id == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "id is required")
		return
	}

	if !pingESSDB(w, ctx, "ESS lembur delete") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSLemburDelete,
		sql.Named("p_id", id),
	)
	if err != nil {
		log.Println("ESS lembur delete SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute lembur delete")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSGetMasterHoliday(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	tahun := essRequestParam(r, "tahun", "year", "p_tahun")
	if tahun == "" {
		tahun = strconv.Itoa(time.Now().Year())
	}
	if _, err := strconv.Atoi(tahun); err != nil || len(tahun) != 4 {
		writeESSError(w, http.StatusBadRequest, "4000001", "tahun must be a 4-digit year")
		return
	}

	if !pingESSDB(w, ctx, "ESS master holiday get") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSMasterHolidayGetrows,
		sql.Named("p_tahun", tahun),
	)
	if err != nil {
		log.Printf("ESS master holiday get SP error: %s | tahun=%q", err.Error(), tahun)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute master holiday get")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

// --- Asset ---

func ESSGetAssetItem(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	dept := essDecodeParam(essRequestParam(r, "dept", "departemen", "p_dept"))
	if dept == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "dept is required")
		return
	}

	if !pingESSDB(w, ctx, "ESS asset item get") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSAssetItemGetrows,
		sql.Named("p_dept", dept),
	)
	if err != nil {
		log.Printf("ESS asset item get SP error: %s | dept=%q", err.Error(), dept)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute asset item get")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

// --- Dinas ---

func ESSGetDinas(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	nik := essRequestParam(r, "nik", "nikstr", "p_nikstr", "p_nik", "user")
	fromDate := essRequestParam(r, "fromDate", "from_date", "p_from_date")
	toDate := essRequestParam(r, "toDate", "to_date", "p_to_date")
	status := essNormalizeKategori(essRequestParam(r, "status", "p_status"))

	if nik == "" || fromDate == "" || toDate == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik, fromDate, and toDate are required")
		return
	}
	if status == "" {
		status = "ALL"
	}

	if !pingESSDB(w, ctx, "ESS dinas get") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSDinasGetrows,
		sql.Named("p_nikstr", nik),
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
		sql.Named("p_status", status),
	)
	if err != nil {
		log.Printf("ESS dinas get SP error: %s | rawQuery=%s | nik=%q status=%q from=%s to=%s",
			err.Error(), r.URL.RawQuery, nik, status, fromDate, toDate)
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to execute dinas get")
		return
	}

	writeESSSPJSON(w, jsonResult, false)
}

func ESSCreateDinas(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "dinas:post", SPESSDinasInsert)
}

func ESSUpdateDinas(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "dinas:put", SPESSDinasUpdate)
}

// --- Rekap ---

func ESSRekapAbsensi(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "rekap/absensi", SPESSRekapAbsensiGetrows)
}

func ESSRekapCuti(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "rekap/cuti", SPESSRekapCutiGetrows)
}
