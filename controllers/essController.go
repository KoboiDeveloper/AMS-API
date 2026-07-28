package controllers

import (
	"GOamsAPI/database"
	"GOamsAPI/middleware"
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
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
	SPESSLogin              = "xsp_api_ess_login"
	SPESSResetPassword      = "xsp_api_ess_reset_password"
	SPESSChangePassword     = "xsp_api_ess_change_password"
	SPESSUserChangePassword = "xsp_api_ess_user_change_password"

	SPESSDashboardInfoGetrow = "xsp_api_ess_dashboard_info_getrow"
	SPESSAttendanceGetrows   = "xsp_api_ess_attendance_getrows"
	SPESSProfileGetrow       = "xsp_api_ess_profile_getrow"
	SPESSProfileUpdate       = "xsp_api_ess_profile_update"

	SPESSIzinGetrows = "xsp_api_ess_izin_getrows"
	SPESSIzinInsert  = "xsp_api_ess_izin_insert"
	SPESSIzinUpdate  = "xsp_api_ess_izin_update"

	SPESSCutiGetrows = "xsp_api_ess_cuti_getrows"
	SPESSCutiInsert  = "xsp_api_ess_cuti_insert"
	SPESSCutiUpdate  = "xsp_api_ess_cuti_update"

	SPESSLemburGetrows = "xsp_api_ess_lembur_getrows"
	SPESSLemburInsert  = "xsp_api_ess_lembur_insert"
	SPESSLemburUpdate  = "xsp_api_ess_lembur_update"

	SPESSDinasGetrows = "xsp_api_ess_dinas_getrows"
	SPESSDinasInsert  = "xsp_api_ess_dinas_insert"
	SPESSDinasUpdate  = "xsp_api_ess_dinas_update"

	SPESSRekapAbsensiGetrows = "xsp_api_ess_rekap_absensi_getrows"
	SPESSRekapCutiGetrows    = "xsp_api_ess_rekap_cuti_getrows"

	SPESSUserOtpVerify = "xsp_api_ess_user_otp_verify"

	essEmailOTPURL    = "https://golangapi-j5iu.onrender.com/web/send-email-otp"
	essEmailOTPToken  = "d8a928b2043db77e340b523547bf16cb4aa483f0645fe0a290ed1f20aab76257"
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
	// Semua SP ESS berada di database RBACESS, bukan database utama (pos_server).
	rows, err := database.RbcaInstance.QueryContext(ctx, spName, args...)
	if err != nil {
		return "", err
	}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
		}
	}
	return jsonResultData, nil
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

func essEmailOTPTokenValue() string {
	if token := strings.TrimSpace(os.Getenv("ESS_EMAIL_OTP_TOKEN")); token != "" {
		return token
	}
	return essEmailOTPToken
}

func sendESSEmailOTP(email, otp string) error {
	payload := map[string]string{
		"email": email,
		"otp":   otp,
		"token": essEmailOTPTokenValue(),
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	resp, err := http.Post(essEmailOTPURL, "application/json", bytes.NewBuffer(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("send email otp failed: status %d body %s", resp.StatusCode, string(respBody))
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

func createESSToken(userID, userName string) (string, error) {
	expirationTime := time.Now().Add(14 * 24 * time.Hour)
	claims := &essClaims{
		UserID:   userID,
		UserName: userName,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
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

		tokenString, err := createESSToken(userID, userName)
		if err != nil {
			writeESSError(w, http.StatusInternalServerError, "5000006", "Could not create token")
			return
		}

		data, ok := result["data"].(map[string]interface{})
		if !ok {
			data = map[string]interface{}{}
		}
		data["token"] = tokenString
		result["data"] = data

		writeESSJSON(w, http.StatusOK, result)

	case "4002500":
		_ = middleware.RecordEssLoginFailure(ctx, essRedisClient, ip, uid)
		writeESSJSON(w, http.StatusUnauthorized, result)

	default:
		writeESSJSON(w, http.StatusBadRequest, result)
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
			writeESSError(w, http.StatusInternalServerError, "5000005", "email missing in reset password response")
			return
		}

		// SP hanya mengembalikan data user/email. OTP digenerate di Go, lalu dikirim email
		// dan disimpan Redis. Pastikan otp-verify juga validasi ke sumber yang sama.
		otp := GenerateOTP(6)
		if err := sendESSEmailOTP(email, otp); err != nil {
			log.Println("ESS reset password send OTP error:", err.Error())
			writeESSError(w, http.StatusInternalServerError, "5000006", "Failed to send OTP email")
			return
		}

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

	userID := strings.TrimSpace(r.FormValue("user_id"))
	if userID == "" {
		userID = strings.TrimSpace(r.FormValue("userId"))
	}
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
	writeESSNotImplemented(w, "user/change-password", SPESSUserChangePassword)
}

// --- Dashboard / Attendance / Profile ---

func ESSDashboardInfo(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "dashboard/info", SPESSDashboardInfoGetrow)
}

func ESSAttendance(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "attendance", SPESSAttendanceGetrows)
}

func ESSGetProfile(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "profile:get", SPESSProfileGetrow)
}

func ESSUpdateProfile(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "profile:put", SPESSProfileUpdate)
}

// --- Izin ---

func ESSGetIzin(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "izin:get", SPESSIzinGetrows)
}

func ESSCreateIzin(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "izin:post", SPESSIzinInsert)
}

func ESSUpdateIzin(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "izin:put", SPESSIzinUpdate)
}

// --- Cuti ---

func ESSGetCuti(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "cuti:get", SPESSCutiGetrows)
}

func ESSCreateCuti(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "cuti:post", SPESSCutiInsert)
}

func ESSUpdateCuti(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "cuti:put", SPESSCutiUpdate)
}

// --- Lembur ---

func ESSGetLembur(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "lembur:get", SPESSLemburGetrows)
}

func ESSCreateLembur(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "lembur:post", SPESSLemburInsert)
}

func ESSUpdateLembur(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "lembur:put", SPESSLemburUpdate)
}

// --- Dinas ---

func ESSGetDinas(w http.ResponseWriter, r *http.Request) {
	writeESSNotImplemented(w, "dinas:get", SPESSDinasGetrows)
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
