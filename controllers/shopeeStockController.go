package controllers

import (
	"GOamsAPI/database"
	"context"
	"database/sql"
	"encoding/json"

	//"GOamsAPI/entities"

	//"encoding/json"
	"fmt"
	"net/http"
	//"golang.org/x/vuln/client"
	// <- kalau pakai lib ini
)

func ShopeeAuthCallback(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Periksa apakah nilai parameter telah diisi
	Code := r.FormValue("code")
	Shop_id := r.FormValue("shop_id")
	if Code == "" || Shop_id == "" {
		// Jika salah satu parameter tidak diisi, munculkan error
		fmt.Println("Error: Parameter tidak lengkap")
		w.WriteHeader(http.StatusUnauthorized)
		// Atau Anda bisa mengembalikan pesan error ke pemanggil fungsi atau melakukan tindakan lain sesuai kebutuhan aplikasi Anda.
	} else {
		var JsonResultData string

		database.Instance.QueryContext(ctx, "xsp_app_shopee_auth_callback_insert",
			sql.Named("p_code", Code),
			sql.Named("p_shop_id", Shop_id),
			sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

		w.Header().Set("Content-Type", "application/json")
		var result map[string]interface{}
		err := json.Unmarshal([]byte(JsonResultData), &result)
		if err != nil {
			http.Error(w, "Error parsing JSON", http.StatusInternalServerError)
			return
		}

		if result["responseCode"].(string) == "2002500" {
			w.WriteHeader(http.StatusOK)
			fmt.Fprint(w, string(JsonResultData))
		}
	}
}
