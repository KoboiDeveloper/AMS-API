package controllers

// DigitalSales (/dgs) — marketplace AR & prasales, parity with legacy
// module/MARKETPLACE (Ar_List, Confirm_sales popup, Ar_Realisasi, komisi_Setting).
// Every endpoint is guarded by requireDigitalSales (role DIGITAL_SALES / SUPERADMIN)
// and every write is recorded in RBACESS.dbo.RBAC_DS_ActionLog.

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"GOamsAPI/database"

	mssql "github.com/denisenkom/go-mssqldb"
	"github.com/gorilla/mux"
)

const (
	dgsRoleCode    = "DIGITAL_SALES"
	dgsQueryTO     = 60 * time.Second
	dgsDashTTL     = 60 * time.Second
	dgsPageSizeMax = 200
)

// ───────────────────────── guard / helpers ─────────────────────────

type dgsRoleEntry struct {
	ok bool
	at time.Time
}

var dgsRoleCache sync.Map // nik(upper) → dgsRoleEntry

func dgsHasAccess(ctx context.Context, nik string) bool {
	nik = strings.ToUpper(strings.TrimSpace(nik))
	if nik == "" {
		return false
	}
	if v, ok := dgsRoleCache.Load(nik); ok {
		e := v.(dgsRoleEntry)
		if time.Since(e.at) < 30*time.Second {
			return e.ok
		}
	}
	var n int
	err := database.RbcaInstance.QueryRowContext(ctx, `
		SELECT COUNT(1)
		FROM dbo.RBAC_UserRole ur
		INNER JOIN dbo.RBAC_Role r ON r.role_id = ur.role_id
		WHERE UPPER(ur.nik) = @nik AND ur.is_active = 1 AND r.is_active = 1
		  AND r.role_code IN ('DIGITAL_SALES','SUPERADMIN')`,
		sql.Named("nik", nik)).Scan(&n)
	ok := err == nil && n > 0
	if err != nil {
		log.Printf("dgs role check error: %v", err)
	}
	dgsRoleCache.Store(nik, dgsRoleEntry{ok: ok, at: time.Now()})
	return ok
}

// requireDigitalSales wraps a handler: JWT nik must hold DIGITAL_SALES / SUPERADMIN.
func requireDigitalSales(h func(w http.ResponseWriter, r *http.Request, nik string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		nik := strings.TrimSpace(rbcaNikFromJWT(r))
		ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
		defer cancel()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		if !dgsHasAccess(ctx, nik) {
			writeRbcaJSON(w, rbcaErrorJSON("4032500", "akses ditolak: khusus akun Digital Sales"))
			return
		}
		h(w, r, nik)
	}
}

func dgsOK(w http.ResponseWriter, data interface{}, extra map[string]interface{}) {
	m := map[string]interface{}{"responseCode": "2002500", "responseMessage": "Success"}
	if data != nil {
		m["data"] = data
	}
	for k, v := range extra {
		m[k] = v
	}
	writeRbcaJSON(w, marshalRbcaJSON(m))
}

func dgsFail(w http.ResponseWriter, code, msg string) {
	writeRbcaJSON(w, rbcaErrorJSON(code, msg))
}

func dgsBad(w http.ResponseWriter, msg string) { dgsFail(w, "4002500", msg) }

func dgsSQLErr(w http.ResponseWriter, what string, err error) {
	var me mssql.Error
	if errors.As(err, &me) && me.Class >= 11 && me.Class <= 16 {
		dgsFail(w, "4002500", strings.TrimSpace(me.Message))
		return
	}
	log.Printf("dgs %s: %v", what, err)
	dgsFail(w, "5000005", "gagal memproses: "+err.Error())
}

func dgsNormVal(v interface{}) interface{} {
	switch t := v.(type) {
	case []byte:
		return string(t)
	case time.Time:
		if t.Hour() == 0 && t.Minute() == 0 && t.Second() == 0 && t.Nanosecond() == 0 {
			return t.Format("2006-01-02")
		}
		return t.Format("2006-01-02 15:04:05")
	default:
		return v
	}
}

func dgsScanRows(rows *sql.Rows) ([]map[string]interface{}, error) {
	cols, err := rows.Columns()
	if err != nil {
		return nil, err
	}
	out := make([]map[string]interface{}, 0, 64)
	for rows.Next() {
		vals := make([]interface{}, len(cols))
		ptrs := make([]interface{}, len(cols))
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return nil, err
		}
		m := make(map[string]interface{}, len(cols))
		for i, c := range cols {
			m[c] = dgsNormVal(vals[i])
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func dgsQuery(ctx context.Context, q string, args ...interface{}) ([]map[string]interface{}, error) {
	c, cancel := context.WithTimeout(ctx, dgsQueryTO)
	defer cancel()
	rows, err := database.RbcaInstance.QueryContext(c, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return dgsScanRows(rows)
}

func dgsFirst(rows []map[string]interface{}) map[string]interface{} {
	if len(rows) > 0 {
		return rows[0]
	}
	return map[string]interface{}{}
}

func dgsAudit(r *http.Request, nik, action, ref string, payload interface{}) {
	b, _ := json.Marshal(payload)
	s := string(b)
	if len(s) > 8000 {
		s = s[:8000] + "…"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_, err := database.RbcaInstance.ExecContext(ctx, `
		INSERT INTO dbo.RBAC_DS_ActionLog (nik, action, ref_key, payload, ip_address)
		VALUES (@nik, @action, @ref, @payload, @ip)`,
		sql.Named("nik", nik), sql.Named("action", action),
		sql.Named("ref", truncStr(ref, 250)), sql.Named("payload", s),
		sql.Named("ip", truncStr(clientIPAddress(r), 64)))
	if err != nil {
		log.Printf("dgs audit insert failed (%s): %v", action, err)
	}
}

func truncStr(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

func dgsDecode(r *http.Request, v interface{}) error {
	if r.Body == nil {
		return errors.New("body kosong")
	}
	dec := json.NewDecoder(r.Body)
	return dec.Decode(v)
}

func dgsYMD(s string) (string, bool) {
	t, err := time.Parse("2006-01-02", strings.TrimSpace(s))
	if err != nil {
		return "", false
	}
	return t.Format("2006-01-02"), true
}

func dgsWIB() *time.Location {
	loc, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		return time.FixedZone("WIB", 7*3600)
	}
	return loc
}

func dgsRange(r *http.Request) (string, string, error) {
	now := time.Now().In(dgsWIB())
	from, okF := dgsYMD(firstNonEmpty(r.URL.Query().Get("from_date"), r.URL.Query().Get("from")))
	to, okT := dgsYMD(firstNonEmpty(r.URL.Query().Get("to_date"), r.URL.Query().Get("to")))
	if !okT {
		to = now.Format("2006-01-02")
	}
	if !okF {
		t, _ := time.Parse("2006-01-02", to)
		from = t.AddDate(0, 0, -29).Format("2006-01-02")
	}
	tf, _ := time.Parse("2006-01-02", from)
	tt, _ := time.Parse("2006-01-02", to)
	if tt.Before(tf) {
		return "", "", errors.New("tanggal akhir lebih kecil dari tanggal awal")
	}
	if tt.Sub(tf) > 800*24*time.Hour {
		return "", "", errors.New("rentang tanggal maksimal ±2 tahun")
	}
	return from, to, nil
}

func dgsMP(r *http.Request) string {
	mp := strings.TrimSpace(r.URL.Query().Get("marketplace"))
	if strings.EqualFold(mp, "ALL") || mp == "0" {
		return ""
	}
	return mp
}

func dgsInt(s string, def, min, max int) int {
	n, err := strconv.Atoi(strings.TrimSpace(s))
	if err != nil {
		return def
	}
	if n < min {
		return min
	}
	if n > max {
		return max
	}
	return n
}

var dgsTagRe = regexp.MustCompile(`<[^>]*>`)

// ───────────────────────── dashboard ─────────────────────────

const dgsHdrFilter = `h.TANGGAL_TRANSAKSI BETWEEN CAST(@f AS date) AND CAST(@t AS date) AND (@mp = '' OR h.NAMA_MP = @mp)`

func dgsStatusAgg(prefix string) string {
	return fmt.Sprintf(`
		COUNT(*) AS %[1]stotal,
		SUM(CASE WHEN h.STATUS_TRANSAKSI = '0' THEN 1 ELSE 0 END) AS %[1]spending,
		SUM(CASE WHEN h.STATUS_TRANSAKSI = '1' THEN 1 ELSE 0 END) AS %[1]sapproved,
		SUM(CASE WHEN h.STATUS_TRANSAKSI = '2' THEN 1 ELSE 0 END) AS %[1]srejected,
		CAST(SUM(ISNULL(h.GRAND_TOTAL,0)) AS float) AS %[1]svalue`, prefix)
}

type dgsDashJob struct {
	key string
	sql string
}

func dgsDashJobs() []dgsDashJob {
	hdr := "FROM pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK)"
	arJoin := `FROM pos_server.dbo.MARKETPLACE_AR a WITH (NOLOCK)
		INNER JOIN pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK) ON h.ID_TR_SALES_HEADER = a.ID_TR_SALES_HEADER`
	return []dgsDashJob{
		{"kpi_prasales", `SELECT ` + dgsStatusAgg("") + `,
			CAST(SUM(CASE WHEN h.STATUS_TRANSAKSI = '0' THEN ISNULL(h.GRAND_TOTAL,0) ELSE 0 END) AS float) AS pending_value,
			CAST(SUM(CASE WHEN h.STATUS_TRANSAKSI = '1' THEN ISNULL(h.GRAND_TOTAL,0) ELSE 0 END) AS float) AS approved_value,
			CAST(SUM(CASE WHEN h.STATUS_TRANSAKSI = '2' THEN ISNULL(h.GRAND_TOTAL,0) ELSE 0 END) AS float) AS rejected_value,
			CAST(SUM(ISNULL(h.GRAND_TOTAL_MP,0)) AS float) AS value_mp
			` + hdr + ` WHERE ` + dgsHdrFilter},
		{"kpi_ar", `SELECT COUNT(*) AS ar_total,
			SUM(CASE WHEN a.TGL_SAMPAI IS NULL THEN 1 ELSE 0 END) AS in_transit,
			CAST(SUM(CASE WHEN a.TGL_SAMPAI IS NULL THEN ISNULL(h.GRAND_TOTAL,0) ELSE 0 END) AS float) AS in_transit_value,
			SUM(CASE WHEN a.TGL_SAMPAI IS NOT NULL AND a.TGL_REALISASI IS NULL THEN 1 ELSE 0 END) AS unpaid,
			CAST(SUM(CASE WHEN a.TGL_SAMPAI IS NOT NULL AND a.TGL_REALISASI IS NULL THEN ISNULL(a.TOTALAR,0) ELSE 0 END) AS float) AS unpaid_value,
			SUM(CASE WHEN a.TGL_REALISASI IS NOT NULL THEN 1 ELSE 0 END) AS paid,
			CAST(SUM(CASE WHEN a.TGL_REALISASI IS NOT NULL THEN ISNULL(a.TOTALAR,0) ELSE 0 END) AS float) AS paid_value,
			CAST(SUM(ISNULL(a.TOTALAR,0)) AS float) AS total_ar
			` + arJoin + ` WHERE ` + dgsHdrFilter},
		{"kpi_retur", `SELECT
			SUM(ISNULL(d.QTY,0)) AS sold_qty,
			SUM(CASE WHEN d.STATUS IN (2,8,9) THEN ISNULL(d.QTY,0) ELSE 0 END) AS retur_qty,
			SUM(CASE WHEN d.STATUS = 9 THEN ISNULL(d.QTY,0) ELSE 0 END) AS retur_waiting_qty,
			SUM(CASE WHEN d.STATUS = 2 THEN ISNULL(d.QTY,0) ELSE 0 END) AS retur_received_qty,
			SUM(CASE WHEN d.STATUS = 8 THEN ISNULL(d.QTY,0) ELSE 0 END) AS retur_mismatch_qty,
			CAST(SUM(CASE WHEN d.STATUS IN (2,8,9) THEN ISNULL(d.NET,0) ELSE 0 END) AS float) AS retur_value
			FROM pos_server.dbo.TR_PRASALES_DETAIL d WITH (NOLOCK)
			INNER JOIN pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK) ON h.ID_PRASALES_HEADER = d.ID_PRASALES_HEADER
			WHERE ` + dgsHdrFilter},
		{"daily", `SELECT CONVERT(varchar(10), h.TANGGAL_TRANSAKSI, 23) AS d, ` + dgsStatusAgg("") + `
			` + hdr + ` WHERE ` + dgsHdrFilter + ` GROUP BY h.TANGGAL_TRANSAKSI ORDER BY h.TANGGAL_TRANSAKSI`},
		{"by_marketplace", `SELECT h.NAMA_MP AS marketplace, ` + dgsStatusAgg("") + `,
			CAST(SUM(ISNULL(h.GRAND_TOTAL_MP,0)) AS float) AS value_mp,
			SUM(CASE WHEN h.GRAND_TOTAL_MP IS NOT NULL AND ABS(ISNULL(h.GRAND_TOTAL,0) - h.GRAND_TOTAL_MP) > 1 THEN 1 ELSE 0 END) AS mismatch_count
			` + hdr + ` WHERE ` + dgsHdrFilter + ` GROUP BY h.NAMA_MP ORDER BY SUM(ISNULL(h.GRAND_TOTAL,0)) DESC`},
		{"by_store", `SELECT TOP 20 h.ID_STORE AS store, ` + dgsStatusAgg("") + `
			` + hdr + ` WHERE ` + dgsHdrFilter + ` GROUP BY h.ID_STORE ORDER BY SUM(ISNULL(h.GRAND_TOTAL,0)) DESC`},
		{"aging_pending", `SELECT x.age_days, COUNT(*) AS c, CAST(SUM(x.gt) AS float) AS value FROM (
				SELECT DATEDIFF(day, h.TANGGAL_TRANSAKSI, CAST(GETDATE() AS date)) AS age_days, ISNULL(h.GRAND_TOTAL,0) AS gt
				` + hdr + ` WHERE h.STATUS_TRANSAKSI = '0' AND h.TANGGAL_TRANSAKSI >= DATEADD(day,-365,CAST(GETDATE() AS date))
				AND (@mp = '' OR h.NAMA_MP = @mp)) x GROUP BY x.age_days`},
		{"aging_unpaid", `SELECT x.age_days, COUNT(*) AS c, CAST(SUM(x.v) AS float) AS value FROM (
				SELECT DATEDIFF(day, a.TGL_SAMPAI, CAST(GETDATE() AS date)) AS age_days, ISNULL(a.TOTALAR,0) AS v
				` + arJoin + ` WHERE a.TGL_SAMPAI IS NOT NULL AND a.TGL_REALISASI IS NULL
				AND (@mp = '' OR h.NAMA_MP = @mp)) x GROUP BY x.age_days`},
		{"fees", `SELECT
			CAST(SUM(ISNULL(a.ONGKIR,0)) AS float) AS ongkir,
			CAST(SUM(ISNULL(a.PAYMENT_GATEWAY,0)) AS float) AS payment_gateway,
			CAST(SUM(ISNULL(a.BIAYA_LAYANAN,0)) AS float) AS biaya_layanan,
			CAST(SUM(ISNULL(a.PREMI,0)) AS float) AS premi,
			CAST(SUM(ISNULL(a.BIAYA_PROGRAM,0)) AS float) AS biaya_program,
			CAST(SUM(ISNULL(a.KOMISI_AFFILIATE,0)) AS float) AS komisi_affiliate,
			CAST(SUM(ISNULL(a.BIAYA_TRANSAKSI,0)) AS float) AS biaya_transaksi,
			CAST(SUM(ISNULL(a.BIAYA_PROSES_PESANAN,0)) AS float) AS biaya_proses_pesanan,
			CAST(SUM(ISNULL(a.KOMISI_DINAMIS,0)) AS float) AS komisi_dinamis,
			CAST(SUM(ISNULL(a.TOTALAR,0)) AS float) AS total_ar
			` + arJoin + ` WHERE ` + dgsHdrFilter},
		{"fees_detail", `SELECT
			CAST(SUM(ISNULL(d.TOTAL_SALES,0)) AS float) AS total_sales,
			CAST(SUM(ISNULL(d.KOMISI_AWAL,0)) AS float) AS komisi_awal,
			CAST(SUM(ISNULL(d.PPN,0)) AS float) AS ppn,
			CAST(SUM(ISNULL(d.PPH23,0)) AS float) AS pph23,
			CAST(SUM(ISNULL(d.TOTAL,0)) AS float) AS total
			FROM pos_server.dbo.MARKETPLACE_AR_DETAIL d WITH (NOLOCK)
			INNER JOIN pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK) ON h.ID_TR_SALES_HEADER = d.ID_TR_SALES_HEADER
			WHERE ` + dgsHdrFilter},
		{"top_articles", `SELECT TOP 10 d.PLU AS plu, MAX(CAST(d.ARTICLE AS varchar(120))) AS article,
			SUM(ISNULL(d.QTY,0)) AS qty, CAST(SUM(ISNULL(d.NET,0)) AS float) AS value,
			SUM(CASE WHEN d.STATUS IN (2,8,9) THEN ISNULL(d.QTY,0) ELSE 0 END) AS retur_qty
			FROM pos_server.dbo.TR_PRASALES_DETAIL d WITH (NOLOCK)
			INNER JOIN pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK) ON h.ID_PRASALES_HEADER = d.ID_PRASALES_HEADER
			WHERE ` + dgsHdrFilter + ` GROUP BY d.PLU ORDER BY SUM(ISNULL(d.QTY,0)) DESC`},
		{"oldest_pending", `SELECT TOP 15 h.ID_PRASALES_HEADER AS id, h.NO_INVOICE AS invoice, h.NAMA_MP AS marketplace, h.ID_STORE AS store,
			CONVERT(varchar(10), h.TANGGAL_TRANSAKSI, 23) AS tanggal, CAST(ISNULL(h.GRAND_TOTAL,0) AS float) AS total,
			DATEDIFF(day, h.TANGGAL_TRANSAKSI, CAST(GETDATE() AS date)) AS age_days
			` + hdr + ` WHERE h.STATUS_TRANSAKSI = '0' AND h.TANGGAL_TRANSAKSI >= DATEADD(day,-365,CAST(GETDATE() AS date))
			AND (@mp = '' OR h.NAMA_MP = @mp) ORDER BY h.TANGGAL_TRANSAKSI ASC, h.NO_URUT ASC`},
		{"oldest_unpaid", `SELECT TOP 15 a.NO_ORDER AS invoice, h.NAMA_MP AS marketplace, h.ID_STORE AS store,
			CONVERT(varchar(10), a.TGL_SAMPAI, 23) AS tgl_sampai, CAST(ISNULL(a.TOTALAR,0) AS float) AS total,
			DATEDIFF(day, a.TGL_SAMPAI, CAST(GETDATE() AS date)) AS age_days
			` + arJoin + ` WHERE a.TGL_SAMPAI IS NOT NULL AND a.TGL_REALISASI IS NULL
			AND (@mp = '' OR h.NAMA_MP = @mp) ORDER BY a.TGL_SAMPAI ASC`},
		{"oldest_transit", `SELECT TOP 15 a.NO_ORDER AS invoice, h.NAMA_MP AS marketplace, h.ID_STORE AS store,
			CONVERT(varchar(10), ISNULL(a.TGL_KIRIM, a.TGL_PO), 23) AS tgl_kirim, CAST(ISNULL(h.GRAND_TOTAL,0) AS float) AS total,
			DATEDIFF(day, ISNULL(a.TGL_KIRIM, a.TGL_PO), CAST(GETDATE() AS date)) AS age_days
			` + arJoin + ` WHERE a.TGL_SAMPAI IS NULL AND ISNULL(a.TGL_KIRIM, a.TGL_PO) IS NOT NULL
			AND ISNULL(a.TGL_KIRIM, a.TGL_PO) >= DATEADD(day,-365,CAST(GETDATE() AS date))
			AND (@mp = '' OR h.NAMA_MP = @mp) ORDER BY ISNULL(a.TGL_KIRIM, a.TGL_PO) ASC`},
	}
}

// DgsDashboardHandler — GET /dgs/mp/dashboard?from_date&to_date&marketplace[&refresh=1]
func DgsDashboardHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		from, to, err := dgsRange(r)
		if err != nil {
			dgsBad(w, err.Error())
			return
		}
		mp := dgsMP(r)
		cacheKey := fmt.Sprintf("dgs:dash:v1:%s:%s:%s", from, to, strings.ToUpper(mp))
		if r.URL.Query().Get("refresh") != "1" && regDashRedis != nil {
			if raw, e := regDashRedis.Get(r.Context(), cacheKey).Bytes(); e == nil && len(raw) > 0 {
				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("X-DGS-Cache", "hit")
				_, _ = w.Write(raw)
				return
			}
		}

		jobs := dgsDashJobs()
		results := make([][]map[string]interface{}, len(jobs))
		errs := make([]error, len(jobs))
		var wg sync.WaitGroup
		for i := range jobs {
			wg.Add(1)
			go func(i int) {
				defer wg.Done()
				results[i], errs[i] = dgsQuery(r.Context(), jobs[i].sql,
					sql.Named("f", from), sql.Named("t", to), sql.Named("mp", mp))
			}(i)
		}
		wg.Wait()

		data := map[string]interface{}{"from_date": from, "to_date": to, "marketplace": mp, "built_at": time.Now().In(dgsWIB()).Format("2006-01-02 15:04:05")}
		for i, j := range jobs {
			if errs[i] != nil {
				log.Printf("dgs dashboard %s: %v", j.key, errs[i])
				dgsFail(w, "5000005", fmt.Sprintf("gagal memuat dashboard (%s): %v", j.key, errs[i]))
				return
			}
			switch j.key {
			case "kpi_prasales", "kpi_ar", "kpi_retur", "fees", "fees_detail":
				data[j.key] = dgsFirst(results[i])
			default:
				data[j.key] = results[i]
			}
		}
		body := marshalRbcaJSON(map[string]interface{}{"responseCode": "2002500", "responseMessage": "Success", "data": data})
		if regDashRedis != nil {
			_ = regDashRedis.Set(r.Context(), cacheKey, []byte(body), dgsDashTTL).Err()
		}
		w.Header().Set("X-DGS-Cache", "miss")
		writeRbcaJSON(w, body)
	})
}

// ───────────────────────── prasales list / confirm ─────────────────────────

// DgsPrasalesListHandler — GET /dgs/mp/prasales (paged)
func DgsPrasalesListHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		from, to, err := dgsRange(r)
		if err != nil {
			dgsBad(w, err.Error())
			return
		}
		q := r.URL.Query()
		page := dgsInt(q.Get("page"), 1, 1, 100000)
		size := dgsInt(q.Get("page_size"), 50, 1, dgsPageSizeMax)
		status := strings.TrimSpace(q.Get("status"))
		if status != "0" && status != "1" && status != "2" {
			status = ""
		}
		store := strings.ToUpper(strings.TrimSpace(q.Get("store")))
		kw := strings.TrimSpace(q.Get("keywords"))
		rows, err := dgsQuery(r.Context(), `
			SELECT COUNT(*) OVER() AS TOTAL_ROWS,
				h.ID_PRASALES_HEADER, h.NO_INVOICE, h.NAMA_MP, h.ID_STORE,
				h.TANGGAL_TRANSAKSI, CONVERT(varchar(8), h.JAM_TRANSAKSI, 108) AS JAM_TRANSAKSI,
				CAST(ISNULL(h.GRAND_TOTAL,0) AS float) AS GRAND_TOTAL,
				CAST(h.GRAND_TOTAL_MP AS float) AS GRAND_TOTAL_MP,
				h.STATUS_TRANSAKSI, h.NO_RESI, h.TGL_KONFIRMASI, h.ID_TR_SALES_HEADER,
				h.KurirKuya AS KURIR, h.Sumber AS SUMBER,
				ISNULL(i.items,0) AS ITEMS, ISNULL(i.checked,0) AS ITEMS_CHECKED, ISNULL(i.retur,0) AS ITEMS_RETUR,
				DATEDIFF(day, h.TANGGAL_TRANSAKSI, CAST(GETDATE() AS date)) AS AGE_DAYS
			FROM pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK)
			OUTER APPLY (
				SELECT COUNT(*) AS items,
				       SUM(CASE WHEN d.STATUS <> 0 THEN 1 ELSE 0 END) AS checked,
				       SUM(CASE WHEN d.STATUS IN (2,9) THEN 1 ELSE 0 END) AS retur
				FROM pos_server.dbo.TR_PRASALES_DETAIL d WITH (NOLOCK)
				WHERE d.ID_PRASALES_HEADER = h.ID_PRASALES_HEADER
			) i
			WHERE h.TANGGAL_TRANSAKSI BETWEEN CAST(@f AS date) AND CAST(@t AS date)
			  AND (@mp = '' OR h.NAMA_MP = @mp)
			  AND (@status = '' OR h.STATUS_TRANSAKSI = @status)
			  AND (@store = '' OR h.ID_STORE = @store)
			  AND (@kw = '' OR h.NO_INVOICE LIKE '%' + @kw + '%' OR h.NO_RESI LIKE '%' + @kw + '%')
			ORDER BY h.TANGGAL_TRANSAKSI DESC, h.NO_URUT DESC
			OFFSET @off ROWS FETCH NEXT @n ROWS ONLY`,
			sql.Named("f", from), sql.Named("t", to), sql.Named("mp", dgsMP(r)),
			sql.Named("status", status), sql.Named("store", store), sql.Named("kw", kw),
			sql.Named("off", (page-1)*size), sql.Named("n", size))
		if err != nil {
			dgsSQLErr(w, "prasales list", err)
			return
		}
		total := 0
		if len(rows) > 0 {
			if n, ok := rows[0]["TOTAL_ROWS"].(int64); ok {
				total = int(n)
			}
		}
		dgsOK(w, rows, map[string]interface{}{"total": total, "page": page, "page_size": size})
	})
}

func dgsPrasalesItems(ctx context.Context, id string) (map[string]interface{}, []map[string]interface{}, error) {
	infoRows, err := dgsQuery(ctx, `EXEC pos_server.dbo.xsp_get_ar_proses_info_button_getrow @p_id_prasales = @id`, sql.Named("id", id))
	if err != nil {
		return nil, nil, err
	}
	items, err := dgsQuery(ctx, `EXEC pos_server.dbo.xsp_get_ar_confirmation_getrows @p_id_prasales = @id`, sql.Named("id", id))
	if err != nil {
		return nil, nil, err
	}
	for _, it := range items {
		if s, ok := it["KETERANGAN_ADMIN"].(string); ok {
			it["KETERANGAN_ADMIN"] = strings.TrimSpace(dgsTagRe.ReplaceAllString(s, ""))
		}
	}
	return dgsFirst(infoRows), items, nil
}

// DgsPrasalesItemsHandler — GET /dgs/mp/prasales/{id}/items
func DgsPrasalesItemsHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		id := strings.TrimSpace(mux.Vars(r)["id"])
		if id == "" {
			dgsBad(w, "id prasales wajib")
			return
		}
		info, items, err := dgsPrasalesItems(r.Context(), id)
		if err != nil {
			dgsSQLErr(w, "prasales items", err)
			return
		}
		hdr, _ := dgsQuery(r.Context(), `
			SELECT h.ID_PRASALES_HEADER, h.NO_INVOICE, h.NAMA_MP, h.ID_STORE, h.TANGGAL_TRANSAKSI, h.STATUS_TRANSAKSI,
			       CAST(ISNULL(h.GRAND_TOTAL,0) AS float) AS GRAND_TOTAL, h.NO_RESI, h.ID_TR_SALES_HEADER
			FROM pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK) WHERE h.ID_PRASALES_HEADER = @id`, sql.Named("id", id))
		dgsOK(w, map[string]interface{}{"header": dgsFirst(hdr), "info": info, "items": items}, nil)
	})
}

type dgsItemActionReq struct {
	Action     string  `json:"action"` // approve | retur
	IDs        []int64 `json:"ids"`    // TR_PRASALES_DETAIL.NO_URUT
	Keterangan string  `json:"keterangan"`
}

// DgsPrasalesItemActionHandler — POST /dgs/mp/prasales/items/action
// Parity Confirm_sales popup: Approve (xsp_get_ar_confirmation_approve_update) /
// Retur (xsp_get_ar_confirmation_retur_update). Only items whose header is still NEW (status 0).
func DgsPrasalesItemActionHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		var req dgsItemActionReq
		if err := dgsDecode(r, &req); err != nil {
			dgsBad(w, "payload tidak valid")
			return
		}
		req.Action = strings.ToLower(strings.TrimSpace(req.Action))
		req.Keterangan = strings.TrimSpace(req.Keterangan)
		if req.Action != "approve" && req.Action != "retur" {
			dgsBad(w, "action harus approve atau retur")
			return
		}
		if len(req.IDs) == 0 || len(req.IDs) > 500 {
			dgsBad(w, "pilih minimal 1 item (maks 500)")
			return
		}
		if req.Action == "retur" {
			if req.Keterangan == "" {
				dgsBad(w, "keterangan retur wajib diisi")
				return
			}
			if len(req.Keterangan) > 100 {
				dgsBad(w, "keterangan retur maksimal 100 karakter")
				return
			}
		}
		ctx, cancel := context.WithTimeout(r.Context(), dgsQueryTO)
		defer cancel()
		tx, err := database.RbcaInstance.BeginTx(ctx, nil)
		if err != nil {
			dgsSQLErr(w, "item action begin", err)
			return
		}
		defer tx.Rollback()
		done, skipped := 0, 0
		for _, id := range req.IDs {
			var st sql.NullString
			e := tx.QueryRowContext(ctx, `
				SELECT h.STATUS_TRANSAKSI
				FROM pos_server.dbo.TR_PRASALES_DETAIL d WITH (UPDLOCK)
				INNER JOIN pos_server.dbo.TR_PRASALES_HEADER h ON h.ID_PRASALES_HEADER = d.ID_PRASALES_HEADER
				WHERE d.NO_URUT = @id`, sql.Named("id", id)).Scan(&st)
			if e != nil || !st.Valid || st.String != "0" {
				skipped++
				continue
			}
			if req.Action == "approve" {
				_, e = tx.ExecContext(ctx, `EXEC pos_server.dbo.xsp_get_ar_confirmation_approve_update @p_id = @id`, sql.Named("id", id))
			} else {
				_, e = tx.ExecContext(ctx, `EXEC pos_server.dbo.xsp_get_ar_confirmation_retur_update @p_id = @id, @p_keterangan_retur = @ket`,
					sql.Named("id", id), sql.Named("ket", req.Keterangan))
			}
			if e != nil {
				dgsSQLErr(w, "item action", e)
				return
			}
			done++
		}
		if err := tx.Commit(); err != nil {
			dgsSQLErr(w, "item action commit", err)
			return
		}
		dgsAudit(r, nik, "PRASALES_ITEM_"+strings.ToUpper(req.Action), fmt.Sprint(req.IDs), map[string]interface{}{"ids": req.IDs, "ket": req.Keterangan, "done": done, "skipped": skipped})
		dgsOK(w, map[string]interface{}{"done": done, "skipped": skipped}, nil)
	})
}

type dgsProsesReq struct {
	IDPrasales string `json:"id_prasales_header"`
}

// DgsPrasalesProsesHandler — POST /dgs/mp/prasales/proses
// Parity Confirm_sales "PROSES" (xsp_confirm_sales_popup_inject): creates TR_SALES + MARKETPLACE_AR rows.
func DgsPrasalesProsesHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		var req dgsProsesReq
		if err := dgsDecode(r, &req); err != nil || strings.TrimSpace(req.IDPrasales) == "" {
			dgsBad(w, "id_prasales_header wajib")
			return
		}
		id := strings.TrimSpace(req.IDPrasales)
		ctx, cancel := context.WithTimeout(r.Context(), 90*time.Second)
		defer cancel()
		var invoice string
		var status string
		err := database.RbcaInstance.QueryRowContext(ctx, `
			SELECT NO_INVOICE, STATUS_TRANSAKSI FROM pos_server.dbo.TR_PRASALES_HEADER WITH (NOLOCK)
			WHERE ID_PRASALES_HEADER = @id`, sql.Named("id", id)).Scan(&invoice, &status)
		if err == sql.ErrNoRows {
			dgsFail(w, "4042500", "prasales tidak ditemukan")
			return
		}
		if err != nil {
			dgsSQLErr(w, "proses lookup", err)
			return
		}
		if status != "0" {
			dgsBad(w, "transaksi ini sudah diproses (status bukan NEW)")
			return
		}
		info, _, err := dgsPrasalesItems(ctx, id)
		if err != nil {
			dgsSQLErr(w, "proses info", err)
			return
		}
		toInt := func(v interface{}) int64 {
			switch t := v.(type) {
			case int64:
				return t
			case int32:
				return int64(t)
			case float64:
				return int64(t)
			}
			return 0
		}
		if toInt(info["total_row"]) == 0 || toInt(info["total_row"]) != toInt(info["total_checked"]) {
			dgsBad(w, "semua item harus di-approve atau diretur sebelum PROSES")
			return
		}
		if _, err := database.RbcaInstance.ExecContext(ctx,
			`EXEC pos_server.dbo.xsp_confirm_sales_popup_inject @p_id_prasales_header = @id, @p_invoice = @inv`,
			sql.Named("id", id), sql.Named("inv", invoice)); err != nil {
			dgsSQLErr(w, "proses inject", err)
			return
		}
		dgsAudit(r, nik, "PRASALES_PROSES", invoice, map[string]interface{}{"id_prasales_header": id, "invoice": invoice})
		dgsOK(w, map[string]interface{}{"invoice": invoice}, nil)
	})
}

// ───────────────────────── AR realisasi ─────────────────────────

type dgsRealisasiReq struct {
	Invoice      string `json:"invoice"`
	TglRealisasi string `json:"tgl_realisasi"`
}

// DgsArRealisasiSaveHandler — POST /dgs/mp/ar-realisasi/save
// Parity Ar_Realisasi (xsp_ar_realisasi_uang_masuk_update).
func DgsArRealisasiSaveHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		var req dgsRealisasiReq
		if err := dgsDecode(r, &req); err != nil {
			dgsBad(w, "payload tidak valid")
			return
		}
		req.Invoice = strings.TrimSpace(req.Invoice)
		ymd, ok := dgsYMD(req.TglRealisasi)
		if req.Invoice == "" || !ok {
			dgsBad(w, "invoice dan tgl realisasi (YYYY-MM-DD) wajib")
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), dgsQueryTO)
		defer cancel()
		var n int
		if err := database.RbcaInstance.QueryRowContext(ctx,
			`SELECT COUNT(*) FROM pos_server.dbo.MARKETPLACE_AR WITH (NOLOCK) WHERE NO_ORDER = @inv`,
			sql.Named("inv", req.Invoice)).Scan(&n); err != nil {
			dgsSQLErr(w, "realisasi lookup", err)
			return
		}
		if n == 0 {
			dgsFail(w, "4042500", "invoice tidak ditemukan di AR")
			return
		}
		t, _ := time.Parse("2006-01-02", ymd)
		if _, err := database.RbcaInstance.ExecContext(ctx,
			`EXEC pos_server.dbo.xsp_ar_realisasi_uang_masuk_update @p_tgl_realisasi = @tgl, @p_invoice = @inv`,
			sql.Named("tgl", t), sql.Named("inv", req.Invoice)); err != nil {
			dgsSQLErr(w, "realisasi update", err)
			return
		}
		dgsAudit(r, nik, "AR_REALISASI_SAVE", req.Invoice, req)
		dgsOK(w, map[string]interface{}{"invoice": req.Invoice, "tgl_realisasi": ymd, "affected": n}, nil)
	})
}

// ───────────────────────── Setting komisi ─────────────────────────

// DgsMarketplacesHandler — GET /dgs/mp/marketplaces
func DgsMarketplacesHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		rows, err := dgsQuery(r.Context(), `
			SELECT MARKETPLACE FROM (
				SELECT UPPER(LTRIM(RTRIM(MARKETPLACE))) AS MARKETPLACE FROM pos_server.dbo.WEB_MASTER_MARKETPLACE WITH (NOLOCK)
				UNION
				SELECT UPPER(LTRIM(RTRIM(MP_NAME))) FROM pos_server.dbo.MARKETPLACE_COMMISSION WITH (NOLOCK)
			) x WHERE MARKETPLACE IS NOT NULL AND MARKETPLACE <> '' AND MARKETPLACE NOT IN ('ALL','PILIH') ORDER BY MARKETPLACE`)
		if err != nil {
			dgsSQLErr(w, "marketplaces", err)
			return
		}
		dgsOK(w, rows, nil)
	})
}

// DgsKomisiInfoHandler — GET /dgs/mp/komisi/info (komisi terbaru per marketplace)
func DgsKomisiInfoHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		rows, err := dgsQuery(r.Context(), `EXEC pos_server.dbo.XSP_GET_INFO_KOMISI_GETROW`)
		if err != nil {
			dgsSQLErr(w, "komisi info", err)
			return
		}
		dgsOK(w, dgsFirst(rows), nil)
	})
}

// DgsKomisiListHandler — GET /dgs/mp/komisi?marketplace=
func DgsKomisiListHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		mp := dgsMP(r)
		if mp == "" {
			mp = "ALL"
		}
		rows, err := dgsQuery(r.Context(), `EXEC pos_server.dbo.xsp_marketplace_commission_getrows @p_marketplace = @mp`, sql.Named("mp", mp))
		if err != nil {
			dgsSQLErr(w, "komisi list", err)
			return
		}
		dgsOK(w, rows, nil)
	})
}

type dgsKomisiReq struct {
	MpName string  `json:"mp_name"`
	Komisi float64 `json:"komisi"`
}

func dgsKomisiValid(k float64) bool { return k >= 0 && k <= 100 }

// DgsKomisiCreateHandler — POST /dgs/mp/komisi
func DgsKomisiCreateHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		var req dgsKomisiReq
		if err := dgsDecode(r, &req); err != nil {
			dgsBad(w, "payload tidak valid")
			return
		}
		req.MpName = strings.ToUpper(strings.TrimSpace(req.MpName))
		if req.MpName == "" || !dgsKomisiValid(req.Komisi) {
			dgsBad(w, "marketplace wajib dan komisi harus 0–100")
			return
		}
		if _, err := database.RbcaInstance.ExecContext(r.Context(),
			`EXEC pos_server.dbo.xsp_marketplace_commission_insert @p_mp_name = @mp, @p_komisi = @k`,
			sql.Named("mp", req.MpName), sql.Named("k", req.Komisi)); err != nil {
			dgsSQLErr(w, "komisi insert", err)
			return
		}
		dgsAudit(r, nik, "KOMISI_CREATE", req.MpName, req)
		dgsOK(w, nil, nil)
	})
}

// DgsKomisiUpdateHandler — PUT /dgs/mp/komisi/{id}
func DgsKomisiUpdateHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		id, err := strconv.Atoi(mux.Vars(r)["id"])
		var req dgsKomisiReq
		if err != nil || dgsDecode(r, &req) != nil || !dgsKomisiValid(req.Komisi) {
			dgsBad(w, "id valid dan komisi 0–100 wajib")
			return
		}
		if _, err := database.RbcaInstance.ExecContext(r.Context(),
			`EXEC pos_server.dbo.xsp_marketplace_commission_update @p_id = @id, @p_komisi = @k`,
			sql.Named("id", id), sql.Named("k", req.Komisi)); err != nil {
			dgsSQLErr(w, "komisi update", err)
			return
		}
		dgsAudit(r, nik, "KOMISI_UPDATE", strconv.Itoa(id), req)
		dgsOK(w, nil, nil)
	})
}

type dgsKomisiDeleteReq struct {
	IDs []int `json:"ids"`
}

// DgsKomisiDeleteHandler — POST /dgs/mp/komisi/delete (bulk, body {ids:[...]})
func DgsKomisiDeleteHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		var req dgsKomisiDeleteReq
		if err := dgsDecode(r, &req); err != nil || len(req.IDs) == 0 || len(req.IDs) > 200 {
			dgsBad(w, "pilih 1–200 baris untuk dihapus")
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), dgsQueryTO)
		defer cancel()
		tx, err := database.RbcaInstance.BeginTx(ctx, nil)
		if err != nil {
			dgsSQLErr(w, "komisi delete begin", err)
			return
		}
		defer tx.Rollback()
		for _, id := range req.IDs {
			if _, err := tx.ExecContext(ctx, `EXEC pos_server.dbo.xsp_marketplace_commission_delete @p_id = @id`, sql.Named("id", id)); err != nil {
				dgsSQLErr(w, "komisi delete", err)
				return
			}
		}
		if err := tx.Commit(); err != nil {
			dgsSQLErr(w, "komisi delete commit", err)
			return
		}
		dgsAudit(r, nik, "KOMISI_DELETE", fmt.Sprint(req.IDs), req)
		dgsOK(w, map[string]interface{}{"deleted": len(req.IDs)}, nil)
	})
}

// RegisterDigitalSalesRoutes mounts /dgs/mp/* on an authenticated (JWT) subrouter.
func RegisterDigitalSalesRoutes(r *mux.Router) {
	r.HandleFunc("/dgs/mp/dashboard", DgsDashboardHandler()).Methods("GET")
	r.HandleFunc("/dgs/mp/marketplaces", DgsMarketplacesHandler()).Methods("GET")
	r.HandleFunc("/dgs/mp/analisa-barang", DgsProductAnalysisHandler()).Methods("GET")
	r.HandleFunc("/dgs/mp/prasales", DgsPrasalesListHandler()).Methods("GET")
	r.HandleFunc("/dgs/mp/prasales/items/action", DgsPrasalesItemActionHandler()).Methods("POST")
	r.HandleFunc("/dgs/mp/prasales/proses", DgsPrasalesProsesHandler()).Methods("POST")
	r.HandleFunc("/dgs/mp/prasales/{id}/items", DgsPrasalesItemsHandler()).Methods("GET")
	r.HandleFunc("/dgs/mp/ar/{id}", DgsArGetHandler()).Methods("GET")
	r.HandleFunc("/dgs/mp/ar/save", DgsArSaveHandler()).Methods("POST")
	r.HandleFunc("/dgs/mp/ar/template", DgsArTemplateHandler()).Methods("POST")
	r.HandleFunc("/dgs/mp/ar/upload", DgsArUploadHandler()).Methods("POST")
	r.HandleFunc("/dgs/mp/ar-realisasi/save", DgsArRealisasiSaveHandler()).Methods("POST")
	r.HandleFunc("/dgs/mp/komisi/info", DgsKomisiInfoHandler()).Methods("GET")
	r.HandleFunc("/dgs/mp/komisi/delete", DgsKomisiDeleteHandler()).Methods("POST")
	r.HandleFunc("/dgs/mp/komisi", DgsKomisiListHandler()).Methods("GET")
	r.HandleFunc("/dgs/mp/komisi", DgsKomisiCreateHandler()).Methods("POST")
	r.HandleFunc("/dgs/mp/komisi/{id}", DgsKomisiUpdateHandler()).Methods("PUT")
	r.HandleFunc("/dgs/mp/retur/item", DgsReturGetHandler()).Methods("GET")
	r.HandleFunc("/dgs/mp/retur/image-link", DgsReturImageLinkHandler()).Methods("GET")
	r.HandleFunc("/dgs/mp/retur/confirm", DgsReturConfirmHandler()).Methods("POST")
}
