package controllers

// DigitalSales — AR edit (cart.aspx), template/upload (Ar_List 07E), retur confirm (MP_confirm_retur).

import (
	"context"
	"database/sql"
	"fmt"
	"io"
	"math"
	"net/http"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"GOamsAPI/database"
	"GOamsAPI/dropbox"
	"github.com/gorilla/mux"
)

// ───────────────────────── AR get / save (cart.aspx) ─────────────────────────

func dgsArItems(ctx context.Context, id string) ([]map[string]interface{}, error) {
	return dgsQuery(ctx, `
		SELECT ISNULL(b.ID,0) AS ID, c.ID_TR_SALES_DETAIL, c.PLU, c.DESKRIPSI, c.QTY,
			CAST(ISNULL(c.Harga_Jual,0) AS float) AS PRICE_POS,
			CAST(ISNULL(b.HARGA_JUAL,0) AS float) AS HARGA_JUAL,
			CAST(ISNULL(b.DISKON,0) AS float) AS DISKON,
			CAST(ISNULL(b.SUBSIDI,0) AS float) AS SUBSIDI,
			CAST(ISNULL(b.TOTAL_SALES,0) AS float) AS TOTAL_SALES,
			CAST(ISNULL(b.KOMISI,0) AS float) AS KOMISI,
			CAST(ISNULL(b.KOMISI_AWAL,0) AS float) AS KOMISI_AWAL,
			CAST(ISNULL(b.KOMISI_NILAI,0) AS float) AS KOMISI_NILAI,
			CAST(ISNULL(b.PPN,0) AS float) AS PPN,
			CAST(ISNULL(b.PPH23,0) AS float) AS PPH23,
			CAST(ISNULL(b.TOTAL,0) AS float) AS TOTAL
		FROM pos_server.dbo.TR_SALES_DETAIL c WITH (NOLOCK)
		LEFT JOIN pos_server.dbo.MARKETPLACE_AR_DETAIL b WITH (NOLOCK) ON b.ID_TR_SALES_DETAIL = c.ID_TR_SALES_DETAIL
		WHERE c.ID_TR_SALES_HEADER = @id
		ORDER BY c.[No]`, sql.Named("id", id))
}

// DgsArGetHandler — GET /dgs/mp/ar/{id}  (id = ID_TR_SALES_HEADER)
func DgsArGetHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		id := strings.TrimSpace(muxVar(r, "id"))
		if id == "" {
			dgsBad(w, "id wajib")
			return
		}
		pre, err := dgsQuery(r.Context(), `
			SELECT TOP 1 h.NAMA_MP, h.NO_INVOICE, h.ID_STORE, h.ID_PRASALES_HEADER, h.NO_RESI,
			       h.TANGGAL_TRANSAKSI
			FROM pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK)
			WHERE h.ID_TR_SALES_HEADER = @id`, sql.Named("id", id))
		if err != nil {
			dgsSQLErr(w, "ar get prasales", err)
			return
		}
		if len(pre) == 0 {
			dgsFail(w, "4042500", "transaksi marketplace tidak ditemukan")
			return
		}
		hdrRows, err := dgsQuery(r.Context(), `EXEC pos_server.dbo.xsp_get_ar_marketplace_getrow @p_id = @id`, sql.Named("id", id))
		if err != nil {
			dgsSQLErr(w, "ar get header", err)
			return
		}
		items, err := dgsArItems(r.Context(), id)
		if err != nil {
			dgsSQLErr(w, "ar get items", err)
			return
		}
		dgsOK(w, map[string]interface{}{
			"prasales": dgsFirst(pre),
			"exists":   len(hdrRows) > 0,
			"header":   dgsFirst(hdrRows),
			"items":    items,
		}, nil)
	})
}

type dgsArItemReq struct {
	ID        int     `json:"id"`
	HargaJual float64 `json:"harga_jual"`
	Diskon    float64 `json:"diskon"`
	Subsidi   float64 `json:"subsidi"`
	Komisi    float64 `json:"komisi"`
}

type dgsArSaveReq struct {
	IDTrSalesHeader    string         `json:"id_tr_sales_header"`
	NoOrder            string         `json:"no_order"`
	NomorResi          string         `json:"nomor_resi"`
	TglPo              string         `json:"tgl_po"`
	TglKirim           string         `json:"tgl_kirim"`
	TglSampai          string         `json:"tgl_sampai"`
	TipeOngkir         string         `json:"tipe_ongkir"`
	Ongkir             float64        `json:"ongkir"`
	PaymentGateway     float64        `json:"payment_gateway"`
	BiayaLayanan       float64        `json:"biaya_layanan"`
	Premi              float64        `json:"premi"`
	BiayaProgram       float64        `json:"biaya_program"`
	KomisiAffiliate    float64        `json:"komisi_affiliate"`
	BiayaTransaksi     float64        `json:"biaya_transaksi"`
	BiayaProsesPesanan float64        `json:"biaya_proses_pesanan"`
	KomisiDinamis      float64        `json:"komisi_dinamis"`
	CheckDpp           bool           `json:"check_dpp"`
	CheckPpn           bool           `json:"check_ppn"`
	Items              []dgsArItemReq `json:"items"`
}

// dgsItemCalc mirrors cart.aspx per-marketplace commission formulas.
func dgsItemCalc(mp string, qty int, hargaJual, diskon, subsidi, komisi float64) (totalSales, komisiAwal, komisiNilai, ppn, pph, total float64, ok bool) {
	base := float64(qty)*hargaJual - diskon + subsidi
	awal := base * komisi / 100
	var nilai float64
	switch strings.ToUpper(strings.TrimSpace(mp)) {
	case "TOKOPEDIA":
		nilai = awal
	case "SHOPEE", "BLIBLI":
		nilai = (100.0 / 108.0) * awal
	case "TIKTOK", "JD.ID", "LAZADA", "BUKALAPAK", "ZALORA", "BLANJA", "BLANJA.COM", "DIRECT SELLING", "ZILINGO", "ZILLINGO":
		nilai = awal * 100 / 110
	default:
		return 0, 0, 0, 0, 0, 0, false
	}
	// Rounding verified against rows saved by the legacy ASP page:
	// KOMISI_AWAL & TOTAL are truncated, DPP/PPN/PPH23 are rounded to whole rupiah.
	totalSales = math.Round(base*100) / 100
	komisiAwal = math.Floor(awal)
	komisiNilai = math.Round(nilai)
	ppn = math.Round(komisiNilai * 10 / 100)
	pph = math.Round(komisiNilai * 2 / 100)
	total = math.Floor(base - awal)
	return totalSales, komisiAwal, komisiNilai, ppn, pph, total, true
}

func dgsNullDate(s string) (interface{}, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, nil
	}
	if len(s) >= 10 {
		s = s[:10]
	}
	s = strings.ReplaceAll(s, "/", "-")
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return nil, fmt.Errorf("format tanggal tidak valid: %q", s)
	}
	return t, nil
}

func dgsMoneyOK(vals ...float64) bool {
	for _, v := range vals {
		if math.IsNaN(v) || math.IsInf(v, 0) || math.Abs(v) > 1e13 {
			return false
		}
	}
	return true
}

// DgsArSaveHandler — POST /dgs/mp/ar/save
func DgsArSaveHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		var req dgsArSaveReq
		if err := dgsDecode(r, &req); err != nil {
			dgsBad(w, "payload tidak valid")
			return
		}
		req.IDTrSalesHeader = strings.TrimSpace(req.IDTrSalesHeader)
		req.NoOrder = strings.TrimSpace(req.NoOrder)
		req.NomorResi = strings.TrimSpace(req.NomorResi)
		req.TipeOngkir = strings.ToUpper(strings.TrimSpace(req.TipeOngkir))
		if req.IDTrSalesHeader == "" || req.NoOrder == "" {
			dgsBad(w, "id transaksi dan no order wajib")
			return
		}
		if len(req.NoOrder) > 64 || len(req.NomorResi) > 50 {
			dgsBad(w, "no order / no resi terlalu panjang")
			return
		}
		if req.TipeOngkir != "NORMAL" && req.TipeOngkir != "SUBSIDI" {
			dgsBad(w, "tipe ongkir harus NORMAL atau SUBSIDI")
			return
		}
		if !dgsMoneyOK(req.Ongkir, req.PaymentGateway, req.BiayaLayanan, req.Premi, req.BiayaProgram,
			req.KomisiAffiliate, req.BiayaTransaksi, req.BiayaProsesPesanan, req.KomisiDinamis) {
			dgsBad(w, "nilai biaya tidak valid")
			return
		}
		tglPo, e1 := dgsNullDate(req.TglPo)
		tglKirim, e2 := dgsNullDate(req.TglKirim)
		tglSampai, e3 := dgsNullDate(req.TglSampai)
		for _, e := range []error{e1, e2, e3} {
			if e != nil {
				dgsBad(w, e.Error())
				return
			}
		}
		if len(req.Items) > 200 {
			dgsBad(w, "terlalu banyak item")
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 90*time.Second)
		defer cancel()

		var mp, invoice string
		err := database.RbcaInstance.QueryRowContext(ctx, `
			SELECT TOP 1 NAMA_MP, NO_INVOICE FROM pos_server.dbo.TR_PRASALES_HEADER WITH (NOLOCK)
			WHERE ID_TR_SALES_HEADER = @id`, sql.Named("id", req.IDTrSalesHeader)).Scan(&mp, &invoice)
		if err == sql.ErrNoRows {
			dgsFail(w, "4042500", "transaksi marketplace tidak ditemukan")
			return
		}
		if err != nil {
			dgsSQLErr(w, "ar save lookup", err)
			return
		}
		var exists int
		if err := database.RbcaInstance.QueryRowContext(ctx,
			`SELECT COUNT(*) FROM pos_server.dbo.MARKETPLACE_AR WITH (NOLOCK) WHERE ID_TR_SALES_HEADER = @id`,
			sql.Named("id", req.IDTrSalesHeader)).Scan(&exists); err != nil {
			dgsSQLErr(w, "ar save exists", err)
			return
		}

		tx, err := database.RbcaInstance.BeginTx(ctx, nil)
		if err != nil {
			dgsSQLErr(w, "ar save begin", err)
			return
		}
		defer tx.Rollback()

		updated := 0
		for _, it := range req.Items {
			if it.ID <= 0 {
				continue
			}
			if !dgsMoneyOK(it.HargaJual, it.Diskon, it.Subsidi, it.Komisi) || it.Komisi < 0 || it.Komisi > 100 {
				dgsBad(w, "nilai item tidak valid (komisi 0–100)")
				return
			}
			var qty int
			e := tx.QueryRowContext(ctx, `
				SELECT c.QTY FROM pos_server.dbo.MARKETPLACE_AR_DETAIL b
				INNER JOIN pos_server.dbo.TR_SALES_DETAIL c ON c.ID_TR_SALES_DETAIL = b.ID_TR_SALES_DETAIL
				WHERE b.ID = @id AND b.ID_TR_SALES_HEADER = @h`,
				sql.Named("id", it.ID), sql.Named("h", req.IDTrSalesHeader)).Scan(&qty)
			if e != nil {
				dgsBad(w, fmt.Sprintf("item #%d tidak termasuk transaksi ini", it.ID))
				return
			}
			ts, ka, kn, ppn, pph, tot, ok := dgsItemCalc(mp, qty, it.HargaJual, it.Diskon, it.Subsidi, it.Komisi)
			if ok {
				_, e = tx.ExecContext(ctx, `
					UPDATE pos_server.dbo.MARKETPLACE_AR_DETAIL
					SET HARGA_JUAL=@hj, DISKON=@dk, SUBSIDI=@sb, KOMISI=@km,
					    TOTAL_SALES=@ts, KOMISI_AWAL=@ka, KOMISI_NILAI=@kn, PPN=@ppn, PPH23=@pph, TOTAL=@tot
					WHERE ID=@id`,
					sql.Named("hj", it.HargaJual), sql.Named("dk", it.Diskon), sql.Named("sb", it.Subsidi), sql.Named("km", it.Komisi),
					sql.Named("ts", ts), sql.Named("ka", ka), sql.Named("kn", kn), sql.Named("ppn", ppn), sql.Named("pph", pph),
					sql.Named("tot", tot), sql.Named("id", it.ID))
			} else {
				_, e = tx.ExecContext(ctx, `
					UPDATE pos_server.dbo.MARKETPLACE_AR_DETAIL
					SET HARGA_JUAL=@hj, DISKON=@dk, SUBSIDI=@sb, KOMISI=@km WHERE ID=@id`,
					sql.Named("hj", it.HargaJual), sql.Named("dk", it.Diskon), sql.Named("sb", it.Subsidi),
					sql.Named("km", it.Komisi), sql.Named("id", it.ID))
			}
			if e != nil {
				dgsSQLErr(w, "ar save item", e)
				return
			}
			updated++
		}

		var e error
		if exists > 0 {
			chkDpp, chkPpn := 0, 0
			if req.CheckDpp {
				chkDpp = 1
			}
			if req.CheckPpn {
				chkPpn = 1
			}
			_, e = tx.ExecContext(ctx, `EXEC pos_server.dbo.xsp_ar_marketplace_lookup_update
				@p_id_tr_sales_header=@id, @p_no_order=@no, @p_nomor_resi=@resi, @p_tgl_po=@po, @p_tgl_kirim=@kirim, @p_tgl_sampai=@sampai,
				@p_ongkir=@ongkir, @p_tipe_ongkir=@tipe, @p_payment_gateway=@pg, @p_check_dpp=@dpp, @p_check_ppn=@ppn,
				@p_biaya_layanan=@bl, @p_premi=@premi, @p_biaya_program=@bp, @p_komisi_affiliate=@ka, @p_biaya_transaksi=@bt,
				@p_biaya_proses_pesanan=@bpp, @p_komisi_dinamis=@kd`,
				sql.Named("id", req.IDTrSalesHeader), sql.Named("no", req.NoOrder), sql.Named("resi", req.NomorResi),
				sql.Named("po", tglPo), sql.Named("kirim", tglKirim), sql.Named("sampai", tglSampai),
				sql.Named("ongkir", req.Ongkir), sql.Named("tipe", req.TipeOngkir), sql.Named("pg", req.PaymentGateway),
				sql.Named("dpp", chkDpp), sql.Named("ppn", chkPpn), sql.Named("bl", req.BiayaLayanan), sql.Named("premi", req.Premi),
				sql.Named("bp", req.BiayaProgram), sql.Named("ka", req.KomisiAffiliate), sql.Named("bt", req.BiayaTransaksi),
				sql.Named("bpp", req.BiayaProsesPesanan), sql.Named("kd", req.KomisiDinamis))
		} else {
			_, e = tx.ExecContext(ctx, `EXEC pos_server.dbo.xsp_ar_marketplace_lookup_insert
				@p_id_tr_sales_header=@id, @p_marketplace_id=@mp, @p_no_order=@no, @p_nomor_resi=@resi, @p_tgl_po=@po, @p_tgl_kirim=@kirim,
				@p_tgl_sampai=@sampai, @p_ongkir=@ongkir, @p_tipe_ongkir=@tipe, @p_payment_gateway=@pg, @p_biaya_layanan=@bl,
				@p_premi=@premi, @p_biaya_program=@bp, @p_komisi_affiliate=@ka, @p_biaya_transaksi=@bt,
				@p_biaya_proses_pesanan=@bpp, @p_komisi_dinamis=@kd`,
				sql.Named("id", req.IDTrSalesHeader), sql.Named("mp", mp), sql.Named("no", req.NoOrder), sql.Named("resi", req.NomorResi),
				sql.Named("po", tglPo), sql.Named("kirim", tglKirim), sql.Named("sampai", tglSampai),
				sql.Named("ongkir", req.Ongkir), sql.Named("tipe", req.TipeOngkir), sql.Named("pg", req.PaymentGateway),
				sql.Named("bl", req.BiayaLayanan), sql.Named("premi", req.Premi), sql.Named("bp", req.BiayaProgram),
				sql.Named("ka", req.KomisiAffiliate), sql.Named("bt", req.BiayaTransaksi),
				sql.Named("bpp", req.BiayaProsesPesanan), sql.Named("kd", req.KomisiDinamis))
		}
		if e != nil {
			dgsSQLErr(w, "ar save lookup sp", e)
			return
		}
		if err := tx.Commit(); err != nil {
			dgsSQLErr(w, "ar save commit", err)
			return
		}
		mode := "INSERT"
		if exists > 0 {
			mode = "UPDATE"
		}
		dgsAudit(r, nik, "AR_SAVE_"+mode, req.NoOrder, req)
		dgsOK(w, map[string]interface{}{"mode": mode, "items_updated": updated, "invoice": invoice}, nil)
	})
}

// muxVar avoids importing mux twice in this file's signature list.
func muxVar(r *http.Request, key string) string { return mux.Vars(r)[key] }

// ───────────────────────── AR template ─────────────────────────

type dgsTemplateReq struct {
	Invoices []string `json:"invoices"`
}

// DgsArTemplateHandler — POST /dgs/mp/ar/template  (body {invoices:[...]})
// Same two datasets as btnExportTemplateAR*_Click (sheet AR + DETAIL); xlsx is built in the browser.
func DgsArTemplateHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		var req dgsTemplateReq
		if err := dgsDecode(r, &req); err != nil {
			dgsBad(w, "payload tidak valid")
			return
		}
		seen := map[string]bool{}
		inv := make([]string, 0, len(req.Invoices))
		for _, s := range req.Invoices {
			s = strings.ToUpper(strings.TrimSpace(s))
			if s == "" || seen[s] {
				continue
			}
			if len(s) > 64 {
				dgsBad(w, "invoice terlalu panjang: "+truncStr(s, 20))
				return
			}
			seen[s] = true
			inv = append(inv, s)
		}
		if len(inv) == 0 {
			dgsBad(w, "daftar invoice kosong")
			return
		}
		if len(inv) > 1500 {
			dgsBad(w, "maksimal 1500 invoice per template")
			return
		}
		ph := make([]string, len(inv))
		args := make([]interface{}, len(inv))
		for i, s := range inv {
			ph[i] = fmt.Sprintf("@i%d", i)
			args[i] = sql.Named(fmt.Sprintf("i%d", i), s)
		}
		in := strings.Join(ph, ",")
		ar, err := dgsQuery(r.Context(), `
			SELECT '' AS ACTION, a.MARKETPLACE_ID AS MARKETPLACE, b.ID_TR_SALES_DETAIL, UPPER(a.NO_ORDER) AS NO_INVOICE, c.PLU, b.DEKSRIPSI, b.QTY,
				CAST(ISNULL(c.Harga_Jual,0) AS float) AS [PRICE POS], CAST(ISNULL(b.HARGA_JUAL,0) AS float) AS [PRICE MP],
				CAST(ISNULL(b.DISKON,0) AS float) AS DISKON, CAST(ISNULL(b.SUBSIDI,0) AS float) AS SUBSIDI,
				CAST(ISNULL(b.TOTAL_SALES,0) AS float) AS TOTAL_SALES, CAST(ISNULL(b.KOMISI,0) AS float) AS KOMISI_PERSEN,
				CAST(ISNULL(b.KOMISI_AWAL,0) AS float) AS KOMISI, CAST(ISNULL(b.KOMISI_NILAI,0) AS float) AS DPP_KOMISI,
				CAST(ISNULL(b.PPN,0) AS float) AS PPN, CAST(ISNULL(b.PPH23,0) AS float) AS PPH23, CAST(ISNULL(b.TOTAL,0) AS float) AS TOTAL
			FROM pos_server.dbo.MARKETPLACE_AR a WITH (NOLOCK)
			INNER JOIN pos_server.dbo.MARKETPLACE_AR_DETAIL b WITH (NOLOCK) ON b.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER
			INNER JOIN pos_server.dbo.TR_SALES_DETAIL c WITH (NOLOCK) ON c.ID_TR_SALES_DETAIL = b.ID_TR_SALES_DETAIL
			WHERE a.NO_ORDER COLLATE Latin1_General_CI_AS IN (`+in+`)
			ORDER BY UPPER(a.NO_ORDER)`, args...)
		if err != nil {
			dgsSQLErr(w, "template ar", err)
			return
		}
		detail, err := dgsQuery(r.Context(), `
			SELECT a.NO_ORDER AS NO_INVOICE, a.NOMOR_RESI, CONVERT(varchar(10), a.TGL_PO, 23) AS TGL_PO,
				CONVERT(varchar(10), a.TGL_KIRIM, 23) AS TGL_KIRIM, CONVERT(varchar(10), a.TGL_SAMPAI, 23) AS TGL_SAMPAI,
				a.TIPE_ONGKIR, CAST(ISNULL(a.ONGKIR,0) AS float) AS NILAI_ONGKIR, CAST(ISNULL(a.PAYMENT_GATEWAY,0) AS float) AS PAYMENT_GATEWAY,
				CAST(ISNULL(a.BIAYA_LAYANAN,0) AS float) AS BIAYA_LAYANAN, CAST(ISNULL(a.PREMI,0) AS float) AS PREMI,
				CAST(ISNULL(a.BIAYA_PROGRAM,0) AS float) AS BIAYA_PROGRAM, CAST(ISNULL(a.KOMISI_AFFILIATE,0) AS float) AS KOMISI_AFFILIATE,
				CAST(ISNULL(a.BIAYA_TRANSAKSI,0) AS float) AS BIAYA_TRANSAKSI, CAST(ISNULL(a.BIAYA_PROSES_PESANAN,0) AS float) AS BIAYA_PROSES_PESANAN,
				CAST(ISNULL(a.KOMISI_DINAMIS,0) AS float) AS KOMISI_DINAMIS, CAST(0 AS float) AS TOTAL_AR_PLUS_ONGKIR,
				a.ID_TR_SALES_HEADER, CAST(NULL AS varchar(10)) AS TGL_REALISASI
			FROM pos_server.dbo.MARKETPLACE_AR a WITH (NOLOCK)
			WHERE a.NO_ORDER COLLATE Latin1_General_CI_AS IN (`+in+`)
			ORDER BY UPPER(a.NO_ORDER)`, args...)
		if err != nil {
			dgsSQLErr(w, "template detail", err)
			return
		}
		dgsAudit(r, nik, "AR_TEMPLATE", fmt.Sprintf("%d invoice", len(inv)), map[string]interface{}{"invoices": len(inv), "ar_rows": len(ar), "detail_rows": len(detail)})
		dgsOK(w, map[string]interface{}{"ar": ar, "detail": detail, "requested": len(inv)}, nil)
	})
}

// ───────────────────────── AR upload (07E only) ─────────────────────────

var dgsUploadMu sync.Mutex

type dgsUploadReq struct {
	Ar     []map[string]interface{} `json:"ar"`
	Detail []map[string]interface{} `json:"detail"`
}

func dgsStr(m map[string]interface{}, key string, max int) string {
	v, ok := m[key]
	if !ok || v == nil {
		return ""
	}
	s := strings.TrimSpace(fmt.Sprint(v))
	if len(s) > max {
		s = s[:max]
	}
	return s
}

func dgsNum(m map[string]interface{}, key string) (float64, error) {
	v, ok := m[key]
	if !ok || v == nil || fmt.Sprint(v) == "" {
		return 0, nil
	}
	switch t := v.(type) {
	case float64:
		if math.IsNaN(t) || math.IsInf(t, 0) {
			return 0, fmt.Errorf("%s bukan angka", key)
		}
		return t, nil
	case string:
		var f float64
		_, err := fmt.Sscanf(strings.ReplaceAll(strings.TrimSpace(t), ",", ""), "%g", &f)
		if err != nil {
			return 0, fmt.Errorf("%s bukan angka: %q", key, t)
		}
		return f, nil
	}
	return 0, fmt.Errorf("%s bukan angka", key)
}

// DgsArUpload07EHandler — POST /dgs/mp/ar/upload-07e
// Parity FileUpload07E: temp tables → xsp_export_ar_market_place_07E. Rows must belong to store 07E.
func DgsArUpload07EHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		var req dgsUploadReq
		if err := dgsDecode(r, &req); err != nil {
			dgsBad(w, "payload tidak valid")
			return
		}
		if len(req.Ar) == 0 || len(req.Detail) == 0 {
			dgsBad(w, "sheet AR dan DETAIL wajib berisi data")
			return
		}
		if len(req.Ar) > 5000 || len(req.Detail) > 5000 {
			dgsBad(w, "maksimal 5000 baris per sheet")
			return
		}
		if !dgsUploadMu.TryLock() {
			dgsFail(w, "4232500", "ada upload AR 07E lain yang sedang berjalan, coba lagi sebentar")
			return
		}
		defer dgsUploadMu.Unlock()

		// parse + validate before touching the DB
		type arRow struct {
			id, inv, plu, desk string
			qty                int
			n                  [11]float64 // price_pos, price_mp, diskon, subsidi, total_sales, komisi%, komisi_awal, nilai, ppn, pph, total
		}
		arKeys := []string{"PRICE POS", "PRICE MP", "DISKON", "SUBSIDI", "TOTAL_SALES", "KOMISI_PERSEN", "KOMISI", "DPP_KOMISI", "PPN", "PPH23", "TOTAL"}
		arRows := make([]arRow, 0, len(req.Ar))
		for i, m := range req.Ar {
			a := arRow{id: dgsStr(m, "ID_TR_SALES_DETAIL", 32), inv: dgsStr(m, "NO_INVOICE", 32), plu: dgsStr(m, "PLU", 32), desk: dgsStr(m, "DEKSRIPSI", 50)}
			if a.id == "" || a.inv == "" {
				dgsBad(w, fmt.Sprintf("sheet AR baris %d: ID_TR_SALES_DETAIL / NO_INVOICE kosong", i+2))
				return
			}
			q, err := dgsNum(m, "QTY")
			if err != nil {
				dgsBad(w, fmt.Sprintf("sheet AR baris %d: %v", i+2, err))
				return
			}
			a.qty = int(q)
			for k, key := range arKeys {
				v, err := dgsNum(m, key)
				if err != nil || !dgsMoneyOK(v) {
					dgsBad(w, fmt.Sprintf("sheet AR baris %d: kolom %s tidak valid", i+2, key))
					return
				}
				a.n[k] = v
			}
			if a.n[5] < 0 || a.n[5] > 100 {
				dgsBad(w, fmt.Sprintf("sheet AR baris %d: KOMISI_PERSEN harus 0–100", i+2))
				return
			}
			arRows = append(arRows, a)
		}
		type dtRow struct {
			inv, resi, tipe, hid     string
			po, kirim, sampai, reali interface{}
			n                        [10]float64 // ongkir, pg, layanan, premi, program, affiliate, transaksi, proses, dinamis, total
		}
		dtKeys := []string{"NILAI_ONGKIR", "PAYMENT_GATEWAY", "BIAYA_LAYANAN", "PREMI", "BIAYA_PROGRAM", "KOMISI_AFFILIATE", "BIAYA_TRANSAKSI", "BIAYA_PROSES_PESANAN", "KOMISI_DINAMIS", "TOTAL_AR_PLUS_ONGKIR"}
		dtRows := make([]dtRow, 0, len(req.Detail))
		for i, m := range req.Detail {
			d := dtRow{inv: dgsStr(m, "NO_INVOICE", 200), resi: dgsStr(m, "NOMOR_RESI", 50),
				tipe: strings.ToUpper(dgsStr(m, "TIPE_ONGKIR", 50)), hid: dgsStr(m, "ID_TR_SALES_HEADER", 32)}
			if d.inv == "" || d.hid == "" {
				dgsBad(w, fmt.Sprintf("sheet DETAIL baris %d: NO_INVOICE / ID_TR_SALES_HEADER kosong", i+2))
				return
			}
			if d.tipe != "NORMAL" && d.tipe != "SUBSIDI" {
				dgsBad(w, fmt.Sprintf("sheet DETAIL baris %d: TIPE_ONGKIR harus NORMAL/SUBSIDI", i+2))
				return
			}
			var err error
			if d.po, err = dgsNullDate(dgsStr(m, "TGL_PO", 30)); err != nil {
				dgsBad(w, fmt.Sprintf("sheet DETAIL baris %d: TGL_PO %v", i+2, err))
				return
			}
			if d.kirim, err = dgsNullDate(dgsStr(m, "TGL_KIRIM", 30)); err != nil {
				dgsBad(w, fmt.Sprintf("sheet DETAIL baris %d: TGL_KIRIM %v", i+2, err))
				return
			}
			if d.sampai, err = dgsNullDate(dgsStr(m, "TGL_SAMPAI", 30)); err != nil {
				dgsBad(w, fmt.Sprintf("sheet DETAIL baris %d: TGL_SAMPAI %v", i+2, err))
				return
			}
			if d.reali, err = dgsNullDate(dgsStr(m, "TGL_REALISASI", 30)); err != nil {
				dgsBad(w, fmt.Sprintf("sheet DETAIL baris %d: TGL_REALISASI %v", i+2, err))
				return
			}
			for k, key := range dtKeys {
				v, err := dgsNum(m, key)
				if err != nil || !dgsMoneyOK(v) {
					dgsBad(w, fmt.Sprintf("sheet DETAIL baris %d: kolom %s tidak valid", i+2, key))
					return
				}
				d.n[k] = v
			}
			dtRows = append(dtRows, d)
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Minute)
		defer cancel()
		db := database.RbcaInstance
		if _, err := db.ExecContext(ctx, `EXEC pos_server.dbo.xsp_tbl_ar_detail_temp_create @p_store = '07E'`); err != nil {
			dgsSQLErr(w, "upload temp ar", err)
			return
		}
		if _, err := db.ExecContext(ctx, `EXEC pos_server.dbo.xsp_tbl_ar_detail_pengiriman_temp_create @p_store = '07E'`); err != nil {
			dgsSQLErr(w, "upload temp pengiriman", err)
			return
		}
		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			dgsSQLErr(w, "upload begin", err)
			return
		}
		defer tx.Rollback()

		const chunk = 100
		for s := 0; s < len(arRows); s += chunk {
			e := s + chunk
			if e > len(arRows) {
				e = len(arRows)
			}
			var sb strings.Builder
			sb.WriteString(`INSERT INTO pos_server.dbo.web_tbl_ar_detail_tem_07E
				(ID_TR_SALES_DETAIL, INVOICE, PLU, DEKSRIPSI, QTY, PRICE_POS, PRICE_MP, DISKON, SUBSIDI, TOTAL_SALES, KOMISI, KOMISI_AWAL, KOMISI_NILAI, PPN, PPH23, TOTAL) VALUES `)
			args := make([]interface{}, 0, (e-s)*16)
			for i := s; i < e; i++ {
				a := arRows[i]
				if i > s {
					sb.WriteString(",")
				}
				base := len(args)
				sb.WriteString("(")
				for k := 1; k <= 16; k++ {
					if k > 1 {
						sb.WriteString(",")
					}
					fmt.Fprintf(&sb, "@p%d", base+k)
				}
				sb.WriteString(")")
				args = append(args, a.id, a.inv, a.plu, a.desk, a.qty,
					a.n[0], a.n[1], a.n[2], a.n[3], a.n[4], a.n[5], a.n[6], a.n[7], a.n[8], a.n[9], a.n[10])
			}
			if _, err := tx.ExecContext(ctx, sb.String(), args...); err != nil {
				dgsSQLErr(w, "upload insert ar", err)
				return
			}
		}
		for s := 0; s < len(dtRows); s += chunk {
			e := s + chunk
			if e > len(dtRows) {
				e = len(dtRows)
			}
			var sb strings.Builder
			sb.WriteString(`INSERT INTO pos_server.dbo.web_tbl_ar_detail_pengiriman_tem_07E
				(INVOICE, NO_RESI, TGL_PO, TGL_KIRIM, TGL_SAMPAI, TIPE_ONGKIR, ONGKIR, PAYMENT_GATEWAY, BIAYA_LAYANAN, PREMI, BIAYA_PROGRAM,
				 KOMISI_AFFILIATE, BIAYA_TRANSAKSI, BIAYA_PROSES_PESANAN, KOMISI_DINAMIS, TOTALAR, ID_TR_SALES_HEADER, TGL_REALISASI) VALUES `)
			args := make([]interface{}, 0, (e-s)*18)
			for i := s; i < e; i++ {
				d := dtRows[i]
				if i > s {
					sb.WriteString(",")
				}
				base := len(args)
				sb.WriteString("(")
				for k := 1; k <= 18; k++ {
					if k > 1 {
						sb.WriteString(",")
					}
					fmt.Fprintf(&sb, "@p%d", base+k)
				}
				sb.WriteString(")")
				args = append(args, d.inv, d.resi, d.po, d.kirim, d.sampai, d.tipe,
					d.n[0], d.n[1], d.n[2], d.n[3], d.n[4], d.n[5], d.n[6], d.n[7], d.n[8], d.n[9], d.hid, d.reali)
			}
			if _, err := tx.ExecContext(ctx, sb.String(), args...); err != nil {
				dgsSQLErr(w, "upload insert detail", err)
				return
			}
		}

		// Safety: every uploaded row must exist and belong to store 07E.
		var badAr, badDt int
		if err := tx.QueryRowContext(ctx, `
			SELECT COUNT(*) FROM pos_server.dbo.web_tbl_ar_detail_tem_07E t
			LEFT JOIN pos_server.dbo.MARKETPLACE_AR_DETAIL d ON d.ID_TR_SALES_DETAIL = t.ID_TR_SALES_DETAIL
			LEFT JOIN pos_server.dbo.TR_PRASALES_HEADER h ON h.ID_TR_SALES_HEADER = d.ID_TR_SALES_HEADER
			WHERE h.ID_STORE IS NULL OR h.ID_STORE <> '07E'`).Scan(&badAr); err != nil {
			dgsSQLErr(w, "upload validate ar", err)
			return
		}
		if err := tx.QueryRowContext(ctx, `
			SELECT COUNT(*) FROM pos_server.dbo.web_tbl_ar_detail_pengiriman_tem_07E t
			LEFT JOIN pos_server.dbo.TR_PRASALES_HEADER h ON h.ID_TR_SALES_HEADER = t.ID_TR_SALES_HEADER
			WHERE h.ID_STORE IS NULL OR h.ID_STORE <> '07E'`).Scan(&badDt); err != nil {
			dgsSQLErr(w, "upload validate detail", err)
			return
		}
		if badAr > 0 || badDt > 0 {
			dgsBad(w, fmt.Sprintf("upload ditolak: %d baris AR dan %d baris DETAIL tidak ditemukan / bukan toko 07E", badAr, badDt))
			return
		}
		if err := tx.Commit(); err != nil {
			dgsSQLErr(w, "upload commit", err)
			return
		}
		if _, err := db.ExecContext(ctx, `EXEC pos_server.dbo.xsp_export_ar_market_place_07E`); err != nil {
			dgsSQLErr(w, "upload export sp", err)
			return
		}
		dgsAudit(r, nik, "AR_UPLOAD_07E", "07E", map[string]interface{}{"ar_rows": len(arRows), "detail_rows": len(dtRows)})
		dgsOK(w, map[string]interface{}{"ar_rows": len(arRows), "detail_rows": len(dtRows)}, nil)
	})
}

// ───────────────────────── Retur confirm (MP_confirm_retur) ─────────────────────────

var dgsReturKategori = map[string]string{
	"barang layak jual":       "Barang Layak Jual",
	"barang tidak layak jual": "Barang Tidak Layak Jual",
	"barang tidak sesuai":     "Barang Tidak Sesuai",
	"barang tidak kembali":    "Barang Tidak kembali",
	"batal retur":             "Batal Retur",
}

// DgsReturGetHandler — GET /dgs/mp/retur/item?invoice=&plu=
func DgsReturGetHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		inv := strings.TrimSpace(r.URL.Query().Get("invoice"))
		plu := strings.TrimSpace(r.URL.Query().Get("plu"))
		if inv == "" || plu == "" {
			dgsBad(w, "invoice dan plu wajib")
			return
		}
		rows, err := dgsQuery(r.Context(), `EXEC pos_server.dbo.xsp_get_ar_confirmation_retur_getrow @p_invoice = @inv, @p_plu = @plu`,
			sql.Named("inv", inv), sql.Named("plu", plu))
		if err != nil {
			dgsSQLErr(w, "retur get", err)
			return
		}
		if len(rows) == 0 {
			dgsFail(w, "4042500", "item retur tidak ditemukan")
			return
		}
		dgsOK(w, dgsFirst(rows), nil)
	})
}

// DgsReturImageLinkHandler — GET /dgs/mp/retur/image-link?path=
func DgsReturImageLinkHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		p := strings.TrimSpace(r.URL.Query().Get("path"))
		if !strings.HasPrefix(p, "/uploads/dgs-retur/") || strings.Contains(p, "..") {
			dgsBad(w, "path foto tidak valid")
			return
		}
		client, err := dropbox.NewClientFromEnv()
		if err != nil {
			dgsFail(w, "5000005", "dropbox belum dikonfigurasi")
			return
		}
		link, err := client.GetTemporaryLink(p)
		if err != nil {
			dgsFail(w, "5000005", "gagal mengambil foto: "+err.Error())
			return
		}
		dgsOK(w, map[string]interface{}{"link": link}, nil)
	})
}

// DgsReturConfirmHandler — POST /dgs/mp/retur/confirm (multipart)
// fields: invoice, plu, tanggal_kembali (YYYY-MM-DD), kategori, keterangan, image1..image5 (files, optional)
func DgsReturConfirmHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		r.Body = http.MaxBytesReader(w, r.Body, 5*(10<<20)+(1<<20))
		if err := r.ParseMultipartForm(32 << 20); err != nil {
			dgsBad(w, "form tidak valid atau file terlalu besar (maks 10MB per foto)")
			return
		}
		inv := strings.TrimSpace(r.FormValue("invoice"))
		plu := strings.TrimSpace(r.FormValue("plu"))
		ket := strings.TrimSpace(r.FormValue("keterangan"))
		kategori, okK := dgsReturKategori[strings.ToLower(strings.TrimSpace(r.FormValue("kategori")))]
		if inv == "" || plu == "" || !okK {
			dgsBad(w, "invoice, plu, dan kategori (valid) wajib")
			return
		}
		if len(ket) > 200 {
			dgsBad(w, "keterangan maksimal 200 karakter")
			return
		}
		var tgl time.Time
		if kategori != "Batal Retur" {
			ymd, ok := dgsYMD(r.FormValue("tanggal_kembali"))
			if !ok {
				dgsBad(w, "tanggal kembali wajib (YYYY-MM-DD)")
				return
			}
			tgl, _ = time.Parse("2006-01-02", ymd)
		} else {
			tgl = time.Now()
		}
		ctx, cancel := context.WithTimeout(r.Context(), 3*time.Minute)
		defer cancel()

		var found int
		if err := database.RbcaInstance.QueryRowContext(ctx, `
			SELECT COUNT(*) FROM pos_server.dbo.TR_PRASALES_DETAIL d WITH (NOLOCK)
			INNER JOIN pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK) ON h.ID_PRASALES_HEADER = d.ID_PRASALES_HEADER
			WHERE h.NO_INVOICE = @inv AND d.PLU = @plu
			  AND (d.STATUS IN (2,8,9) OR d.TANGGAL_RETUR IS NOT NULL OR d.KATEGORI_BARANG_KEMBALI IS NOT NULL)`,
			sql.Named("inv", inv), sql.Named("plu", plu)).Scan(&found); err != nil {
			dgsSQLErr(w, "retur lookup", err)
			return
		}
		if found == 0 {
			dgsFail(w, "4042500", "item bukan item retur / tidak ditemukan")
			return
		}

		// existing images
		cur, err := dgsQuery(ctx, `EXEC pos_server.dbo.xsp_get_ar_confirmation_retur_getrow @p_invoice = @inv, @p_plu = @plu`,
			sql.Named("inv", inv), sql.Named("plu", plu))
		if err != nil {
			dgsSQLErr(w, "retur current", err)
			return
		}
		row := dgsFirst(cur)
		imgs := make([]interface{}, 5)
		var client *dropbox.Client
		uploaded := 0
		for i := 1; i <= 5; i++ {
			key := fmt.Sprintf("IMAGE%d", i)
			if s, ok := row[key].(string); ok && s != "" && s != "no_image.png" {
				imgs[i-1] = s
			}
			file, hdr, err := r.FormFile(fmt.Sprintf("image%d", i))
			if err != nil || file == nil {
				continue
			}
			content, rerr := io.ReadAll(io.LimitReader(file, 10<<20+1))
			file.Close()
			if rerr != nil || len(content) == 0 {
				continue
			}
			if len(content) > 10<<20 {
				dgsBad(w, fmt.Sprintf("foto %d melebihi 10MB", i))
				return
			}
			ext := strings.ToLower(filepath.Ext(hdr.Filename))
			ct := http.DetectContentType(content)
			if !(ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".webp" || ext == ".gif") || !strings.HasPrefix(ct, "image/") {
				dgsBad(w, fmt.Sprintf("foto %d harus berupa gambar (jpg/png/webp/gif)", i))
				return
			}
			if client == nil {
				if client, err = dropbox.NewClientFromEnv(); err != nil {
					dgsFail(w, "5000005", "dropbox belum dikonfigurasi")
					return
				}
			}
			now := time.Now()
			path := fmt.Sprintf("/uploads/dgs-retur/%s/%04d%02d/%s_%d_%s", sanitizeModule(inv), now.Year(), int(now.Month()),
				randomHex(4), i, sanitizeFilename(hdr.Filename))
			if _, err := client.Upload(path, content); err != nil {
				dgsFail(w, "5000005", fmt.Sprintf("gagal upload foto %d: %v", i, err))
				return
			}
			imgs[i-1] = path
			uploaded++
		}

		if _, err := database.RbcaInstance.ExecContext(ctx, `
			EXEC pos_server.dbo.xsp_get_ar_confirmation_retur_approve_update
				@p_invoice=@inv, @p_plu=@plu, @p_tanggal_kembali=@tgl, @p_kategori_barang_kembali=@kat, @p_keterangan_gudang=@ket`,
			sql.Named("inv", inv), sql.Named("plu", plu), sql.Named("tgl", tgl), sql.Named("kat", kategori), sql.Named("ket", ket)); err != nil {
			dgsSQLErr(w, "retur confirm", err)
			return
		}
		if _, err := database.RbcaInstance.ExecContext(ctx, `
			EXEC pos_server.dbo.xsp_get_ar_confirmation_retur_upload_image_update
				@p_invoice=@inv, @p_plu=@plu, @p_image1=@i1, @p_image2=@i2, @p_image3=@i3, @p_image4=@i4, @p_image5=@i5`,
			sql.Named("inv", inv), sql.Named("plu", plu),
			sql.Named("i1", imgs[0]), sql.Named("i2", imgs[1]), sql.Named("i3", imgs[2]), sql.Named("i4", imgs[3]), sql.Named("i5", imgs[4])); err != nil {
			dgsSQLErr(w, "retur images", err)
			return
		}
		dgsAudit(r, nik, "RETUR_CONFIRM", inv+"|"+plu, map[string]interface{}{"invoice": inv, "plu": plu, "kategori": kategori, "tgl": tgl.Format("2006-01-02"), "ket": ket, "images_uploaded": uploaded})
		dgsOK(w, map[string]interface{}{"kategori": kategori, "images_uploaded": uploaded}, nil)
	})
}
