package controllers

import (
	"GOamsAPI/database"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const (
	SPGetEmployeeByNik      = "xsp_api_get_employee_by_nik"
	SPGetDiskonPlatinum     = "xsp_api_get_diskon_platinum"
)

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

func GetEmployeeDiskonPlatinum(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if ctx == nil {
		ctx = context.Background()
	}

	if r.Method != http.MethodGet {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4050001", "Method not allowed"), r.Method, SPGetDiskonPlatinum)
		return
	}

	nik := parseEmployeeNomorInduk(r)
	if nik == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "nik is required"), r.Method, SPGetDiskonPlatinum)
		return
	}

	yearRaw := parseEmployeeParam(r, "year", "tahun", "p_year")
	if yearRaw == "" {
		yearRaw = strconv.Itoa(time.Now().Year())
	}
	year, err := strconv.Atoi(yearRaw)
	if err != nil || yearRaw != strconv.Itoa(year) || year < 1000 || year > 9999 {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "year must be a 4-digit year"), r.Method, SPGetDiskonPlatinum)
		return
	}

	if err := database.RbcaInstance.PingContext(ctx); err != nil {
		log.Println("employee diskon platinum DB ping error:", err.Error())
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000001", "Database unavailable"), r.Method, SPGetDiskonPlatinum)
		return
	}

	jsonResult, err := runNamedSPOn(database.RbcaInstance, ctx, SPGetDiskonPlatinum,
		sql.Named("p_nik", nik),
		sql.Named("p_year", year),
	)
	if err != nil {
		log.Printf("employee diskon platinum SP error: %s | nik=%q year=%d", err.Error(), nik, year)
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "Failed to execute diskon platinum"), r.Method, SPGetDiskonPlatinum)
		return
	}

	if strings.TrimSpace(jsonResult) == "" {
		log.Printf("employee diskon platinum empty bitparam | nik=%q year=%d", nik, year)
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, SPGetDiskonPlatinum)
		return
	}

	writeRbcaJSONResponse(w, normalizeDiskonPlatinumJSON(jsonResult), r.Method, SPGetDiskonPlatinum)
}

func runNamedSPOn(db *sql.DB, ctx context.Context, spName string, namedArgs ...interface{}) (string, error) {
	var jsonResultData string
	args := append(append([]interface{}{}, namedArgs...), sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))
	rows, err := db.QueryContext(ctx, spName, args...)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var rowJSON string
	if rows.Next() {
		var col sql.NullString
		if scanErr := rows.Scan(&col); scanErr == nil && col.Valid {
			rowJSON = col.String
		}
	}
	for rows.Next() {
	}

	if strings.TrimSpace(jsonResultData) != "" {
		return jsonResultData, nil
	}
	return rowJSON, nil
}

func normalizeDiskonPlatinumJSON(raw string) string {
	trimmed := strings.TrimSpace(raw)
	var obj map[string]interface{}
	if err := json.Unmarshal([]byte(trimmed), &obj); err != nil {
		return rbcaErrorJSON("5000003", "invalid JSON response from database")
	}

	if code, ok := obj["responseCode"]; ok && strings.TrimSpace(fmt.Sprint(code)) != "" {
		return trimmed
	}

	payload := obj
	if td, ok := obj["transactionData"]; ok {
		if tdMap, isMap := td.(map[string]interface{}); isMap {
			payload = tdMap
		}
	}

	wrapped, err := json.Marshal(map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "success",
		"transactionData": payload,
	})
	if err != nil {
		return trimmed
	}
	return string(wrapped)
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

func parseEmployeeParam(r *http.Request, keys ...string) string {
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
