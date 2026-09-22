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

const defaultAMSLogoURL = "https://web.amscorp.id:3060/images/ams_logo_white.png"

var (
	essPengajuanTmplOnce sync.Once
	essPengajuanTmpl     *template.Template
	essPengajuanTmplErr  error
	essOTPTmplOnce       sync.Once
	essOTPTmpl           *template.Template
	essOTPTmplErr        error
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
	OTP          string
	ValidMinutes int
	Year         int
}

func getBrevoClient() (*brevo.Client, error) {
	brevoClientOnce.Do(func() {
		brevoClient, brevoClientErr = brevo.NewFromEnv()
	})
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

// sendESSOTPViaBrevo mengirim OTP reset password lewat Brevo.
func sendESSOTPViaBrevo(email, otp string, validFor time.Duration) error {
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

	html, err := renderESSOTPHTML(essOTPMailData{
		LogoURL:      essLogoURL(),
		SubjectTitle: "Kode Verifikasi OTP — AMS ESS",
		OTP:          otp,
		ValidMinutes: minutes,
		Year:         time.Now().In(essJakartaLoc).Year(),
	})
	if err != nil {
		return fmt.Errorf("render otp template: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()

	subject := "[AMS ESS] Kode OTP Reset Password"
	if err := client.SendHTML(ctx, []string{email}, subject, html, "ess-otp", "reset-password"); err != nil {
		return err
	}
	return nil
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
	rows := []essDetailRow{
		{Label: "NIK", Value: essMapString(data, "nik", "nikstr")},
		{Label: "Kategori", Value: essMapString(data, "kategori")},
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

// notifyESSPengajuanFromJSON mengirim email ke emailSm & emailManager setelah insert sukses.
// Dijalankan async; kegagalan email tidak gagalkan response API.
func notifyESSPengajuanFromJSON(jsonResult, jenis string) {
	raw := strings.TrimSpace(jsonResult)
	if raw == "" {
		return
	}

	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &payload); err != nil {
		log.Println("ESS notify parse error:", err.Error())
		return
	}

	code := essMapString(payload, "responseCode")
	if !essIsPengajuanSuccess(code) {
		return
	}

	data, _ := payload["data"].(map[string]interface{})
	if data == nil {
		return
	}

	emails := essCollectApproverEmails(data)
	if len(emails) == 0 {
		log.Printf("ESS notify %s: no approver email in response", jenis)
		return
	}

	go func() {
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
		status := essMapString(data, "status")
		if status == "" {
			status = "NEW"
		}

		logoURL := essLogoURL()

		mailData := essPengajuanMailData{
			LogoURL:      logoURL,
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

		subject := fmt.Sprintf("[AMS ESS] Pengajuan %s baru — NIK %s", label, nik)
		if err := client.SendHTML(ctx, emails, subject, html, "ess-pengajuan", jenis); err != nil {
			log.Printf("ESS notify %s send failed to %v: %v", jenis, emails, err)
			return
		}
		log.Printf("ESS notify %s email sent to %v id=%s nik=%s", jenis, emails, id, nik)
	}()
}
