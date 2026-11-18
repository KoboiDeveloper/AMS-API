package controllers

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"GOamsAPI/database"
)

// Gift detail / editor parity (gift_info.aspx.cs)

func MarcommGiftGet(w http.ResponseWriter, r *http.Request) {
	marcommGetRowDAL(w, r, "get_voucher_header", "p_id", marcommPathID(r))
}

func MarcommGiftDetails(w http.ResponseWriter, r *http.Request) {
	voucherID := firstNonEmpty(marcommQ(r, "id_voucher"), marcommPathID(r))
	marcommList(w, r, "xsp_get_gift_generate_detail_getrows",
		sql.Named("p_id_voucher", voucherID),
	)
}

func marcommQInt(r *http.Request, key string) int {
	s := strings.TrimSpace(marcommQ(r, key))
	if s == "" {
		return 0
	}
	// Strip thousand separators (id-ID / en-US) before parse.
	cleaned := strings.NewReplacer(".", "", ",", "", " ", "").Replace(s)
	if n, err := strconv.Atoi(cleaned); err == nil {
		return n
	}
	if f, err := strconv.ParseFloat(strings.ReplaceAll(s, ",", ""), 64); err == nil {
		return int(f)
	}
	return 0
}

func giftLookupField(row map[string]interface{}, keys []string) string {
	for _, want := range keys {
		for k, v := range row {
			if !strings.EqualFold(k, want) || v == nil {
				continue
			}
			s := strings.TrimSpace(fmt.Sprint(v))
			if s != "" {
				return s
			}
		}
	}
	return ""
}

func giftLookupOptions(rows []map[string]interface{}, valueKeys, labelKeys []string) []map[string]interface{} {
	out := make([]map[string]interface{}, 0, len(rows))
	for _, row := range rows {
		value := giftLookupField(row, valueKeys)
		if value == "" {
			continue
		}
		label := giftLookupField(row, labelKeys)
		if label == "" {
			label = value
		}
		out = append(out, map[string]interface{}{"value": value, "label": label})
	}
	return out
}

func MarcommGiftCategories(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	rows, err := marcommQuerySP(ctx, "xsp_app_member_category_gift")
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	marcommWriteRowsOK(w, giftLookupOptions(rows, []string{"code"}, []string{"keterangan"}))
}

func MarcommGiftBrands(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	rows, err := marcommQuerySP(ctx, "xsp_gl_brand_KAITAN_getrows", sql.Named("p_keywords", ""))
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	marcommWriteRowsOK(w, giftLookupOptions(rows, []string{"idbrand"}, []string{"description", "idbrand"}))
}

func giftStoreMetaMap(ctx context.Context, brand string) map[string][2]string {
	out := map[string][2]string{}
	if database.Instance == nil {
		return out
	}
	q := `
SELECT Store_ID, Store_Name, Store_Kota
FROM DT_Store WITH (NOLOCK)
WHERE (@brand = '' OR Store_Brand_ID = @brand OR Brand_ACCT = @brand OR Store_Brand_ID_2 = @brand)`
	rows, err := database.Instance.QueryContext(ctx, q, sql.Named("brand", brand))
	if err != nil {
		log.Printf("marcomm gift store meta: %s", err.Error())
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var id, name, kota sql.NullString
		if err := rows.Scan(&id, &name, &kota); err != nil {
			continue
		}
		sid := strings.TrimSpace(id.String)
		if sid == "" {
			continue
		}
		out[strings.ToUpper(sid)] = [2]string{
			strings.TrimSpace(name.String),
			strings.TrimSpace(kota.String),
		}
	}
	return out
}

func giftStoreLabel(value string, meta map[string][2]string, row map[string]interface{}) string {
	name := giftLookupField(row, []string{"description", "DESCRIPTION", "nama_cabang", "store_name"})
	city := ""
	if m, ok := meta[strings.ToUpper(value)]; ok {
		if strings.TrimSpace(m[0]) != "" {
			name = strings.TrimSpace(m[0])
		}
		city = strings.TrimSpace(m[1])
	}
	if city == "" {
		city = giftLookupField(row, []string{"kota", "city", "Store_Kota", "store_kota"})
	}
	label := strings.TrimSpace(name)
	if label == "" {
		label = value
	}
	if city != "" && !strings.Contains(strings.ToLower(label), strings.ToLower(city)) {
		label = label + " - " + city
	}
	return label
}

func giftStoreOptions(rows []map[string]interface{}, meta map[string][2]string) []map[string]interface{} {
	out := make([]map[string]interface{}, 0, len(rows))
	for _, row := range rows {
		value := giftLookupField(row, []string{"id_cabang", "ID_CABANG", "idcabang", "store_id", "id_store"})
		if value == "" {
			continue
		}
		out = append(out, map[string]interface{}{
			"value": value,
			"label": giftStoreLabel(value, meta, row),
		})
	}
	return out
}

func MarcommGiftStores(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	brand := firstNonEmpty(marcommQ(r, "brand"), marcommQ(r, "idbrand"))
	rows, err := marcommQuerySP(ctx, "xsp_acct_cabang_getrows_KAIT_ddl",
		sql.Named("p_keywords", ""),
		sql.Named("p_idbrand", brand),
	)
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	meta := giftStoreMetaMap(ctx, brand)
	// Fallback: if brand filter returned nothing (Brand_ACCT codes like RC), load all meta once.
	if len(meta) == 0 {
		meta = giftStoreMetaMap(ctx, "")
	}
	marcommWriteRowsOK(w, giftStoreOptions(rows, meta))
}

func giftLoadTempMembers(ctx context.Context, members []string) error {
	if err := marcommExecSP(ctx, "xsp_tbl_gift_member_temp_create"); err != nil {
		return err
	}
	for _, m := range members {
		m = strings.TrimSpace(m)
		if m == "" {
			continue
		}
		if _, err := database.Instance.ExecContext(ctx,
			"INSERT INTO MOBILE_MEMBER_GIFT_TEMP (ID_MEMBER) VALUES (@p)",
			sql.Named("p", m),
		); err != nil {
			return err
		}
	}
	return nil
}

func MarcommGiftCreate(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	if members := marcommBodyStringSlice(r, "members"); len(members) > 0 {
		if err := giftLoadTempMembers(ctx, members); err != nil {
			log.Printf("marcomm gift temp members: %s", err.Error())
			writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
			return
		}
	}
	var newID sql.NullInt64
	nominal, _ := strconv.ParseFloat(strings.TrimSpace(marcommQ(r, "nominal")), 64)
	err := marcommExecSP(ctx, "xsp_generate_gift_marcomm_insert",
		sql.Named("p_no_urut", sql.Out{Dest: &newID}),
		sql.Named("p_account_number", marcommQ(r, "account_number")),
		sql.Named("p_tipe_penerima", marcommQ(r, "tipe_penerima")),
		sql.Named("p_brand", marcommQ(r, "brand")),
		sql.Named("p_store", marcommQ(r, "store")),
		sql.Named("p_qty", marcommQInt(r, "qty")),
		sql.Named("p_nominal", nominal),
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
		sql.Named("p_judul", marcommQ(r, "judul")),
		sql.Named("p_keterangan", marcommQ(r, "keterangan")),
		sql.Named("p_image_url", marcommQ(r, "image_url")),
		sql.Named("p_cre_by", firstNonEmpty(marcommQ(r, "created_by"), "MARCOMM")),
		sql.Named("p_cre_date", time.Now()),
		sql.Named("p_cre_ip_address", r.RemoteAddr),
		sql.Named("p_vType", firstNonEmpty(marcommQ(r, "vType"), "GIFT")),
		sql.Named("p_persentase", marcommQInt(r, "persentase")),
		sql.Named("p_jenis_potongan", firstNonEmpty(marcommQ(r, "jenis_potongan"), "CASH")),
		sql.Named("p_kategori_gift", marcommQ(r, "kategori_gift")),
	)
	if err != nil {
		log.Printf("marcomm gift insert: %s", err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	if newID.Valid && newID.Int64 > 0 {
		marcommWriteObjectOK(w, map[string]interface{}{"id": newID.Int64, "no_urut": newID.Int64})
		return
	}
	marcommWriteEmptyOK(w)
}

func MarcommGiftUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_generate_voucher_marcomm_update",
		sql.Named("p_id", marcommPathID(r)),
		sql.Named("p_judul", marcommQ(r, "judul")),
		sql.Named("p_keterangan", marcommQ(r, "keterangan")),
		sql.Named("p_image_url", marcommQ(r, "image_url")),
		sql.Named("p_kategori_gift", marcommQ(r, "kategori_gift")),
	)
}

// MarcommGiftTempMembers — optional Excel-import parity; accepts members[] of id_member.
func MarcommGiftTempMembers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	members := marcommBodyStringSlice(r, "members")
	if len(members) == 0 {
		if one := marcommQ(r, "id_member"); one != "" {
			members = []string{one}
		}
	}
	if len(members) == 0 {
		writeRbcaJSON(w, rbcaErrorJSON("4002500", "members required"))
		return
	}
	if err := giftLoadTempMembers(ctx, members); err != nil {
		log.Printf("marcomm gift temp members: %s", err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	marcommWriteEmptyOK(w)
}