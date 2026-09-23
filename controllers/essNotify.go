package controllers

import (
	"GOamsAPI/brevo"
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"os"
	"strings"
	"sync"
	"time"
)

//go:embed ess_pengajuan_mail.html
var essPengajuanMailHTML string

//go:embed ess_otp_mail.html
var essOTPMailHTML string

//go:embed ess_approval_mail.html
var essApprovalMailHTML string

const defaultAMSLogoURL = "https://web.amscorp.id:3060/images/ams_logo_white.png"

var (
	essPengajuanTmplOnce sync.Once
	essPengajuanTmpl     *template.Template
	essPengajuanTmplErr  error
	essOTPTmplOnce       sync.Once
	essOTPTmpl           *template.Template
	essOTPTmplErr        error
	essApprovalTmplOnce  sync.Once
	essApprovalTmpl      *template.Template
	essApprovalTmplErr   error
	brevoClientOnce      sync.Once
	brevoClient          *brevo.Client
	brevoClientErr       error
)

type essDetailRow struct {
	Label string
	Value string
}

type essPengajuanMailData struct {
	LogoURL      string
	SubjectTitle string
	JenisLabel   string
	Status       string
	ID           string
	Year         int
	Rows         []essDetailRow
}

type essOTPMailData struct {
	LogoURL      string
	SubjectTitle string
	Title        string
	Intro        string
	OTP          string
	ValidMinutes int
	Year         int
}

type essApprovalMailData struct {
	LogoURL      string
	SubjectTitle string
	Headline     string
	Intro        string
	Nama         string
	Status       string
	ID           string
	Year         int
	AccentColor  string
	BadgeBg      string
	BadgeFg      string
	Rows         []essDetailRow
}

func getBrevoClient() (*brevo.Client, error) {
	brevoClientOnce.Do(func() {
		brevoClient, brevoClientErr = brevo.NewFromEnv()
	})
	// Jika init gagal (env belum ada), izinkan retry di request berikutnya.
	if brevoClientErr != nil {
		c, err := brevo.NewFromEnv()
		if err == nil {
			brevoClient = c
			brevoClientErr = nil
		}
		return brevoClient, brevoClientErr
	}
	return brevoClient, brevoClientErr
}

func loadESSPengajuanTemplate() (*template.Template, error) {
	essPengajuanTmplOnce.Do(func() {
		essPengajuanTmpl, essPengajuanTmplErr = template.New("ess_pengajuan").Parse(essPengajuanMailHTML)
	})
	return essPengajuanTmpl, essPengajuanTmplErr
}

func loadESSOTPTemplate() (*template.Template, error) {
	essOTPTmplOnce.Do(func() {
		essOTPTmpl, essOTPTmplErr = template.New("ess_otp").Parse(essOTPMailHTML)
	})
	return essOTPTmpl, essOTPTmplErr
}

func loadESSApprovalTemplate() (*template.Template, error) {
	essApprovalTmplOnce.Do(func() {
		essApprovalTmpl, essApprovalTmplErr = template.New("ess_approval").Parse(essApprovalMailHTML)
	})
	return essApprovalTmpl, essApprovalTmplErr
}

func essLogoURL() string {
	logoURL := strings.TrimSpace(os.Getenv("AMS_LOGO_URL"))
	if logoURL == "" {
		return defaultAMSLogoURL
	}
	return logoURL
}

func renderESSOTPHTML(data essOTPMailData) (string, error) {
	tmpl, err := loadESSOTPTemplate()
	if err != nil {
		return "", err
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		return "", err
	}
	return buf.String(), nil
}

// sendESSOTPViaBrevo mengirim OTP lewat Brevo. otpType dipakai sebagai judul email.
func sendESSOTPViaBrevo(email, otp, otpType string, validFor time.Duration) error {
	email = strings.TrimSpace(email)
	otp = strings.TrimSpace(otp)
	if email == "" || otp == "" {
		return fmt.Errorf("email and otp are required")
	}

	client, err := getBrevoClient()
	if err != nil {
		return err
	}

	minutes := int(validFor.Minutes())
	if minutes <= 0 {
		minutes = 10
	}

	title, subject, intro := essOTPTitleFromType(otpType)

	html, err := renderESSOTPHTML(essOTPMailData{
		LogoURL:      essLogoURL(),
		SubjectTitle: subject,
		Title:        title,
		Intro:        intro,
		OTP:          otp,
		ValidMinutes: minutes,
		Year:         time.Now().In(essJakartaLoc).Year(),
	})
	if err != nil {
		return fmt.Errorf("render otp template: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()

	tag := essOTPTypeKey(otpType)
	if err := client.SendHTML(ctx, []string{email}, subject, html, "ess-otp", tag); err != nil {
		return err
	}
	return nil
}

// essOTPTypeKey normalisasi type untuk key storage / tag.
func essOTPTypeKey(raw string) string {
	t := strings.ToLower(strings.TrimSpace(raw))
	t = strings.ReplaceAll(t, " ", "_")
	t = strings.ReplaceAll(t, "-", "_")
	switch t {
	case "", "default", "otp":
		return "default"
	case "forgot", "forgotpassword", "reset_password", "resetpassword":
		return "forgot_password"
	case "email", "new_email", "changeemail", "change_email_otp":
		return "change_email"
	case "two_factor", "twofactor", "2fa_verification", "2fa_verification_code":
		return "2fa"
	case "pin", "change_pin_code", "change_pin_code_otp", "changepin":
		return "change_pin"
	default:
		return t
	}
}

// essOTPTitleFromType — type jadi judul email (subject + headline).
func essOTPTitleFromType(raw string) (title, subject, intro string) {
	key := essOTPTypeKey(raw)
	switch key {
	case "forgot_password":
		title = "Forgot Password"
		intro = "Gunakan kode berikut untuk reset password di AMS ESS."
	case "change_email":
		title = "Change Email"
		intro = "Gunakan kode berikut untuk verifikasi perubahan email di AMS ESS."
	case "2fa":
		title = "2FA Verification Code"
		intro = "Gunakan kode berikut untuk verifikasi dua faktor (2FA) di AMS ESS."
	case "change_pin":
		title = "Change Pin Code OTP"
		intro = "Gunakan kode berikut untuk mengubah PIN di AMS ESS."
	default:
		// Pakai type dari request sebagai judul (custom).
		title = strings.TrimSpace(raw)
		if title == "" || key == "default" {
			title = "Verification Code"
		}
		intro = fmt.Sprintf("Gunakan kode berikut untuk %s di AMS ESS.", strings.ToLower(title))
	}
	subject = fmt.Sprintf("[AMS ESS] %s", title)
	return title, subject, intro
}

func essMapString(m map[string]interface{}, keys ...string) string {
	if m == nil {
		return ""
	}
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			s := strings.TrimSpace(fmt.Sprint(v))
			if s != "" && s != "<nil>" {
				return s
			}
		}
	}
	return ""
}

func essIsPengajuanSuccess(code string) bool {
	code = strings.TrimSpace(code)
	switch code {
	case "00", "2000000", "2002500", "2002700":
		return true
	default:
		return strings.HasPrefix(code, "200")
	}
}

func essCollectApproverEmails(data map[string]interface{}) []string {
	emails := []string{}
	seen := map[string]struct{}{}
	add := func(raw string) {
		email := strings.TrimSpace(strings.ToLower(raw))
		if email == "" || !strings.Contains(email, "@") {
			return
		}
		if _, ok := seen[email]; ok {
			return
		}
		seen[email] = struct{}{}
		emails = append(emails, email)
	}
	add(essMapString(data, "emailSm", "email_sm", "emailSM", "EmailSm"))
	add(essMapString(data, "emailManager", "email_manager", "EmailManager"))
	return emails
}

func essBuildPengajuanRows(jenis string, data map[string]interface{}) []essDetailRow {
	rows := []essDetailRow{}
	if nama := essMapString(data, "nama", "name", "namaLengkap", "nama_lengkap", "nickName"); nama != "" {
		rows = append(rows, essDetailRow{Label: "Nama", Value: nama})
	}
	if nik := essMapString(data, "nik", "nikstr"); nik != "" {
		rows = append(rows, essDetailRow{Label: "NIK", Value: nik})
	}
	if kat := essMapString(data, "kategori"); kat != "" {
		rows = append(rows, essDetailRow{Label: "Kategori", Value: kat})
	}

	switch strings.ToLower(jenis) {
	case "izin":
		rows = append(rows,
			essDetailRow{Label: "Tanggal", Value: formatESSDateRange(
				essMapString(data, "fromDate", "from_date", "tanggalDari"),
				essMapString(data, "toDate", "to_date", "tanggalSampai"),
			)},
			essDetailRow{Label: "Jam", Value: formatESSTimeRange(
				essMapString(data, "jamDari", "jam_dari"),
				essMapString(data, "jamSampai", "jam_sampai"),
			)},
		)
	case "cuti":
		khusus := essMapString(data, "kategoriKhusus", "kategori_khusus")
		if khusus != "" {
			rows = append(rows, essDetailRow{Label: "Kategori Khusus", Value: khusus})
		}
		rows = append(rows,
			essDetailRow{Label: "Periode", Value: formatESSDateRange(
				essMapString(data, "tanggalDari", "tanggal_dari", "fromDate"),
				essMapString(data, "tanggalSampai", "tanggal_sampai", "toDate"),
			)},
		)
		if n := essMapString(data, "totalCuti", "total_cuti"); n != "" {
			rows = append(rows, essDetailRow{Label: "Total Hari", Value: n})
		}
		if n := essMapString(data, "sisaCuti", "sisa_cuti"); n != "" {
			rows = append(rows, essDetailRow{Label: "Sisa Cuti", Value: n})
		}
	case "lembur":
		rows = append(rows,
			essDetailRow{Label: "Tanggal", Value: essMapString(data, "tanggal", "tanggalLembur")},
			essDetailRow{Label: "Jam", Value: formatESSTimeRange(
				essMapString(data, "jamDari", "jam_dari"),
				essMapString(data, "jamSampai", "jam_sampai"),
			)},
		)
	}

	if reason := essMapString(data, "reason", "alasan"); reason != "" {
		rows = append(rows, essDetailRow{Label: "Alasan", Value: reason})
	}
	return rows
}

func formatESSDateRange(from, to string) string {
	from = strings.TrimSpace(from)
	to = strings.TrimSpace(to)
	if from == "" && to == "" {
		return "—"
	}
	if to == "" || to == from {
		return from
	}
	return from + " s/d " + to
}

func formatESSTimeRange(from, to string) string {
	from = strings.TrimSpace(from)
	to = strings.TrimSpace(to)
	if from == "" && to == "" {
		return "—"
	}
	if to == "" {
		return from
	}
	if from == "" {
		return to
	}
	return from + " – " + to
}

func essJenisLabel(jenis string) string {
	switch strings.ToLower(strings.TrimSpace(jenis)) {
	case "izin":
		return "Izin"
	case "cuti":
		return "Cuti"
	case "lembur":
		return "Lembur"
	default:
		j := strings.TrimSpace(jenis)
		if j == "" {
			return "Pengajuan"
		}
		return strings.ToUpper(j[:1]) + strings.ToLower(j[1:])
	}
}

func renderESSPengajuanHTML(data essPengajuanMailData) (string, error) {
	tmpl, err := loadESSPengajuanTemplate()
	if err != nil {
		return "", err
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		return "", err
	}
	return buf.String(), nil
}

func renderESSApprovalHTML(data essApprovalMailData) (string, error) {
	tmpl, err := loadESSApprovalTemplate()
	if err != nil {
		return "", err
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		return "", err
	}
	return buf.String(), nil
}

func essIsApproveAction(tipe string) bool {
	t := strings.ToUpper(strings.TrimSpace(tipe))
	switch t {
	case "APPROVE", "APPROVED", "SETUJU", "DISETUJUI", "A", "Y", "YES", "1", "TRUE":
		return true
	default:
		return strings.Contains(t, "APPROVE") || strings.Contains(t, "SETUJU")
	}
}

func essIsRejectAction(tipe string) bool {
	t := strings.ToUpper(strings.TrimSpace(tipe))
	switch t {
	case "REJECT", "REJECTED", "TOLAK", "DITOLAK", "R", "N", "NO", "0", "FALSE":
		return true
	default:
		return strings.Contains(t, "REJECT") || strings.Contains(t, "TOLAK")
	}
}

func essApplicantEmail(data map[string]interface{}) string {
	return essMapString(data, "email", "Email", "emailPengaju", "email_pengaju", "userEmail")
}

// notifyESSPengajuanFromJSON — email Brevo DAN web-push, paralel, tidak saling block.
func notifyESSPengajuanFromJSON(jsonResult, jenis string) {
	data, ok := essNotifySuccessData(jsonResult, "pengajuan "+jenis)
	if !ok {
		return
	}
	go essSendPengajuanEmail(data, jenis, "NEW")
	go essDispatchPush(essBuildPengajuanPush(jenis, data))
}

func essNotifySuccessData(jsonResult, label string) (map[string]interface{}, bool) {
	raw := strings.TrimSpace(jsonResult)
	if raw == "" {
		return nil, false
	}
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &payload); err != nil {
		log.Printf("ESS notify %s parse error: %v", label, err)
		return nil, false
	}
	code := essMapString(payload, "responseCode")
	if !essIsPengajuanSuccess(code) && code != "00" && !strings.HasPrefix(code, "20") {
		return nil, false
	}
	data, _ := payload["data"].(map[string]interface{})
	if data == nil {
		data = payload
	}
	return data, true
}

func essSendPengajuanEmail(data map[string]interface{}, jenis, statusDefault string) {
	emails := essCollectApproverEmails(data)
	if len(emails) == 0 {
		log.Printf("ESS notify %s: no approver email in response", jenis)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()

	client, err := getBrevoClient()
	if err != nil {
		log.Println("ESS notify brevo init:", err.Error())
		return
	}

	label := essJenisLabel(jenis)
	id := essMapString(data, "id")
	nik := essMapString(data, "nik", "nikstr")
	nama := essMapString(data, "nama", "name", "namaLengkap", "nama_lengkap", "nickName")
	status := essMapString(data, "status")
	if status == "" {
		status = statusDefault
	}

	mailData := essPengajuanMailData{
		LogoURL:      essLogoURL(),
		SubjectTitle: fmt.Sprintf("Pengajuan %s — AMS ESS", label),
		JenisLabel:   label,
		Status:       status,
		ID:           id,
		Year:         time.Now().In(essJakartaLoc).Year(),
		Rows:         essBuildPengajuanRows(jenis, data),
	}

	html, err := renderESSPengajuanHTML(mailData)
	if err != nil {
		log.Println("ESS notify render template:", err.Error())
		return
	}

	who := nik
	if nama != "" && nik != "" {
		who = fmt.Sprintf("%s (%s)", nama, nik)
	} else if nama != "" {
		who = nama
	}

	subject := fmt.Sprintf("[AMS ESS] Pengajuan %s baru — %s", label, who)
	tag := "ess-pengajuan"
	if strings.EqualFold(statusDefault, "CANCELLED") || strings.EqualFold(status, "CANCELLED") || strings.EqualFold(status, "DIBATALKAN") {
		subject = fmt.Sprintf("[AMS ESS] Pengajuan %s dibatalkan — %s", label, who)
		tag = "ess-pengajuan-cancel"
	}

	if err := client.SendHTML(ctx, emails, subject, html, tag, jenis); err != nil {
		log.Printf("ESS notify %s send failed to %v: %v", jenis, emails, err)
		return
	}
	log.Printf("ESS notify %s email sent to %v id=%s nama=%s nik=%s", jenis, emails, id, nama, nik)
}

// notifyESSApprovalFromJSON — email ke pengaju DAN web-push, paralel.
func notifyESSApprovalFromJSON(jsonResult, jenis, tipeApprove string) {
	data, ok := essNotifySuccessData(jsonResult, "approval "+jenis)
	if !ok {
		return
	}
	go essSendApprovalEmail(data, jenis, tipeApprove)
	go essDispatchPush(essBuildApprovalPush(jenis, tipeApprove, data))
}

func essSendApprovalEmail(data map[string]interface{}, jenis, tipeApprove string) {
	approved := essIsApproveAction(tipeApprove)
	rejected := essIsRejectAction(tipeApprove)
	if !approved && !rejected {
		approved = true
	}

	toEmail := essApplicantEmail(data)
	if toEmail == "" || !strings.Contains(toEmail, "@") {
		log.Printf("ESS approval notify %s: no applicant email in response", jenis)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()

	client, err := getBrevoClient()
	if err != nil {
		log.Println("ESS approval notify brevo init:", err.Error())
		return
	}

	label := essJenisLabel(jenis)
	id := essMapString(data, "id")
	nama := essMapString(data, "nama", "name", "namaLengkap", "nama_lengkap", "nickName")
	nik := essMapString(data, "nik", "nikstr")
	status := essMapString(data, "status")

	rows := essBuildPengajuanRows(jenis, data)
	if rejected {
		if alasan := essMapString(data, "alasanPenolakan", "alasan_penolakan", "rejectReason"); alasan != "" {
			rows = append(rows, essDetailRow{Label: "Alasan Penolakan", Value: alasan})
		}
	}

	var (
		headline, intro, statusLabel string
		accent, badgeBg, badgeFg     string
		tag                          string
	)
	if rejected {
		if status == "" {
			status = "REJECTED"
		}
		statusLabel = status
		headline = fmt.Sprintf("Pengajuan %s Ditolak", label)
		intro = fmt.Sprintf("Pengajuan %s Anda telah ditolak oleh atasan. Silakan cek detail di bawah atau ajukan ulang jika diperlukan.", label)
		accent = "#c62828"
		badgeBg = "#fdecea"
		badgeFg = "#c62828"
		tag = "ess-approval-reject"
	} else {
		if status == "" {
			status = "APPROVED"
		}
		statusLabel = status
		headline = fmt.Sprintf("Pengajuan %s Disetujui", label)
		intro = fmt.Sprintf("Pengajuan %s Anda telah disetujui oleh atasan. Berikut ringkasan pengajuannya.", label)
		accent = "#2e7d32"
		badgeBg = "#e8f5e9"
		badgeFg = "#2e7d32"
		tag = "ess-approval-approve"
	}

	mailData := essApprovalMailData{
		LogoURL:      essLogoURL(),
		SubjectTitle: headline + " — AMS ESS",
		Headline:     headline,
		Intro:        intro,
		Nama:         nama,
		Status:       statusLabel,
		ID:           id,
		Year:         time.Now().In(essJakartaLoc).Year(),
		AccentColor:  accent,
		BadgeBg:      badgeBg,
		BadgeFg:      badgeFg,
		Rows:         rows,
	}

	html, err := renderESSApprovalHTML(mailData)
	if err != nil {
		log.Println("ESS approval notify render:", err.Error())
		return
	}

	who := nama
	if who == "" {
		who = nik
	}
	subject := fmt.Sprintf("[AMS ESS] %s", headline)
	if who != "" {
		subject = fmt.Sprintf("[AMS ESS] %s — %s", headline, who)
	}

	if err := client.SendHTML(ctx, []string{toEmail}, subject, html, tag, jenis); err != nil {
		log.Printf("ESS approval notify %s send failed to %s: %v", jenis, toEmail, err)
		return
	}
	log.Printf("ESS approval notify %s sent to %s id=%s tipe=%s", jenis, toEmail, id, tipeApprove)
}

// notifyESSPembatalanFromJSON — email + push ke approver saat pegawai batal/hapus pengajuan.
func notifyESSPembatalanFromJSON(jsonResult, jenis string) {
	data, ok := essNotifySuccessData(jsonResult, "cancel "+jenis)
	if !ok {
		return
	}
	if essMapString(data, "status") == "" {
		data["status"] = "CANCELLED"
	}
	go essSendPengajuanEmail(data, jenis, "CANCELLED")
	go essDispatchPush(essBuildCancelPush(jenis, data))
}
