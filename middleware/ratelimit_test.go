package middleware

import (
	"bytes"
	"mime/multipart"
	"net/http"
	"net/url"
	"strings"
	"testing"
)

func TestMemberIDFromRequestPreservesBodyForURLEncoded(t *testing.T) {
	form := url.Values{}
	form.Set("memberID", "12345")
	form.Set("voucher_code", "VC001")
	form.Set("ip_address", "127.0.0.1")
	form.Set("pin", "1234")
	body := form.Encode()

	req := httptestNewRequest(http.MethodPost, "/api/v2.0/member/mobile/voucher/redeem", body)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	memberID, err := memberIDFromRequest(req)
	if err != nil {
		t.Fatalf("memberIDFromRequest error: %v", err)
	}
	if memberID != "12345" {
		t.Fatalf("expected memberID 12345, got %q", memberID)
	}

	assertFormValues(t, req, map[string]string{
		"memberID":     "12345",
		"voucher_code": "VC001",
		"ip_address":   "127.0.0.1",
		"pin":          "1234",
	})
}

func TestMemberIDFromRequestPreservesBodyForMultipart(t *testing.T) {
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	_ = writer.WriteField("memberID", "999")
	_ = writer.WriteField("missionID", "M001")
	writer.Close()

	req, err := http.NewRequest(http.MethodPost, "/api/v2.0/member/mobile/mission/join", bytes.NewReader(body.Bytes()))
	if err != nil {
		t.Fatalf("new request error: %v", err)
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.ContentLength = int64(body.Len())

	memberID, err := memberIDFromRequest(req)
	if err != nil {
		t.Fatalf("memberIDFromRequest error: %v", err)
	}
	if memberID != "999" {
		t.Fatalf("expected memberID 999, got %q", memberID)
	}

	assertFormValues(t, req, map[string]string{
		"memberID":  "999",
		"missionID": "M001",
	})
}

func TestMemberIDFromRequestPreservesBodyForCustomRedeem(t *testing.T) {
	form := url.Values{}
	form.Set("memberID", "777")
	form.Set("nominal", "50000")
	form.Set("ip_address", "10.0.0.1")
	form.Set("pin", "4321")
	body := form.Encode()

	req := httptestNewRequest(http.MethodPost, "/api/v2.0/member/mobile/voucher/redeem/custom", body)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	memberID, err := memberIDFromRequest(req)
	if err != nil {
		t.Fatalf("memberIDFromRequest error: %v", err)
	}
	if memberID != "777" {
		t.Fatalf("expected memberID 777, got %q", memberID)
	}

	assertFormValues(t, req, map[string]string{
		"memberID":   "777",
		"nominal":    "50000",
		"ip_address": "10.0.0.1",
		"pin":        "4321",
	})
}

func httptestNewRequest(method, target, body string) *http.Request {
	req, err := http.NewRequest(method, target, strings.NewReader(body))
	if err != nil {
		panic(err)
	}
	return req
}

func assertFormValues(t *testing.T, req *http.Request, expected map[string]string) {
	t.Helper()

	if err := req.ParseForm(); err != nil {
		t.Fatalf("handler ParseForm error: %v", err)
	}

	for key, want := range expected {
		got := req.FormValue(key)
		if got != want {
			t.Fatalf("FormValue(%q) = %q, want %q", key, got, want)
		}
	}
}
