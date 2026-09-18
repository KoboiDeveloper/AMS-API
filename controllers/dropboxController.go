package controllers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"GOamsAPI/dropbox"
)

const dropboxMaxUploadBytes = 32 << 20 // 32 MiB

var (
	safeModuleRe = regexp.MustCompile(`[^a-zA-Z0-9_-]+`)
	safeFileRe   = regexp.MustCompile(`[^a-zA-Z0-9._-]+`)
)

func writeDropboxJSON(w http.ResponseWriter, status int, payload map[string]interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func dropboxError(code, message string) map[string]interface{} {
	return map[string]interface{}{
		"responseCode":    code,
		"responseMessage": message,
	}
}

func sanitizeModule(module string) string {
	module = strings.TrimSpace(strings.ToLower(module))
	if module == "" {
		return "general"
	}
	module = safeModuleRe.ReplaceAllString(module, "_")
	if module == "" {
		return "general"
	}
	return module
}

func sanitizeFilename(name string) string {
	base := filepath.Base(strings.TrimSpace(name))
	base = strings.ReplaceAll(base, "\\", "_")
	base = strings.ReplaceAll(base, "/", "_")
	base = safeFileRe.ReplaceAllString(base, "_")
	base = strings.Trim(base, "._")
	if base == "" {
		return "file.bin"
	}
	if len(base) > 120 {
		ext := filepath.Ext(base)
		stem := strings.TrimSuffix(base, ext)
		if len(stem) > 100 {
			stem = stem[:100]
		}
		base = stem + ext
	}
	return base
}

func randomHex(n int) string {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(buf)
}

func buildDropboxPath(module, originalName string) string {
	now := time.Now()
	filename := sanitizeFilename(originalName)
	id := randomHex(6)
	return fmt.Sprintf(
		"/uploads/%s/%04d/%02d/%s_%s",
		sanitizeModule(module),
		now.Year(),
		int(now.Month()),
		id,
		filename,
	)
}

// buildDcrDropboxPath: /uploads/dcr/{store}/{yyyy}/{mm}/{dd}/{hex}_{filename}
func buildDcrDropboxPath(storeID, originalName string) string {
	now := time.Now()
	store := sanitizeModule(storeID)
	if store == "" || store == "general" {
		store = "unknown"
	}
	filename := sanitizeFilename(originalName)
	id := randomHex(6)
	return fmt.Sprintf(
		"/uploads/dcr/%s/%04d/%02d/%02d/%s_%s",
		store,
		now.Year(),
		int(now.Month()),
		now.Day(),
		id,
		filename,
	)
}

// UploadDropboxFile handles multipart upload to Dropbox.
// POST /api/v1/files/upload
// form fields: file (required), module (optional), path (optional absolute Dropbox path)
func UploadDropboxFile(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(dropboxMaxUploadBytes); err != nil {
		writeDropboxJSON(w, http.StatusBadRequest, dropboxError("4000001", "invalid multipart form or file too large (max 32MB)"))
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		writeDropboxJSON(w, http.StatusBadRequest, dropboxError("4000001", "file field is required"))
		return
	}
	defer file.Close()

	content, err := io.ReadAll(io.LimitReader(file, dropboxMaxUploadBytes+1))
	if err != nil {
		writeDropboxJSON(w, http.StatusBadRequest, dropboxError("4000002", "failed to read uploaded file"))
		return
	}
	if len(content) == 0 {
		writeDropboxJSON(w, http.StatusBadRequest, dropboxError("4000001", "uploaded file is empty"))
		return
	}
	if len(content) > dropboxMaxUploadBytes {
		writeDropboxJSON(w, http.StatusBadRequest, dropboxError("4000001", "file too large (max 32MB)"))
		return
	}

	module := r.FormValue("module")
	customPath := strings.TrimSpace(r.FormValue("path"))
	dropboxPath := customPath
	if dropboxPath == "" {
		dropboxPath = buildDropboxPath(module, header.Filename)
	} else {
		if !strings.HasPrefix(dropboxPath, "/") {
			dropboxPath = "/" + dropboxPath
		}
	}

	client, err := dropbox.NewClientFromEnv()
	if err != nil {
		writeDropboxJSON(w, http.StatusInternalServerError, dropboxError("5000003", err.Error()))
		return
	}

	result, err := client.UploadWithTemporaryLink(dropboxPath, content)
	if err != nil {
		writeDropboxJSON(w, http.StatusBadGateway, dropboxError("5020001", err.Error()))
		return
	}

	writeDropboxJSON(w, http.StatusOK, map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "file uploaded",
		"data": map[string]interface{}{
			"id":            result.ID,
			"name":          result.Name,
			"path":          result.PathDisplay,
			"pathLower":     result.PathLower,
			"size":          result.Size,
			"temporaryLink": result.TemporaryLink,
			"module":        sanitizeModule(module),
			"originalName":  header.Filename,
		},
	})
}

// GetDropboxTemporaryLink returns a temporary download link for an existing Dropbox path.
// GET /api/v1/files/temporary-link?path=/uploads/...
func GetDropboxTemporaryLink(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSpace(r.URL.Query().Get("path"))
	if path == "" {
		writeDropboxJSON(w, http.StatusBadRequest, dropboxError("4000001", "path query is required"))
		return
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}

	client, err := dropbox.NewClientFromEnv()
	if err != nil {
		writeDropboxJSON(w, http.StatusInternalServerError, dropboxError("5000003", err.Error()))
		return
	}

	link, err := client.GetTemporaryLink(path)
	if err != nil {
		writeDropboxJSON(w, http.StatusBadGateway, dropboxError("5020001", err.Error()))
		return
	}

	writeDropboxJSON(w, http.StatusOK, map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "ok",
		"data": map[string]interface{}{
			"path":          path,
			"temporaryLink": link,
		},
	})
}
