package controllers

import (
	"GOamsAPI/database"
	"GOamsAPI/dropbox"
	"context"
	"database/sql"
	"errors"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"
)

func runPosSPQuery(ctx context.Context, spName string, namedArgs ...interface{}) string {
	var jsonResultData string
	args := append(namedArgs, sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))
	rows, err := database.Instance.QueryContext(ctx, spName, args...)
	if err != nil {
		log.Fatal("Error executing SP ", spName, ": ", err.Error())
	}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
		}
	}
	return jsonResultData
}

func pingPosDatabase(ctx context.Context) error {
	return database.Instance.PingContext(ctx)
}

func GetStoreEmployeeList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingPosDatabase(ctx); err != nil {
		log.Fatal("Error reading store employee list: ", err.Error())
	}

	jsonResultData := runPosSPQuery(ctx, "xsp_ams_new_personal_list_store_api_getrows",
		sql.Named("p_keywords", parseRbcaFilterString(rbcaParam(r, "keywords"))),
		sql.Named("p_store_id", parseRbcaFilterString(rbcaParam(r, "store_id"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_personal_list_store_api_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_personal_list_store_api_getrows")
}

func GetStoreSalesByClassPrice(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingPosDatabase(ctx); err != nil {
		log.Fatal("Error reading store sales by class price: ", err.Error())
	}

	jsonResultData := runPosSPQuery(ctx, "xsp_ams_new_analisa_sales_by_class_price_store_api_getrows",
		sql.Named("p_store_id", parseRbcaFilterString(rbcaParam(r, "store_id"))),
		sql.Named("p_date", parseOptionalString(rbcaParam(r, "date"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_analisa_sales_by_class_price_store_api_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_analisa_sales_by_class_price_store_api_getrows")
}

func GetStoreSalesBatch(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingPosDatabase(ctx); err != nil {
		log.Fatal("Error reading store sales batch: ", err.Error())
	}

	jsonResultData := runPosSPQuery(ctx, "xsp_ams_new_dt_batch_api_getrows",
		sql.Named("p_from_date", parseOptionalString(rbcaParam(r, "from_date"))),
		sql.Named("p_to_date", parseOptionalString(rbcaParam(r, "to_date"))),
		sql.Named("p_store_id", parseRbcaFilterString(rbcaParam(r, "store_id"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_dt_batch_api_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_dt_batch_api_getrows")
}

func GetStoreSalesManpower(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingPosDatabase(ctx); err != nil {
		log.Fatal("Error reading store sales manpower: ", err.Error())
	}

	jsonResultData := runPosSPQuery(ctx, "xsp_ams_new_sales_by_man_power_api_getrows",
		sql.Named("p_store_id", parseRbcaFilterString(rbcaParam(r, "store_id"))),
		sql.Named("p_user_nik", parseRbcaFilterString(rbcaParam(r, "user_nik"))),
		sql.Named("p_from_date", parseOptionalString(rbcaParam(r, "from_date"))),
		sql.Named("p_to_date", parseOptionalString(rbcaParam(r, "to_date"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_sales_by_man_power_api_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_sales_by_man_power_api_getrows")
}

func GetStoreNikList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingPosDatabase(ctx); err != nil {
		log.Fatal("Error reading store nik list: ", err.Error())
	}

	jsonResultData := runPosSPQuery(ctx, "xsp_ams_new_nik_by_store_api_getrows",
		sql.Named("p_store_id", parseRbcaFilterString(rbcaParam(r, "store_id"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_nik_by_store_api_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_nik_by_store_api_getrows")
}

func GetStoreSalesBestSellerInstore(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingPosDatabase(ctx); err != nil {
		log.Fatal("Error reading store bestseller instore: ", err.Error())
	}

	jsonResultData := runPosSPQuery(ctx, "xsp_ams_new_item_best_seller_api_getrows",
		sql.Named("p_plu", parseRbcaFilterString(rbcaParam(r, "plu"))),
		sql.Named("p_from_date", parseOptionalString(rbcaParam(r, "from_date"))),
		sql.Named("p_to_date", parseOptionalString(rbcaParam(r, "to_date"))),
		sql.Named("p_store_id", parseRbcaFilterString(rbcaParam(r, "store_id"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_item_best_seller_api_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_item_best_seller_api_getrows")
}

func GetStoreSalesBestSellerAllStore(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingPosDatabase(ctx); err != nil {
		log.Fatal("Error reading store bestseller allstore: ", err.Error())
	}

	jsonResultData := runPosSPQuery(ctx, "xsp_ams_new_item_brand_best_seller_api_getrows",
		sql.Named("p_plu", parseRbcaFilterString(rbcaParam(r, "plu"))),
		sql.Named("p_from_date", parseOptionalString(rbcaParam(r, "from_date"))),
		sql.Named("p_to_date", parseOptionalString(rbcaParam(r, "to_date"))),
		sql.Named("p_store_id", parseRbcaFilterString(rbcaParam(r, "store_id"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_item_brand_best_seller_api_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_item_brand_best_seller_api_getrows")
}

func GetStoreItemPromo(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingPosDatabase(ctx); err != nil {
		log.Fatal("Error reading store item promo: ", err.Error())
	}

	jsonResultData := runPosSPQuery(ctx, "xsp_ams_new_store_item_promosi_api_getrows",
		sql.Named("p_store_id", parseRbcaFilterString(rbcaParam(r, "store_id"))),
		sql.Named("p_plu", parseRbcaFilterString(rbcaParam(r, "plu"))),
		sql.Named("p_from_date", parseOptionalString(rbcaParam(r, "from_date"))),
		sql.Named("p_to_date", parseOptionalString(rbcaParam(r, "to_date"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_store_item_promosi_api_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_store_item_promosi_api_getrows")
}

func GetStoreSalesRefund(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingPosDatabase(ctx); err != nil {
		log.Fatal("Error reading store sales refund: ", err.Error())
	}

	jsonResultData := runPosSPQuery(ctx, "xsp_ams_new_store_sales_refund_api_getrows",
		sql.Named("p_store_id", parseRbcaFilterString(rbcaParam(r, "store_id"))),
		sql.Named("p_from_date", parseOptionalString(rbcaParam(r, "from_date"))),
		sql.Named("p_to_date", parseOptionalString(rbcaParam(r, "to_date"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_store_sales_refund_api_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_store_sales_refund_api_getrows")
}

func GetStoreSalesRefundDetail(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingPosDatabase(ctx); err != nil {
		log.Fatal("Error reading store sales refund detail: ", err.Error())
	}

	jsonResultData := runPosSPQuery(ctx, "xsp_ams_new_store_sales_refund_detail_api_getrows",
		sql.Named("p_id_tr_sales_refund", parseRbcaFilterString(rbcaParam(r, "id_tr_sales_refund"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_ams_new_store_sales_refund_detail_api_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_ams_new_store_sales_refund_detail_api_getrows")
}

// GetStoreSlipSetoranBank — list slip setoran bank / DCR per toko.
// SP: xsp_api_dt_dcr_getrows (@p_from_date, @p_to_date, @p_store_id, @bitparam) — RBCA
func GetStoreSlipSetoranBank(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading store slip setoran bank: ", err.Error())
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

	jsonResultData := runRbcaSPQuery(ctx, "xsp_api_dt_dcr_getrows",
		sql.Named("p_from_date", parseOptionalString(fromDate)),
		sql.Named("p_to_date", parseOptionalString(toDate)),
		sql.Named("p_store_id", parseRbcaFilterString(storeID)))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_api_dt_dcr_getrows")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_api_dt_dcr_getrows")
}

func parseDcrAmount(value string) float64 {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0
	}
	value = strings.ReplaceAll(value, ",", "")
	parsed, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return 0
	}
	return parsed
}

func readOptionalMultipartFile(r *http.Request, field string) (multipart.File, *multipart.FileHeader, bool) {
	file, header, err := r.FormFile(field)
	if err != nil || file == nil || header == nil {
		return nil, nil, false
	}
	return file, header, true
}

var errDcrFileTooLarge = errors.New("file too large (max 32MB per image)")

// resolveDcrImageField uploads multipart file to Dropbox when present,
// otherwise uses the form/JSON string path (already uploaded).
func resolveDcrImageField(r *http.Request, field string, client *dropbox.Client) (string, error) {
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
		path := buildDropboxPath("dcr", header.Filename)
		meta, err := client.Upload(path, content)
		if err != nil {
			return "", err
		}
		if meta != nil && strings.TrimSpace(meta.PathDisplay) != "" {
			return meta.PathDisplay, nil
		}
		return path, nil
	}

	// Already-uploaded path / filename from form or JSON body
	return strings.TrimSpace(rbcaParam(r, field)), nil
}

// CreateStoreSlipSetoranBank — insert DCR images + nilai.
// POST /api/v1/store/setoran/slip-setoran-bank (multipart or JSON)
// SP (RBCA): xsp_api_dt_dcr_image_insert
func CreateStoreSlipSetoranBank(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error inserting store slip setoran bank: ", err.Error())
	}

	contentType := strings.ToLower(r.Header.Get("Content-Type"))
	if strings.Contains(contentType, "multipart/form-data") {
		if err := r.ParseMultipartForm(48 << 20); err != nil {
			writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "invalid multipart form or payload too large"), r.Method, "xsp_api_dt_dcr_image_insert")
			return
		}
	} else if err := r.ParseForm(); err != nil {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "invalid form payload"), r.Method, "xsp_api_dt_dcr_image_insert")
		return
	}

	client, err := dropbox.NewClientFromEnv()
	if err != nil {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000003", err.Error()), r.Method, "xsp_api_dt_dcr_image_insert")
		return
	}

	imageFields := []string{"image_1", "image_2", "image_3", "image_4", "image_5", "image_6"}
	images := make([]string, len(imageFields))
	hasImage := false
	for i, field := range imageFields {
		path, upErr := resolveDcrImageField(r, field, client)
		if upErr != nil {
			msg := upErr.Error()
			if errors.Is(upErr, errDcrFileTooLarge) {
				msg = errDcrFileTooLarge.Error()
			}
			writeRbcaJSONResponse(w, rbcaErrorJSON("5020001", "dropbox upload failed for "+field+": "+msg), r.Method, "xsp_api_dt_dcr_image_insert")
			return
		}
		images[i] = path
		if path != "" {
			hasImage = true
		}
	}

	if !hasImage {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4003101", "Minimal satu gambar wajib diisi"), r.Method, "xsp_api_dt_dcr_image_insert")
		return
	}

	creBy := strings.TrimSpace(rbcaParam(r, "cre_by"))
	if creBy == "" {
		creBy = strings.TrimSpace(rbcaParam(r, "created_by"))
	}
	if creBy == "" {
		creBy = rbcaNikFromJWT(r)
	}
	if creBy == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "cre_by is required"), r.Method, "xsp_api_dt_dcr_image_insert")
		return
	}

	nilaiBni := parseDcrAmount(firstNonEmpty(rbcaParam(r, "nilai_bni"), rbcaParam(r, "nilaiBni")))
	nilaiMandiri := parseDcrAmount(firstNonEmpty(rbcaParam(r, "nilai_mandiri"), rbcaParam(r, "nilaiMandiri")))
	nilaiDirect := parseDcrAmount(firstNonEmpty(rbcaParam(r, "nilai_directselling"), rbcaParam(r, "nilai_direct_selling"), rbcaParam(r, "nilaiDirectSelling")))

	tglBatch := strings.TrimSpace(firstNonEmpty(rbcaParam(r, "tgl_batch"), rbcaParam(r, "tglBatch")))
	creDate := strings.TrimSpace(firstNonEmpty(rbcaParam(r, "cre_date"), tglBatch))

	creIP := strings.TrimSpace(rbcaParam(r, "cre_ip_address"))
	if creIP == "" {
		creIP = clientIPAddress(r)
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_api_dt_dcr_image_insert",
		sql.Named("p_image_1", parseOptionalString(images[0])),
		sql.Named("p_image_2", parseOptionalString(images[1])),
		sql.Named("p_image_3", parseOptionalString(images[2])),
		sql.Named("p_image_4", parseOptionalString(images[3])),
		sql.Named("p_image_5", parseOptionalString(images[4])),
		sql.Named("p_image_6", parseOptionalString(images[5])),
		sql.Named("p_nilai_bni", nilaiBni),
		sql.Named("p_nilai_mandiri", nilaiMandiri),
		sql.Named("p_nilai_directselling", nilaiDirect),
		sql.Named("p_cre_by", creBy),
		sql.Named("p_cre_date", parseOptionalString(creDate)),
		sql.Named("p_cre_ip_address", parseOptionalString(creIP)),
		sql.Named("p_mod_by", parseOptionalString(firstNonEmpty(rbcaParam(r, "mod_by"), rbcaParam(r, "updated_by")))),
		sql.Named("p_mod_date", parseOptionalString(rbcaParam(r, "mod_date"))),
		sql.Named("p_mod_ip_address", parseOptionalString(rbcaParam(r, "mod_ip_address"))),
	)

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_api_dt_dcr_image_insert")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_api_dt_dcr_image_insert")
}

// UpdateStoreSlipSetoranBank — update DCR images + nilai by id.
// PUT /api/v1/store/setoran/slip-setoran-bank (multipart or JSON)
// SP (RBCA): xsp_api_dt_dcr_image_update
func UpdateStoreSlipSetoranBank(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error updating store slip setoran bank: ", err.Error())
	}

	contentType := strings.ToLower(r.Header.Get("Content-Type"))
	if strings.Contains(contentType, "multipart/form-data") {
		if err := r.ParseMultipartForm(48 << 20); err != nil {
			writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "invalid multipart form or payload too large"), r.Method, "xsp_api_dt_dcr_image_update")
			return
		}
	} else if err := r.ParseForm(); err != nil {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "invalid form payload"), r.Method, "xsp_api_dt_dcr_image_update")
		return
	}

	idRaw := strings.TrimSpace(firstNonEmpty(rbcaParam(r, "id"), rbcaParam(r, "p_id")))
	if idRaw == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "id is required"), r.Method, "xsp_api_dt_dcr_image_update")
		return
	}
	idVal, err := strconv.ParseInt(idRaw, 10, 64)
	if err != nil || idVal <= 0 {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "id must be a positive number"), r.Method, "xsp_api_dt_dcr_image_update")
		return
	}

	client, err := dropbox.NewClientFromEnv()
	if err != nil {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000003", err.Error()), r.Method, "xsp_api_dt_dcr_image_update")
		return
	}

	imageFields := []string{"image_1", "image_2", "image_3", "image_4", "image_5", "image_6"}
	images := make([]string, len(imageFields))
	hasImage := false
	for i, field := range imageFields {
		path, upErr := resolveDcrImageField(r, field, client)
		if upErr != nil {
			msg := upErr.Error()
			if errors.Is(upErr, errDcrFileTooLarge) {
				msg = errDcrFileTooLarge.Error()
			}
			writeRbcaJSONResponse(w, rbcaErrorJSON("5020001", "dropbox upload failed for "+field+": "+msg), r.Method, "xsp_api_dt_dcr_image_update")
			return
		}
		images[i] = path
		if path != "" {
			hasImage = true
		}
	}

	if !hasImage {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4003101", "Minimal satu gambar wajib diisi"), r.Method, "xsp_api_dt_dcr_image_update")
		return
	}

	modBy := strings.TrimSpace(firstNonEmpty(rbcaParam(r, "mod_by"), rbcaParam(r, "updated_by"), rbcaParam(r, "cre_by")))
	if modBy == "" {
		modBy = rbcaNikFromJWT(r)
	}
	if modBy == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("4000001", "mod_by is required"), r.Method, "xsp_api_dt_dcr_image_update")
		return
	}

	nilaiBni := parseDcrAmount(firstNonEmpty(rbcaParam(r, "nilai_bni"), rbcaParam(r, "nilaiBni")))
	nilaiMandiri := parseDcrAmount(firstNonEmpty(rbcaParam(r, "nilai_mandiri"), rbcaParam(r, "nilaiMandiri")))
	nilaiDirect := parseDcrAmount(firstNonEmpty(rbcaParam(r, "nilai_directselling"), rbcaParam(r, "nilai_direct_selling"), rbcaParam(r, "nilaiDirectSelling")))

	modIP := strings.TrimSpace(rbcaParam(r, "mod_ip_address"))
	if modIP == "" {
		modIP = clientIPAddress(r)
	}

	jsonResultData := runRbcaSPQuery(ctx, "xsp_api_dt_dcr_image_update",
		sql.Named("p_id", idVal),
		sql.Named("p_image_1", parseOptionalString(images[0])),
		sql.Named("p_image_2", parseOptionalString(images[1])),
		sql.Named("p_image_3", parseOptionalString(images[2])),
		sql.Named("p_image_4", parseOptionalString(images[3])),
		sql.Named("p_image_5", parseOptionalString(images[4])),
		sql.Named("p_image_6", parseOptionalString(images[5])),
		sql.Named("p_mod_by", modBy),
		sql.Named("p_mod_date", parseOptionalString(rbcaParam(r, "mod_date"))),
		sql.Named("p_mod_ip_address", parseOptionalString(modIP)),
		sql.Named("p_nilai_bni", nilaiBni),
		sql.Named("p_nilai_mandiri", nilaiMandiri),
		sql.Named("p_nilai_directselling", nilaiDirect),
	)

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "xsp_api_dt_dcr_image_update")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_api_dt_dcr_image_update")
}
