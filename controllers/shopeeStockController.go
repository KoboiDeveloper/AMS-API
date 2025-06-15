package controllers

import (
	"GOamsAPI/database"
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"io/ioutil"
	"strconv"
	"time"

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

		ShopeeGetToken(w, r, Code, Shop_id)
	}
}

func GetTokenShopLevel(code string, shopID int, partnerID int, key string, host string) (string, error) {
	ts := time.Now().Unix()

	// Body JSON
	bodyObj := map[string]interface{}{
		"code":       code,
		"shop_id":    shopID,
		"partner_id": partnerID,
	}
	bodyJSON, _ := json.Marshal(bodyObj)

	// HMAC SHA256 sign
	path := "/api/v2/auth/token/get"
	baseStr := fmt.Sprintf("%d%s%d", partnerID, path, ts)
	h := hmac.New(sha256.New, []byte(key))
	h.Write([]byte(baseStr))
	sign := hex.EncodeToString(h.Sum(nil))

	// URL
	url := fmt.Sprintf("%s%s?partner_id=%d&timestamp=%d&sign=%s", host, path, partnerID, ts, sign)

	// HTTP POST
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(bodyJSON))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "Golang/1.16")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, _ := ioutil.ReadAll(resp.Body)
	return string(respBody), nil
}

func ShopeeGetToken(w http.ResponseWriter, r *http.Request, code string, shopID string) {

	ctx := context.Background()

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Periksa apakah nilai parameter telah diisi
	Code := r.FormValue("code")
	ShopIDStr := r.FormValue("shop_id")
	ShopID, err := strconv.Atoi(ShopIDStr)
	PartnerID := 2011595
	Key := "644b6f654544724b6a586f4f6e4a6c697778754a517342485a586f6965487258"
	host := "https://partner.shopeemobile.com"

	// Ambil Token dari shopee dulu
	tokenResp, err := GetTokenShopLevel(Code, ShopID, PartnerID, Key, host)
	var content map[string]interface{}
	json.Unmarshal([]byte(tokenResp), &content)
	if err != nil {
		fmt.Println("Error:", err)
	} else {
		fmt.Println("Access Token:", content["access_token"])
	}

	//value dari parameter ke db
	AccessToken := content["access_token"]
	AccessTokenDate := time.Now()
	//inject Token ke DB
	if AccessToken == "" {
		// Jika salah satu parameter tidak diisi, munculkan error
		fmt.Println("Error: Parameter tidak lengkap")
		w.WriteHeader(http.StatusUnauthorized)
		// Atau Anda bisa mengembalikan pesan error ke pemanggil fungsi atau melakukan tindakan lain sesuai kebutuhan aplikasi Anda.
	} else {
		var JsonResultData string

		database.Instance.QueryContext(ctx, "xsp_app_shopee_auth_acces_token_update",
			sql.Named("p_access_token", AccessToken),
			sql.Named("p_access_token_date", AccessTokenDate),
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
