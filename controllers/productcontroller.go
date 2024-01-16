package controllers

import (
	"GOamsAPI/database"
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
