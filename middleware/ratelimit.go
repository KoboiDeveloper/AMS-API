package middleware

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
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
)

type rateLimitResponse struct {
	ResponseCode string `json:"responseCode"`
	Message      string `json:"message"`
}

// MemberIDRateLimit membatasi request per memberID berdasarkan scope endpoint.
func MemberIDRateLimit(redisClient *redis.Client, scope, message string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if err := r.ParseForm(); err != nil {
				logrus.WithError(err).Warnf("member rate limit (%s): failed to parse form, allowing request", scope)
				next.ServeHTTP(w, r)
				return
			}

			memberID := strings.TrimSpace(r.FormValue("memberID"))
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

// MemberVoucherRateLimit membatasi redeem voucher per memberID.
func MemberVoucherRateLimit(redisClient *redis.Client) func(http.Handler) http.Handler {
	return MemberIDRateLimit(redisClient, "voucher:redeem", "Terlalu banyak permintaan redeem. Coba lagi nanti.")
}

// MemberMissionJoinRateLimit membatasi join mission per memberID.
func MemberMissionJoinRateLimit(redisClient *redis.Client) func(http.Handler) http.Handler {
	return MemberIDRateLimit(redisClient, "mission:join", "Terlalu banyak permintaan join mission. Coba lagi nanti.")
}

// CatalogStockRateLimit membatasi akses endpoint catalog stock per IP.
// Normal: 60 req/menit. Bot/suspicious: 10 req/menit. User-Agent kosong diblokir.
func CatalogStockRateLimit(redisClient *redis.Client) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := clientIP(r)
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

func clientIP(r *http.Request) string {
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
