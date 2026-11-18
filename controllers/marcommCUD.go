package controllers

import (
	"database/sql"
	"log"
	"net/http"
	"strings"
)

func marcommCUD(w http.ResponseWriter, r *http.Request, sp string, args ...interface{}) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	if err := marcommExecSP(ctx, sp, args...); err != nil {
		log.Printf("marcomm CUD %s: %s", sp, err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	marcommWriteEmptyOK(w)
}

// Promo status — xsp_app_member_promo_status_update
func MarcommPromoStatus(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_promo_status_update",
		sql.Named("p_id", marcommPathID(r)),
		sql.Named("p_ngapain", firstNonEmpty(marcommQ(r, "ngapain"), marcommQ(r, "status"))),
	)
}

// App voucher status — xsp_app_member_voucher_status_update
func MarcommAppVoucherStatus(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_voucher_status_update",
		sql.Named("p_id", marcommPathID(r)),
		sql.Named("p_ngapain", firstNonEmpty(marcommQ(r, "ngapain"), marcommQ(r, "status"))),
	)
}

func MarcommMasterFaqCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_faq_insert",
		sql.Named("p_title", marcommQ(r, "title")),
		sql.Named("p_description", marcommQ(r, "description")),
		sql.Named("p_category", marcommQ(r, "category")),
	)
}

func MarcommMasterFaqUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_faq_update",
		sql.Named("p_id", marcommPathID(r)),
		sql.Named("p_title", marcommQ(r, "title")),
		sql.Named("p_description", marcommQ(r, "description")),
		sql.Named("p_category", marcommQ(r, "category")),
	)
}

func MarcommMasterFaqDelete(w http.ResponseWriter, r *http.Request) {
	// TODO: legacy DAL.Delete("app_member_faq") — try conventional delete SP
	marcommCUD(w, r, "xsp_app_member_faq_delete",
		sql.Named("p_id", marcommPathID(r)),
	)
}

func MarcommMasterFaqCategoryCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_category_faq_insert",
		sql.Named("p_code", marcommQ(r, "code")),
		sql.Named("p_description", marcommQ(r, "description")),
	)
}

func MarcommMasterFaqCategoryUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_category_faq_update",
		sql.Named("p_code", firstNonEmpty(marcommPathID(r), marcommQ(r, "code"))),
		sql.Named("p_description", marcommQ(r, "description")),
	)
}

func MarcommMasterFaqCategoryDelete(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_category_faq_delete",
		sql.Named("p_id", marcommPathID(r)),
	)
}

func MarcommMasterPointRegisterCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_master_custom_point_insert",
		sql.Named("p_keterangan", firstNonEmpty(marcommQ(r, "keterangan"), marcommQ(r, "description"))),
		sql.Named("p_point", marcommQ(r, "point")),
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
	)
}

func MarcommMasterPointRegisterUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_master_custom_point_update",
		sql.Named("p_id", marcommPathID(r)),
		sql.Named("p_keterangan", firstNonEmpty(marcommQ(r, "keterangan"), marcommQ(r, "description"))),
		sql.Named("p_point", marcommQ(r, "point")),
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
	)
}

func MarcommMasterPointRegisterDelete(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_master_custom_point_delete",
		sql.Named("p_id", marcommPathID(r)),
	)
}

func MarcommMasterVoucherCategoryCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_master_jenis_gift_voucher_insert",
		sql.Named("p_code", marcommQ(r, "code")),
		sql.Named("p_description", firstNonEmpty(marcommQ(r, "description"), marcommQ(r, "keterangan"))),
		sql.Named("p_tipe", "VOUCHER"),
	)
}

func MarcommMasterVoucherCategoryUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_master_jenis_gift_voucher_update",
		sql.Named("p_code", firstNonEmpty(marcommQ(r, "code"), marcommPathID(r))),
		sql.Named("p_description", firstNonEmpty(marcommQ(r, "description"), marcommQ(r, "keterangan"))),
		sql.Named("p_tipe", "VOUCHER"),
	)
}

func MarcommMasterVoucherCategoryDelete(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_master_jenis_gift_voucher_delete",
		sql.Named("p_id", marcommPathID(r)),
	)
}

func MarcommMasterGiftCategoryCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_master_jenis_gift_voucher_insert",
		sql.Named("p_code", marcommQ(r, "code")),
		sql.Named("p_description", firstNonEmpty(marcommQ(r, "description"), marcommQ(r, "keterangan"))),
		sql.Named("p_tipe", "GIFT"),
	)
}

func MarcommMasterGiftCategoryUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_master_jenis_gift_voucher_update",
		sql.Named("p_code", firstNonEmpty(marcommQ(r, "code"), marcommPathID(r))),
		sql.Named("p_description", firstNonEmpty(marcommQ(r, "description"), marcommQ(r, "keterangan"))),
		sql.Named("p_tipe", "GIFT"),
	)
}

func MarcommMasterGiftCategoryDelete(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_master_jenis_gift_voucher_delete",
		sql.Named("p_id", marcommPathID(r)),
	)
}

func MarcommMasterSyaratKetentuanSave(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_syarat_ketentuan_insert",
		sql.Named("p_detail", marcommQ(r, "detail")),
	)
}

// --- Promo full CRUD (lookup_promo.aspx.cs) ---

func MarcommPromoGet(w http.ResponseWriter, r *http.Request) {
	marcommGetRowDAL(w, r, "app_member_promo", "p_id", marcommPathID(r))
}

func MarcommPromoCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUDInsertMaybeID(w, r, "xsp_app_member_promo_insert",
		sql.Named("p_image_title", marcommQ(r, "image_title")),
		sql.Named("p_image_subtitle", marcommQ(r, "image_subtitle")),
		sql.Named("p_promo_title", marcommQ(r, "promo_title")),
		sql.Named("p_promo_detail", marcommQ(r, "promo_detail")),
		sql.Named("p_promo_location", marcommQ(r, "promo_location")),
		sql.Named("p_promo_start_date", marcommQDate(r, "promo_start_date")),
		sql.Named("p_promo_end_date", marcommQDate(r, "promo_end_date")),
		sql.Named("p_category", marcommQ(r, "category")),
		sql.Named("p_brand", marcommQ(r, "brand")),
		sql.Named("p_image_url", marcommQ(r, "image_url")),
	)
}

func MarcommPromoUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_promo_update",
		sql.Named("p_id", marcommPathID(r)),
		sql.Named("p_image_title", marcommQ(r, "image_title")),
		sql.Named("p_image_subtitle", marcommQ(r, "image_subtitle")),
		sql.Named("p_promo_title", marcommQ(r, "promo_title")),
		sql.Named("p_promo_detail", marcommQ(r, "promo_detail")),
		sql.Named("p_promo_location", marcommQ(r, "promo_location")),
		sql.Named("p_promo_start_date", marcommQDate(r, "promo_start_date")),
		sql.Named("p_promo_end_date", marcommQDate(r, "promo_end_date")),
		sql.Named("p_category", marcommQ(r, "category")),
		sql.Named("p_brand", marcommQ(r, "brand")),
		sql.Named("p_image_url", marcommQ(r, "image_url")),
	)
}

func MarcommPromoDelete(w http.ResponseWriter, r *http.Request) {
	marcommDeleteDAL(w, r, "app_member_promo", sql.Named("p_id", marcommPathID(r)))
}

// --- App vouchers full CRUD (lookup_voucher.aspx.cs) ---

func MarcommAppVoucherGet(w http.ResponseWriter, r *http.Request) {
	marcommGetRowDAL(w, r, "app_member_voucher", "p_id", marcommPathID(r))
}

func marcommAppVoucherInsertSP(category string) string {
	if strings.EqualFold(category, "VCR") {
		return "xsp_app_member_voucher_normal_insert"
	}
	return "xsp_app_member_voucher_Special_offer_insert"
}

func marcommAppVoucherUpdateSP(category string) string {
	if strings.EqualFold(category, "VCR") {
		return "xsp_app_member_voucher_normal_update"
	}
	return "xsp_app_member_voucher_special_offer_update"
}

func marcommAppVoucherArgs(r *http.Request) []interface{} {
	return []interface{}{
		sql.Named("p_vouchercode", marcommQ(r, "vouchercode")),
		sql.Named("p_nominal", marcommQ(r, "nominal")),
		sql.Named("p_pointVoucher", marcommQ(r, "pointVoucher")),
		sql.Named("p_fromDate", marcommQDate(r, "fromDate")),
		sql.Named("p_toDate", marcommQDate(r, "toDate")),
		sql.Named("p_category", marcommQ(r, "category")),
		sql.Named("p_expired_from_Date", marcommQDate(r, "expired_from_Date")),
		sql.Named("p_expired_to_Date", marcommQDate(r, "expired_to_Date")),
		sql.Named("p_normal_expired_month", marcommQ(r, "normal_expired_month")),
		sql.Named("p_maxReedem", marcommQ(r, "maxReedem")),
		sql.Named("p_voucher_title", marcommQ(r, "voucher_title")),
		sql.Named("p_voucher_detail", marcommQ(r, "voucher_detail")),
		sql.Named("p_image_url", marcommQ(r, "image_url")),
	}
}

func MarcommAppVoucherCreate(w http.ResponseWriter, r *http.Request) {
	category := marcommQ(r, "category")
	args := marcommAppVoucherArgs(r)
	marcommCUDInsertMaybeID(w, r, marcommAppVoucherInsertSP(category), args...)
}

func MarcommAppVoucherUpdate(w http.ResponseWriter, r *http.Request) {
	category := marcommQ(r, "category")
	args := append(marcommAppVoucherArgs(r), sql.Named("p_id", marcommPathID(r)))
	marcommCUD(w, r, marcommAppVoucherUpdateSP(category), args...)
}

func MarcommAppVoucherDelete(w http.ResponseWriter, r *http.Request) {
	marcommDeleteDAL(w, r, "app_member_voucher", sql.Named("p_id", marcommPathID(r)))
}

// --- Special holiday CRUD (special_holiday_info.aspx.cs) ---

func MarcommMasterSpecialHolidayGet(w http.ResponseWriter, r *http.Request) {
	marcommGetRowDAL(w, r, "dashboard_member_special_day", "p_id", marcommPathID(r))
}

func MarcommMasterSpecialHolidayCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUDInsertMaybeID(w, r, "xsp_dashboard_member_special_day_insert",
		sql.Named("p_date", marcommQ(r, "date")),
		sql.Named("p_name", firstNonEmpty(marcommQ(r, "name"), marcommQ(r, "description"))),
	)
}

func MarcommMasterSpecialHolidayUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_dashboard_member_special_day_update",
		sql.Named("p_id", marcommPathID(r)),
		sql.Named("p_date", marcommQ(r, "date")),
		sql.Named("p_name", firstNonEmpty(marcommQ(r, "name"), marcommQ(r, "description"))),
	)
}

func MarcommMasterSpecialHolidayDelete(w http.ResponseWriter, r *http.Request) {
	marcommDeleteDAL(w, r, "dashboard_member_special_day", sql.Named("p_id", marcommPathID(r)))
}

func MarcommMasterSpecialHolidayStatus(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_dashboard_member_special_day_status_update",
		sql.Named("p_id", marcommPathID(r)),
		sql.Named("p_ngapain", firstNonEmpty(marcommQ(r, "ngapain"), marcommQ(r, "status"))),
	)
}

// --- Store location (storeLoc.aspx / lookup_storeLoc.aspx) ---

func MarcommMasterStoreLocationGet(w http.ResponseWriter, r *http.Request) {
	marcommGetRowDAL(w, r, "get_all_store_location", "p_store", marcommPathID(r))
}

func MarcommMasterStoreLocationUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "XSP_get_all_store_location_update",
		sql.Named("p_store", firstNonEmpty(marcommPathID(r), marcommQ(r, "store"))),
		sql.Named("p_kota", marcommQ(r, "kota")),
		sql.Named("p_provinsi", marcommQ(r, "provinsi")),
		sql.Named("p_alamat", marcommQ(r, "alamat")),
		sql.Named("p_location_map", firstNonEmpty(marcommQ(r, "location_map"), marcommQ(r, "LOCATION_MAP"))),
		sql.Named("p_link_map", firstNonEmpty(marcommQ(r, "link_map"), marcommQ(r, "LINK_MAP"))),
	)
}

func MarcommMasterStoreLocationStatus(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_store_status_active_update",
		sql.Named("p_store", firstNonEmpty(marcommPathID(r), marcommQ(r, "store"))),
		sql.Named("p_ngapain", firstNonEmpty(marcommQ(r, "ngapain"), marcommQ(r, "status"))),
	)
}

// --- FAQ contact info (Faq.aspx left panel) ---

func MarcommMasterContactInfo(w http.ResponseWriter, r *http.Request) {
	// SP has no parameters (unlike typical DAL getrow with p_id)
	marcommGetRowSP(w, r, "xsp_app_member_contact_info_getrow")
}

func MarcommMasterContactInfoUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_contact_info_update",
		sql.Named("p_phone_number", firstNonEmpty(marcommQ(r, "phone_number"), marcommQ(r, "phone"))),
		sql.Named("p_instagram", marcommQ(r, "instagram")),
		sql.Named("p_email", marcommQ(r, "email")),
	)
}