package controllers

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strings"
)

// Placeholder SP names — diganti saat SP dikirim.
const (
	SPStoreKasGetrows                 = "xsp_api_store_kas_getrows"
	SPStoreKasDelete                  = "xsp_api_store_kas_delete"
	SPStoreKasInsert                  = "xsp_api_store_kas_insert"
	SPStoreKasRealisasiFinanceGetrows = "xsp_api_store_kas_realisasi_finance_getrows"
	SPStoreKasRealisasiFinanceUpdate  = "xsp_api_store_kas_realisasi_finance_update"
	SPStoreKasRealisasiManualGetrows  = "xsp_api_store_kas_realisasi_manual_getrows"
	SPStoreKasRealisasiManualUpdate   = "xsp_api_store_kas_realisasi_manual_update"
	SPStoreKasPettyCashGetrows        = "xsp_api_store_kas_pettycash_getrows"
)

func writeStoreKasNotImplemented(w http.ResponseWriter, endpoint, spName string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusNotImplemented)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"responseCode":    "5010001",
		"responseMessage": "Store kas endpoint not implemented yet: " + endpoint + " (waiting for SP)",
		"storedProcedure": spName,
		"database":        "RBCA",
	})
}

// GET /api/v1/store/kas
// SP: xsp_api_store_kas_getrows (@p_from_date, @p_to_date, @p_store_id, @bitparam)
func GetStoreKas(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Println("Error reading store kas getrows:", err.Error())
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000001", "Database unavailable"), r.Method, SPStoreKasGetrows)
		return
	}

	fromDate := rbcaParam(r, "from_date")
	if fromDate == "" {
		fromDate = rbcaParam(r, "fromDate")
	}
	toDate := rbcaParam(r, "to_date")
	if toDate == "" {
		toDate = rbcaParam(r, "toDate")
	}
	storeID := rbcaParam(r, "store_id")
	if storeID == "" {
		storeID = rbcaParam(r, "storeId")
	}

	jsonResultData := runRbcaSPQuery(ctx, SPStoreKasGetrows,
		sql.Named("p_from_date", parseOptionalString(fromDate)),
		sql.Named("p_to_date", parseOptionalString(toDate)),
		sql.Named("p_store_id", parseRbcaFilterString(storeID)),
	)

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, SPStoreKasGetrows)
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, SPStoreKasGetrows)
}

// DELETE /api/v1/store/kas
func DeleteStoreKas(w http.ResponseWriter, r *http.Request) {
	writeStoreKasNotImplemented(w, "DELETE /store/kas", SPStoreKasDelete)
}

// POST /api/v1/store/kas
func CreateStoreKas(w http.ResponseWriter, r *http.Request) {
	writeStoreKasNotImplemented(w, "POST /store/kas", SPStoreKasInsert)
}

// GET /api/v1/store/kas/realisasi/finance
func GetStoreKasRealisasiFinance(w http.ResponseWriter, r *http.Request) {
	writeStoreKasNotImplemented(w, "GET /store/kas/realisasi/finance", SPStoreKasRealisasiFinanceGetrows)
}

// PUT /api/v1/store/kas/realisasi/finance
func UpdateStoreKasRealisasiFinance(w http.ResponseWriter, r *http.Request) {
	writeStoreKasNotImplemented(w, "PUT /store/kas/realisasi/finance", SPStoreKasRealisasiFinanceUpdate)
}

// GET /api/v1/store/kas/realisasi/manual
func GetStoreKasRealisasiManual(w http.ResponseWriter, r *http.Request) {
	writeStoreKasNotImplemented(w, "GET /store/kas/realisasi/manual", SPStoreKasRealisasiManualGetrows)
}

// PUT /api/v1/store/kas/realisasi/manual
func UpdateStoreKasRealisasiManual(w http.ResponseWriter, r *http.Request) {
	writeStoreKasNotImplemented(w, "PUT /store/kas/realisasi/manual", SPStoreKasRealisasiManualUpdate)
}

// GET /api/v1/store/kas/pettycash
func GetStoreKasPettyCash(w http.ResponseWriter, r *http.Request) {
	writeStoreKasNotImplemented(w, "GET /store/kas/pettycash", SPStoreKasPettyCashGetrows)
}
