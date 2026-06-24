package controllers

import (
	"GOamsAPI/database"
	"context"
	"database/sql"
	"log"
	"net/http"
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
