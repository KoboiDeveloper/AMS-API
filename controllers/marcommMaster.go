package controllers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strings"

	"GOamsAPI/database"
)

// --- Master lists ---

func MarcommMasterPointRegister(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_master_custom_point_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
	)
}

func MarcommMasterStoreLocation(w http.ResponseWriter, r *http.Request) {
	// ASP storeLoc.aspx BindData: SelectedItem.Text for provinsi/kota
	// (value "0" → text "All Province" / "All City").
	status := firstNonEmpty(marcommQ(r, "status"), marcommQ(r, "status_store"))
	if status == "" {
		status = "ALL"
	}
	brand := marcommQ(r, "brand")
	if brand == "" {
		brand = "all"
	}
	provinsi := strings.TrimSpace(marcommQ(r, "provinsi"))
	if provinsi == "" || provinsi == "0" || strings.EqualFold(provinsi, "all") || strings.EqualFold(provinsi, "all province") {
		provinsi = "All Province"
	}
	kota := strings.TrimSpace(marcommQ(r, "kota"))
	if kota == "" || kota == "0" || strings.EqualFold(kota, "all") || strings.EqualFold(kota, "all city") {
		kota = "All City"
	}
	marcommList(w, r, "XSP_get_all_store_location_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
		sql.Named("p_status_store", status),
		sql.Named("p_brand", brand),
		sql.Named("p_provinsi", provinsi),
		sql.Named("p_kota", kota),
	)
}

func MarcommMasterFaq(w http.ResponseWriter, r *http.Request) {
	category := firstNonEmpty(marcommQ(r, "category"), marcommQ(r, "kategori"))
	if category == "" {
		category = "ALL"
	}
	marcommList(w, r, "xsp_app_member_faq_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
		sql.Named("p_category", category),
	)
}

func MarcommMasterVoucherCategory(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_master_jenis_gift_voucher_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
		sql.Named("p_tipe", "VOUCHER"),
	)
}

func MarcommMasterGiftCategory(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_master_jenis_gift_voucher_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
		sql.Named("p_tipe", "GIFT"),
	)
}

func MarcommMasterFaqCategory(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_category_faq_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
	)
}

func MarcommMasterSpecialHoliday(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_dashboard_member_special_day_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
	)
}

func MarcommMasterTier(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_dashboard_member_tier_header_getrows")
}

func MarcommMasterTierGet(w http.ResponseWriter, r *http.Request) {
	marcommGetRowDAL(w, r, "dashboard_member_tier_detail", "p_id_tier_header", marcommPathID(r))
}

func MarcommMasterTierUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_dashboard_member_tier_detail_update",
		sql.Named("p_id", marcommPathID(r)),
		sql.Named("p_amount_from", marcommQ(r, "amount_from")),
		sql.Named("p_amount_to", marcommQ(r, "amount_to")),
		sql.Named("p_is_point_increase", marcommBoolish(r, "is_point_increase")),
		sql.Named("p_purchase_amount", marcommQ(r, "purchase_amount")),
		sql.Named("p_point_persen", marcommQ(r, "point_persen")),
		sql.Named("p_point_rupiah", marcommQ(r, "point_rupiah")),
		sql.Named("p_is_birthday_treats", marcommBoolish(r, "is_birthday_treats")),
		sql.Named("p_is_bigday_treats", marcommBoolish(r, "is_bigday_treats")),
		sql.Named("p_is_birthday_gift", marcommBoolish(r, "is_birthday_gift")),
		sql.Named("p_min_brithday_gift_amount", marcommQ(r, "min_brithday_gift_amount")),
		sql.Named("p_birthday_gift_voucher_amount", marcommQ(r, "birthday_gift_voucher_amount")),
		sql.Named("p_is_limited_item_access", marcommBoolish(r, "is_limited_item_access")),
		sql.Named("p_is_freebies_on_purchase_limited_item", marcommBoolish(r, "is_freebies_on_purchase_limited_item")),
		sql.Named("p_is_free_merchandise", marcommBoolish(r, "is_free_merchandise")),
	)
}

func MarcommMasterTierTags(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_dashboard_member_tier_header_tags_getrows",
		sql.Named("p_id_tier", marcommPathID(r)),
	)
}

// marcommSyaratDetailFromPayload normalizes SP/json shapes to {detail, tglUpdate}
// and URL-decodes detail like ASP HttpUtility.UrlDecode.
func marcommSyaratDetailFromPayload(v interface{}) map[string]interface{} {
	decode := func(s string) string {
		s = strings.TrimSpace(s)
		if s == "" {
			return s
		}
		if d, err := url.QueryUnescape(s); err == nil {
			return d
		}
		return s
	}
	pick := func(m map[string]interface{}) map[string]interface{} {
		detail := firstNonEmpty(fmt.Sprint(m["detail"]), fmt.Sprint(m["DETAIL"]))
		if detail == "<nil>" {
			detail = ""
		}
		out := map[string]interface{}{"detail": decode(detail)}
		if t := firstNonEmpty(fmt.Sprint(m["tglUpdate"]), fmt.Sprint(m["tgl_update"]), fmt.Sprint(m["TGLUPDATE"])); t != "" && t != "<nil>" {
			out["tglUpdate"] = t
		}
		return out
	}
	switch t := v.(type) {
	case map[string]interface{}:
		if arr, ok := t["syaratKetentuanData"].([]interface{}); ok && len(arr) > 0 {
			if row, ok := arr[0].(map[string]interface{}); ok {
				return pick(row)
			}
		}
		if _, has := t["detail"]; has {
			return pick(t)
		}
		if data, ok := t["data"]; ok {
			return marcommSyaratDetailFromPayload(data)
		}
	case []interface{}:
		if len(t) > 0 {
			return marcommSyaratDetailFromPayload(t[0])
		}
	}
	return map[string]interface{}{"detail": ""}
}

// MarcommMasterSyaratKetentuan — legacy GetRow app_member_syarat_ketentuan → xsp_app_member_master_syarat_ketentuan
func MarcommMasterSyaratKetentuan(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	var bitparam string
	_, err := database.Instance.QueryContext(ctx, "xsp_app_member_master_syarat_ketentuan",
		sql.Named("bitparam", sql.Out{Dest: &bitparam}),
	)
	if err != nil {
		log.Printf("marcomm syarat ketentuan: %s", err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	bitparam = strings.TrimSpace(bitparam)
	if bitparam != "" {
		var envelope map[string]interface{}
		if json.Unmarshal([]byte(bitparam), &envelope) == nil {
			marcommWriteObjectOK(w, marcommSyaratDetailFromPayload(envelope))
			return
		}
	}
	rows, err := marcommQuerySP(ctx, "xsp_app_member_master_syarat_ketentuan")
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	if len(rows) > 0 {
		marcommWriteObjectOK(w, marcommSyaratDetailFromPayload(rows[0]))
		return
	}
	marcommWriteObjectOK(w, map[string]interface{}{"detail": ""})
}