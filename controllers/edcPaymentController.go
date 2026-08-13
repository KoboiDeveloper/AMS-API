package controllers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

const edcBridgeTimeout = 90 * time.Second

func edcDir() string {
	if override := strings.TrimSpace(os.Getenv("EDC_BRIDGE_DIR")); override != "" {
		return override
	}
	// Prefer relative to process CWD (API usually started from repo root).
	candidates := []string{
		filepath.Join("edc"),
		filepath.Join(".", "edc"),
	}
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Join(filepath.Dir(exe), "edc"))
	}
	_, thisFile, _, ok := runtime.Caller(0)
	if ok {
		// controllers/ -> ../edc
		candidates = append(candidates, filepath.Clean(filepath.Join(filepath.Dir(thisFile), "..", "edc")))
	}
	for _, c := range candidates {
		cli := filepath.Join(c, "cli.js")
		if st, err := os.Stat(cli); err == nil && !st.IsDir() {
			abs, _ := filepath.Abs(c)
			return abs
		}
	}
	abs, _ := filepath.Abs("edc")
	return abs
}

func edcNodeBin() string {
	if v := strings.TrimSpace(os.Getenv("EDC_NODE_BIN")); v != "" {
		return v
	}
	return "node"
}

func readEdcRequestBody(r *http.Request) (map[string]interface{}, error) {
	if body := rbcaBodyValues(r); body != nil {
		return body, nil
	}
	if r.Body == nil {
		return map[string]interface{}{}, nil
	}
	raw, err := io.ReadAll(r.Body)
	if err != nil {
		return nil, err
	}
	if len(bytes.TrimSpace(raw)) == 0 {
		return map[string]interface{}{}, nil
	}
	out := map[string]interface{}{}
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil, err
	}
	return out, nil
}

func runEdcBridge(ctx context.Context, command string, payload map[string]interface{}) (map[string]interface{}, int, error) {
	dir := edcDir()
	cli := filepath.Join(dir, "cli.js")
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, 500, err
	}

	cmdCtx, cancel := context.WithTimeout(ctx, edcBridgeTimeout)
	defer cancel()

	cmd := exec.CommandContext(cmdCtx, edcNodeBin(), cli, command, string(payloadBytes))
	cmd.Dir = dir
	cmd.Env = os.Environ()

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	runErr := cmd.Run()
	outRaw := bytes.TrimSpace(stdout.Bytes())
	result := map[string]interface{}{}
	if len(outRaw) > 0 {
		if uErr := json.Unmarshal(outRaw, &result); uErr != nil {
			result = map[string]interface{}{
				"ok":    false,
				"error": fmt.Sprintf("invalid bridge JSON: %v; raw=%s", uErr, string(outRaw)),
			}
		}
	}

	if runErr != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = runErr.Error()
		}
		if existing, _ := result["error"].(string); existing == "" {
			result["ok"] = false
			result["error"] = msg
			if _, has := result["status"]; !has {
				result["status"] = "failed"
			}
		}
		status := 500
		if exitErr, ok := runErr.(*exec.ExitError); ok && exitErr.ExitCode() == 2 {
			status = 400
		}
		return result, status, nil
	}

	return result, 200, nil
}

func writeEdcJSON(w http.ResponseWriter, status int, payload map[string]interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func handleEdcCommand(w http.ResponseWriter, r *http.Request, command string) {
	body, err := readEdcRequestBody(r)
	if err != nil {
		writeEdcJSON(w, 400, map[string]interface{}{
			"ok":    false,
			"error": "invalid JSON body",
		})
		return
	}

	result, status, bridgeErr := runEdcBridge(r.Context(), command, body)
	if bridgeErr != nil {
		writeEdcJSON(w, 500, map[string]interface{}{
			"ok":    false,
			"error": bridgeErr.Error(),
		})
		return
	}
	writeEdcJSON(w, status, result)
}

// EdcPaymentStart POST /api/v1/payment/edc/start
func EdcPaymentStart(w http.ResponseWriter, r *http.Request) {
	handleEdcCommand(w, r, "start")
}

// EdcPaymentStatus POST /api/v1/payment/edc/status
func EdcPaymentStatus(w http.ResponseWriter, r *http.Request) {
	handleEdcCommand(w, r, "status")
}

// EdcPaymentCancel POST /api/v1/payment/edc/cancel
func EdcPaymentCancel(w http.ResponseWriter, r *http.Request) {
	handleEdcCommand(w, r, "cancel")
}
