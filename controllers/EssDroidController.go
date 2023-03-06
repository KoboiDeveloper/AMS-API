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
func GetActivityHome(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_ess_get_last_activity",
		// sql.Named("p_xidstore", r.FormValue("id_store")),
		// sql.Named("p_xbatch", r.FormValue("tgl_batch")),
		// sql.Named("p_article", r.FormValue("article")),
		// sql.Named("p_apiKey", r.FormValue("apiKey")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
