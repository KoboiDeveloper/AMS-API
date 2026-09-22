package brevo

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

const sendURL = "https://api.brevo.com/v3/smtp/email"

// Client mengirim transactional email via Brevo REST API.
type Client struct {
	APIKey    string
	FromEmail string
	FromName  string
	HTTP      *http.Client
}

// NewFromEnv membaca BREVO_API_KEY, BREVO_FROM_EMAIL, BREVO_FROM_NAME.
func NewFromEnv() (*Client, error) {
	apiKey := strings.TrimSpace(os.Getenv("BREVO_API_KEY"))
	fromEmail := strings.TrimSpace(os.Getenv("BREVO_FROM_EMAIL"))
	fromName := strings.TrimSpace(os.Getenv("BREVO_FROM_NAME"))
	if fromName == "" {
		fromName = "AMS ESS"
	}
	if apiKey == "" {
		return nil, fmt.Errorf("BREVO_API_KEY is not set")
	}
	if fromEmail == "" {
		return nil, fmt.Errorf("BREVO_FROM_EMAIL is not set")
	}
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
	req.Header.Set("accept", "application/json")
	req.Header.Set("content-type", "application/json")
	req.Header.Set("api-key", c.APIKey)

	resp, err := c.HTTP.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("brevo status %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}
	return nil
}
