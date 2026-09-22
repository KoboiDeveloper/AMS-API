package brevo

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
	"unicode"
)

const sendURL = "https://api.brevo.com/v3/smtp/email"

// Client mengirim transactional email via Brevo REST API.
type Client struct {
	APIKey    string
	FromEmail string
	FromName  string
	HTTP      *http.Client
}

// sanitizeEnv membersihkan kutip, BOM, whitespace yang sering ikut saat paste di Render.
func sanitizeEnv(raw string) string {
	s := strings.TrimSpace(raw)
	s = strings.TrimPrefix(s, "\ufeff")
	s = strings.Trim(s, "\"'")
	s = strings.TrimSpace(s)
	s = strings.Map(func(r rune) rune {
		if r == '\n' || r == '\r' || r == '\t' || unicode.IsControl(r) {
			return -1
		}
		return r
	}, s)
	return strings.TrimSpace(s)
}

func envFirst(keys ...string) string {
	for _, k := range keys {
		if v := sanitizeEnv(os.Getenv(k)); v != "" {
			return v
		}
	}
	return ""
}

func maskKey(key string) string {
	n := len(key)
	if n == 0 {
		return "(empty)"
	}
	if n <= 8 {
		return fmt.Sprintf("len=%d", n)
	}
	return fmt.Sprintf("len=%d prefix=%s… suffix=…%s", n, key[:6], key[n-4:])
}

// NewFromEnv membaca BREVO_API_KEY, BREVO_FROM_EMAIL, BREVO_FROM_NAME.
func NewFromEnv() (*Client, error) {
	apiKey := envFirst("BREVO_API_KEY", "SENDINBLUE_API_KEY", "BREVO_APIKEY")
	fromEmail := envFirst("BREVO_FROM_EMAIL", "BREVO_SENDER_EMAIL")
	fromName := envFirst("BREVO_FROM_NAME", "BREVO_SENDER_NAME")
	if fromName == "" {
		fromName = "AMS ESS"
	}
	if apiKey == "" {
		return nil, fmt.Errorf("BREVO_API_KEY is not set")
	}
	if fromEmail == "" {
		return nil, fmt.Errorf("BREVO_FROM_EMAIL is not set")
	}
	log.Printf("brevo: init ok key=%s from=%s", maskKey(apiKey), fromEmail)
	return &Client{
		APIKey:    apiKey,
		FromEmail: fromEmail,
		FromName:  fromName,
		HTTP:      &http.Client{Timeout: 20 * time.Second},
	}, nil
}

type mailAddress struct {
	Email string `json:"email"`
	Name  string `json:"name,omitempty"`
}

type sendPayload struct {
	Sender      mailAddress   `json:"sender"`
	To          []mailAddress `json:"to"`
	Subject     string        `json:"subject"`
	HTMLContent string        `json:"htmlContent"`
	Tags        []string      `json:"tags,omitempty"`
}

// SendHTML mengirim email HTML ke satu atau lebih penerima.
func (c *Client) SendHTML(ctx context.Context, toEmails []string, subject, html string, tags ...string) error {
	if c == nil {
		return fmt.Errorf("brevo client is nil")
	}
	recipients := make([]mailAddress, 0, len(toEmails))
	seen := map[string]struct{}{}
	for _, raw := range toEmails {
		email := strings.TrimSpace(strings.ToLower(raw))
		if email == "" {
			continue
		}
		if _, ok := seen[email]; ok {
			continue
		}
		seen[email] = struct{}{}
		recipients = append(recipients, mailAddress{Email: email})
	}
	if len(recipients) == 0 {
		return fmt.Errorf("no recipients")
	}

	body := sendPayload{
		Sender:      mailAddress{Email: c.FromEmail, Name: c.FromName},
		To:          recipients,
		Subject:     strings.TrimSpace(subject),
		HTMLContent: html,
		Tags:        tags,
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, sendURL, bytes.NewReader(raw))
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	// Jangan pakai Header.Set("api-key") — Go men-canonicalize jadi "Api-Key".
	req.Header["api-key"] = []string{c.APIKey}

	resp, err := c.HTTP.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		if resp.StatusCode == http.StatusUnauthorized {
			return fmt.Errorf("brevo status 401 (key=%s): %s — pastikan BREVO_API_KEY = API key v3 (biasanya mulai xkeysib-), bukan SMTP key; tanpa kutip",
				maskKey(c.APIKey), strings.TrimSpace(string(respBody)))
		}
		return fmt.Errorf("brevo status %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}
	return nil
}
