package controllers

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/gorilla/mux"
)

func essNotificationNIK(r *http.Request) string {
	nik := strings.TrimSpace(essRequestParam(r,
		"nik", "nikstr", "p_nikstr", "p_nik", "user", "user_id", "userId", "uid",
	))
	if nik == "" {
		if claims, err := parseESSAuthClaims(r); err == nil && claims != nil {
			nik = strings.TrimSpace(claims.UserID)
		}
	}
	return nik
}

func essSubscribeKeys(r *http.Request) (endpoint, p256dh, auth string) {
	endpoint = strings.TrimSpace(essRequestParam(r, "endpoint"))
	p256dh = strings.TrimSpace(essRequestParam(r, "p256dh", "keys.p256dh"))
	auth = strings.TrimSpace(essRequestParam(r, "auth", "keys.auth"))

	body := essJSONBody(r)
	if body == nil {
		return endpoint, p256dh, auth
	}
	if endpoint == "" {
		endpoint = essMapString(body, "endpoint")
	}
	if keys, ok := body["keys"].(map[string]interface{}); ok {
		if p256dh == "" {
			p256dh = essMapString(keys, "p256dh", "P256DH")
		}
		if auth == "" {
			auth = essMapString(keys, "auth", "AUTH")
		}
	}
	if p256dh == "" {
		p256dh = essMapString(body, "p256dh")
	}
	if auth == "" {
		auth = essMapString(body, "auth")
	}
	return endpoint, p256dh, auth
}

// ESSGetVAPIDPublicKey — public key untuk browser PushManager.subscribe
func ESSGetVAPIDPublicKey(w http.ResponseWriter, r *http.Request) {
	key := essVAPIDPublicKey()
	if key == "" {
		writeESSError(w, http.StatusInternalServerError, "5000003", "VAPID_PUBLIC_KEY is not configured")
		return
	}
	writeESSJSON(w, http.StatusOK, map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "ok",
		"data": map[string]string{
			"publicKey": key,
		},
	})
}

// ESSSubscribePush — daftar / update Web Push subscription
func ESSSubscribePush(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	nik := essNotificationNIK(r)
	endpoint, p256dh, auth := essSubscribeKeys(r)
	userAgent := strings.TrimSpace(r.UserAgent())
	if len(userAgent) > 255 {
		userAgent = userAgent[:255]
	}

	if nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik is required")
		return
	}
	if endpoint == "" || p256dh == "" || auth == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "endpoint, keys.p256dh, and keys.auth are required")
		return
	}

	ctx := context.Background()
	if !pingESSDB(w, ctx, "ESS push subscribe") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSPushSubscribe,
		sql.Named("p_nik", nik),
		sql.Named("p_endpoint", endpoint),
		sql.Named("p_p256dh", p256dh),
		sql.Named("p_auth", auth),
		sql.Named("p_user_agent", userAgent),
	)
	if err != nil {
		log.Println("ESS push subscribe SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to save push subscription")
		return
	}
	writeESSSPJSON(w, jsonResult, false)
}

// ESSUnsubscribePush — hapus subscription saat logout / izin dimatikan
func ESSUnsubscribePush(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	endpoint, _, _ := essSubscribeKeys(r)
	if endpoint == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "endpoint is required")
		return
	}
	nik := essNotificationNIK(r)

	ctx := context.Background()
	if !pingESSDB(w, ctx, "ESS push unsubscribe") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSPushUnsubscribe,
		sql.Named("p_endpoint", endpoint),
		sql.Named("p_nik", nik),
	)
	if err != nil {
		log.Println("ESS push unsubscribe SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to remove push subscription")
		return
	}
	writeESSSPJSON(w, jsonResult, false)
}

// ESSGetNotifications — histori drawer
func ESSGetNotifications(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	nik := essNotificationNIK(r)
	if nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik is required")
		return
	}

	page, _ := strconv.Atoi(strings.TrimSpace(essRequestParam(r, "page")))
	limit, _ := strconv.Atoi(strings.TrimSpace(essRequestParam(r, "limit")))
	unreadRaw := strings.ToLower(strings.TrimSpace(essRequestParam(r, "unread_only", "unreadOnly")))
	unreadOnly := unreadRaw == "1" || unreadRaw == "true" || unreadRaw == "yes"

	ctx := context.Background()
	if !pingESSDB(w, ctx, "ESS notification list") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSNotificationGetrows,
		sql.Named("p_nik", nik),
		sql.Named("p_page", page),
		sql.Named("p_limit", limit),
		sql.Named("p_unread_only", unreadOnly),
	)
	if err != nil {
		log.Println("ESS notification list SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to load notifications")
		return
	}
	writeESSSPJSON(w, jsonResult, false)
}

// ESSReadNotification — tandai satu notifikasi dibaca
func ESSReadNotification(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut && r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	idRaw := strings.TrimSpace(mux.Vars(r)["id"])
	if idRaw == "" {
		idRaw = strings.TrimSpace(essRequestParam(r, "id", "p_id"))
	}
	id, err := strconv.ParseInt(idRaw, 10, 64)
	if err != nil || id <= 0 {
		writeESSError(w, http.StatusBadRequest, "4000001", "id is required")
		return
	}

	nik := essNotificationNIK(r)
	if nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik is required")
		return
	}

	ctx := context.Background()
	if !pingESSDB(w, ctx, "ESS notification read") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSNotificationRead,
		sql.Named("p_id", id),
		sql.Named("p_nik", nik),
	)
	if err != nil {
		log.Println("ESS notification read SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to mark notification read")
		return
	}
	writeESSSPJSON(w, jsonResult, false)
}

// ESSReadAllNotifications — tandai semua notifikasi user dibaca
func ESSReadAllNotifications(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut && r.Method != http.MethodPost {
		writeESSError(w, http.StatusMethodNotAllowed, "4050001", "Method not allowed")
		return
	}

	nik := essNotificationNIK(r)
	if nik == "" {
		writeESSError(w, http.StatusBadRequest, "4000001", "nik is required")
		return
	}

	ctx := context.Background()
	if !pingESSDB(w, ctx, "ESS notification read-all") {
		return
	}

	jsonResult, err := runESSSPQuery(ctx, SPESSNotificationReadAll,
		sql.Named("p_nik", nik),
	)
	if err != nil {
		log.Println("ESS notification read-all SP error:", err.Error())
		writeESSError(w, http.StatusInternalServerError, "5000002", "Failed to mark notifications read")
		return
	}
	writeESSSPJSON(w, jsonResult, false)
}
