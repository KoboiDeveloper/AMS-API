package controllers

import (
	"GOamsAPI/database"
	"bytes"
	"encoding/json"
	"io/ioutil"
	"strconv"

	//"GOamsAPI/entities"
	"context"
	"database/sql"

	//"encoding/json"
	"fmt"
	"log"
	"net/http"

	//"golang.org/x/vuln/client"
	"github.com/gorilla/mux"
)

func CreateProduct(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "XSP_API_PRODUK_INSERT",
		sql.Named("p_kode_barcode", r.FormValue("kode_barcode")),
		sql.Named("p_nama_barang", r.FormValue("nama_barang")),
		sql.Named("p_kategori", r.FormValue("kategori")),
		sql.Named("p_qty", r.FormValue("qty")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}

// func checkIfProductExists(productId string) bool {
// 	var product entities.Product
// 	database.Instance.First(&product, productId)
// 	return product.ID != 0
// }

func GetProductById(w http.ResponseWriter, r *http.Request) {
	productId := mux.Vars(r)["id"]

	ctx := context.Background()
	///?id=300
	id, err := strconv.Atoi(productId)
	if err != nil || id < 1 {
		fmt.Fprint(w, err)
		// log.Fatal(err)
		return
	} //end

	// resp, err := http.Get("https://www.google.com")
	// if err != nil {
	//    log.Fatal(err)
	// }

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_personel_identitas_getrow_api",
		//	sql.Named("p_pegawai_id", id),
		sql.Named("p_pegawai_id", id),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")

	fmt.Fprint(w, JsonResultData)

}

func GetStoreLastStock(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_rpt_last_stock_p_last_batch_api",
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

func UpdateProduct(w http.ResponseWriter, r *http.Request) {
	productId := mux.Vars(r)["id"]

	ctx := context.Background()
	///?id=300
	id, err := strconv.Atoi(productId)
	if err != nil || id < 1 {
		fmt.Fprint(w, err)
		// log.Fatal(err)
		return
	} //end
	var JsonResultData string
	database.Instance.QueryContext(ctx, "XSP_API_PRODUK_UPDATE",
		//	sql.Named("p_pegawai_id", id),
		sql.Named("p_id", id),
		sql.Named("p_kode_barcode", r.FormValue("kode_barcode")),
		sql.Named("p_nama_barang", r.FormValue("nama_barang")),
		sql.Named("p_kategori", r.FormValue("kategori")),
		sql.Named("p_qty", r.FormValue("qty")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")

	fmt.Fprint(w, JsonResultData)

}

func DeleteProduct(w http.ResponseWriter, r *http.Request) {
	productId := mux.Vars(r)["id"]

	ctx := context.Background()
	///?id=300
	id, err := strconv.Atoi(productId)
	if err != nil || id < 1 {
		fmt.Fprint(w, err)
		// log.Fatal(err)
		return
	} //end
	var JsonResultData string
	database.Instance.QueryContext(ctx, "XSP_API_PRODUK_DELETE",
		//	sql.Named("p_pegawai_id", id),
		sql.Named("p_id", id),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")

	fmt.Fprint(w, JsonResultData)

}

// /////space management
func GetSpaceManagement(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_space_management_getrows",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func CreateSpaceManagement(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_space_management_insert",
		sql.Named("p_luas_toko", r.FormValue("luas_toko")),
		sql.Named("p_min_luas", r.FormValue("min_luas")),
		sql.Named("p_max_luas", r.FormValue("max_luas")),
		sql.Named("p_ideal_inventory", r.FormValue("ideal_inventory")),
		// sql.Named("p_brand", r.FormValue("brand")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func UpdateSpaceManagement(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_space_management_update",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("p_luas_toko", r.FormValue("luas_toko")),
		sql.Named("p_min_luas", r.FormValue("min_luas")),
		sql.Named("p_max_luas", r.FormValue("max_luas")),
		sql.Named("p_ideal_inventory", r.FormValue("ideal_inventory")),
		// sql.Named("p_brand", r.FormValue("brand")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func DeleteSpaceManagement(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_space_management_delete",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}

// ////// KOMPOSISI IDEAL

func GetKomposisiIdealInfo(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_komposisi_ideal_info_getrows",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

// get Komposisi Ideal for Modal Space Management by luas toko and brand
func GetKomposisiIdeal(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_komposisi_ideal_getrows",
		sql.Named("p_brand", r.FormValue("brand")),
		sql.Named("p_luas_toko", r.FormValue("luas_toko")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func CreateKomposisiIdeal(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_komposisi_ideal_insert",

		sql.Named("p_id_space_management", r.FormValue("id_space_management")),
		sql.Named("p_class", r.FormValue("class")),
		sql.Named("p_komposisi", r.FormValue("komposisi")),
		sql.Named("p_brand", r.FormValue("brand")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func UpdateKomposisiIdeal(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_komposisi_ideal_update",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("p_id_space_management", r.FormValue("id_space_management")),
		sql.Named("p_class", r.FormValue("class")),
		sql.Named("p_komposisi", r.FormValue("komposisi")),
		sql.Named("p_brand", r.FormValue("brand")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func DeleteKomposisiIdeal(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_komposisi_ideal_delete",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}

///////// DROPDOWN

func GetDropdownLuasToko(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_dropdown_luas_toko_getrows",

		sql.Named("p_brand", r.FormValue("Brand")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}
func GetDropdownClassVM(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_dropdown_class_vm_getrows",
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}
func GetDropdownClass(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_dropdown_class_getrows",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))
	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}

func GetDropdownAreaSales(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_dropdown_Area_sales_getrows",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))
	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}
func GetDropdownClassVMSingle(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_dropdown_class_vm_single_getrows",
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("p_class", r.FormValue("class_code")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}

func GetDropdownBrandID(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}
	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_dropdown_brand_id_getrows",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}
func GetDropdownBrandIDs(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}
	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_dropdown_brand_ids_getrows",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}
func GetDropdownStoreID(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}
	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_dropdown_store_id_getrows",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}

func GetDropdownArticleByStore(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}
	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_md_buyer_existing_Store_article_dropdown_getrows",
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}

// ////// AREA SALES
func GetAreaSales(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_area_sales_getrows",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func CreateAreaSales(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_area_sales_insert",

		sql.Named("p_kode", r.FormValue("kode")),
		sql.Named("p_keterangan", r.FormValue("keterangan")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func UpdateAreaSales(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_area_sales_update",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("p_kode", r.FormValue("kode")),
		sql.Named("p_keterangan", r.FormValue("keterangan")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func DeleteAreaSales(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_area_sales_delete",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}

// ////// GRAND OPENING
func GetGrandOpening(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_grand_opening_getrows",
		sql.Named("p_tipe_store", r.FormValue("tipestore")),
		sql.Named("p_brand", r.FormValue("brand")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func CreateGrandOpening(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_grand_opening_insert",

		sql.Named("p_brand", r.FormValue("brand")),
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("p_kota", r.FormValue("kota")),
		sql.Named("p_tanggal_go", r.FormValue("tanggal_go")),
		sql.Named("p_luas_toko_real", r.FormValue("luas_toko_real")),
		sql.Named("p_luas_toko", r.FormValue("luas_toko")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func UpdateGrandOpening(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_grand_opening_update",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("p_brand", r.FormValue("brand")),
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("p_kota", r.FormValue("kota")),
		sql.Named("p_tanggal_go", r.FormValue("tanggal_go")),
		sql.Named("p_luas_toko_real", r.FormValue("luas_toko_real")),

		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func DeleteGrandOpening(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_grand_opening_delete",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}

func GetKategoriLuasToko(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_kategori_luas_toko_getrow",
		sql.Named("p_luas_toko_real", r.FormValue("luasTokoReal")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}

// ////// GRAND OPENING VM
func GetGrandOpeningDetail(w http.ResponseWriter, r *http.Request) {

	productId := mux.Vars(r)["id"]

	ctx := context.Background()
	///?id=300
	id, err := strconv.Atoi(productId)
	if err != nil || id < 1 {
		fmt.Fprint(w, err)
		// log.Fatal(err)
		return
	} //end

	// resp, err := http.Get("https://www.google.com")
	// if err != nil {
	//    log.Fatal(err)
	// }

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_grand_opening_vm_getrow",
		//	sql.Named("p_pegawai_id", id),
		sql.Named("p_id", id),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")

	fmt.Fprint(w, JsonResultData)
	//json.NewEncoder(w).Encode(products)
}

// ////// VM STORAGE - GRAND OPENING
func GetVmStorage(w http.ResponseWriter, r *http.Request) {
	luas_tokoId := mux.Vars(r)["luas_toko"]

	ctx := context.Background()

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_vm_storage_getrows",
		sql.Named("p_luas_toko", luas_tokoId),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func CreateVmStorage(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_vm_storage_insert",

		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("p_luas_toko", r.FormValue("luas_toko")),
		sql.Named("p_class", r.FormValue("class")),
		sql.Named("p_area_sales", r.FormValue("area_sales")),
		sql.Named("p_qty_pajang", r.FormValue("qty_pajang")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func UpdateVmStorage(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_vm_storage_update",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("p_luas_toko", r.FormValue("luas_toko")),
		sql.Named("p_class", r.FormValue("class")),
		sql.Named("p_area_sales", r.FormValue("area_sales")),
		sql.Named("p_qty_pajang", r.FormValue("qty_pajang")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func DeleteVmStorage(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_vm_storage_delete",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}

// ////// MD BUYER - STORE GRAND OPENING
func GetMdBuyerGO(w http.ResponseWriter, r *http.Request) {

	goID := mux.Vars(r)["id"]
	brand := mux.Vars(r)["brand"]

	ctx := context.Background()
	///?id=300
	id, err := strconv.Atoi(goID)
	if err != nil || id < 1 {
		fmt.Fprint(w, err)
		// log.Fatal(err)
		return
	} //end

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_md_buyer_getrows",
		sql.Named("p_id", id),
		sql.Named("p_brand", brand),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func GetMdBuyerExsistingStore(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_md_buyer_existing_Store_getrows",
		sql.Named("p_brand_id", r.FormValue("brand")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMdBuyerExsistingStoreByclass(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_md_buyer_existing_Store_by_class_getrows",
		sql.Named("p_store_id", r.FormValue("StoreID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func GetMdBuyerExsistingStoreByDept(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_md_buyer_existing_Store_by_dept_getrows",
		sql.Named("p_store_id", r.FormValue("StoreID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMdBuyerExsistingStoreDetailInventory(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_md_buyer_existing_Store_detail_inventory_getrows",
		sql.Named("p_store_id", r.FormValue("StoreID")),
		sql.Named("p_Article", r.FormValue("Article")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMdBuyerExsistingStoreDetailInventory_DC_SCAN(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	////
	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_grand_opening_Store_detail_inventory_dc_scan_getrows",
		sql.Named("p_store_id", r.FormValue("StoreID")),
		sql.Named("p_tgl_go", r.FormValue("Tgl_GO")),
		sql.Named("p_theme", r.FormValue("theme")),
		sql.Named("p_article", r.FormValue("article")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func GetMdBuyerExsistingStoreDetailInventory_DC_SCAN_by_Class(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_grand_opening_Store_detail_inventory_dc_scan_by_class_getrows",
		sql.Named("p_id", r.FormValue("id")),
		sql.Named("p_brand", r.FormValue("brand")),
		sql.Named("p_store_id", r.FormValue("StoreID")),
		sql.Named("p_tgl_go", r.FormValue("Tgl_GO")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

//////AGING REPORT

func GetMdBuyerExsistingBrandAging(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_md_buyer_report_aging_by_brand_getrows",
		sql.Named("p_brand_id", r.FormValue("BrandID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMdBuyerExsistingStoreAging(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_md_buyer_report_aging_by_store_getrows",
		sql.Named("p_brand_id", r.FormValue("BrandID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMdBuyerExsistingStoreClassAging(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_md_buyer_report_aging_by_store_class_getrows",
		sql.Named("p_store_id", r.FormValue("StoreID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

// //// TARGET SALES
func GetTargetSalesStore(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_Target_sales_store_getrows",
		sql.Named("p_brand_id", r.FormValue("brand")),
		sql.Named("p_bulan", r.FormValue("bulan")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func GetTargetSalesStorePopupAnalisis(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_Target_sales_analisis_getrow",

		sql.Named("p_store_id", r.FormValue("StoreID")),
		sql.Named("p_from_date", r.FormValue("FromDate")),
		sql.Named("p_to_date", r.FormValue("ToDate")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func CreateTargetSales(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_target_sales_insert",
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("p_bulan", r.FormValue("bulan")),
		sql.Named("p_year", r.FormValue("tahun")),
		sql.Named("p_TargetSales", r.FormValue("TARGET_SALES")),
		sql.Named("p_TipeTarget", r.FormValue("TIPE_TARGET")),
		sql.Named("p_analisaFromDate", r.FormValue("analisaFromDate")),
		sql.Named("p_analisaToDate", r.FormValue("analisaToDate")),
		sql.Named("p_analisaQty", r.FormValue("analisaQty")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
}
func UpdateTargetSales(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_target_sales_update",
		//	sql.Named("p_pegawai_id", id),
		sql.Named("p_store_id", r.FormValue("store_id")),
		sql.Named("p_bulan", r.FormValue("bulan")),
		sql.Named("p_year", r.FormValue("tahun")),
		sql.Named("p_TargetSales", r.FormValue("TARGET_SALES")),
		sql.Named("p_TipeTarget", r.FormValue("TIPE_TARGET")),
		sql.Named("p_analisaFromDate", r.FormValue("analisaFromDate")),
		sql.Named("p_analisaToDate", r.FormValue("analisaToDate")),
		sql.Named("p_analisaQty", r.FormValue("analisaQty")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")

	fmt.Fprint(w, JsonResultData)

}

//////   DASHBIARDas

func GetSalesChartDashboardDaily(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	// database.Instance.QueryContext(ctx, "api_md_buyer_existing_Store_by_class_getrows",
	database.Instance.QueryContext(ctx, "api_sales_chart_dashboard_daily_getrows",
		sql.Named("p_month", r.FormValue("month")),
		sql.Named("p_year", r.FormValue("year")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetSalesChartDashboardWeekly(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	// database.Instance.QueryContext(ctx, "api_md_buyer_existing_Store_by_class_getrows",
	database.Instance.QueryContext(ctx, "api_sales_chart_dashboard_weekly_getrows",
		sql.Named("p_month", r.FormValue("month")),
		sql.Named("p_year", r.FormValue("year")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetSalesChartDashboardMonthly(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	// database.Instance.QueryContext(ctx, "api_md_buyer_existing_Store_by_class_getrows",
	database.Instance.QueryContext(ctx, "api_sales_chart_dashboard_monthly_getrows",
		sql.Named("p_year", r.FormValue("year")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetTOrendahDashboard(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_get_TO_rendah_dashboard_getrows",
		sql.Named("p_brand_id", r.FormValue("brand")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func GetKurangBarang(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_get_barang_kurang_dashboard_getrows",
		sql.Named("p_brand_id", r.FormValue("brand")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func GetTotalTokoGO(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Data: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_get_total_toko_go_chart_getrows",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetDropdownGOThemeFilter(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "api_dropdown_go_theme_filter_getrows",

		sql.Named("p_store_id", r.FormValue("StoreID")),
		sql.Named("p_tgl_go", r.FormValue("Tgl_GO")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)

	fmt.Fprint(w, string(JsonResultData))

	//json.NewEncoder(w).Encode(products)
}

func GetmemberActivity(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_dashboard_member_Activity_chart_getrow",
		sql.Named("p_from_date", r.FormValue("from_date")),
		sql.Named("p_to_date", r.FormValue("to_date")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetGrowthMemberActivity(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_dashboard_member_Activity_growth_member_chart_getrow",
		sql.Named("p_from_date", r.FormValue("from_date")),
		sql.Named("p_to_date", r.FormValue("to_date")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

// /mobile Controller member
func GetMemberDashboardInfo(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_dashboard_info_getrow",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMemberDashboardPromo(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_dashboard_promo_getrow",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMemberPromoList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_promo_list_getrow",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func GetMemberPromoDetail(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_promo_detail_getrow",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("p_id_promo", r.FormValue("id_promo")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetStoreLocationList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_Location_list_getrow",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func GetStoreLocationDetail(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_Location_detail_getrow",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("p_id_store", r.FormValue("id_store")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMemberProfile(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_profile_getrow",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMemberProfileUpdate(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_profile_update",
		sql.Named("p_id_member", r.FormValue("id_member")),
		// ------------------
		sql.Named("p_nama_lengkap", r.FormValue("namaLengkap")),
		sql.Named("p_nama_panggilan", r.FormValue("namaPanggilan")),
		sql.Named("p_no_telepon", r.FormValue("notelpon")),
		sql.Named("p_email", r.FormValue("email")),
		sql.Named("p_password", r.FormValue("password")),
		sql.Named("p_provinsi", r.FormValue("provinsi")),
		sql.Named("p_kota", r.FormValue("kota")),
		sql.Named("p_kelamin", r.FormValue("kelamin")),
		sql.Named("p_tgl_lahir", r.FormValue("tglLahir")),
		sql.Named("p_minat_kategori", r.FormValue("minatKategori")),
		sql.Named("p_alamat", r.FormValue("alamat")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMemberTransactionHistory(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_history_transaction_getrows",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func CreateMemberVoucher(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	idMember := r.FormValue("id_member")
	voucherCode := r.FormValue("voucher_code")
	ipAddress := r.FormValue("ip_address")

	if idMember == "" || voucherCode == "" || ipAddress == "" {
		// Jika salah satu parameter tidak diisi, munculkan error
		fmt.Println("Error: Parameter tidak lengkap")
		w.WriteHeader(http.StatusBadRequest)
		// Atau Anda bisa mengembalikan pesan error ke pemanggil fungsi atau melakukan tindakan lain sesuai kebutuhan aplikasi Anda.
	} else {
		// Check if database is alive.
		err := database.Instance.PingContext(ctx)
		if err != nil {
			log.Fatal("Error Cuyy: ", err.Error())
		}
		var JsonResultData string
		database.Instance.QueryContext(ctx, "xsp_app_member_redeem_voucher_insert",
			sql.Named("p_id_member", idMember),
			sql.Named("p_vouchercode", voucherCode),
			sql.Named("p_ip_address", ipAddress),
			sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, string(JsonResultData))

	}
}

func GetMemberVoucherDetail(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_voucher_detail_getrow",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("p_no_voucher", r.FormValue("no_voucher")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMemberVoucherList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_voucher_list_getrows",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func GetMemberGiftList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_gift_list_getrows",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMemberVoucherTukarList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_voucher_list_untuk_tukar_getrows",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetMemberVoucherTransactionHistoryList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_voucher_transaction_history_list_getrows",
		sql.Named("p_id_member", r.FormValue("id_member")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetVerify(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Periksa apakah nilai parameter telah diisi
	userAccount := r.FormValue("userAccount")
	if userAccount == "" {
		// Jika salah satu parameter tidak diisi, munculkan error
		fmt.Println("Error: Parameter tidak lengkap")
		w.WriteHeader(http.StatusUnauthorized)
		// Atau Anda bisa mengembalikan pesan error ke pemanggil fungsi atau melakukan tindakan lain sesuai kebutuhan aplikasi Anda.
	} else {

		var JsonResultData string

		database.Instance.QueryContext(ctx, "xsp_app_member_verify",
			sql.Named("p_userAccount", r.FormValue("userAccount")),
			sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

		w.Header().Set("Content-Type", "application/json")
		var result map[string]interface{}
		if err := json.Unmarshal([]byte(JsonResultData), &result); err != nil {
			http.Error(w, "Error parsing JSON", http.StatusInternalServerError)
			return
		}

		// loginData, ok := result)
		// if !ok {
		// 	http.Error(w, "Error extracting loginData", http.StatusInternalServerError)
		// 	return
		// }

		// loginDataJSON, err := json.Marshal(result)
		// if err != nil {
		// 	http.Error(w, "Error marshalling loginData", http.StatusInternalServerError)
		// 	return
		// }

		if result["responseMessage"].(string) == "User Exists" {
			fmt.Fprint(w, json.NewEncoder(w).Encode(result))
			SendOTP(w, r, userAccount)
		}
		// else {
		// 	w.WriteHeader(http.StatusOK)
		// 	fmt.Fprint(w, string(JsonResultData))
		// }

	}
}

func GetValidate(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Periksa apakah nilai parameter telah diisi
	idMember := r.FormValue("idMember")
	if idMember == "" {
		// Jika salah satu parameter tidak diisi, munculkan error
		fmt.Println("Error: Parameter tidak lengkap")
		w.WriteHeader(http.StatusUnauthorized)
		// Atau Anda bisa mengembalikan pesan error ke pemanggil fungsi atau melakukan tindakan lain sesuai kebutuhan aplikasi Anda.
	} else {

		var JsonResultData string

		database.Instance.QueryContext(ctx, "xsp_app_member_validate",
			sql.Named("p_id_member", r.FormValue("idMember")),
			sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, string(JsonResultData))
	}
}

func GetLogin(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Periksa apakah nilai parameter telah diisi
	user := r.FormValue("user")
	password := r.FormValue("password")

	if user == "" || password == "" {
		// Jika salah satu parameter tidak diisi, munculkan error
		fmt.Println("Error: Parameter tidak lengkap")
		w.WriteHeader(http.StatusUnauthorized)
		// Atau Anda bisa mengembalikan pesan error ke pemanggil fungsi atau melakukan tindakan lain sesuai kebutuhan aplikasi Anda.
	} else {

		// Check if database is alive.
		err := database.Instance.PingContext(ctx)
		if err != nil {
			log.Fatal("Error Cuyy: ", err.Error())
		}
		var JsonResultData string
		database.Instance.QueryContext(ctx, "xsp_app_member_login",
			sql.Named("p_user", r.FormValue("user")),
			sql.Named("p_password", r.FormValue("password")),

			sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		//w.WriteHeader(http.StatusUnauthorized)
		//json.NewEncoder(w).Encode(JsonResultData)
		fmt.Fprint(w, string(JsonResultData))
	}
}

func GetRegisterUser(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	namaLengkap := r.FormValue("namaLengkap")
	namaPanggilan := r.FormValue("namaPanggilan")
	notelpon := r.FormValue("notelpon")
	email := r.FormValue("email")
	password := r.FormValue("password")
	provinsi := r.FormValue("provinsi")
	kota := r.FormValue("kota")
	kelamin := r.FormValue("kelamin")
	tglLahir := r.FormValue("tglLahir")
	minatKategori := r.FormValue("minatKategori")
	alamat := r.FormValue("alamat")

	if namaLengkap == "" || namaPanggilan == "" || notelpon == "" || email == "" || password == "" || provinsi == "" || kota == "" || kelamin == "" || tglLahir == "" || minatKategori == "" || alamat == "" {
		// Jika salah satu parameter tidak diisi, munculkan error
		fmt.Println("Error: Parameter tidak lengkap")
		w.WriteHeader(http.StatusBadRequest)
		// Atau Anda bisa mengembalikan pesan error ke pemanggil fungsi atau melakukan tindakan lain sesuai kebutuhan aplikasi Anda.
	} else {

		// Check if database is alive.
		err := database.Instance.PingContext(ctx)
		if err != nil {
			log.Fatal("Error Cuyy: ", err.Error())
		}
		var JsonResultData string
		database.Instance.QueryContext(ctx, "xsp_app_member_register",

			sql.Named("p_nama_lengkap", namaLengkap),
			sql.Named("p_nama_panggilan", namaPanggilan),
			sql.Named("p_no_telepon", notelpon),
			sql.Named("p_email", email),
			sql.Named("p_password", password),
			sql.Named("p_provinsi", provinsi),
			sql.Named("p_kota", kota),
			sql.Named("p_kelamin", kelamin),
			sql.Named("p_tgl_lahir", tglLahir),
			sql.Named("p_minat_kategori", minatKategori),
			sql.Named("p_alamat", alamat),
			sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, string(JsonResultData))
	}
}

func GetProvincesList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_master_provinces",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetCitiesList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_app_member_master_cities",
		sql.Named("p_prov_id", r.FormValue("provID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetContactInfo(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_app_member_contact_info_getrow",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetFAQInfo(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_app_member_faq_getrows",
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func CreateTokenNotification(w http.ResponseWriter, r *http.Request) {

	ctx := context.Background()

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	idMember := r.FormValue("id_member")
	ExpoPushToken := r.FormValue("ExpoPushToken")

	if idMember == "" || ExpoPushToken == "" {
		// Jika salah satu parameter tidak diisi, munculkan error
		fmt.Println("Error: Parameter tidak lengkap")
		w.WriteHeader(http.StatusBadRequest)
		// Atau Anda bisa mengembalikan pesan error ke pemanggil fungsi atau melakukan tindakan lain sesuai kebutuhan aplikasi Anda.
	} else {
		// Check if database is alive.
		err := database.Instance.PingContext(ctx)
		if err != nil {
			log.Fatal("Error Cuyy: ", err.Error())
		}
		var JsonResultData string
		database.Instance.QueryContext(ctx, "xsp_app_member_notification_token_insert",
			sql.Named("p_id_member", idMember),
			sql.Named("p_notification_token", ExpoPushToken),
			sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, string(JsonResultData))

	}
}

func GetStoraDashboardSales(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_store_dashboard_sales_getrow",
		sql.Named("p_store_id", r.FormValue("storeID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetStoraDashboardSalesChart(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_store_dashboard_sales_overview_chart_getrow",
		sql.Named("p_store_id", r.FormValue("storeID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetStoraDashboardRecentTransaction(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_store_dashboard_recent_transaction_getrows",
		sql.Named("p_store_id", r.FormValue("storeID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetStoraDashboardTaskOverview(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_store_dashboard_task_overview_getrows",
		sql.Named("p_store_id", r.FormValue("storeID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetStoreSalesDcr(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_store_sales_dcr_getrow",
		sql.Named("p_store_id", r.FormValue("storeID")),
		sql.Named("p_date", r.FormValue("date")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetStoreSalesDetail(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_store_sales_detail_getrow",

		sql.Named("p_from_date", r.FormValue("fromDate")),
		sql.Named("p_to_date", r.FormValue("toDate")),
		sql.Named("p_store_id", r.FormValue("storeID")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

func GetStoreSalesDetailItem(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_store_sales_detail_item_getrows",

		sql.Named("p_id_tr_sales_header", r.FormValue("id_tr_sales_header")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
func GetStoreSalesDetailPayment(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_api_store_sales_detail_payment_getrows",

		sql.Named("p_id_tr_sales_header", r.FormValue("id_tr_sales_header")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}

var reqBody struct {
	RandomNumber int `json:"randomNumber"`
}

func SendOTP(w http.ResponseWriter, r *http.Request, userAccount string) {

	if err := json.NewDecoder(r.Body).Decode(&reqBody); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	randomNumberStr := strconv.Itoa(reqBody.RandomNumber)

	qiscusBody := map[string]interface{}{
		"to":   userAccount,
		"type": "template",
		"template": map[string]interface{}{
			"namespace": "7a2ceabe_e950_4283_82ac_5909ac117bf6",
			"name":      "otpmember_1",
			"language": map[string]interface{}{
				"policy": "deterministic",
				"code":   "id",
			},
			"components": []interface{}{
				map[string]interface{}{
					"type": "body",
					"parameters": []interface{}{
						map[string]interface{}{
							"type": "text",
							"text": randomNumberStr,
						},
					},
				},
				map[string]interface{}{
					"type":     "button",
					"sub_type": "url",
					"index":    0,
					"parameters": []interface{}{
						map[string]interface{}{
							"type": "text",
							"text": randomNumberStr,
						},
					},
				},
			},
		},
	}

	jsonData, err := json.Marshal(qiscusBody)
	if err != nil {
		http.Error(w, "Error marshalling JSON", http.StatusInternalServerError)
		return
	}

	req, err := http.NewRequest("POST", "https://omnichannel.qiscus.com/whatsapp/v1/dmvzl-wfbfx3bo5bbzrj1/3384/messages/", bytes.NewBuffer(jsonData))
	if err != nil {
		http.Error(w, "Error creating request", http.StatusInternalServerError)
		return
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Qiscus-App-Id", "dmvzl-wfbfx3bo5bbzrj1")
	req.Header.Set("Qiscus-Secret-Key", "27a6859bc8065575a3a135408e262e6e")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Error sending request", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		http.Error(w, "Error reading response", http.StatusInternalServerError)
		return
	}

	if resp.StatusCode != http.StatusOK {
		http.Error(w, string(body), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	// w.Write(body)
}
