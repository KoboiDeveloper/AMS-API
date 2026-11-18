package controllers

import (
	"database/sql"
	"net/http"
)

// Tools generate_voucher.aspx.cs parity — /marcomm/voucher/generated/{id}

func MarcommVoucherGeneratedGet(w http.ResponseWriter, r *http.Request) {
	marcommGetRowDAL(w, r, "get_voucher_header", "p_id", marcommPathID(r))
}

func MarcommVoucherGeneratedDetails(w http.ResponseWriter, r *http.Request) {
	voucherID := firstNonEmpty(marcommQ(r, "id_voucher"), marcommPathID(r))
	marcommList(w, r, "xsp_get_voucher_generate_detail_getrows",
		sql.Named("p_id_voucher", voucherID),
	)
}

func MarcommVoucherGeneratedCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUDInsertMaybeID(w, r, "xsp_generate_voucher_marcomm_insert",
		sql.Named("p_account_number", marcommQ(r, "account_number")),
		sql.Named("p_tipe_penerima", marcommQ(r, "tipe_penerima")),
		sql.Named("p_brand", marcommQ(r, "brand")),
		sql.Named("p_store", marcommQ(r, "store")),
		sql.Named("p_qty", marcommQ(r, "qty")),
		sql.Named("p_nominal", marcommQ(r, "nominal")),
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
		sql.Named("p_keterangan", marcommQ(r, "keterangan")),
		sql.Named("p_vType", marcommQ(r, "vType")),
		sql.Named("p_persentase", firstNonEmpty(marcommQ(r, "persentase"), "0")),
		sql.Named("p_jenis_potongan", marcommQ(r, "jenis_potongan")),
		sql.Named("p_master_code_voucher", marcommQ(r, "master_code_voucher")),
	)
}