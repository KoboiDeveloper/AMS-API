package dropbox

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

const (
	tokenURL    = "https://api.dropboxapi.com/oauth2/token"
	uploadURL   = "https://content.dropboxapi.com/2/files/upload"
	tempLinkURL = "https://api.dropboxapi.com/2/files/get_temporary_link"
	deleteURL   = "https://api.dropboxapi.com/2/files/delete_v2"
)

type Client struct {
	appKey       string
	appSecret    string
	refreshToken string
	httpClient   *http.Client

	mu          sync.Mutex
	accessToken string
	expiresAt   time.Time
}

type UploadResult struct {
	Name           string `json:"name"`
	PathLower      string `json:"path_lower"`
	PathDisplay    string `json:"path_display"`
	ID             string `json:"id"`
	Size           int64  `json:"size"`
	TemporaryLink  string `json:"temporary_link,omitempty"`
}

type dropboxAPIError struct {
	StatusCode int
	Body       string
}

func (e *dropboxAPIError) Error() string {
	return fmt.Sprintf("dropbox api error %d: %s", e.StatusCode, e.Body)
}

func NewClientFromEnv() (*Client, error) {
	appKey := strings.TrimSpace(os.Getenv("DROPBOX_APP_KEY"))
	appSecret := strings.TrimSpace(os.Getenv("DROPBOX_APP_SECRET"))
	refreshToken := strings.TrimSpace(os.Getenv("DROPBOX_REFRESH_TOKEN"))
	if appKey == "" || appSecret == "" || refreshToken == "" {
		return nil, fmt.Errorf("DROPBOX_APP_KEY, DROPBOX_APP_SECRET, and DROPBOX_REFRESH_TOKEN are required")
	}
	return &Client{
		appKey:       appKey,
		appSecret:    appSecret,
		refreshToken: refreshToken,
		httpClient:   &http.Client{Timeout: 120 * time.Second},
	}, nil
}

func (c *Client) getAccessToken() (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.accessToken != "" && time.Now().Before(c.expiresAt.Add(-60*time.Second)) {
		return c.accessToken, nil
	}

	form := url.Values{}
	form.Set("grant_type", "refresh_token")
	form.Set("refresh_token", c.refreshToken)

	req, err := http.NewRequest(http.MethodPost, tokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.SetBasicAuth(c.appKey, c.appSecret)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return "", &dropboxAPIError{StatusCode: resp.StatusCode, Body: string(body)}
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
		TokenType   string `json:"token_type"`
	}
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return "", err
	}
	if strings.TrimSpace(tokenResp.AccessToken) == "" {
		return "", fmt.Errorf("empty access_token from dropbox")
	}

	expiresIn := tokenResp.ExpiresIn
	if expiresIn <= 0 {
		expiresIn = 14400
	}
	c.accessToken = tokenResp.AccessToken
	c.expiresAt = time.Now().Add(time.Duration(expiresIn) * time.Second)
	return c.accessToken, nil
}

type uploadArg struct {
	Path           string `json:"path"`
	Mode           string `json:"mode"`
	Autorename     bool   `json:"autorename"`
	Mute           bool   `json:"mute"`
	StrictConflict bool   `json:"strict_conflict"`
}

func (c *Client) Upload(path string, content []byte) (*UploadResult, error) {
	token, err := c.getAccessToken()
	if err != nil {
		return nil, err
	}

	argJSON, err := json.Marshal(uploadArg{
		Path:           path,
		Mode:           "overwrite",
		Autorename:     false,
		Mute:           false,
		StrictConflict: false,
	})
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest(http.MethodPost, uploadURL, bytes.NewReader(content))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("Dropbox-API-Arg", string(argJSON))

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return nil, &dropboxAPIError{StatusCode: resp.StatusCode, Body: string(body)}
	}

	var meta UploadResult
	if err := json.Unmarshal(body, &meta); err != nil {
		return nil, err
	}
	return &meta, nil
}

func (c *Client) GetTemporaryLink(path string) (string, error) {
	token, err := c.getAccessToken()
	if err != nil {
		return "", err
	}

	payload, _ := json.Marshal(map[string]string{"path": path})
	req, err := http.NewRequest(http.MethodPost, tempLinkURL, bytes.NewReader(payload))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return "", &dropboxAPIError{StatusCode: resp.StatusCode, Body: string(body)}
	}

	var result struct {
		Link string `json:"link"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return "", err
	}
	return result.Link, nil
}

// Delete removes a file at path via Dropbox files/delete_v2.
// path_not_found is treated as success (already gone).
func (c *Client) Delete(path string) error {
	path = strings.TrimSpace(path)
	if path == "" {
		return nil
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}

	token, err := c.getAccessToken()
	if err != nil {
		return err
	}

	payload, _ := json.Marshal(map[string]string{"path": path})
	req, err := http.NewRequest(http.MethodPost, deleteURL, bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		// Sudah tidak ada → anggap sukses
		if resp.StatusCode == http.StatusConflict || strings.Contains(string(body), "path_lookup/not_found") || strings.Contains(string(body), "not_found") {
			return nil
		}
		return &dropboxAPIError{StatusCode: resp.StatusCode, Body: string(body)}
	}
	return nil
}

func (c *Client) UploadWithTemporaryLink(path string, content []byte) (*UploadResult, error) {
	meta, err := c.Upload(path, content)
	if err != nil {
		return nil, err
	}
	linkPath := meta.PathDisplay
	if linkPath == "" {
		linkPath = path
	}
	link, linkErr := c.GetTemporaryLink(linkPath)
	if linkErr == nil {
		meta.TemporaryLink = link
	}
	return meta, nil
}
