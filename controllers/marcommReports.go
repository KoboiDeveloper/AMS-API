package controllers

import (
	"database/sql"
	"net/http"
)

// --- Reports ---

func MarcommReportGift(w http.ResponseWriter, r *http.Request) {
	status := marcommQ(r, "status")
	if status == "" {
		status = "ALL"
	}
	kategori := marcommQ(r, "kategori")
	if kategori == "" {
		kategori = "ALL"
	}
	marcommList(w, r, "xsp_header_gift_marcomm_rpt_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
		sql.Named("p_status", status),
		sql.Named("p_kategori", kategori),
	)
}

func MarcommReportGiftDetail(w http.ResponseWriter, r *http.Request) {
	status := marcommQ(r, "status")
	if status == "" {
		status = "ALL"
	}
	marcommList(w, r, "xsp_header_gift_marcomm_detail_rpt_getrows",
		sql.Named("p_id_voucher", marcommPathID(r)),
		sql.Named("p_status", status),
	)
}

func MarcommReportRedemption(w http.ResponseWriter, r *http.Request) {
	// reedem_rpt.aspx: ddlCategoryVoucher default "All Voucher"
	kategori := firstNonEmpty(marcommQ(r, "category"), marcommQ(r, "kategori"))
	if kategori == "" {
		kategori = "All Voucher"
	}
	marcommList(w, r, "XSP_APP_MEMBER_REEDEMPTION_REPORT",
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
		sql.Named("p_kategori", kategori),
	)
}

func MarcommReportBirthdayVoucher(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "XSP_APP_MEMBER_BIRTHDAY_VOUCHER_REPORT",
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
	)
}

// --- Voucher reports / lists ---

func MarcommVoucherGenerated(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_voucher_list_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
		sql.Named("p_from_date", marcommQDateSlashYMD(r, "from_date")),
		sql.Named("p_to_date", marcommQDateSlashYMD(r, "to_date")),
	)
}

func MarcommVoucherReport(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_header_vouchermarcomm_rpt_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
		sql.Named("p_status", marcommQ(r, "status")),
	)
}

func MarcommVoucherReportDetail(w http.ResponseWriter, r *http.Request) {
	status := marcommQ(r, "status")
	if status == "" {
		status = "ALL"
	}
	marcommList(w, r, "xsp_header_vouchermarcomm_detail_rpt_getrows",
		sql.Named("p_id_voucher", marcommPathID(r)),
		sql.Named("p_status", status),
	)
}

func MarcommVoucherUsed(w http.ResponseWriter, r *http.Request) {
	store := marcommQ(r, "store")
	if store == "" {
		store = "ALL"
	}
	marcommList(w, r, "xsp_early_voucher_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
		sql.Named("p_from_date", marcommQDateSlashYMD(r, "from_date")),
		sql.Named("p_to_date", marcommQDateSlashYMD(r, "to_date")),
		sql.Named("p_store", store),
	)
}