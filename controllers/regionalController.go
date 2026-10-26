package controllers

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"GOamsAPI/database"

	"github.com/gorilla/mux"
)

var regListParamKeys = []string{
	"keywords", "from_date", "to_date", "is_active",
	"id_brand", "id_store", "brand", "store_id",
	"status", "kategori", "group", "dept", "department",
	"cabang", "id_cabang", "year", "month", "period",
	"tipe", "is_pajak", "id_mesin", "currentmonth", "tahun",
	"actor_nik",
	// Legacy REGIONAL report extras (wcmenu_REGIONAL parity)
	"plu", "article", "voucher", "invoice", "marketplace",
	"multi_store", "brand_filter", "brand_to", "store_to",
	"tgl", "provinsi", "kota", "id_member", "confirm_status",
	"gh_id", "id_gh",
}

func runRegSP(ctx context.Context, spName string, namedArgs ...interface{}) string {
	var jsonResultData string
	args := append(namedArgs, sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))
	rows, err := database.RbcaInstance.QueryContext(ctx, spName, args...)
	if err != nil {
		log.Printf("Error executing REG SP %s: %s", spName, err.Error())
		return rbcaErrorJSON("5000005", err.Error())
	}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
		}
	}
	return jsonResultData
}

func writeRegSPResponse(w http.ResponseWriter, r *http.Request, spName string, jsonResult string) {
	if strings.TrimSpace(jsonResult) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, spName)
		return
	}
	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResult), r.Method, spName)
}

func regActor(r *http.Request) string {
	if v := rbcaParam(r, "created_by"); v != "" {
		return v
	}
	if v := rbcaParam(r, "updated_by"); v != "" {
		return v
	}
	if v := rbcaNikFromJWT(r); v != "" {
		return v
	}
	return ""
}

func regQuery(r *http.Request, key string) string {
	if v := rbcaParam(r, key); v != "" {
		return v
	}
	switch key {
	case "keywords":
		return rbcaParam(r, "search")
	case "from_date":
		if v := rbcaParam(r, "date_from"); v != "" {
			return v
		}
		return rbcaParam(r, "from")
	case "to_date":
		if v := rbcaParam(r, "date_to"); v != "" {
			return v
		}
		return rbcaParam(r, "to")
	case "id_brand":
		return rbcaParam(r, "brand_id")
	case "id_store":
		if v := rbcaParam(r, "store_id"); v != "" {
			return v
		}
		return rbcaParam(r, "id_store")
	case "actor_nik", "gh_id", "id_gh":
		if v := rbcaParam(r, "gh_id"); v != "" {
			return v
		}
		if v := rbcaParam(r, "id_gh"); v != "" {
			return v
		}
		return regActor(r)
	case "brand":
		return firstNonEmpty(rbcaParam(r, "id_brand"), rbcaParam(r, "brand"))
	case "store_id":
		return firstNonEmpty(rbcaParam(r, "id_store"), rbcaParam(r, "store_id"), rbcaParam(r, "store"))
	}
	return ""
}

func regListHandler(spName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		args := make([]interface{}, 0, len(regListParamKeys))
		for _, key := range regListParamKeys {
			args = append(args, sql.Named("p_"+key, parseOptionalString(regQuery(r, key))))
		}
		jsonResult := runRegSP(ctx, spName, args...)
		writeRegSPResponse(w, r, spName, jsonResult)
	}
}

func regGetHandler(spName string, idKey string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		id := mux.Vars(r)[idKey]
		if id == "" {
			id = rbcaParam(r, "id")
		}
		jsonResult := runRegSP(ctx, spName, sql.Named("p_id", id))
		writeRegSPResponse(w, r, spName, jsonResult)
	}
}

func regInsertHandler(spName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		payload, _ := json.Marshal(rbcaBodyValues(r))
		actor := regActor(r)
		jsonResult := runRegSP(ctx, spName,
			sql.Named("p_payload", string(payload)),
			sql.Named("p_created_by", parseOptionalString(actor)),
			sql.Named("p_actor_nik", parseOptionalString(actor)),
		)
		writeRegSPResponse(w, r, spName, jsonResult)
	}
}

func regUpdateHandler(spName string, idKey string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		id := mux.Vars(r)[idKey]
		payload, _ := json.Marshal(rbcaBodyValues(r))
		actor := regActor(r)
		jsonResult := runRegSP(ctx, spName,
			sql.Named("p_id", id),
			sql.Named("p_payload", string(payload)),
			sql.Named("p_updated_by", parseOptionalString(actor)),
			sql.Named("p_actor_nik", parseOptionalString(actor)),
		)
		writeRegSPResponse(w, r, spName, jsonResult)
	}
}

func regDeleteHandler(spName string, idKey string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		id := mux.Vars(r)[idKey]
		actor := regActor(r)
		payload, _ := json.Marshal(map[string]string{"id": id})
		jsonResult := runRegSP(ctx, spName,
			sql.Named("p_id", id),
			sql.Named("p_payload", string(payload)),
			sql.Named("p_updated_by", parseOptionalString(actor)),
			sql.Named("p_actor_nik", parseOptionalString(actor)),
		)
		writeRegSPResponse(w, r, spName, jsonResult)
	}
}

func RegisterRegionalEntityRoutes(r *mux.Router, path, entity string, withCRUD bool) {
	base := "/regional/" + path
	r.HandleFunc(base, regListHandler("xsp_ams_new_reg_"+entity+"_getrows")).Methods("GET")
	if !withCRUD {
		return
	}
	r.HandleFunc(base, regInsertHandler("xsp_ams_new_reg_"+entity+"_insert")).Methods("POST")
	r.HandleFunc(base+"/{id}", regGetHandler("xsp_ams_new_reg_"+entity+"_getrow", "id")).Methods("GET")
	r.HandleFunc(base+"/{id}", regUpdateHandler("xsp_ams_new_reg_"+entity+"_update", "id")).Methods("PUT")
	r.HandleFunc(base+"/{id}", regDeleteHandler("xsp_ams_new_reg_"+entity+"_delete", "id")).Methods("DELETE")
}

// RegSalesDetailInfoHandler — GET /regional/rpt/sales/sales-detail/{id}/info
// Parity seles_detail_info.aspx (items + payments for one ID_TR_SALES_HEADER).
func RegSalesDetailInfoHandler(w http.ResponseWriter, r *http.Request) {
	regGetHandler("xsp_ams_new_reg_rpt_sales_detail_info_getrow", "id")(w, r)
}

// RegTrStInDetailHandler — GET /regional/rpt/inv/tr-st-in/{id}/detail
// Parity Rpt_Tr_St_In_Detail.aspx (TR_ST_DETAIL by NO_TR_ST_HEADER / TRSTH).
func RegTrStInDetailHandler(w http.ResponseWriter, r *http.Request) {
	regGetHandler("xsp_ams_new_reg_rpt_tr_st_in_detail_getrows", "id")(w, r)
}

// RegOutstandingDetailHandler — GET /regional/rpt/inv/outstanding/{id}/detail
// Parity outSstockDetail.aspx (TR_ST_DETAIL by NO_TR_ST_HEADER / CB).
func RegOutstandingDetailHandler(w http.ResponseWriter, r *http.Request) {
	regGetHandler("xsp_ams_new_reg_rpt_outstanding_detail_getrows", "id")(w, r)
}

// RegTrStOutDetailHandler — GET /regional/rpt/inv/tr-st-out/{id}/detail
// Parity Rpt_Tr_St_Detail.aspx / STOUT print lines.
func RegTrStOutDetailHandler(w http.ResponseWriter, r *http.Request) {
	regGetHandler("xsp_ams_new_reg_rpt_tr_st_out_detail_getrows", "id")(w, r)
}

// RegLastStockBatchDateHandler — GET /regional/rpt/inv/last-stock/{id}/batch-date
// Parity Rpt_Last_stock.aspx BindTglBatchAkhir → xsp_rpt_last_tanggal_batch_getrow.
func RegLastStockBatchDateHandler(w http.ResponseWriter, r *http.Request) {
	regGetHandler("xsp_ams_new_reg_rpt_last_stock_batch_getrow", "id")(w, r)
}

// RegTrSoDetailHandler — GET /regional/rpt/so/tr-so/{id}/detail?id_store=&tipe=
// Parity Rpt_Tr_So_Detail.aspx (FULL / DEPT / CLASS).
func RegTrSoDetailHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	id := mux.Vars(r)["id"]
	store := firstNonEmpty(rbcaParam(r, "id_store"), rbcaParam(r, "store"), rbcaParam(r, "store_id"))
	tipe := firstNonEmpty(rbcaParam(r, "tipe"), "FULL")
	jsonResult := runRegSP(ctx, "xsp_ams_new_reg_rpt_tr_so_detail_getrows",
		sql.Named("p_id", id),
		sql.Named("p_id_store", parseOptionalString(store)),
		sql.Named("p_tipe", parseOptionalString(tipe)),
	)
	writeRegSPResponse(w, r, "xsp_ams_new_reg_rpt_tr_so_detail_getrows", jsonResult)
}

// RegTrSoSelisihHandler — GET /regional/rpt/so/tr-so/{id}/selisih?tipe=&status=
// Parity Rpt_Tr_So_Detail_Selisih.aspx (ALL|FIX × FULL|DEPT|CLASS).
func RegTrSoSelisihHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	id := mux.Vars(r)["id"]
	tipe := firstNonEmpty(rbcaParam(r, "tipe"), "FULL")
	status := firstNonEmpty(rbcaParam(r, "status"), "ALL")
	jsonResult := runRegSP(ctx, "xsp_ams_new_reg_rpt_tr_so_selisih_getrows",
		sql.Named("p_id", id),
		sql.Named("p_tipe", parseOptionalString(tipe)),
		sql.Named("p_status", parseOptionalString(status)),
	)
	writeRegSPResponse(w, r, "xsp_ams_new_reg_rpt_tr_so_selisih_getrows", jsonResult)
}

// RegTrSoGawangHandler — GET /regional/rpt/so/tr-so/{id}/gawang?id_store=&article=
// Parity Chk_Gawang_G_sum.aspx.
func RegTrSoGawangHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	id := mux.Vars(r)["id"]
	store := firstNonEmpty(rbcaParam(r, "id_store"), rbcaParam(r, "store"), rbcaParam(r, "store_id"))
	article := firstNonEmpty(rbcaParam(r, "article"), rbcaParam(r, "gawang"))
	jsonResult := runRegSP(ctx, "xsp_ams_new_reg_rpt_tr_so_gawang_getrows",
		sql.Named("p_id", id),
		sql.Named("p_id_store", parseOptionalString(store)),
		sql.Named("p_article", parseOptionalString(article)),
	)
	writeRegSPResponse(w, r, "xsp_ams_new_reg_rpt_tr_so_gawang_getrows", jsonResult)
}

// RegTrSoGawangDetailHandler — GET /regional/rpt/so/tr-so/{id}/gawang-detail?id_store=&article=
// Parity Chk_Gawang_G.aspx.
func RegTrSoGawangDetailHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	id := mux.Vars(r)["id"]
	store := firstNonEmpty(rbcaParam(r, "id_store"), rbcaParam(r, "store"), rbcaParam(r, "store_id"))
	article := firstNonEmpty(rbcaParam(r, "article"), rbcaParam(r, "gawang"))
	jsonResult := runRegSP(ctx, "xsp_ams_new_reg_rpt_tr_so_gawang_detail_getrows",
		sql.Named("p_id", id),
		sql.Named("p_id_store", parseOptionalString(store)),
		sql.Named("p_article", parseOptionalString(article)),
	)
	writeRegSPResponse(w, r, "xsp_ams_new_reg_rpt_tr_so_gawang_detail_getrows", jsonResult)
}

// RegTrSoGawangPluHandler — GET /regional/rpt/so/tr-so/{id}/gawang-plu?id_store=&plu=
// Parity Chk_Gawang.aspx.
func RegTrSoGawangPluHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	id := mux.Vars(r)["id"]
	store := firstNonEmpty(rbcaParam(r, "id_store"), rbcaParam(r, "store"), rbcaParam(r, "store_id"))
	plu := firstNonEmpty(rbcaParam(r, "plu"), rbcaParam(r, "article"))
	jsonResult := runRegSP(ctx, "xsp_ams_new_reg_rpt_tr_so_gawang_plu_getrows",
		sql.Named("p_id", id),
		sql.Named("p_id_store", parseOptionalString(store)),
		sql.Named("p_plu", parseOptionalString(plu)),
	)
	writeRegSPResponse(w, r, "xsp_ams_new_reg_rpt_tr_so_gawang_plu_getrows", jsonResult)
}

// RegTrSoPartialDetailHandler — GET /regional/rpt/so/tr-so-partial/{id}/detail
// Parity Rpt_Tr_So_Partial_Detail2.aspx.
func RegTrSoPartialDetailHandler(w http.ResponseWriter, r *http.Request) {
	regGetHandler("xsp_ams_new_reg_rpt_tr_so_partial_detail_getrows", "id")(w, r)
}

// RegVoucherFisikDetailHandler — GET /regional/rpt/voucher/fisik/{id}/detail?status=
// Parity module/Tools/voucher_rpt.aspx child repeater.
func RegVoucherFisikDetailHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	id := mux.Vars(r)["id"]
	status := firstNonEmpty(rbcaParam(r, "status"), "ALL")
	jsonResult := runRegSP(ctx, "xsp_ams_new_reg_rpt_voucher_fisik_detail_getrows",
		sql.Named("p_id", id),
		sql.Named("p_status", parseOptionalString(status)),
	)
	writeRegSPResponse(w, r, "xsp_ams_new_reg_rpt_voucher_fisik_detail_getrows", jsonResult)
}

// RegVoucherImlekDetailHandler — GET /regional/rpt/voucher/imlek/{id}/detail?id_cabang=&status=
// Parity module/Tools/voucher_imlek_rpt.aspx child repeater.
func RegVoucherImlekDetailHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	id := mux.Vars(r)["id"]
	cabang := firstNonEmpty(rbcaParam(r, "id_cabang"), rbcaParam(r, "id_store"), rbcaParam(r, "store_id"), rbcaParam(r, "store"))
	status := firstNonEmpty(rbcaParam(r, "status"), "ALL")
	jsonResult := runRegSP(ctx, "xsp_ams_new_reg_rpt_voucher_imlek_detail_getrows",
		sql.Named("p_id", id),
		sql.Named("p_id_cabang", parseOptionalString(cabang)),
		sql.Named("p_status", parseOptionalString(status)),
	)
	writeRegSPResponse(w, r, "xsp_ams_new_reg_rpt_voucher_imlek_detail_getrows", jsonResult)
}

func RegionalLookupHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	lookupType := mux.Vars(r)["type"]
	if lookupType == "" {
		lookupType = rbcaParam(r, "type")
	}
	jsonResult := runRegSP(ctx, "xsp_ams_new_reg_lookup_getrows",
		sql.Named("p_type", lookupType),
		sql.Named("p_keywords", parseOptionalString(regQuery(r, "keywords"))),
		sql.Named("p_parent_id", parseOptionalString(firstNonEmpty(rbcaParam(r, "parent_id"), rbcaParam(r, "id_brand")))),
		sql.Named("p_actor_nik", parseOptionalString(regActor(r))),
	)
	writeRegSPResponse(w, r, "xsp_ams_new_reg_lookup_getrows", jsonResult)
}

// RegionalTotalSales — GET /regional/mobile/total-sales
// Parity with module/Mobile/Reg_Tot_Sales.aspx → xsp_api_mobile_get_sales_summary_bydate_getrows
func RegionalTotalSales(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := database.Instance.PingContext(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}

	fromDate := firstNonEmpty(rbcaParam(r, "fromDate"), rbcaParam(r, "from_date"), regQuery(r, "from_date"))
	toDate := firstNonEmpty(rbcaParam(r, "toDate"), rbcaParam(r, "to_date"), regQuery(r, "to_date"))
	brandID := firstNonEmpty(rbcaParam(r, "brandID"), rbcaParam(r, "id_brand"), rbcaParam(r, "brand"), "all")
	// Same internal token used by legacy Reg_Tot_Sales.aspx (SP validates it)
	const legacyToken = "kontol kontol kontol anjing tai babi"

	var jsonResultData string
	rows, err := database.Instance.QueryContext(ctx, "xsp_api_mobile_get_sales_summary_bydate_getrows",
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
		sql.Named("p_brand", brandID),
		sql.Named("p_token", legacyToken),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}),
	)
	if err != nil {
		log.Printf("RegionalTotalSales SP error: %s", err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
		}
	}
	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSON(w, rbcaErrorJSON("5000002", "empty response from database"))
		return
	}
	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "xsp_api_mobile_get_sales_summary_bydate_getrows")
}

/* RegionalDashboardSummary lives in regionalDashboardCache.go (Redis-first + warm). */

// --- Marketplace AR List (view-only) — Ar_List.aspx parity ---

func RegMpArListByStoreHandler(w http.ResponseWriter, r *http.Request) {
	regListHandler("xsp_ams_new_reg_ar_list_by_store_getrows")(w, r)
}

func RegMpArListTotalHandler(w http.ResponseWriter, r *http.Request) {
	regListHandler("xsp_ams_new_reg_ar_total_getrows")(w, r)
}

func RegMpArListDetailRealisasiHandler(w http.ResponseWriter, r *http.Request) {
	regListHandler("xsp_ams_new_reg_ar_detail_realisasi_getrows")(w, r)
}

func RegMpArListPluSummaryHandler(w http.ResponseWriter, r *http.Request) {
	regListHandler("xsp_ams_new_reg_ar_plu_summary_getrows")(w, r)
}

func RegMpArListTransaksiDetailHandler(w http.ResponseWriter, r *http.Request) {
	regListHandler("xsp_ams_new_reg_ar_transaksi_detail_getrows")(w, r)
}

// RegMpArListDetailHandler — GET /regional/mp/ar-list/{id}/info
// Parity cart.aspx checkdata (xsp_get_ar_marketplace_getrow) — view-only.
func RegMpArListDetailHandler(w http.ResponseWriter, r *http.Request) {
	regGetHandler("xsp_ams_new_reg_ar_list_detail_getrow", "id")(w, r)
}

// --- Marketplace AR Realisasi (view-only) — Ar_Realisasi.aspx parity ---

func RegMpArRealisasiListHandler(w http.ResponseWriter, r *http.Request) {
	regListHandler("xsp_ams_new_reg_ar_realisasi_getrows")(w, r)
}

// --- Marketplace MP Retur / Gudang (view-only) — MP_gudang.aspx parity ---

func RegMpReturListHandler(w http.ResponseWriter, r *http.Request) {
	regListHandler("xsp_ams_new_reg_mp_retur_getrows")(w, r)
}

func RegMpReturBadgeHandler(w http.ResponseWriter, r *http.Request) {
	regListHandler("xsp_ams_new_reg_mp_retur_badge_getrow")(w, r)
}
