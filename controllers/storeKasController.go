package controllers

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"GOamsAPI/dropbox"
)

const (
	SPStoreKasGetrows                 = "xsp_api_store_kas_getrows"
	SPStoreKasDelete                  = "xsp_api_store_kas_delete"
	SPStoreKasInsert                  = "xsp_api_store_kas_insert"
	SPStoreKasMasterCoa               = "xsp_api_store_kas_master_coa"
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

func isKasStatusBaru(status string) bool {
	key := strings.ToLower(strings.TrimSpace(status))
	if key == "" {
		return false
	}
	if strings.Contains(key, "ajukan") {
		return false
	}
	return key == "baru" || strings.HasPrefix(key, "baru") || key == "1"
}

func resolveKasPhotoField(r *http.Request, field string, client *dropbox.Client, storeID string) (string, error) {
	file, header, ok := readOptionalMultipartFile(r, field)
	if ok {
		defer file.Close()
		content, err := io.ReadAll(io.LimitReader(file, dropboxMaxUploadBytes+1))
		if err != nil {
			return "", err
		}
		if len(content) == 0 {
			return "", nil
		}
		if len(content) > dropboxMaxUploadBytes {
			return "", errDcrFileTooLarge
		}
		path := buildKasDropboxPath(storeID, header.Filename)
		meta, err := client.Upload(path, content)
		if err != nil {
			return "", err
		}
		if meta != nil && strings.TrimSpace(meta.PathDisplay) != "" {
			return meta.PathDisplay, nil
		}
		return path, nil
	}

	return strings.TrimSpace(firstNonEmpty(
		rbcaParam(r, field),
		rbcaParam(r, "photo_path"),
		rbcaParam(r, "photoPath"),
	)), nil
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

	fromDate := firstNonEmpty(rbcaParam(r, "from_date"), rbcaParam(r, "fromDate"))
	toDate := firstNonEmpty(rbcaParam(r, "to_date"), rbcaParam(r, "toDate"))
	storeID := firstNonEmpty(rbcaParam(r, "store_id"), rbcaParam(r, "storeId"))

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

// GET /api/v1/store/kas/master-coa
// SP: xsp_api_store_kas_master_coa (@bitparam)
// Response rows: code, deskripsi, keterangan
func GetStoreKasMasterCoa(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Println("Error reading store kas master coa:", err.Error())
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000001", "Database unavailable"), r.Method, SPStoreKasMasterCoa)
		return
	}

	jsonResultData := runRbcaSPQuery(ctx, SPStoreKasMasterCoa)

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, SPStoreKasMasterCoa)
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, SPStoreKasMasterCoa)
}

// DELETE /api/v1/store/kas
// SP: xsp_api_store_kas_delete (@p_id, @bitparam)
// Hanya status "Baru" yang boleh dihapus (dicek dari query status bila dikirim).
func DeleteStoreKas(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Println("Error deleting store kas:", err.Error())
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000001", "Database unavailable"), r.Method, SPStoreKasDelete)
		return
	}

	_ = r.ParseForm()

	idRaw := firstNonEmpty(rbcaParam(r, "id"), rbcaParam(r, "p_id"))
	if idRaw == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "id is required"), r.Method, SPStoreKasDelete)
		return
	}
	idVal, err := strconv.Atoi(idRaw)
	if err != nil || idVal <= 0 {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "id must be a positive number"), r.Method, SPStoreKasDelete)
		return
	}

	status := firstNonEmpty(rbcaParam(r, "status"), rbcaParam(r, "p_status"))
	if status != "" && !isKasStatusBaru(status) {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4002501", "Hanya data dengan status Baru yang dapat dihapus"), r.Method, SPStoreKasDelete)
		return
	}

	jsonResultData := runRbcaSPQuery(ctx, SPStoreKasDelete,
		sql.Named("p_id", idVal),
	)

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, SPStoreKasDelete)
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, SPStoreKasDelete)
}

// POST /api/v1/store/kas (multipart or form)
// SP: xsp_api_store_kas_insert
// Foto wajib — diupload ke Dropbox (/uploads/kas/...) lalu path disimpan di p_photo.
func CreateStoreKas(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Println("Error inserting store kas:", err.Error())
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000001", "Database unavailable"), r.Method, SPStoreKasInsert)
		return
	}

	contentType := strings.ToLower(r.Header.Get("Content-Type"))
	if strings.Contains(contentType, "multipart/form-data") {
		if err := r.ParseMultipartForm(48 << 20); err != nil {
			writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "invalid multipart form or payload too large"), r.Method, SPStoreKasInsert)
			return
		}
	} else if err := r.ParseForm(); err != nil {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "invalid form payload"), r.Method, SPStoreKasInsert)
		return
	}

	storeID := firstNonEmpty(rbcaParam(r, "store_id"), rbcaParam(r, "storeId"), rbcaParam(r, "store"))
	if storeID == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "store_id is required"), r.Method, SPStoreKasInsert)
		return
	}

	brandID := firstNonEmpty(rbcaParam(r, "brand_id"), rbcaParam(r, "brandId"))
	if brandID == "" {
		brandID = "CELCIUS"
	}

	dateVal := firstNonEmpty(rbcaParam(r, "date"), rbcaParam(r, "p_date"))
	datetimeVal := firstNonEmpty(rbcaParam(r, "datetime"), rbcaParam(r, "p_datetime"), dateVal)
	if dateVal == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "date is required"), r.Method, SPStoreKasInsert)
		return
	}

	remarks := strings.TrimSpace(firstNonEmpty(rbcaParam(r, "remarks"), rbcaParam(r, "p_remarks"), rbcaParam(r, "keterangan")))
	if remarks == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "remarks is required"), r.Method, SPStoreKasInsert)
		return
	}

	coa := strings.TrimSpace(firstNonEmpty(rbcaParam(r, "coa"), rbcaParam(r, "p_coa"), rbcaParam(r, "code")))
	if coa == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "coa is required"), r.Method, SPStoreKasInsert)
		return
	}
	if len(coa) > 7 {
		coa = coa[:7]
	}

	amountOut := parseDcrAmount(firstNonEmpty(
		rbcaParam(r, "amount_out"),
		rbcaParam(r, "amountOut"),
		rbcaParam(r, "p_amount_out"),
	))
	if amountOut <= 0 {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "amount_out must be greater than 0"), r.Method, SPStoreKasInsert)
		return
	}

	client, err := dropbox.NewClientFromEnv()
	if err != nil {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000003", err.Error()), r.Method, SPStoreKasInsert)
		return
	}

	photo, upErr := resolveKasPhotoField(r, "photo", client, storeID)
	if upErr != nil {
		msg := upErr.Error()
		if errors.Is(upErr, errDcrFileTooLarge) {
			msg = errDcrFileTooLarge.Error()
		}
		writeRbcaJSONResponse(w, rbcaErrorJSON("5020001", "dropbox upload failed for photo: "+msg), r.Method, SPStoreKasInsert)
		return
	}
	photo = normalizeDcrImagePath(photo)
	if photo == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4003101", "Foto bukti kas wajib diisi"), r.Method, SPStoreKasInsert)
		return
	}

	creBy := firstNonEmpty(rbcaParam(r, "cre_by"), rbcaParam(r, "created_by"), rbcaNikFromJWT(r))
	if creBy == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "cre_by is required"), r.Method, SPStoreKasInsert)
		return
	}

	nowStr := time.Now().Format("2006-01-02 15:04:05")
	creDate := firstNonEmpty(rbcaParam(r, "cre_date"), nowStr)
	creIP := firstNonEmpty(rbcaParam(r, "cre_ip_address"), clientIPAddress(r))
	modBy := firstNonEmpty(rbcaParam(r, "mod_by"), rbcaParam(r, "updated_by"), creBy)
	modDate := firstNonEmpty(rbcaParam(r, "mod_date"), creDate)
	modIP := firstNonEmpty(rbcaParam(r, "mod_ip_address"), creIP)

	jsonResultData := runRbcaSPQuery(ctx, SPStoreKasInsert,
		sql.Named("p_brand_id", brandID),
		sql.Named("p_store_id", storeID),
		sql.Named("p_date", dateVal),
		sql.Named("p_datetime", datetimeVal),
		sql.Named("p_remarks", remarks),
		sql.Named("p_photo", photo),
		sql.Named("p_amount_out", amountOut),
		sql.Named("p_coa", coa),
		sql.Named("p_cre_by", creBy),
		sql.Named("p_cre_date", parseOptionalString(creDate)),
		sql.Named("p_cre_ip_address", parseOptionalString(creIP)),
		sql.Named("p_mod_by", parseOptionalString(modBy)),
		sql.Named("p_mod_date", parseOptionalString(modDate)),
		sql.Named("p_mod_ip_address", parseOptionalString(modIP)),
	)

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, SPStoreKasInsert)
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, SPStoreKasInsert)
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
