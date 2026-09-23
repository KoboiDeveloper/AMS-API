package controllers

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
	"unicode"

	webpush "github.com/SherClockHolmes/webpush-go"
)

const (
	SPESSPushSubscribe            = "xsp_api_ess_push_subscribe"
	SPESSPushUnsubscribe          = "xsp_api_ess_push_unsubscribe"
	SPESSPushSubscriptionsGetrows = "xsp_api_ess_push_subscriptions_getrows"
	SPESSNotificationInsert       = "xsp_api_ess_notification_insert"
	SPESSNotificationGetrows      = "xsp_api_ess_notification_getrows"
	SPESSNotificationRead         = "xsp_api_ess_notification_read"
	SPESSNotificationReadAll      = "xsp_api_ess_notification_read_all"
	SPESSUserNikByEmail           = "xsp_api_ess_user_nik_by_email"
)

// Env: VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT (mailto:ops@example.com)

type essPushMessage struct {
	Title      string
	Body       string
	TargetURL  string
	Category   string
	Tag        string
	SenderNIK  string
	Metadata   map[string]interface{}
	Recipients []string
}

type essPushSubscriptionRow struct {
	ID       int64  `json:"id"`
	NIK      string `json:"nik"`
	Endpoint string `json:"endpoint"`
	P256dh   string `json:"p256dh"`
	Auth     string `json:"auth"`
}

func essVAPIDPublicKey() string {
	return strings.TrimSpace(os.Getenv("VAPID_PUBLIC_KEY"))
}

func essVAPIDPrivateKey() string {
	return strings.TrimSpace(os.Getenv("VAPID_PRIVATE_KEY"))
}

func essVAPIDSubject() string {
	s := strings.TrimSpace(os.Getenv("VAPID_SUBJECT"))
	if s == "" {
		return "mailto:ess@amscorp.id"
	}
	return s
}

func essLooksLikeNIK(raw string) bool {
	s := strings.TrimSpace(raw)
	if s == "" || len(s) > 20 || strings.Contains(s, "@") || strings.Contains(s, " ") {
		return false
	}
	digits := 0
	for _, r := range s {
		if unicode.IsDigit(r) {
			digits++
			continue
		}
		if !unicode.IsLetter(r) && r != '-' && r != '_' {
			return false
		}
	}
	return digits >= 4
}

func essCollectApproverNIKs(data map[string]interface{}) []string {
	out := []string{}
	seen := map[string]struct{}{}
	add := func(raw string) {
		nik := strings.TrimSpace(raw)
		if !essLooksLikeNIK(nik) {
			return
		}
		key := strings.ToLower(nik)
		if _, ok := seen[key]; ok {
			return
		}
		seen[key] = struct{}{}
		out = append(out, nik)
	}
	add(essMapString(data, "nikSm", "nik_sm", "nikSM", "NikSm"))
	add(essMapString(data, "nikManager", "nik_manager", "NikManager"))
	add(essMapString(data, "nikApproval", "nik_approval", "nikApprover", "nik_approver"))
	dept := essMapString(data, "deptApproval", "dept_approval")
	if essLooksLikeNIK(dept) {
		add(dept)
	}
	return out
}

func essApplicantNIK(data map[string]interface{}) string {
	nik := essMapString(data, "nik", "nikstr", "p_nikstr", "userId", "user_id")
	if essLooksLikeNIK(nik) || strings.TrimSpace(nik) != "" {
		return strings.TrimSpace(nik)
	}
	return ""
}

func essLookupNIKByEmail(email string) string {
	email = strings.TrimSpace(strings.ToLower(email))
	if email == "" || !strings.Contains(email, "@") {
		return ""
	}
	jsonResult, err := runESSSPQuery(context.Background(), SPESSUserNikByEmail,
		sql.Named("p_email", email),
	)
	if err != nil || strings.TrimSpace(jsonResult) == "" {
		if err != nil {
			log.Printf("ESS nik-by-email lookup failed (%s): %v", email, err)
		}
		return ""
	}
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &payload); err != nil {
		return ""
	}
	if !essIsPengajuanSuccess(essMapString(payload, "responseCode")) {
		return ""
	}
	if data, ok := payload["data"].(map[string]interface{}); ok {
		return essMapString(data, "nik", "NIK", "userId")
	}
	return ""
}

func essResolveApproverNIKs(data map[string]interface{}) []string {
	niks := essCollectApproverNIKs(data)
	seen := map[string]struct{}{}
	for _, n := range niks {
		seen[strings.ToLower(n)] = struct{}{}
	}
	add := func(nik string) {
		nik = strings.TrimSpace(nik)
		if nik == "" {
			return
		}
		key := strings.ToLower(nik)
		if _, ok := seen[key]; ok {
			return
		}
		seen[key] = struct{}{}
		niks = append(niks, nik)
	}
	for _, email := range essCollectApproverEmails(data) {
		add(essLookupNIKByEmail(email))
	}
	return niks
}

func essResolveApplicantNIK(data map[string]interface{}) string {
	if nik := essApplicantNIK(data); nik != "" {
		return nik
	}
	return essLookupNIKByEmail(essApplicantEmail(data))
}

func essNotificationTargetURL(jenis, action string) string {
	j := strings.ToLower(strings.TrimSpace(jenis))
	switch strings.ToUpper(strings.TrimSpace(action)) {
	case "NEW", "CANCELLED":
		switch j {
		case "cuti":
			return "/dashboard/approval/cuti"
		case "lembur":
			return "/dashboard/approval/lembur"
		default:
			return "/dashboard/approval/izin"
		}
	default:
		switch j {
		case "cuti":
			return "/dashboard/cuti"
		case "lembur":
			return "/dashboard/lembur"
		default:
			return "/dashboard/izin"
		}
	}
}

func essKategoriLabel(jenis string, data map[string]interface{}) string {
	kat := essMapString(data, "kategori", "kategoriKhusus", "kategori_khusus")
	if kat != "" {
		return kat
	}
	return essJenisLabel(jenis)
}

func essDateLabel(jenis string, data map[string]interface{}) string {
	switch strings.ToLower(jenis) {
	case "cuti":
		return formatESSDateRange(
			essMapString(data, "tanggalDari", "tanggal_dari", "fromDate"),
			essMapString(data, "tanggalSampai", "tanggal_sampai", "toDate"),
		)
	case "lembur":
		t := essMapString(data, "tanggal", "tanggalLembur")
		if t == "" {
			return "hari ini"
		}
		return t
	default:
		return formatESSDateRange(
			essMapString(data, "fromDate", "from_date", "tanggalDari"),
			essMapString(data, "toDate", "to_date", "tanggalSampai"),
		)
	}
}

func essLemburHoursLabel(data map[string]interface{}) string {
	if n := essMapString(data, "totalJam", "total_jam", "jam", "durasi"); n != "" {
		return n
	}
	from := essMapString(data, "jamDari", "jam_dari")
	to := essMapString(data, "jamSampai", "jam_sampai")
	if from != "" && to != "" {
		return from + " – " + to
	}
	return ""
}

func essBuildPengajuanPush(jenis string, data map[string]interface{}) essPushMessage {
	nama := essMapString(data, "nama", "name", "namaLengkap", "nama_lengkap", "nickName")
	if nama == "" {
		nama = essApplicantNIK(data)
	}
	if nama == "" {
		nama = "Pegawai"
	}
	kat := essKategoriLabel(jenis, data)
	dates := essDateLabel(jenis, data)
	id := essMapString(data, "id")
	label := essJenisLabel(jenis)

	title := fmt.Sprintf("Pengajuan %s Baru", label)
	body := fmt.Sprintf("%s mengajukan %s (%s). Perlu persetujuan Anda.", nama, kat, dates)
	if strings.EqualFold(jenis, "lembur") {
		title = "Pengajuan Lembur Menunggu Approval"
		hours := essLemburHoursLabel(data)
		if hours != "" {
			body = fmt.Sprintf("%s mengajukan lembur (%s) pada %s.", nama, hours, dates)
		} else {
			body = fmt.Sprintf("%s mengajukan lembur pada %s.", nama, dates)
		}
	}

	return essPushMessage{
		Title:      title,
		Body:       body,
		TargetURL:  essNotificationTargetURL(jenis, "NEW"),
		Category:   "APPROVAL",
		Tag:        fmt.Sprintf("new-%s-%s", strings.ToLower(jenis), id),
		SenderNIK:  essApplicantNIK(data),
		Recipients: essResolveApproverNIKs(data),
		Metadata: map[string]interface{}{
			"id":     id,
			"type":   strings.ToUpper(jenis),
			"action": "NEW",
		},
	}
}

func essBuildApprovalPush(jenis, tipeApprove string, data map[string]interface{}) essPushMessage {
	approved := essIsApproveAction(tipeApprove)
	rejected := essIsRejectAction(tipeApprove)
	if !approved && !rejected {
		approved = true
	}
	id := essMapString(data, "id")
	label := essJenisLabel(jenis)
	kat := essKategoriLabel(jenis, data)
	atasan := essMapString(data, "namaAtasan", "nama_atasan", "approverName", "approver_name", "namaApprover")
	alasan := essMapString(data, "alasanPenolakan", "alasan_penolakan", "rejectReason")
	dates := essDateLabel(jenis, data)

	action := "APPROVED"
	title := fmt.Sprintf("Pengajuan %s Disetujui ✅", label)
	body := fmt.Sprintf("Pengajuan %s Anda telah disetujui.", kat)
	if atasan != "" {
		body = fmt.Sprintf("Pengajuan %s Anda telah disetujui oleh %s.", kat, atasan)
	}

	if rejected {
		action = "REJECTED"
		title = "Pengajuan Ditolak ❌"
		body = fmt.Sprintf("Pengajuan %s Anda ditolak.", label)
		if alasan != "" {
			body = fmt.Sprintf("Pengajuan %s Anda ditolak. Catatan: %s.", label, alasan)
		}
	}

	if strings.EqualFold(jenis, "lembur") {
		title = "Status Lembur Diperbarui"
		statusWord := "disetujui"
		if rejected {
			statusWord = "ditolak"
		}
		body = fmt.Sprintf("Pengajuan lembur Anda untuk tgl %s telah %s.", dates, statusWord)
		if rejected && alasan != "" {
			body = body + " Catatan: " + alasan + "."
		}
	}

	return essPushMessage{
		Title:      title,
		Body:       body,
		TargetURL:  essNotificationTargetURL(jenis, action),
		Category:   "APPROVAL",
		Tag:        fmt.Sprintf("%s-%s-%s", strings.ToLower(action), strings.ToLower(jenis), id),
		SenderNIK:  essMapString(data, "nikApprover", "nik_approver", "nikAtasan", "nik_atasan"),
		Recipients: filterNonEmpty([]string{essResolveApplicantNIK(data)}),
		Metadata: map[string]interface{}{
			"id":     id,
			"type":   strings.ToUpper(jenis),
			"action": action,
		},
	}
}

func essBuildCancelPush(jenis string, data map[string]interface{}) essPushMessage {
	nama := essMapString(data, "nama", "name", "namaLengkap", "nama_lengkap", "nickName")
	if nama == "" {
		nama = essApplicantNIK(data)
	}
	if nama == "" {
		nama = "Pegawai"
	}
	dates := essDateLabel(jenis, data)
	id := essMapString(data, "id")
	label := strings.ToLower(essJenisLabel(jenis))

	return essPushMessage{
		Title:      "Pengajuan Dibatalkan",
		Body:       fmt.Sprintf("%s telah membatalkan pengajuan %s tanggal %s.", nama, label, dates),
		TargetURL:  essNotificationTargetURL(jenis, "CANCELLED"),
		Category:   "APPROVAL",
		Tag:        fmt.Sprintf("cancelled-%s-%s", strings.ToLower(jenis), id),
		SenderNIK:  essApplicantNIK(data),
		Recipients: essResolveApproverNIKs(data),
		Metadata: map[string]interface{}{
			"id":     id,
			"type":   strings.ToUpper(jenis),
			"action": "CANCELLED",
		},
	}
}

func filterNonEmpty(in []string) []string {
	out := []string{}
	for _, s := range in {
		if strings.TrimSpace(s) != "" {
			out = append(out, strings.TrimSpace(s))
		}
	}
	return out
}

func essDispatchPush(msg essPushMessage) {
	if len(msg.Recipients) == 0 {
		log.Printf("ESS push skip: no recipient NIK title=%q", msg.Title)
		return
	}

	metaJSON := ""
	if msg.Metadata != nil {
		if b, err := json.Marshal(msg.Metadata); err == nil {
			metaJSON = string(b)
		}
	}

	for _, nik := range msg.Recipients {
		notifID := essInsertNotificationRow(nik, msg.SenderNIK, msg.Category, msg.Title, msg.Body, msg.TargetURL, metaJSON)
		essSendWebPushToNIK(nik, notifID, msg)
	}
}

func essInsertNotificationRow(nik, sender, category, title, body, targetURL, metadata string) int64 {
	jsonResult, err := runESSSPQuery(context.Background(), SPESSNotificationInsert,
		sql.Named("p_nik", nik),
		sql.Named("p_sender_nik", sender),
		sql.Named("p_category", category),
		sql.Named("p_title", title),
		sql.Named("p_body", body),
		sql.Named("p_target_url", targetURL),
		sql.Named("p_metadata", metadata),
	)
	if err != nil {
		log.Printf("ESS notification insert failed nik=%s: %v", nik, err)
		return 0
	}
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &payload); err != nil {
		return 0
	}
	data, _ := payload["data"].(map[string]interface{})
	if data == nil {
		return 0
	}
	raw := essMapString(data, "id")
	id, _ := strconv.ParseInt(raw, 10, 64)
	return id
}

func essLoadPushSubscriptions(nik string) []essPushSubscriptionRow {
	jsonResult, err := runESSSPQuery(context.Background(), SPESSPushSubscriptionsGetrows,
		sql.Named("p_nik", nik),
	)
	if err != nil || strings.TrimSpace(jsonResult) == "" {
		if err != nil {
			log.Printf("ESS load push subscriptions failed nik=%s: %v", nik, err)
		}
		return nil
	}
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &payload); err != nil {
		return nil
	}
	raw, _ := payload["data"]
	b, err := json.Marshal(raw)
	if err != nil {
		return nil
	}
	var rows []essPushSubscriptionRow
	if err := json.Unmarshal(b, &rows); err != nil {
		return nil
	}
	return rows
}

func essSendWebPushToNIK(nik string, notifID int64, msg essPushMessage) {
	pub := essVAPIDPublicKey()
	priv := essVAPIDPrivateKey()
	if pub == "" || priv == "" {
		log.Printf("ESS web-push skipped nik=%s: VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY not set", nik)
		return
	}

	subs := essLoadPushSubscriptions(nik)
	if len(subs) == 0 {
		log.Printf("ESS web-push skip nik=%s: no subscriptions", nik)
		return
	}

	payload := map[string]interface{}{
		"notification": map[string]interface{}{
			"title":    msg.Title,
			"body":     msg.Body,
			"icon":     "/icons/icon-192x192.png",
			"badge":    "/icons/badge-72x72.png",
			"tag":      msg.Tag,
			"renotify": true,
			"vibrate":  []int{100, 50, 100},
			"data": map[string]interface{}{
				"url":      msg.TargetURL,
				"id":       notifID,
				"category": msg.Category,
			},
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		log.Println("ESS web-push marshal error:", err.Error())
		return
	}

	for _, sub := range subs {
		resp, sendErr := webpush.SendNotification(body, &webpush.Subscription{
			Endpoint: sub.Endpoint,
			Keys: webpush.Keys{
				Auth:   sub.Auth,
				P256dh: sub.P256dh,
			},
		}, &webpush.Options{
			Subscriber:      essVAPIDSubject(),
			VAPIDPublicKey:  pub,
			VAPIDPrivateKey: priv,
			TTL:             60 * 60 * 4,
		})
		if sendErr != nil {
			log.Printf("ESS web-push send error nik=%s: %v", nik, sendErr)
			continue
		}
		status := 0
		if resp != nil {
			status = resp.StatusCode
			_, _ = io.Copy(io.Discard, resp.Body)
			_ = resp.Body.Close()
		}
		if status == 404 || status == 410 {
			log.Printf("ESS web-push stale subscription nik=%s status=%d — removing", nik, status)
			_, _ = runESSSPQuery(context.Background(), SPESSPushUnsubscribe,
				sql.Named("p_endpoint", sub.Endpoint),
				sql.Named("p_nik", nik),
			)
			continue
		}
		if status >= 300 {
			log.Printf("ESS web-push failed nik=%s status=%d", nik, status)
			continue
		}
		log.Printf("ESS web-push sent nik=%s status=%d title=%q", nik, status, msg.Title)
	}
}
