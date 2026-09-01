package controllers

import (
	"GOamsAPI/database"
	"context"
	"database/sql"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"strings"
)

const SPGetEmployeeByNik = "xsp_api_get_employee_by_nik"

func GetEmployeeByNik(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if ctx == nil {
		ctx = context.Background()
	}

	nomorInduk := parseEmployeeNomorInduk(r)
	if nomorInduk == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "nomor_induk is required"), r.Method, SPGetEmployeeByNik)
		return
	}

	if err := database.Instance.PingContext(ctx); err != nil {
		log.Println("employee by nik DB ping error:", err.Error())
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000001", "Database unavailable"), r.Method, SPGetEmployeeByNik)
		return
	}

	jsonResult, err := runEmployeeSPQuery(ctx, SPGetEmployeeByNik,
		sql.Named("p_nomor_induk", nomorInduk),
	)
	if err != nil {
		log.Println("employee by nik SP error:", err.Error())
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "Failed to execute employee lookup"), r.Method, SPGetEmployeeByNik)
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, SPGetEmployeeByNik)
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResult), r.Method, SPGetEmployeeByNik)
}

func parseEmployeeNomorInduk(r *http.Request) string {
	keys := []string{"nomor_induk", "p_nomor_induk", "nik"}

	for _, key := range keys {
		if val := strings.TrimSpace(r.URL.Query().Get(key)); val != "" {
			return val
		}
	}

	_ = r.ParseForm()
	for _, key := range keys {
		if val := strings.TrimSpace(r.FormValue(key)); val != "" {
			return val
		}
	}

	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "application/json") {
		return ""
	}

	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil || len(bodyBytes) == 0 {
		return ""
	}
	r.Body = io.NopCloser(strings.NewReader(string(bodyBytes)))

	var body map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &body); err != nil {
		return ""
	}

	for _, key := range keys {
		if raw, ok := body[key]; ok && raw != nil {
			if val := strings.TrimSpace(mapValueToString(raw)); val != "" {
				return val
			}
		}
	}

	return ""
}

func runEmployeeSPQuery(ctx context.Context, spName string, namedArgs ...interface{}) (string, error) {
	var jsonResultData string
	args := append(namedArgs, sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))
	rows, err := database.Instance.QueryContext(ctx, spName, args...)
	if err != nil {
		return "", err
	}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
		}
	}
	return jsonResultData, nil
}
