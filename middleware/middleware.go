package middleware

import (
	"GOamsAPI/database"
	"context"
	"crypto/subtle"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v4"
)

func writeRbcaAuthError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"responseCode":    code,
		"responseMessage": message,
	})
}

func RbcaJWTMiddleware(next http.Handler) http.Handler {
	jwtKey := []byte(os.Getenv("JWT_KEY"))

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := strings.TrimSpace(r.Header.Get("Authorization"))
		if authHeader == "" {
			writeRbcaAuthError(w, http.StatusUnauthorized, "4010002", "Authorization header required")
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		tokenString = strings.TrimSpace(tokenString)
		if tokenString == "" || tokenString == authHeader {
			writeRbcaAuthError(w, http.StatusUnauthorized, "4010003", "Bearer token required")
			return
		}

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method")
			}
			return jwtKey, nil
		})

		if err != nil || !token.Valid {
			writeRbcaAuthError(w, http.StatusUnauthorized, "4010004", "Invalid or expired token")
			return
		}

		next.ServeHTTP(w, r)
	})
}

func JWTMiddleware(next http.Handler) http.Handler {

	JwtKey := []byte(os.Getenv("JWT_KEY"))

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "Authorization header required", http.StatusUnauthorized)
			return
		}

		tokenString := strings.Replace(authHeader, "Bearer ", "", 1)

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, http.ErrNoCookie
			}
			return JwtKey, nil
		})

		if err != nil || !token.Valid {
			http.Error(w, "Invalid token", http.StatusUnauthorized)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// EssJWTMiddleware — JWT + cek sesi aktif di ESS_USER_LOGIN_SESSION (jika token punya jti).
// Token lama tanpa jti tetap diizinkan sampai expire.
func EssJWTMiddleware(next http.Handler) http.Handler {
	jwtKey := []byte(os.Getenv("JWT_KEY"))

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := strings.TrimSpace(r.Header.Get("Authorization"))
		if authHeader == "" {
			writeRbcaAuthError(w, http.StatusUnauthorized, "4010002", "Authorization header required")
			return
		}

		tokenString := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
		if tokenString == "" || tokenString == authHeader {
			tokenString = strings.TrimSpace(strings.TrimPrefix(authHeader, "bearer "))
		}
		if tokenString == "" {
			writeRbcaAuthError(w, http.StatusUnauthorized, "4010002", "Authorization header required")
			return
		}

		claims := jwt.MapClaims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method")
			}
			return jwtKey, nil
		})
		if err != nil || token == nil || !token.Valid {
			writeRbcaAuthError(w, http.StatusUnauthorized, "4010001", "Invalid token")
			return
		}

		jti, _ := claims["jti"].(string)
		jti = strings.TrimSpace(jti)
		userID, _ := claims["userId"].(string)
		userID = strings.TrimSpace(userID)
		if userID == "" {
			if sub, ok := claims["sub"].(string); ok {
				userID = strings.TrimSpace(sub)
			}
		}

		if jti != "" && userID != "" && database.RbcaInstance != nil {
			ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
			defer cancel()

			var active int
			err := database.RbcaInstance.QueryRowContext(ctx, `
SELECT TOP 1 1
FROM dbo.ESS_USER_LOGIN_SESSION WITH (NOLOCK)
WHERE ID = @p_id
  AND USER_ID = @p_user_id
  AND IS_ACTIVE = 1
  AND EXPIRES_AT > SYSUTCDATETIME()`,
				sql.Named("p_id", jti),
				sql.Named("p_user_id", userID),
			).Scan(&active)
			if err == sql.ErrNoRows {
				writeRbcaAuthError(w, http.StatusUnauthorized, "4012700", "Session revoked or expired. Please login again.")
				return
			}
			if err != nil {
				// Jangan kunci semua user jika tabel belum ada / DB hiccup.
				log.Println("ESS session check error:", err.Error())
			}
		}

		next.ServeHTTP(w, r)
	})
}

// essAbsensiAPIKey default key untuk endpoint absensi log (bisa override via ESS_ABSENSI_API_KEY).
const essAbsensiAPIKeyDefault = "d8a928b2043db77e340b523547bf16cb4aa483f0645fe0a290ed1f20aab76257"

// employeeNikAPIKeyDefault key untuk endpoint cek NIK karyawan (bisa override via EMPLOYEE_NIK_API_KEY).
const employeeNikAPIKeyDefault = "2aff63d7bf434415e80ad9de5206ee9b977f259e87db99ef3403842584a45c9a"

func envOrDefault(envKey, fallback string) string {
	if key := strings.TrimSpace(os.Getenv(envKey)); key != "" {
		return key
	}
	return fallback
}

func essAbsensiAPIKey() string {
	return envOrDefault("ESS_ABSENSI_API_KEY", essAbsensiAPIKeyDefault)
}

func employeeNikAPIKey() string {
	return envOrDefault("EMPLOYEE_NIK_API_KEY", employeeNikAPIKeyDefault)
}

func apiKeyMatches(provided, expected string) bool {
	a := []byte(provided)
	b := []byte(expected)
	if len(a) != len(b) {
		return false
	}
	return subtle.ConstantTimeCompare(a, b) == 1
}

func requireAPIKey(expected string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := strings.TrimSpace(r.Header.Get("X-API-Key"))
		if key == "" {
			writeRbcaAuthError(w, http.StatusUnauthorized, "4010003", "X-API-Key header required")
			return
		}
		if !apiKeyMatches(key, expected) {
			writeRbcaAuthError(w, http.StatusUnauthorized, "4010004", "Invalid API key")
			return
		}
		next.ServeHTTP(w, r)
	})
}

// EssAPIKeyMiddleware melindungi endpoint public tanpa JWT — wajib header X-API-Key.
func EssAPIKeyMiddleware(next http.Handler) http.Handler {
	return requireAPIKey(essAbsensiAPIKey(), next)
}

// EmployeeAPIKeyMiddleware melindungi endpoint cek NIK karyawan — wajib header X-API-Key.
func EmployeeAPIKeyMiddleware(next http.Handler) http.Handler {
	return requireAPIKey(employeeNikAPIKey(), next)
}
