package middleware

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/mssola/user_agent"
	"github.com/sirupsen/logrus"
)

const (
	catalogStockNormalLimit     = 60
	catalogStockSuspiciousLimit = 10
	catalogStockWindow          = time.Minute

	memberActionLimit  = 1
	memberActionWindow = time.Minute

	memberLoginLimit  = 5
	memberLoginWindow = time.Minute

	essLoginFailedLimit  = 5
	essLoginFailedWindow = 15 * time.Minute

	essResetPasswordLimit  = 5
	essResetPasswordWindow = time.Minute

	essOtpVerifyFailedLimit  = 5
	essOtpVerifyFailedWindow = time.Minute
)

type rateLimitResponse struct {
	ResponseCode string `json:"responseCode"`
	Message      string `json:"message"`
}

// MemberIDRateLimit membatasi request per memberID berdasarkan scope endpoint.
func MemberIDRateLimit(redisClient *redis.Client, scope, message string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			memberID, err := memberIDFromRequest(r)
			if err != nil {
				logrus.WithError(err).Warnf("member rate limit (%s): failed to read memberID, allowing request", scope)
				next.ServeHTTP(w, r)
				return
			}

			if memberID == "" {
				next.ServeHTTP(w, r)
				return
			}

			key := fmt.Sprintf("ratelimit:member:%s:%s", scope, memberID)
			allowed, remaining, err := checkRateLimitByKey(r.Context(), redisClient, key, memberActionLimit, memberActionWindow)
			if err != nil {
				logrus.WithError(err).Warnf("member rate limit (%s) check failed, allowing request", scope)
				next.ServeHTTP(w, r)
				return
			}

			w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%d", memberActionLimit))
			w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))

			if !allowed {
				w.Header().Set("Retry-After", fmt.Sprintf("%d", int(memberActionWindow.Seconds())))
				writeRateLimitJSON(w, http.StatusTooManyRequests, "4294291", message)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// memberIDFromRequest membaca memberID tanpa memanggil ParseForm agar body tetap bisa dibaca handler.
func memberIDFromRequest(r *http.Request) (string, error) {
	if id := strings.TrimSpace(r.URL.Query().Get("memberID")); id != "" {
		return id, nil
	}

	return formFieldFromRequest(r, "memberID")
}

// essUIDFromRequest membaca uid/user login ESS tanpa mengonsumsi body agar handler tetap bisa membacanya.
func essUIDFromRequest(r *http.Request) (string, error) {
	if id := strings.TrimSpace(r.URL.Query().Get("uid")); id != "" {
		return id, nil
	}

	return formFieldFromRequest(r, "uid", "user")
}

// formFieldFromRequest membaca salah satu field form (urlencoded/multipart) tanpa
// menghabiskan body, sehingga handler berikutnya tetap bisa memanggil ParseForm/FormValue.
func formFieldFromRequest(r *http.Request, keys ...string) (string, error) {
	if r.Body == nil {
		return "", nil
	}

	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		return "", err
	}
	r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
	r.ContentLength = int64(len(bodyBytes))

	if len(bodyBytes) == 0 {
		return "", nil
	}

	ct := r.Header.Get("Content-Type")
	mediaType, _, err := mime.ParseMediaType(ct)
	if err != nil {
		mediaType = ""
	}

	var getValue func(string) string
	switch mediaType {
	case "multipart/form-data":
		if err := r.ParseMultipartForm(32 << 20); err != nil {
			return "", err
		}
		getValue = r.FormValue
	default:
		values, err := url.ParseQuery(string(bodyBytes))
		if err != nil {
			return "", nil
		}
		getValue = values.Get
	}

	for _, key := range keys {
		if v := strings.TrimSpace(getValue(key)); v != "" {
			return v, nil
		}
	}
	return "", nil
}

// MemberVoucherRateLimit membatasi redeem voucher per memberID.
func MemberVoucherRateLimit(redisClient *redis.Client) func(http.Handler) http.Handler {
	return MemberIDRateLimit(redisClient, "voucher:redeem", "Terlalu banyak permintaan redeem. Coba lagi nanti.")
}

// MemberVoucherCustomRateLimit membatasi redeem voucher custom per memberID.
func MemberVoucherCustomRateLimit(redisClient *redis.Client) func(http.Handler) http.Handler {
	return MemberIDRateLimit(redisClient, "voucher:redeem:custom", "Terlalu banyak permintaan redeem custom. Coba lagi nanti.")
}

// MemberMissionJoinRateLimit membatasi join mission per memberID.
func MemberMissionJoinRateLimit(redisClient *redis.Client) func(http.Handler) http.Handler {
	return MemberIDRateLimit(redisClient, "mission:join", "Terlalu banyak permintaan join mission. Coba lagi nanti.")
}

// MemberLoginRateLimit membatasi percobaan login per IP (5x/menit).
func MemberLoginRateLimit(redisClient *redis.Client) func(http.Handler) http.Handler {
	return IPRateLimit(redisClient, "member:login", memberLoginLimit, memberLoginWindow, "4294292", "Terlalu banyak percobaan login. Coba lagi nanti.")
}

// EssLoginFailedGuard memblokir login ESS jika IP ATAU uid yang dituju sudah gagal 5 kali.
func EssLoginFailedGuard(redisClient *redis.Client) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := ClientIP(r)

			blockedByIP, err := IsEssLoginBlocked(r.Context(), redisClient, ip)
			if err != nil {
				logrus.WithError(err).Warn("ess login failed guard check error (ip), allowing request")
				blockedByIP = false
			}

			uid, err := essUIDFromRequest(r)
			if err != nil {
				logrus.WithError(err).Warn("ess login failed guard: failed to read uid, skipping uid check")
				uid = ""
			}

			blockedByUID := false
			if uid != "" {
				blockedByUID, err = IsEssLoginBlockedByUID(r.Context(), redisClient, uid)
				if err != nil {
					logrus.WithError(err).Warn("ess login failed guard check error (uid), allowing request")
					blockedByUID = false
				}
			}

			if blockedByIP || blockedByUID {
				w.Header().Set("Retry-After", fmt.Sprintf("%d", int(essLoginFailedWindow.Seconds())))
				writeESSRateLimitJSON(w, http.StatusTooManyRequests, "4292500", "Too many failed login attempts. Try again later.")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// IsEssLoginBlocked mengecek apakah IP sudah mencapai batas gagal login.
func IsEssLoginBlocked(ctx context.Context, redisClient *redis.Client, ip string) (bool, error) {
	if redisClient == nil || strings.TrimSpace(ip) == "" {
		return false, nil
	}

	key := essLoginFailedKey(ip)
	count, err := redisClient.Get(ctx, key).Int()
	if err == redis.Nil {
		return false, nil
	}
	if err != nil {
		return false, err
	}

	return count >= essLoginFailedLimit, nil
}

// RecordEssLoginFailure menambah counter gagal login per IP.
func RecordEssLoginFailure(ctx context.Context, redisClient *redis.Client, ip string) error {
	if redisClient == nil || strings.TrimSpace(ip) == "" {
		return nil
	}

	key := essLoginFailedKey(ip)
	count, err := redisClient.Incr(ctx, key).Result()
	if err != nil {
		return err
	}

	if count == 1 {
		return redisClient.Expire(ctx, key, essLoginFailedWindow).Err()
	}

	return nil
}

// ClearEssLoginFailures menghapus counter gagal login setelah login sukses.
func ClearEssLoginFailures(ctx context.Context, redisClient *redis.Client, ip string) error {
	if redisClient == nil || strings.TrimSpace(ip) == "" {
		return nil
	}

	return redisClient.Del(ctx, essLoginFailedKey(ip)).Err()
}

func essLoginFailedKey(ip string) string {
	return fmt.Sprintf("ratelimit:ess:login:failed:%s", ip)
}

// IsEssLoginBlockedByUID mengecek apakah uid tujuan sudah mencapai batas gagal login,
// terlepas dari IP mana serangan brute-force berasal.
func IsEssLoginBlockedByUID(ctx context.Context, redisClient *redis.Client, uid string) (bool, error) {
	if redisClient == nil || strings.TrimSpace(uid) == "" {
		return false, nil
	}

	key := essLoginFailedKeyByUID(uid)
	count, err := redisClient.Get(ctx, key).Int()
	if err == redis.Nil {
		return false, nil
	}
	if err != nil {
		return false, err
	}

	return count >= essLoginFailedLimit, nil
}

// RecordEssLoginFailureByUID menambah counter gagal login per uid.
func RecordEssLoginFailureByUID(ctx context.Context, redisClient *redis.Client, uid string) error {
	if redisClient == nil || strings.TrimSpace(uid) == "" {
		return nil
	}

	key := essLoginFailedKeyByUID(uid)
	count, err := redisClient.Incr(ctx, key).Result()
	if err != nil {
		return err
	}

	if count == 1 {
		return redisClient.Expire(ctx, key, essLoginFailedWindow).Err()
	}

	return nil
}

// ClearEssLoginFailuresByUID menghapus counter gagal login per uid setelah login sukses.
func ClearEssLoginFailuresByUID(ctx context.Context, redisClient *redis.Client, uid string) error {
	if redisClient == nil || strings.TrimSpace(uid) == "" {
		return nil
	}

	return redisClient.Del(ctx, essLoginFailedKeyByUID(uid)).Err()
}

func essLoginFailedKeyByUID(uid string) string {
	return fmt.Sprintf("ratelimit:ess:login:failed:uid:%s", strings.ToLower(uid))
}

// EssOtpVerifyFailedGuard memblokir verifikasi OTP ESS jika IP sudah gagal 5 kali dalam 1 menit.
func EssOtpVerifyFailedGuard(redisClient *redis.Client) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := ClientIP(r)
			blocked, err := IsEssOtpVerifyBlocked(r.Context(), redisClient, ip)
			if err != nil {
				logrus.WithError(err).Warn("ess otp verify guard check error, allowing request")
				next.ServeHTTP(w, r)
				return
			}

			if blocked {
				w.Header().Set("Retry-After", fmt.Sprintf("%d", int(essOtpVerifyFailedWindow.Seconds())))
				writeESSRateLimitJSON(w, http.StatusTooManyRequests, "4292502", "Too many failed OTP verification attempts. Try again later.")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// IsEssOtpVerifyBlocked mengecek apakah IP sudah mencapai batas gagal verifikasi OTP.
func IsEssOtpVerifyBlocked(ctx context.Context, redisClient *redis.Client, ip string) (bool, error) {
	if redisClient == nil || strings.TrimSpace(ip) == "" {
		return false, nil
	}

	key := essOtpVerifyFailedKey(ip)
	count, err := redisClient.Get(ctx, key).Int()
	if err == redis.Nil {
		return false, nil
	}
	if err != nil {
		return false, err
	}

	return count >= essOtpVerifyFailedLimit, nil
}

// RecordEssOtpVerifyFailure menambah counter gagal verifikasi OTP per IP.
func RecordEssOtpVerifyFailure(ctx context.Context, redisClient *redis.Client, ip string) error {
	if redisClient == nil || strings.TrimSpace(ip) == "" {
		return nil
	}

	key := essOtpVerifyFailedKey(ip)
	count, err := redisClient.Incr(ctx, key).Result()
	if err != nil {
		return err
	}

	if count == 1 {
		return redisClient.Expire(ctx, key, essOtpVerifyFailedWindow).Err()
	}

	return nil
}

// ClearEssOtpVerifyFailures menghapus counter gagal verifikasi OTP setelah verifikasi sukses.
func ClearEssOtpVerifyFailures(ctx context.Context, redisClient *redis.Client, ip string) error {
	if redisClient == nil || strings.TrimSpace(ip) == "" {
		return nil
	}

	return redisClient.Del(ctx, essOtpVerifyFailedKey(ip)).Err()
}

func essOtpVerifyFailedKey(ip string) string {
	return fmt.Sprintf("ratelimit:ess:otp-verify:failed:%s", ip)
}

// EssResetPasswordRateLimit membatasi request reset password ESS per IP (5x/menit).
func EssResetPasswordRateLimit(redisClient *redis.Client) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := ClientIP(r)
			key := fmt.Sprintf("ratelimit:ess:reset-password:%s", ip)

			allowed, remaining, err := checkRateLimitByKey(r.Context(), redisClient, key, essResetPasswordLimit, essResetPasswordWindow)
			if err != nil {
				logrus.WithError(err).Warn("ess reset password rate limit check failed, allowing request")
				next.ServeHTTP(w, r)
				return
			}

			w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%d", essResetPasswordLimit))
			w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))

			if !allowed {
				w.Header().Set("Retry-After", fmt.Sprintf("%d", int(essResetPasswordWindow.Seconds())))
				writeESSRateLimitJSON(w, http.StatusTooManyRequests, "4292501", "Too many reset password requests. Try again later.")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

func writeESSRateLimitJSON(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"responseCode":    code,
		"responseMessage": message,
	})
}

// IPRateLimit membatasi request per IP berdasarkan scope endpoint.
func IPRateLimit(redisClient *redis.Client, scope string, limit int, window time.Duration, code, message string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := ClientIP(r)
			key := fmt.Sprintf("ratelimit:%s:%s", scope, ip)

			allowed, remaining, err := checkRateLimitByKey(r.Context(), redisClient, key, limit, window)
			if err != nil {
				logrus.WithError(err).Warnf("ip rate limit (%s) check failed, allowing request", scope)
				next.ServeHTTP(w, r)
				return
			}

			w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%d", limit))
			w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))

			if !allowed {
				w.Header().Set("Retry-After", fmt.Sprintf("%d", int(window.Seconds())))
				writeRateLimitJSON(w, http.StatusTooManyRequests, code, message)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// CatalogStockRateLimit membatasi akses endpoint catalog stock per IP.
// Normal: 60 req/menit. Bot/suspicious: 10 req/menit. User-Agent kosong diblokir.
func CatalogStockRateLimit(redisClient *redis.Client) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := ClientIP(r)
			userAgent := strings.TrimSpace(r.UserAgent())

			if userAgent == "" {
				writeRateLimitJSON(w, http.StatusForbidden, "4034291", "User-Agent header is required")
				return
			}

			limit := catalogStockNormalLimit
			tier := "normal"
			if isSuspiciousUserAgent(userAgent) {
				limit = catalogStockSuspiciousLimit
				tier = "suspicious"
			}

			allowed, remaining, err := checkRateLimit(r.Context(), redisClient, "catalog:stock", tier, ip, limit)
			if err != nil {
				logrus.WithError(err).Warn("catalog stock rate limit check failed, allowing request")
				next.ServeHTTP(w, r)
				return
			}

			w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%d", limit))
			w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))

			if !allowed {
				w.Header().Set("Retry-After", "60")
				writeRateLimitJSON(w, http.StatusTooManyRequests, "4294290", "Rate limit exceeded. Try again later.")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

func ClientIP(r *http.Request) string {
	if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
		parts := strings.Split(forwarded, ",")
		if ip := strings.TrimSpace(parts[0]); ip != "" {
			return ip
		}
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

func isSuspiciousUserAgent(ua string) bool {
	parsed := user_agent.New(ua)
	if parsed.Bot() {
		return true
	}

	lower := strings.ToLower(ua)
	suspiciousPatterns := []string{
		"curl/",
		"wget/",
		"python-requests",
		"python-urllib",
		"scrapy",
		"httpclient",
		"libwww-perl",
		"go-http-client",
		"java/",
		"axios/",
		"postman",
		"insomnia",
	}

	for _, pattern := range suspiciousPatterns {
		if strings.Contains(lower, pattern) {
			return true
		}
	}

	return false
}

func checkRateLimit(ctx context.Context, redisClient *redis.Client, scope, tier, ip string, limit int) (allowed bool, remaining int, err error) {
	key := fmt.Sprintf("ratelimit:%s:%s:%s", scope, tier, ip)
	return checkRateLimitByKey(ctx, redisClient, key, limit, catalogStockWindow)
}

func checkRateLimitByKey(ctx context.Context, redisClient *redis.Client, key string, limit int, window time.Duration) (allowed bool, remaining int, err error) {
	if redisClient == nil {
		return true, limit, nil
	}

	count, err := redisClient.Incr(ctx, key).Result()
	if err != nil {
		return false, 0, err
	}

	if count == 1 {
		if err := redisClient.Expire(ctx, key, window).Err(); err != nil {
			return false, 0, err
		}
	}

	if count > int64(limit) {
		return false, 0, nil
	}

	return true, limit - int(count), nil
}

func writeRateLimitJSON(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(rateLimitResponse{
		ResponseCode: code,
		Message:      message,
	})
}
