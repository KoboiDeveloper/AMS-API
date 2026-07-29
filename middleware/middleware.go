package middleware

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"

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

// essAbsensiAPIKey default key untuk endpoint absensi log (bisa override via ESS_ABSENSI_API_KEY).
const essAbsensiAPIKeyDefault = "d8a928b2043db77e340b523547bf16cb4aa483f0645fe0a290ed1f20aab76257"

func essAbsensiAPIKey() string {
	if key := strings.TrimSpace(os.Getenv("ESS_ABSENSI_API_KEY")); key != "" {
		return key
	}
	return essAbsensiAPIKeyDefault
}

// EssAPIKeyMiddleware melindungi endpoint public tanpa JWT — wajib header X-API-Key.
func EssAPIKeyMiddleware(next http.Handler) http.Handler {
	expected := essAbsensiAPIKey()
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := strings.TrimSpace(r.Header.Get("X-API-Key"))
		if key == "" {
			writeRbcaAuthError(w, http.StatusUnauthorized, "4010003", "X-API-Key header required")
			return
		}
		if key != expected {
			writeRbcaAuthError(w, http.StatusUnauthorized, "4010004", "Invalid API key")
			return
		}
		next.ServeHTTP(w, r)
	})
}
