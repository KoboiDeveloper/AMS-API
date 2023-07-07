package controllers

import (
	"GOamsAPI/database"
	//
	//"GOamsAPI/entities"
	"context"
	"database/sql"

	//"encoding/json"
	"fmt"
	"log"
	"net/http"
	//"golang.org/x/vuln/client"
)

// ambil adata aktifitas employee
func GetUserActive(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_check_user_active",
		sql.Named("p_nik", r.FormValue("nik")),
		// sql.Named("p_xbatch", r.FormValue("tgl_batch")),
		// sql.Named("p_article", r.FormValue("article")),
		// sql.Named("p_apiKey", r.FormValue("apiKey")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

//insert plu saat so scan

func UploadPluscan(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_so_store_upload_insert",

		sql.Named("p_code_so", r.FormValue("code_so")),
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("p_tanggal_so", r.FormValue("tanggal_so")),
		sql.Named("p_plu", r.FormValue("plu")),
		sql.Named("p_user_id", r.FormValue("user_id")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}

// history plu scanned

func HistoryPluscan(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_history_plu_scanned",
		sql.Named("p_code_so", r.FormValue("code_so")),
		sql.Named("p_nik", r.FormValue("nik")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
