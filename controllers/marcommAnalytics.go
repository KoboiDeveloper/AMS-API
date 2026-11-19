package controllers

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"math"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/mux"
)

// Analisa Member (marcomm) — GET /marcomm/analytics/member/{section}
//
// Semua angka dihitung ulang dari stored procedure xsp_marcomm_analytics_* (hanya SELECT,
// lihat sql/marcomm/03_member_analytics.sql). Kalimat kesimpulan tidak ditulis mati: tiap
// kalimat dibentuk dari ranking brand pada data yang baru dihitung.
//
// Dua jenis bagian:
//   - periode  : memakai transaksi from_date s.d. to_date (overview, crossbrand, brandhome, voucher, profile, category);
//     trend memperlebar awal periode supaya minimal 16 bulan terlihat.
//   - riwayat  : memakai seluruh riwayat sampai to_date, karena status member (segmen, recency, tier)
//     tidak bisa dibaca dari potongan periode pendek (retention, segment, birthday, tier, quality).

const (
	maTotalBrand    = "SEMUA BRAND"
	maNoTxBrand     = "TANPA TRANSAKSI"
	maMinSample     = 30 // brand dengan sampel di bawah ini tidak diperingkat
	maCacheTTL      = 10 * time.Minute
	maLifecycleFrom = "2000-01-01"
	maDateLayout    = "2006-01-02"
	maTrendMonths   = 15 // bulan penuh sebelum bulan to_date yang selalu ikut di tren
)

type maRow = map[string]interface{}

type maInsight struct {
	Tone  string `json:"tone"` // good | warn | info
	Title string `json:"title"`
	Text  string `json:"text"`
}

// kolom teks: tidak dikonversi ke angka
var maTextKeys = map[string]bool{
	"brand": true, "brand_a": true, "brand_b": true, "brand_dominan": true, "brand_pertama": true, "brand_utama": true,
	"kategori": true, "jenis": true, "kode": true, "contoh": true, "bulan": true, "segmen": true,
	"dimensi": true, "kelompok": true, "tier_name": true, "first_tgl": true, "last_tgl": true,
	"last_ts": true, "nama": true, "email": true, "no_telpon": true, "id_member": true,
	"id_member_apps": true, "brand_register": true, "jenis_kelamin": true,
}

// ---------------------------------------------------------------------------
// angka dan format
// ---------------------------------------------------------------------------

func maF(row maRow, key string) float64 {
	switch v := row[key].(type) {
	case nil:
		return 0
	case float64:
		return v
	case float32:
		return float64(v)
	case int64:
		return float64(v)
	case int32:
		return float64(v)
	case int:
		return float64(v)
	case bool:
		if v {
			return 1
		}
		return 0
	case string:
		f, _ := strconv.ParseFloat(strings.TrimSpace(v), 64)
		return f
	case []byte:
		f, _ := strconv.ParseFloat(strings.TrimSpace(string(v)), 64)
		return f
	}
	return 0
}

func maS(row maRow, key string) string {
	v, ok := row[key]
	if !ok || v == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(v))
}

func maCopy(row maRow) maRow {
	out := make(maRow, len(row)+8)
	for k, v := range row {
		out[k] = v
	}
	return out
}

func maDiv(a, b float64) float64 {
	if b == 0 {
		return 0
	}
	return a / b
}

func maPctOf(a, b float64) float64 { return maDiv(a, b) * 100 }

// maDelta: perubahan persen cur terhadap prev; nil bila pembanding kosong.
func maDelta(cur, prev float64) interface{} {
	if prev <= 0 {
		return nil
	}
	return (cur - prev) / prev * 100
}

func maGroup(s string) string {
	neg := strings.HasPrefix(s, "-")
	s = strings.TrimPrefix(s, "-")
	var b strings.Builder
	for i, c := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			b.WriteByte('.')
		}
		b.WriteRune(c)
	}
	if neg {
		return "-" + b.String()
	}
	return b.String()
}

func maInt(v float64) string { return maGroup(strconv.FormatFloat(math.Round(v), 'f', 0, 64)) }

func maDec(v float64, prec int) string {
	return strings.Replace(strconv.FormatFloat(v, 'f', prec, 64), ".", ",", 1)
}

func maPct(v float64) string { return maDec(v, 1) + "%" }

func maSigned(v float64) string {
	if v > 0 {
		return "+" + maDec(v, 1) + "%"
	}
	return maDec(v, 1) + "%"
}

func maRp(v float64) string {
	a := math.Abs(v)
	switch {
	case a >= 1e12:
		return "Rp" + maDec(v/1e12, 2) + " triliun"
	case a >= 1e9:
		return "Rp" + maDec(v/1e9, 2) + " miliar"
	case a >= 1e6:
		return "Rp" + maDec(v/1e6, 2) + " juta"
	case a >= 1e3:
		return "Rp" + maDec(v/1e3, 0) + " ribu"
	}
	return "Rp" + maInt(v)
}

func maMult(v float64) string { return maDec(v, 1) + " kali" }

var maMonthID = []string{"", "Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"}

func maDateLabel(t time.Time) string {
	return fmt.Sprintf("%d %s %d", t.Day(), maMonthID[int(t.Month())], t.Year())
}

func maMonthLabel(ym string) string {
	t, err := time.Parse("2006-01", ym)
	if err != nil {
		return ym
	}
	return fmt.Sprintf("%s %d", maMonthID[int(t.Month())], t.Year())
}

func maCap(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	return strings.ToUpper(string(r[0])) + string(r[1:])
}

// ---------------------------------------------------------------------------
// aturan kalimat: ranking brand
// ---------------------------------------------------------------------------

type maBV struct {
	Brand string
	Val   float64
	N     float64 // ukuran sampel (member / voucher) di balik nilai ini
}

type maRankOpt struct {
	Focus  string
	AbsTol float64  // selisih yang dianggap "sama" (mis. 2 poin persen); 0 = selisih relatif 5%
	All    *float64 // nilai gabungan semua brand, opsional
	Unit   string   // satuan sampel, default "member"
}

// maRank membentuk kalimat perbandingan brand untuk satu metrik.
// Pengaman: brand bersampel kecil tidak diperingkat; selisih tipis tidak disebut tertinggi/terendah.
func maRank(label string, items []maBV, f func(float64) string, o maRankOpt) string {
	unit := o.Unit
	if unit == "" {
		unit = "member"
	}
	var ok, small []maBV
	for _, it := range items {
		if it.Brand == "" || it.Brand == maTotalBrand || it.Brand == maNoTxBrand {
			continue
		}
		if it.N >= maMinSample {
			ok = append(ok, it)
		} else {
			small = append(small, it)
		}
	}
	sort.SliceStable(ok, func(i, j int) bool { return ok[i].Val > ok[j].Val })

	var sb strings.Builder
	if o.Focus != "" {
		found := false
		for i, it := range ok {
			if it.Brand == o.Focus {
				fmt.Fprintf(&sb, "%s: %s, peringkat %d dari %d brand. ", o.Focus, f(it.Val), i+1, len(ok))
				found = true
				break
			}
		}
		if !found {
			for _, it := range small {
				if it.Brand == o.Focus {
					fmt.Fprintf(&sb, "%s belum diperingkat karena baru %s %s. ", o.Focus, maInt(it.N), unit)
					found = true
					break
				}
			}
		}
		if !found {
			fmt.Fprintf(&sb, "%s tidak punya data untuk %s. ", o.Focus, label)
		}
	}

	switch len(ok) {
	case 0:
		fmt.Fprintf(&sb, "Belum ada brand dengan cukup data (minimal %d %s) untuk membandingkan %s.", maMinSample, unit, label)
	case 1:
		fmt.Fprintf(&sb, "Hanya %s yang punya cukup data untuk %s (%s).", ok[0].Brand, label, f(ok[0].Val))
	default:
		top, bot := ok[0], ok[len(ok)-1]
		diff := top.Val - bot.Val
		same := false
		if o.AbsTol > 0 {
			same = diff < o.AbsTol
		} else {
			den := math.Max(math.Abs(top.Val), math.Abs(bot.Val))
			same = den == 0 || diff/den < 0.05
		}
		if same {
			fmt.Fprintf(&sb, "Semua brand relatif sama untuk %s: tertinggi %s (%s), terendah %s (%s).",
				label, top.Brand, f(top.Val), bot.Brand, f(bot.Val))
		} else {
			fmt.Fprintf(&sb, "%s tertinggi di %s (%s), terendah di %s (%s).",
				maCap(label), top.Brand, f(top.Val), bot.Brand, f(bot.Val))
		}
		if len(ok) > 2 {
			parts := make([]string, 0, len(ok))
			for _, it := range ok {
				parts = append(parts, it.Brand+" "+f(it.Val))
			}
			sb.WriteString(" Urutan: " + strings.Join(parts, " · ") + ".")
		}
	}
	if o.All != nil {
		sb.WriteString(" Semua brand: " + f(*o.All) + ".")
	}
	var skipped []string
	for _, it := range small {
		if it.Brand != o.Focus && it.N > 0 {
			skipped = append(skipped, fmt.Sprintf("%s (%s %s)", it.Brand, maInt(it.N), unit))
		}
	}
	if len(skipped) > 0 {
		sb.WriteString(" Tidak diperingkat karena sampel kecil: " + strings.Join(skipped, ", ") + ".")
	}
	return sb.String()
}

type maChg struct {
	Brand     string
	Cur, Prev float64
}

// maChange membentuk kalimat naik/turun per brand terhadap periode pembanding.
func maChange(metric, versus string, items []maChg, f func(float64) string, focus string) (string, string) {
	type pc struct {
		Brand string
		Pct   float64
		C, P  float64
	}
	var list []pc
	var noBase []string
	for _, it := range items {
		if it.Brand == "" || it.Brand == maTotalBrand {
			continue
		}
		if it.Prev <= 0 {
			if it.Cur > 0 {
				noBase = append(noBase, it.Brand)
			}
			continue
		}
		list = append(list, pc{it.Brand, (it.Cur - it.Prev) / it.Prev * 100, it.Cur, it.Prev})
	}
	if len(list) == 0 {
		return fmt.Sprintf("%s: belum ada data pembanding untuk %s.", maCap(metric), versus), "info"
	}
	sort.SliceStable(list, func(i, j int) bool { return list[i].Pct < list[j].Pct })
	up, down := 0, 0
	var ups, downs []string
	for _, p := range list {
		if p.Pct >= 0 {
			up++
			ups = append(ups, p.Brand)
		} else {
			down++
			downs = append(downs, p.Brand)
		}
	}
	var sb strings.Builder
	if focus != "" {
		for _, p := range list {
			if p.Brand == focus {
				fmt.Fprintf(&sb, "%s: %s dari %s (%s). ", focus, f(p.C), f(p.P), maSigned(p.Pct))
			}
		}
	}
	tone := "info"
	worst, best := list[0], list[len(list)-1]
	switch {
	case down == len(list) && len(list) > 1:
		tone = "warn"
		fmt.Fprintf(&sb, "%s turun di semua brand dibanding %s. Penurunan terbesar %s (%s), terkecil %s (%s).",
			maCap(metric), versus, worst.Brand, maSigned(worst.Pct), best.Brand, maSigned(best.Pct))
	case up == len(list) && len(list) > 1:
		tone = "good"
		fmt.Fprintf(&sb, "%s naik di semua brand dibanding %s. Kenaikan terbesar %s (%s), terkecil %s (%s).",
			maCap(metric), versus, best.Brand, maSigned(best.Pct), worst.Brand, maSigned(worst.Pct))
	case len(list) == 1:
		if list[0].Pct < 0 {
			tone = "warn"
		} else {
			tone = "good"
		}
		fmt.Fprintf(&sb, "%s %s: %s dibanding %s.", maCap(metric), list[0].Brand, maSigned(list[0].Pct), versus)
	default:
		fmt.Fprintf(&sb, "%s dibanding %s: naik di %s; turun di %s.",
			maCap(metric), versus, strings.Join(ups, ", "), strings.Join(downs, ", "))
	}
	if len(list) > 1 {
		parts := make([]string, 0, len(list))
		for i := len(list) - 1; i >= 0; i-- {
			parts = append(parts, list[i].Brand+" "+maSigned(list[i].Pct))
		}
		sb.WriteString(" Rinci: " + strings.Join(parts, " · ") + ".")
	}
	if len(noBase) > 0 {
		sb.WriteString(" Tanpa pembanding (baru punya transaksi): " + strings.Join(noBase, ", ") + ".")
	}
	return sb.String(), tone
}

// ---------------------------------------------------------------------------
// cache + query
// ---------------------------------------------------------------------------

type maCacheEntry struct {
	rows []maRow
	at   time.Time
}

var (
	maCacheMu sync.Mutex
	maCache   = map[string]maCacheEntry{}
)

func maArgs(from, to, brand string, extra ...interface{}) []interface{} {
	args := []interface{}{
		sql.Named("p_from_date", from),
		sql.Named("p_to_date", to),
		sql.Named("p_brand", brand),
	}
	return append(args, extra...)
}

func maNormalize(rows []maRow) {
	for _, row := range rows {
		for k, v := range row {
			if maTextKeys[k] {
				continue
			}
			if s, ok := v.(string); ok {
				if f, err := strconv.ParseFloat(strings.TrimSpace(s), 64); err == nil {
					row[k] = f
				}
			}
		}
	}
}

// maQuery menjalankan SP analisa dengan cache memori 10 menit per kombinasi SP + parameter.
// Baris hasil cache dipakai bersama: pemanggil tidak boleh mengubahnya (pakai maCopy).
func maQuery(ctx context.Context, fresh bool, sp string, args []interface{}) ([]maRow, time.Time, error) {
	var kb strings.Builder
	kb.WriteString(sp)
	for _, a := range args {
		if n, ok := a.(sql.NamedArg); ok {
			fmt.Fprintf(&kb, "|%s=%v", n.Name, n.Value)
		}
	}
	key := kb.String()
	now := time.Now()

	if !fresh {
		maCacheMu.Lock()
		e, ok := maCache[key]
		maCacheMu.Unlock()
		if ok && now.Sub(e.at) < maCacheTTL {
			return e.rows, e.at, nil
		}
	}

	rows, err := marcommQuerySP(ctx, sp, args...)
	if err != nil {
		return nil, now, fmt.Errorf("%s: %w", sp, err)
	}
	if rows == nil {
		rows = []maRow{}
	}
	maNormalize(rows)

	maCacheMu.Lock()
	for k, e := range maCache {
		if now.Sub(e.at) >= maCacheTTL {
			delete(maCache, k)
		}
	}
	maCache[key] = maCacheEntry{rows: rows, at: now}
	maCacheMu.Unlock()
	return rows, now, nil
}

// ---------------------------------------------------------------------------
// request
// ---------------------------------------------------------------------------

type maPeriod struct{ From, To time.Time }

func (p maPeriod) f() string { return p.From.Format(maDateLayout) }
func (p maPeriod) t() string { return p.To.Format(maDateLayout) }
func (p maPeriod) label() string {
	return maDateLabel(p.From) + " – " + maDateLabel(p.To)
}
func (p maPeriod) days() int { return int(p.To.Sub(p.From).Hours()/24) + 1 }

type maMeta struct {
	Brands  []maRow
	Names   []string
	DataMin time.Time
	DataMax time.Time
	LastTS  string
	HasData bool
	At      time.Time
}

// maBadRequest menandai kesalahan input pemanggil (bukan kesalahan server).
type maBadRequest string

func (e maBadRequest) Error() string { return string(e) }

// maWriteErr membalas 400 untuk kesalahan input dan 500 untuk selebihnya.
func maWriteErr(w http.ResponseWriter, section string, err error) {
	if bad, ok := err.(maBadRequest); ok {
		writeRbcaJSON(w, rbcaErrorJSON("4000400", string(bad)))
		return
	}
	log.Printf("marcomm analytics %s: %s", section, err.Error())
	writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
}

type maReq struct {
	Period maPeriod
	Focus  string
	Fresh  bool
	Meta   maMeta
}

func maLoadMeta(ctx context.Context, fresh bool) (maMeta, error) {
	rows, at, err := maQuery(ctx, fresh, "xsp_marcomm_analytics_meta", nil)
	if err != nil {
		return maMeta{}, err
	}
	m := maMeta{At: at}
	for _, r := range rows {
		if maF(r, "is_total") == 1 {
			if t, err := time.ParseInLocation(maDateLayout, maS(r, "first_tgl"), time.Local); err == nil {
				m.DataMin = t
				m.HasData = true
			}
			if t, err := time.ParseInLocation(maDateLayout, maS(r, "last_tgl"), time.Local); err == nil {
				m.DataMax = t
			}
			m.LastTS = maS(r, "last_ts")
			continue
		}
		m.Brands = append(m.Brands, r)
		m.Names = append(m.Names, maS(r, "brand"))
	}
	return m, nil
}

func maToday() time.Time {
	n := time.Now()
	return time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, time.Local)
}

func maDefaultPeriod() maPeriod {
	to := maToday()
	return maPeriod{From: to.AddDate(0, -6, 1), To: to}
}

func maParseReq(ctx context.Context, r *http.Request) (maReq, error) {
	q := maReq{Fresh: marcommQ(r, "refresh") == "1"}
	meta, err := maLoadMeta(ctx, q.Fresh)
	if err != nil {
		return q, err
	}
	q.Meta = meta

	q.Period = maDefaultPeriod()
	fromS, toS := marcommQ(r, "from_date"), marcommQ(r, "to_date")
	if fromS != "" || toS != "" {
		day := func(s string, fallback time.Time) (time.Time, error) {
			if s == "" {
				return fallback, nil
			}
			d, err := marcommParseDate(s)
			if err != nil {
				return d, maBadRequest("format tanggal tidak dikenali: " + s + " (pakai YYYY-MM-DD)")
			}
			return time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, time.Local), nil
		}
		t, err := day(toS, q.Period.To)
		if err != nil {
			return q, err
		}
		// hari dihitung mundur dari to_date, jadi tanggal di masa depan dibatasi ke hari ini
		if today := maToday(); t.After(today) {
			t = today
		}
		f, err := day(fromS, t.AddDate(0, -6, 1))
		if err != nil {
			return q, err
		}
		if f.After(t) {
			return q, maBadRequest("tanggal awal tidak boleh setelah tanggal akhir")
		}
		q.Period = maPeriod{From: f, To: t}
	}

	focus := strings.ToUpper(strings.TrimSpace(marcommQ(r, "brand")))
	for _, n := range meta.Names {
		if n == focus {
			q.Focus = focus
		}
	}
	return q, nil
}

func maEnvelope(q maReq, section, basis string, at time.Time) map[string]interface{} {
	return map[string]interface{}{
		"section":     section,
		"focus_brand": q.Focus,
		"period": map[string]string{
			"from":  q.Period.f(),
			"to":    q.Period.t(),
			"label": q.Period.label(),
		},
		"basis":       basis,
		"computed_at": at.Format("2006-01-02 15:04:05"),
		"insights":    []maInsight{},
		"notes":       []string{},
	}
}

func maBasisPeriod(q maReq) string {
	return "Transaksi member " + q.Period.label()
}

func maBasisLifecycle(q maReq) string {
	return "Seluruh riwayat transaksi member sampai " + maDateLabel(q.Period.To) + " (tanggal awal filter tidak dipakai di bagian ini)"
}

func maIndex(rows []maRow, key string) map[string]maRow {
	out := make(map[string]maRow, len(rows))
	for _, r := range rows {
		out[maS(r, key)] = r
	}
	return out
}

func maIsTotal(r maRow) bool { return maF(r, "is_total") == 1 }

// ---------------------------------------------------------------------------
// handler
// ---------------------------------------------------------------------------

// MarcommMemberAnalytics — GET /marcomm/analytics/member/{section}
func MarcommMemberAnalytics(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	section := strings.ToLower(strings.TrimSpace(mux.Vars(r)["section"]))
	// meta?refresh=1 = tombol "Hitung ulang": buang semua hasil cache supaya bagian lain ikut dihitung ulang
	if section == "meta" && marcommQ(r, "refresh") == "1" {
		maCacheMu.Lock()
		maCache = map[string]maCacheEntry{}
		maCacheMu.Unlock()
	}
	q, err := maParseReq(ctx, r)
	if err != nil {
		maWriteErr(w, section, err)
		return
	}

	var out map[string]interface{}
	switch section {
	case "meta":
		out = maSectionMeta(q)
	case "overview":
		out, err = maSectionOverview(ctx, q)
	case "trend":
		out, err = maSectionTrend(ctx, q)
	case "retention":
		out, err = maSectionRetention(ctx, q)
	case "segment":
		out, err = maSectionSegment(ctx, q)
	case "crossbrand":
		out, err = maSectionCrossbrand(ctx, q)
	case "brandhome":
		out, err = maSectionBrandHome(ctx, q)
	case "voucher":
		out, err = maSectionVoucher(ctx, q)
	case "birthday":
		out, err = maSectionBirthday(ctx, q)
	case "tier":
		out, err = maSectionTier(ctx, q)
	case "profile":
		out, err = maSectionProfile(ctx, q)
	case "category":
		out, err = maSectionCategory(ctx, q)
	case "quality":
		out, err = maSectionQuality(ctx, q)
	case "segment-members":
		out, err = maSectionSegmentMembers(ctx, q, r)
	case "brandhome-members":
		out, err = maSectionBrandHomeMembers(ctx, q, r)
	default:
		writeRbcaJSON(w, rbcaErrorJSON("4000400", "bagian analisa tidak dikenal: "+section))
		return
	}
	if err != nil {
		maWriteErr(w, section, err)
		return
	}
	marcommWriteObjectOK(w, out)
}

// ---------------------------------------------------------------------------
// meta
// ---------------------------------------------------------------------------

func maSectionMeta(q maReq) map[string]interface{} {
	def := maDefaultPeriod()
	brands := make([]maRow, 0, len(q.Meta.Brands))
	for _, b := range q.Meta.Brands {
		brands = append(brands, maCopy(b))
	}
	out := map[string]interface{}{
		"section":      "meta",
		"brands":       brands,
		"has_data":     q.Meta.HasData,
		"last_ts":      q.Meta.LastTS,
		"computed_at":  q.Meta.At.Format("2006-01-02 15:04:05"),
		"cache_minute": int(maCacheTTL.Minutes()),
		"min_sample":   maMinSample,
		"default_period": map[string]string{
			"from": def.f(),
			"to":   def.t(),
		},
	}
	if q.Meta.HasData {
		out["data_from"] = q.Meta.DataMin.Format(maDateLayout)
		out["data_to"] = q.Meta.DataMax.Format(maDateLayout)
	}
	return out
}

// ---------------------------------------------------------------------------
// overview
// ---------------------------------------------------------------------------

func maSectionOverview(ctx context.Context, q maReq) (map[string]interface{}, error) {
	cur, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_brand_overview", maArgs(q.Period.f(), q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "overview", maBasisPeriod(q), at)
	notes := []string{}

	n := q.Period.days()
	prevP := maPeriod{From: q.Period.From.AddDate(0, 0, -n), To: q.Period.From.AddDate(0, 0, -1)}
	yoyP := maPeriod{From: q.Period.From.AddDate(-1, 0, 0), To: q.Period.To.AddDate(-1, 0, 0)}

	load := func(p maPeriod, name string) (map[string]maRow, bool, error) {
		if !q.Meta.HasData || p.From.Before(q.Meta.DataMin) {
			notes = append(notes, fmt.Sprintf("Pembanding %s (%s) tidak ditampilkan karena data baru mulai %s, jadi periodenya tidak utuh.",
				name, p.label(), maDateLabel(q.Meta.DataMin)))
			return nil, false, nil
		}
		rows, _, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_brand_overview", maArgs(p.f(), p.t(), ""))
		if err != nil {
			return nil, false, err
		}
		return maIndex(rows, "brand"), true, nil
	}
	prev, prevOK, err := load(prevP, "periode sebelumnya")
	if err != nil {
		return nil, err
	}
	yoy, yoyOK, err := load(yoyP, "tahun lalu")
	if err != nil {
		return nil, err
	}

	curIdx := maIndex(cur, "brand")
	totalOmzet := maF(curIdx[maTotalBrand], "omzet")

	names := append([]string{}, q.Meta.Names...)
	sort.SliceStable(names, func(i, j int) bool { return maF(curIdx[names[i]], "omzet") > maF(curIdx[names[j]], "omzet") })
	names = append(names, maTotalBrand)

	rows := make([]maRow, 0, len(names))
	var omzetBV, basketBV, spendBV, repeatBV, baruBV []maBV
	var chgTrxPrev, chgOmzPrev, chgTrxYoy, chgOmzYoy []maChg
	var storeDrop []string
	var noTx []string

	for _, name := range names {
		c := curIdx[name]
		members, trx, omzet, stores := maF(c, "members"), maF(c, "trx"), maF(c, "omzet"), maF(c, "stores")
		row := maRow{
			"brand":            name,
			"is_total":         0,
			"members":          members,
			"trx":              trx,
			"omzet":            omzet,
			"stores":           stores,
			"sekali_belanja":   maF(c, "sekali_belanja"),
			"repeat_buyer":     maF(c, "repeat_buyer"),
			"member_baru":      maF(c, "member_baru"),
			"basket":           maDiv(omzet, trx),
			"spend_per_member": maDiv(omzet, members),
			"repeat_pct":       maPctOf(maF(c, "repeat_buyer"), members),
			"baru_pct":         maPctOf(maF(c, "member_baru"), members),
			"share_omzet":      maPctOf(omzet, totalOmzet),
		}
		if name == maTotalBrand {
			row["is_total"] = 1
		}
		for tag, idx := range map[string]map[string]maRow{"prev": prev, "yoy": yoy} {
			if idx == nil {
				continue
			}
			p := idx[name]
			row[tag+"_members"] = maF(p, "members")
			row[tag+"_trx"] = maF(p, "trx")
			row[tag+"_omzet"] = maF(p, "omzet")
			row[tag+"_stores"] = maF(p, "stores")
			row["d_"+tag+"_members"] = maDelta(members, maF(p, "members"))
			row["d_"+tag+"_trx"] = maDelta(trx, maF(p, "trx"))
			row["d_"+tag+"_omzet"] = maDelta(omzet, maF(p, "omzet"))
			row["d_"+tag+"_stores"] = maDelta(stores, maF(p, "stores"))
		}
		rows = append(rows, row)

		if name == maTotalBrand {
			continue
		}
		if trx == 0 {
			noTx = append(noTx, name)
			continue
		}
		omzetBV = append(omzetBV, maBV{name, maPctOf(omzet, totalOmzet), members})
		basketBV = append(basketBV, maBV{name, maDiv(omzet, trx), members})
		spendBV = append(spendBV, maBV{name, maDiv(omzet, members), members})
		repeatBV = append(repeatBV, maBV{name, maPctOf(maF(c, "repeat_buyer"), members), members})
		baruBV = append(baruBV, maBV{name, maPctOf(maF(c, "member_baru"), members), members})
		if prevOK {
			chgTrxPrev = append(chgTrxPrev, maChg{name, trx, maF(prev[name], "trx")})
			chgOmzPrev = append(chgOmzPrev, maChg{name, omzet, maF(prev[name], "omzet")})
		}
		if yoyOK {
			chgTrxYoy = append(chgTrxYoy, maChg{name, trx, maF(yoy[name], "trx")})
			chgOmzYoy = append(chgOmzYoy, maChg{name, omzet, maF(yoy[name], "omzet")})
			ps := maF(yoy[name], "stores")
			if ps > 0 && (stores-ps)/ps <= -0.10 {
				storeDrop = append(storeDrop, fmt.Sprintf("%s (%s → %s store)", name, maInt(ps), maInt(stores)))
			}
		}
	}

	ins := []maInsight{}
	t := curIdx[maTotalBrand]
	if maF(t, "trx") == 0 {
		ins = append(ins, maInsight{"info", "Tidak ada transaksi", "Tidak ada transaksi member pada " + q.Period.label() + "."})
	} else {
		ins = append(ins, maInsight{"info", "Kontribusi omzet",
			fmt.Sprintf("Omzet member %s dari %s member dan %s transaksi. ", maRp(totalOmzet), maInt(maF(t, "members")), maInt(maF(t, "trx"))) +
				maRank("porsi omzet member", omzetBV, maPct, maRankOpt{Focus: q.Focus})})
		allBasket := maDiv(totalOmzet, maF(t, "trx"))
		ins = append(ins, maInsight{"info", "Nilai per transaksi",
			maRank("rata-rata nilai per transaksi", basketBV, maRp, maRankOpt{Focus: q.Focus, All: &allBasket})})
		allSpend := maDiv(totalOmzet, maF(t, "members"))
		ins = append(ins, maInsight{"info", "Belanja per member",
			maRank("rata-rata belanja per member", spendBV, maRp, maRankOpt{Focus: q.Focus, All: &allSpend})})
		allRepeat := maPctOf(maF(t, "repeat_buyer"), maF(t, "members"))
		ins = append(ins, maInsight{"info", "Member yang belanja lebih dari satu hari",
			maRank("porsi member yang belanja lebih dari satu hari di periode ini", repeatBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: &allRepeat})})
		// "baru" = belum punya transaksi sebelum periode. Kalau periode dimulai dari awal data, semua member
		// otomatis terhitung baru, jadi angkanya tidak bermakna dan tidak dibuat kesimpulan.
		if q.Meta.HasData && q.Period.From.After(q.Meta.DataMin) {
			allBaru := maPctOf(maF(t, "member_baru"), maF(t, "members"))
			ins = append(ins, maInsight{"info", "Member yang baru mulai belanja",
				maRank("porsi member yang pertama kali belanja di periode ini", baruBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: &allBaru})})
			notes = append(notes, fmt.Sprintf("Member baru = member yang belum punya transaksi tercatat sebelum %s. Data transaksi baru mulai %s, jadi member yang terakhir belanja sebelum tanggal itu ikut terhitung baru.",
				maDateLabel(q.Period.From), maDateLabel(q.Meta.DataMin)))
		} else {
			notes = append(notes, "Kolom member baru tidak dibuat kesimpulan karena periode dimulai dari awal data, sehingga semua member terhitung baru.")
		}
		if yoyOK {
			txt, tone := maChange("transaksi member", "periode yang sama tahun lalu ("+yoyP.label()+")", chgTrxYoy, maInt, q.Focus)
			ins = append(ins, maInsight{tone, "Transaksi vs tahun lalu", txt})
			txt, tone = maChange("omzet member", "periode yang sama tahun lalu", chgOmzYoy, maRp, q.Focus)
			ins = append(ins, maInsight{tone, "Omzet vs tahun lalu", txt})
			if len(storeDrop) > 0 {
				ins = append(ins, maInsight{"warn", "Store pencatat ikut berkurang",
					"Jumlah store yang mencatat transaksi member turun 10% atau lebih dibanding tahun lalu di " + strings.Join(storeDrop, ", ") +
						". Sebagian penurunan transaksi bisa berasal dari pencatatan member di kasir, bukan dari member yang berhenti belanja."})
			}
		}
		if prevOK {
			txt, tone := maChange("transaksi member", "periode sebelumnya ("+prevP.label()+")", chgTrxPrev, maInt, q.Focus)
			ins = append(ins, maInsight{tone, "Transaksi vs periode sebelumnya", txt})
			txt, tone = maChange("omzet member", "periode sebelumnya", chgOmzPrev, maRp, q.Focus)
			ins = append(ins, maInsight{tone, "Omzet vs periode sebelumnya", txt})
		}
	}
	if len(noTx) > 0 {
		notes = append(notes, "Tidak ada transaksi member di periode ini untuk: "+strings.Join(noTx, ", ")+".")
	}

	out["rows"] = rows
	out["compare"] = map[string]interface{}{
		"prev": map[string]interface{}{"from": prevP.f(), "to": prevP.t(), "label": prevP.label(), "available": prevOK},
		"yoy":  map[string]interface{}{"from": yoyP.f(), "to": yoyP.t(), "label": yoyP.label(), "available": yoyOK},
	}
	out["insights"] = ins
	out["notes"] = notes
	return out, nil
}

// ---------------------------------------------------------------------------
// trend
// ---------------------------------------------------------------------------

func maSectionTrend(ctx context.Context, q maReq) (map[string]interface{}, error) {
	monthStart := time.Date(q.Period.To.Year(), q.Period.To.Month(), 1, 0, 0, 0, 0, time.Local)
	from := monthStart.AddDate(0, -maTrendMonths, 0)
	if q.Period.From.Before(from) {
		from = q.Period.From
	}
	p := maPeriod{From: from, To: q.Period.To}
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_trend", maArgs(p.f(), p.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "trend", "Transaksi member per bulan, "+p.label()+" (minimal "+strconv.Itoa(maTrendMonths+1)+" bulan terakhir supaya bisa dibandingkan dengan tahun lalu)", at)

	isFull := func(ym string) bool {
		ms, err := time.ParseInLocation("2006-01", ym, time.Local)
		if err != nil {
			return false
		}
		me := ms.AddDate(0, 1, -1)
		if ms.Before(p.From) || me.After(p.To) {
			return false
		}
		return !q.Meta.HasData || !ms.Before(q.Meta.DataMin)
	}

	rows := make([]maRow, 0, len(src))
	seen := map[string]bool{}
	var months []string
	byKey := map[string]maRow{} // bulan|brand
	for _, r := range src {
		o := maCopy(r)
		o["basket"] = maDiv(maF(r, "omzet"), maF(r, "trx"))
		rows = append(rows, o)
		ym := maS(r, "bulan")
		if !seen[ym] {
			seen[ym] = true
			months = append(months, ym)
		}
		byKey[ym+"|"+maS(r, "brand")] = r
	}
	sort.Strings(months)
	monthList := make([]maRow, 0, len(months))
	var full []string
	for _, ym := range months {
		f := isFull(ym)
		monthList = append(monthList, maRow{"bulan": ym, "label": maMonthLabel(ym), "partial": !f})
		if f {
			full = append(full, ym)
		}
	}

	ins := []maInsight{}
	notes := []string{}

	// 3 bulan penuh terakhir vs bulan yang sama tahun lalu
	if len(full) >= 3 {
		last := full[len(full)-3:]
		var prevM []string
		okYoy := true
		for _, ym := range last {
			ms, _ := time.ParseInLocation("2006-01", ym, time.Local)
			py := ms.AddDate(-1, 0, 0).Format("2006-01")
			if !isFull(py) || !seen[py] {
				okYoy = false
			}
			prevM = append(prevM, py)
		}
		span := maMonthLabel(last[0]) + " – " + maMonthLabel(last[2])
		if okYoy {
			var chgTrx, chgMem []maChg
			var storeDrop []string
			for _, name := range q.Meta.Names {
				var ct, pt, cm, pm, cs, ps float64
				for i := range last {
					ct += maF(byKey[last[i]+"|"+name], "trx")
					pt += maF(byKey[prevM[i]+"|"+name], "trx")
					cm += maF(byKey[last[i]+"|"+name], "members")
					pm += maF(byKey[prevM[i]+"|"+name], "members")
					cs += maF(byKey[last[i]+"|"+name], "stores")
					ps += maF(byKey[prevM[i]+"|"+name], "stores")
				}
				chgTrx = append(chgTrx, maChg{name, ct, pt})
				chgMem = append(chgMem, maChg{name, cm / 3, pm / 3})
				if ps > 0 && (cs-ps)/ps <= -0.10 {
					storeDrop = append(storeDrop, fmt.Sprintf("%s (rata-rata %s → %s store per bulan)", name, maDec(ps/3, 0), maDec(cs/3, 0)))
				}
			}
			txt, tone := maChange("transaksi member "+span, "bulan yang sama tahun lalu", chgTrx, maInt, q.Focus)
			ins = append(ins, maInsight{tone, "Tiga bulan penuh terakhir vs tahun lalu", txt})
			txt, tone = maChange("rata-rata member aktif per bulan "+span, "bulan yang sama tahun lalu", chgMem, maInt, q.Focus)
			ins = append(ins, maInsight{tone, "Member aktif per bulan", txt})
			if len(storeDrop) > 0 {
				ins = append(ins, maInsight{"warn", "Store pencatat ikut berkurang",
					"Store yang mencatat transaksi member turun 10% atau lebih di " + strings.Join(storeDrop, ", ") +
						". Cek ke operasional apakah member memang berkurang atau kasir makin jarang mengisi member."})
			}
		} else {
			notes = append(notes, "Perbandingan "+span+" dengan tahun lalu tidak dibuat karena bulan yang sama tahun lalu belum utuh di data.")
		}

		// bulan tertinggi dan terendah tiap brand (bulan penuh saja)
		var peak []string
		for _, name := range q.Meta.Names {
			best, worst := "", ""
			var bv, wv float64
			for _, ym := range full {
				v := maF(byKey[ym+"|"+name], "trx")
				if best == "" || v > bv {
					best, bv = ym, v
				}
				if worst == "" || v < wv {
					worst, wv = ym, v
				}
			}
			if best != "" && (q.Focus == "" || q.Focus == name) {
				peak = append(peak, fmt.Sprintf("%s tertinggi %s (%s transaksi), terendah %s (%s)",
					name, maMonthLabel(best), maInt(bv), maMonthLabel(worst), maInt(wv)))
			}
		}
		if len(peak) > 0 {
			ins = append(ins, maInsight{"info", "Bulan tertinggi dan terendah", "Dari bulan yang utuh: " + strings.Join(peak, "; ") + "."})
		}

		// porsi member baru di bulan penuh terakhir
		lastFull := full[len(full)-1]
		var baru []maBV
		for _, name := range q.Meta.Names {
			r := byKey[lastFull+"|"+name]
			baru = append(baru, maBV{name, maPctOf(maF(r, "member_baru"), maF(r, "members")), maF(r, "members")})
		}
		ins = append(ins, maInsight{"info", "Member baru di " + maMonthLabel(lastFull),
			maRank("porsi member aktif "+maMonthLabel(lastFull)+" yang baru pertama kali belanja", baru, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2})})
	} else {
		notes = append(notes, "Belum ada tiga bulan utuh di rentang ini, jadi kesimpulan tren belum dibuat.")
	}
	for _, m := range monthList {
		if m["partial"] == true {
			notes = append(notes, "Bulan yang belum utuh ditandai dan tidak dipakai untuk perbandingan.")
			break
		}
	}

	out["rows"] = rows
	out["months"] = monthList
	out["insights"] = ins
	out["notes"] = notes
	return out, nil
}

// ---------------------------------------------------------------------------
// retention
// ---------------------------------------------------------------------------

func maSectionRetention(ctx context.Context, q maReq) (map[string]interface{}, error) {
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_retention", maArgs(maLifecycleFrom, q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "retention", maBasisLifecycle(q), at)

	rows := make([]maRow, 0, len(src))
	var sekali, pasif, aktif90, b90, b180, lain []maBV
	var total maRow
	for _, r := range src {
		m := maF(r, "members")
		o := maCopy(r)
		o["hb1_pct"] = maPctOf(maF(r, "hb1"), m)
		o["hb2_pct"] = maPctOf(maF(r, "hb2"), m)
		o["hb3p_pct"] = maPctOf(maF(r, "hb3p"), m)
		o["aktif90_pct"] = maPctOf(maF(r, "r_0_30")+maF(r, "r_31_90"), m)
		o["pasif180_pct"] = maPctOf(maF(r, "r_181_365")+maF(r, "r_365p"), m)
		o["k30_pct"] = maPctOf(maF(r, "k30_balik"), maF(r, "k30_members"))
		o["k90_pct"] = maPctOf(maF(r, "k90_balik"), maF(r, "k90_members"))
		o["k180_pct"] = maPctOf(maF(r, "k180_balik"), maF(r, "k180_members"))
		o["k180_sama_pct"] = maPctOf(maF(r, "k180_balik_sama"), maF(r, "k180_members"))
		o["k180_lain_pct"] = maPctOf(maF(r, "k180_balik_lain"), maF(r, "k180_members"))
		rows = append(rows, o)
		if maIsTotal(r) {
			total = o
			continue
		}
		name := maS(r, "brand")
		sekali = append(sekali, maBV{name, maF(o, "hb1_pct"), m})
		pasif = append(pasif, maBV{name, maF(o, "pasif180_pct"), m})
		aktif90 = append(aktif90, maBV{name, maF(o, "aktif90_pct"), m})
		b90 = append(b90, maBV{name, maF(o, "k90_pct"), maF(r, "k90_members")})
		b180 = append(b180, maBV{name, maF(o, "k180_pct"), maF(r, "k180_members")})
		lain = append(lain, maBV{name, maF(o, "k180_lain_pct"), maF(r, "k180_members")})
	}

	ins := []maInsight{}
	if total != nil && maF(total, "members") > 0 {
		all := func(k string) *float64 { v := maF(total, k); return &v }
		ins = append(ins, maInsight{"warn", "Member yang hanya belanja satu hari",
			maRank("porsi member yang hanya belanja satu hari di brand itu", sekali, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: all("hb1_pct")})})
		ins = append(ins, maInsight{"info", "Balik belanja dalam 90 hari",
			maRank("porsi member baru yang belanja lagi dalam 90 hari (menurut brand pertama)", b90, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: all("k90_pct")})})
		ins = append(ins, maInsight{"info", "Balik belanja dalam 180 hari",
			maRank("porsi member baru yang belanja lagi dalam 180 hari (menurut brand pertama)", b180, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: all("k180_pct")})})
		ins = append(ins, maInsight{"info", "Pindah ke brand lain",
			maRank("porsi member baru yang dalam 180 hari belanja di brand lain", lain, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: all("k180_lain_pct")})})
		ins = append(ins, maInsight{"good", "Member yang masih aktif",
			maRank("porsi member yang terakhir belanja dalam 90 hari", aktif90, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: all("aktif90_pct")})})
		ins = append(ins, maInsight{"warn", "Member yang sudah lama tidak belanja",
			maRank("porsi member yang sudah lebih dari 180 hari tidak belanja di brand itu", pasif, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: all("pasif180_pct")})})
	}

	out["rows"] = rows
	out["insights"] = ins
	out["notes"] = []string{
		"Frekuensi dan recency dihitung per brand: member lintas brand terhitung di tiap brand tempat ia belanja.",
		"Kohort balik belanja memakai brand pada hari belanja pertama, dan hanya menghitung member yang sudah melewati jendela 30/90/180 hari sampai " + maDateLabel(q.Period.To) + ".",
		"Balik belanja berarti belanja lagi di hari yang berbeda; beberapa struk di hari yang sama dihitung satu kali belanja.",
	}
	return out, nil
}

// ---------------------------------------------------------------------------
// segment
// ---------------------------------------------------------------------------

type maSegDef struct{ Code, Label, Def, Treatment string }

func maSegmentDefs(vip, value float64) []maSegDef {
	v, n := maRp(vip), maRp(value)
	bernilai := "minimal 2 hari belanja atau belanja ≥ " + n
	return []maSegDef{
		{"A", "VIP", "Total belanja ≥ " + v, "Sentuhan personal dari store dan akses lebih awal, bukan diskon. Saring dulu akun yang perlu dicek."},
		{"B", "Loyal aktif", "Minimal 3 hari belanja, terakhir beli ≤ 180 hari", "Ajak coba brand kedua dan dorong naik tier."},
		{"C", "Potensial", "2 hari belanja, terakhir beli ≤ 180 hari", "Beri pemicu untuk pembelian ketiga."},
		{"D", "Baru", "1 hari belanja, terakhir beli ≤ 90 hari", "Voucher pembelian kedua, kirim dalam 30–60 hari setelah beli."},
		{"E", "Sekali beli 91–180 hari", "1 hari belanja, terakhir beli 91–180 hari", "Pengingat terakhir sebelum jendela balik belanja tertutup."},
		{"F", "Berisiko tapi bernilai", "Terakhir beli 181–365 hari; " + bernilai, "Prioritas win-back."},
		{"G", "Sekali beli 181–365 hari", "Terakhir beli 181–365 hari; 1 hari belanja dan belanja < " + n, "Broadcast murah saja."},
		{"H", "Hilang tapi bernilai", "Terakhir beli > 365 hari; " + bernilai, "Satu kali win-back dengan penawaran lebih kuat."},
		{"I", "Hilang sekali beli", "Terakhir beli > 365 hari; 1 hari belanja dan belanja < " + n, "Jangan habiskan budget di sini."},
	}
}

func maSectionSegment(ctx context.Context, q maReq) (map[string]interface{}, error) {
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_segment", maArgs(maLifecycleFrom, q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "segment", maBasisLifecycle(q), at)

	vip, value := 9000000.0, 1500000.0
	brandMembers := map[string]float64{}
	brandOmzet := map[string]float64{}
	cell := map[string]maRow{} // segmen|brand
	var allMembers, allOmzet float64
	for _, r := range src {
		if v := maF(r, "vip_min"); v > 0 {
			vip = v
		}
		if v := maF(r, "value_min"); v > 0 {
			value = v
		}
		b := maS(r, "brand")
		brandMembers[b] += maF(r, "members")
		brandOmzet[b] += maF(r, "omzet")
		allMembers += maF(r, "members")
		allOmzet += maF(r, "omzet")
		cell[maS(r, "segmen")+"|"+b] = r
	}

	defs := maSegmentDefs(vip, value)
	segs := make([]maRow, 0, len(defs))
	share := map[string][]maBV{} // segmen -> porsi member brand
	count := map[string][]maBV{} // segmen -> jumlah member
	omz := map[string][]maBV{}
	var biggest maRow
	for _, d := range defs {
		var sm, st, so float64
		brands := make([]maRow, 0, len(q.Meta.Names))
		for _, name := range q.Meta.Names {
			c := cell[d.Code+"|"+name]
			m, o := maF(c, "members"), maF(c, "omzet")
			sm += m
			st += maF(c, "trx")
			so += o
			brands = append(brands, maRow{
				"brand":        name,
				"members":      m,
				"trx":          maF(c, "trx"),
				"omzet":        o,
				"pct_of_brand": maPctOf(m, brandMembers[name]),
				"pct_omzet":    maPctOf(o, brandOmzet[name]),
			})
			share[d.Code] = append(share[d.Code], maBV{name, maPctOf(m, brandMembers[name]), brandMembers[name]})
			count[d.Code] = append(count[d.Code], maBV{name, m, brandMembers[name]})
			omz[d.Code] = append(omz[d.Code], maBV{name, o, brandMembers[name]})
		}
		for _, b := range brands {
			b["pct_of_segment"] = maPctOf(maF(b, "members"), sm)
		}
		seg := maRow{
			"code": d.Code, "label": d.Label, "definisi": d.Def, "treatment": d.Treatment,
			"members": sm, "trx": st, "omzet": so,
			"pct_members": maPctOf(sm, allMembers),
			"pct_omzet":   maPctOf(so, allOmzet),
			"avg_spend":   maDiv(so, sm),
			"brands":      brands,
		}
		segs = append(segs, seg)
		if biggest == nil || sm > maF(biggest, "members") {
			biggest = seg
		}
	}

	brandList := make([]maRow, 0, len(q.Meta.Names))
	for _, name := range q.Meta.Names {
		brandList = append(brandList, maRow{"brand": name, "members": brandMembers[name], "omzet": brandOmzet[name]})
	}

	ins := []maInsight{}
	if allMembers > 0 {
		label := func(code string) string {
			for _, d := range defs {
				if d.Code == code {
					return d.Label
				}
			}
			return code
		}
		ins = append(ins, maInsight{"info", "Segmen terbesar",
			fmt.Sprintf("Segmen dengan member terbanyak: %s (%s member, %s dari semua member pembeli). ",
				maS(biggest, "label"), maInt(maF(biggest, "members")), maPct(maF(biggest, "pct_members"))) +
				maRank("porsi member brand di segmen "+maS(biggest, "label"), share[maS(biggest, "code")], maPct, maRankOpt{Focus: q.Focus, AbsTol: 2})})
		ins = append(ins, maInsight{"warn", "Kantong win-back: " + label("F"),
			maRank("omzet member segmen "+label("F"), omz["F"], maRp, maRankOpt{Focus: q.Focus}) + " " +
				maRank("jumlah member segmen "+label("F"), count["F"], maInt, maRankOpt{})})
		ins = append(ins, maInsight{"good", label("B"),
			maRank("porsi member brand yang "+strings.ToLower(label("B")), share["B"], maPct, maRankOpt{Focus: q.Focus, AbsTol: 1})})
		ins = append(ins, maInsight{"info", "Member " + strings.ToLower(label("D")),
			maRank("jumlah member segmen "+label("D")+" (1 hari belanja, ≤ 90 hari)", count["D"], maInt, maRankOpt{Focus: q.Focus})})
		ins = append(ins, maInsight{"info", label("A"),
			maRank("jumlah member "+label("A"), count["A"], maInt, maRankOpt{Focus: q.Focus}) + " " +
				maRank("porsi omzet brand yang berasal dari member "+label("A"), func() []maBV {
					var v []maBV
					for _, name := range q.Meta.Names {
						v = append(v, maBV{name, maPctOf(maF(cell["A|"+name], "omzet"), brandOmzet[name]), brandMembers[name]})
					}
					return v
				}(), maPct, maRankOpt{AbsTol: 1})})
		ins = append(ins, maInsight{"warn", label("I"),
			maRank("porsi member brand yang "+strings.ToLower(label("I")), share["I"], maPct, maRankOpt{Focus: q.Focus, AbsTol: 2})})
	}

	out["segments"] = segs
	out["brands"] = brandList
	out["total"] = maRow{"members": allMembers, "omzet": allOmzet}
	out["thresholds"] = maRow{"vip_min": vip, "value_min": value}
	out["insights"] = ins
	out["notes"] = []string{
		"Tiap member masuk satu segmen dan satu brand, yaitu brand dengan belanja terbesarnya (brand dominan).",
		"Hari dihitung mundur dari " + maDateLabel(q.Period.To) + ". Batas rupiah mengikuti Master Tier: VIP = batas bawah tier 5, bernilai = batas bawah tier 2.",
	}
	return out, nil
}

// ---------------------------------------------------------------------------
// crossbrand
// ---------------------------------------------------------------------------

func maSectionCrossbrand(ctx context.Context, q maReq) (map[string]interface{}, error) {
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_crossbrand_brand", maArgs(q.Period.f(), q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	pairSrc, _, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_crossbrand_pair", maArgs(q.Period.f(), q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "crossbrand", maBasisPeriod(q), at)

	rows := make([]maRow, 0, len(src))
	var lintasBV, multBV, lainBV []maBV
	var total maRow
	for _, r := range src {
		m := maF(r, "members")
		o := maCopy(r)
		avgE := maDiv(maF(r, "omzet_eksklusif"), maF(r, "eksklusif"))
		avgL := maDiv(maF(r, "omzet_lintas_total"), maF(r, "lintas"))
		o["lintas_pct"] = maPctOf(maF(r, "lintas"), m)
		o["avg_spend_eksklusif"] = avgE
		o["avg_spend_lintas"] = avgL
		o["kelipatan"] = maDiv(avgL, avgE)
		rows = append(rows, o)
		if maIsTotal(r) {
			total = o
			continue
		}
		name := maS(r, "brand")
		lintasBV = append(lintasBV, maBV{name, maF(o, "lintas_pct"), m})
		if maF(r, "eksklusif") >= maMinSample && maF(r, "lintas") >= maMinSample {
			multBV = append(multBV, maBV{name, maDiv(avgL, avgE), m})
		} else {
			multBV = append(multBV, maBV{name, 0, math.Min(maF(r, "eksklusif"), maF(r, "lintas"))})
		}
		lainBV = append(lainBV, maBV{name, maF(r, "omzet_lintas_di_brand_lain"), maF(r, "lintas")})
	}

	pairs := make([]maRow, 0, len(pairSrc))
	var best, bestFocus maRow
	for _, r := range pairSrc {
		o := maCopy(r)
		o["pct_a"] = maPctOf(maF(r, "members"), maF(r, "members_a"))
		o["pct_b"] = maPctOf(maF(r, "members"), maF(r, "members_b"))
		pairs = append(pairs, o)
		if best == nil {
			best = o
		}
		if bestFocus == nil && q.Focus != "" && (maS(r, "brand_a") == q.Focus || maS(r, "brand_b") == q.Focus) {
			bestFocus = o
		}
	}
	pairText := func(p maRow) string {
		return fmt.Sprintf("%s + %s (%s member; %s member %s dan %s member %s)",
			maS(p, "brand_a"), maS(p, "brand_b"), maInt(maF(p, "members")),
			maPct(maF(p, "pct_a")), maS(p, "brand_a"), maPct(maF(p, "pct_b")), maS(p, "brand_b"))
	}

	ins := []maInsight{}
	if total != nil && maF(total, "members") > 0 {
		allL := maF(total, "lintas_pct")
		ins = append(ins, maInsight{"info", "Member lintas brand",
			maRank("porsi member yang juga belanja di brand lain", lintasBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: &allL})})
		ins = append(ins, maInsight{"good", "Belanja member lintas brand vs eksklusif",
			fmt.Sprintf("Secara keseluruhan member lintas brand belanja rata-rata %s, member satu brand %s (%s). ",
				maRp(maF(total, "avg_spend_lintas")), maRp(maF(total, "avg_spend_eksklusif")), maMult(maF(total, "kelipatan"))) +
				maRank("kelipatan belanja member lintas brand terhadap member eksklusif", multBV, maMult, maRankOpt{Focus: q.Focus}) +
				" Ini korelasi: member yang memang sering belanja lebih mungkin mencoba brand lain."})
		ins = append(ins, maInsight{"info", "Omzet di brand lain",
			maRank("omzet yang dibelanjakan member brand ini di brand lain", lainBV, maRp, maRankOpt{Focus: q.Focus})})
		if best != nil {
			txt := "Pasangan brand yang paling sering dibeli member yang sama: " + pairText(best) + "."
			if bestFocus != nil {
				txt = "Pasangan terkuat untuk " + q.Focus + ": " + pairText(bestFocus) + ". " + txt
			}
			ins = append(ins, maInsight{"info", "Pasangan brand", txt})
		}
	}

	out["rows"] = rows
	out["pairs"] = pairs
	out["insights"] = ins
	out["notes"] = []string{"Member lintas brand terhitung di tiap brand tempat ia belanja pada periode ini."}
	return out, nil
}

// ---------------------------------------------------------------------------
// brandhome: member per brand menurut brand pertama dan brand utama
// ---------------------------------------------------------------------------

func maSectionBrandHome(ctx context.Context, q maReq) (map[string]interface{}, error) {
	args := maArgs(q.Period.f(), q.Period.t(), "")
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_brandhome_brand", args)
	if err != nil {
		return nil, err
	}
	matSrc, _, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_brandhome_matrix", args)
	if err != nil {
		return nil, err
	}
	trendSrc, _, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_brandhome_trend", args)
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "brandhome",
		"Member yang bertransaksi "+q.Period.label()+"; brand pertama dibaca dari seluruh riwayat transaksi member", at)

	// "baru" hanya bermakna bila periode dimulai setelah awal data (lihat catatan yang sama di overview)
	hasLama := q.Meta.HasData && q.Period.From.After(q.Meta.DataMin)

	srcIdx := maIndex(src, "brand")
	all := maF(srcIdx[maTotalBrand], "members_utama")

	rows := make([]maRow, 0, len(src))
	var total maRow
	var pertamaBV, utamaBV, baruBV, setiaBV, setiaLamaBV, porsiBV, spendBV []maBV
	var naik, turun []string
	signed := func(v float64) string {
		if v > 0 {
			return "+" + maInt(v)
		}
		return maInt(v)
	}
	for _, r := range src {
		mp, mu := maF(r, "members_pertama"), maF(r, "members_utama")
		lama := mp - maF(r, "baru_pertama")
		o := maCopy(r)
		o["share_pertama"] = maPctOf(mp, all)
		o["share_utama"] = maPctOf(mu, all)
		o["baru_pct"] = maPctOf(maF(r, "baru_pertama"), mp)
		o["lama_pertama"] = lama
		o["setia_pct"] = maPctOf(maF(r, "setia"), mp)
		o["setia_lama_pct"] = maPctOf(maF(r, "setia_lama"), lama)
		o["selisih"] = mu - mp
		o["trx_per_member"] = maDiv(maF(r, "trx_utama"), mu)
		o["spend_per_member"] = maDiv(maF(r, "omzet_utama"), mu)
		o["porsi_trx_utama_pct"] = maPctOf(maF(r, "trx_di_brand_utama"), maF(r, "trx_utama"))
		o["seri_pct"] = maPctOf(maF(r, "seri"), mu)
		o["satu_pct"] = maPctOf(maF(r, "satu_transaksi"), mu)
		rows = append(rows, o)
		if maIsTotal(r) {
			total = o
			continue
		}
		name := maS(r, "brand")
		pertamaBV = append(pertamaBV, maBV{name, maF(o, "share_pertama"), mp})
		utamaBV = append(utamaBV, maBV{name, maF(o, "share_utama"), mu})
		baruBV = append(baruBV, maBV{name, maF(o, "baru_pct"), mp})
		setiaBV = append(setiaBV, maBV{name, maF(o, "setia_pct"), mp})
		setiaLamaBV = append(setiaLamaBV, maBV{name, maF(o, "setia_lama_pct"), lama})
		porsiBV = append(porsiBV, maBV{name, maF(o, "porsi_trx_utama_pct"), mu})
		spendBV = append(spendBV, maBV{name, maF(o, "spend_per_member"), mu})
		switch d := mu - mp; {
		case d > 0:
			naik = append(naik, fmt.Sprintf("%s (%s)", name, signed(d)))
		case d < 0:
			turun = append(turun, fmt.Sprintf("%s (%s)", name, signed(d)))
		}
	}

	// matriks brand pertama -> brand utama
	matrix := make([]maRow, 0, len(matSrc))
	var moves []maRow
	for _, r := range matSrc {
		o := maCopy(r)
		bp, bu := maS(r, "brand_pertama"), maS(r, "brand_utama")
		o["pct_pertama"] = maPctOf(maF(r, "members"), maF(srcIdx[bp], "members_pertama"))
		o["pct_utama"] = maPctOf(maF(r, "members"), maF(srcIdx[bu], "members_utama"))
		o["tetap"] = bp == bu
		matrix = append(matrix, o)
		if bp != bu {
			moves = append(moves, o)
		}
	}
	sort.SliceStable(moves, func(i, j int) bool { return maF(moves[i], "members") > maF(moves[j], "members") })
	moveText := func(m maRow) string {
		return fmt.Sprintf("%s member yang pertama belanja di %s sekarang paling sering bertransaksi di %s (%s dari member pintu masuk %s)",
			maInt(maF(m, "members")), maS(m, "brand_pertama"), maS(m, "brand_utama"),
			maPct(maF(m, "pct_pertama")), maS(m, "brand_pertama"))
	}

	// member baru per bulan menurut brand pertama
	type ymKey struct{ ym, brand string }
	cell := map[ymKey]float64{}
	monthTotal := map[string]float64{}
	for _, r := range trendSrc {
		ym, n := maS(r, "bulan"), maF(r, "members")
		cell[ymKey{ym, maS(r, "brand_pertama")}] += n
		monthTotal[ym] += n
	}
	trendFrom := q.Period.From
	if q.Meta.HasData && trendFrom.Before(q.Meta.DataMin) {
		trendFrom = q.Meta.DataMin
	}
	months := []maRow{}
	trend := []maRow{}
	for ms := time.Date(trendFrom.Year(), trendFrom.Month(), 1, 0, 0, 0, 0, time.Local); !ms.After(q.Period.To); ms = ms.AddDate(0, 1, 0) {
		ym := ms.Format("2006-01")
		partial := ms.Before(trendFrom) || ms.AddDate(0, 1, -1).After(q.Period.To)
		months = append(months, maRow{"bulan": ym, "label": maMonthLabel(ym), "partial": partial})
		for _, name := range q.Meta.Names {
			trend = append(trend, maRow{"bulan": ym, "brand": name, "is_total": 0, "members": cell[ymKey{ym, name}]})
		}
		trend = append(trend, maRow{"bulan": ym, "brand": maTotalBrand, "is_total": 1, "members": monthTotal[ym]})
	}

	ins := []maInsight{}
	notes := []string{}
	if total == nil || all == 0 {
		ins = append(ins, maInsight{"info", "Tidak ada transaksi", "Tidak ada transaksi member pada " + q.Period.label() + "."})
	} else {
		ins = append(ins, maInsight{"info", "Pintu masuk member",
			fmt.Sprintf("%s member bertransaksi di periode ini; tiap member dihitung di brand transaksi pertamanya. ", maInt(all)) +
				maRank("porsi member yang transaksi pertamanya di brand ini", pertamaBV, maPct, maRankOpt{Focus: q.Focus})})

		utamaTxt := maRank("porsi member yang paling sering bertransaksi di brand ini", utamaBV, maPct, maRankOpt{Focus: q.Focus})
		if len(naik) > 0 || len(turun) > 0 {
			utamaTxt += " Dibanding jumlah member pintu masuknya:"
			if len(naik) > 0 {
				utamaTxt += " bertambah di " + strings.Join(naik, ", ")
			}
			if len(turun) > 0 {
				if len(naik) > 0 {
					utamaTxt += ";"
				}
				utamaTxt += " berkurang di " + strings.Join(turun, ", ")
			}
			utamaTxt += "."
		}
		ins = append(ins, maInsight{"info", "Brand utama member", utamaTxt})

		setia := maF(total, "setia")
		allSetia := maF(total, "setia_pct")
		ins = append(ins, maInsight{"info", "Tetap di brand pertama",
			fmt.Sprintf("%s dari %s member (%s) brand utamanya masih sama dengan brand pertamanya. ", maInt(setia), maInt(all), maPct(allSetia)) +
				maRank("porsi member yang brand utamanya masih brand pertamanya", setiaBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2})})

		if hasLama && maF(total, "lama_pertama") > 0 {
			allLama := maF(total, "setia_lama_pct")
			ins = append(ins, maInsight{"info", "Kesetiaan member lama",
				fmt.Sprintf("Dari %s member lama (sudah bertransaksi sebelum %s), %s brand utamanya masih brand pertamanya. ",
					maInt(maF(total, "lama_pertama")), maDateLabel(q.Period.From), maPct(allLama)) +
					maRank("porsi member lama yang brand utamanya masih brand pertamanya", setiaLamaBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, Unit: "member lama"}) +
					" Angka ini lebih bermakna daripada angka semua member, karena member baru dengan satu transaksi otomatis tetap di brand pertamanya."})
		}

		if len(moves) > 0 {
			pindah := all - setia
			txt := fmt.Sprintf("%s member (%s) brand utamanya berbeda dari brand pertamanya. Perpindahan terbesar: %s.",
				maInt(pindah), maPct(maPctOf(pindah, all)), moveText(moves[0]))
			if q.Focus != "" {
				var keluar, masuk maRow
				for _, m := range moves {
					if keluar == nil && maS(m, "brand_pertama") == q.Focus {
						keluar = m
					}
					if masuk == nil && maS(m, "brand_utama") == q.Focus {
						masuk = m
					}
				}
				var parts []string
				if keluar != nil {
					parts = append(parts, "keluar terbesar "+moveText(keluar))
				}
				if masuk != nil {
					parts = append(parts, "masuk terbesar "+moveText(masuk))
				}
				if len(parts) > 0 {
					txt = "Untuk " + q.Focus + ": " + strings.Join(parts, "; ") + ". " + txt
				}
			}
			ins = append(ins, maInsight{"info", "Perpindahan brand", txt})
		}

		if hasLama {
			allBaru := maF(total, "baru_pct")
			ins = append(ins, maInsight{"info", "Member baru menurut brand pertama",
				fmt.Sprintf("%s dari %s member (%s) baru pertama kali bertransaksi di periode ini. ", maInt(maF(total, "baru_pertama")), maInt(all), maPct(allBaru)) +
					maRank("porsi member baru di antara member pintu masuk brand ini", baruBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2})})
			notes = append(notes, fmt.Sprintf("Member baru = transaksi pertamanya jatuh di periode ini; member lama = sudah bertransaksi sebelum %s.", maDateLabel(q.Period.From)))
		} else {
			notes = append(notes, "Kolom member baru dan member lama tidak dibuat kesimpulan karena periode dimulai dari awal data, sehingga semua member terhitung baru.")
		}

		allPorsi := maF(total, "porsi_trx_utama_pct")
		ins = append(ins, maInsight{"info", "Kekuatan brand utama",
			fmt.Sprintf("%s member (%s) hanya punya satu transaksi di periode ini, jadi brand utamanya adalah satu-satunya brand tempat ia belanja. %s member (%s) transaksinya seri di dua brand atau lebih, sehingga brand utamanya ditentukan oleh omzet yang lebih besar. ",
				maInt(maF(total, "satu_transaksi")), maPct(maF(total, "satu_pct")), maInt(maF(total, "seri")), maPct(maF(total, "seri_pct"))) +
				maRank("porsi transaksi member yang terjadi di brand utamanya", porsiBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: &allPorsi})})

		allSpend := maF(total, "spend_per_member")
		ins = append(ins, maInsight{"info", "Nilai member per brand utama",
			maRank("rata-rata belanja per member menurut brand utamanya", spendBV, maRp, maRankOpt{Focus: q.Focus, All: &allSpend}) +
				" Belanja dihitung dari semua brand tempat member itu bertransaksi."})
	}

	notes = append(notes,
		"Tiap member dihitung satu kali di tiap sudut pandang, jadi jumlah semua brand sama dengan jumlah member yang bertransaksi di periode ini.",
		"Brand utama = brand dengan jumlah transaksi terbanyak di periode ini. Bila seri, dipilih brand dengan omzet lebih besar, lalu transaksi paling baru.",
		"Brand utama berbeda dengan brand dominan di tab lain, yang ditentukan dari rupiah belanja terbesar.",
	)
	if q.Meta.HasData {
		notes = append(notes, fmt.Sprintf("Brand pertama = brand pada transaksi pertama member sepanjang riwayat, tidak berubah bila periode diganti. Data transaksi baru mulai %s, jadi transaksi sebelum tanggal itu tidak terbaca.",
			maDateLabel(q.Meta.DataMin)))
	}

	out["rows"] = rows
	out["matrix"] = matrix
	out["months"] = months
	out["trend"] = trend
	out["has_lama"] = hasLama
	out["insights"] = ins
	out["notes"] = notes
	return out, nil
}

// ---------------------------------------------------------------------------
// voucher
// ---------------------------------------------------------------------------

func maSectionVoucher(ctx context.Context, q maReq) (map[string]interface{}, error) {
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_voucher", maArgs(q.Period.f(), q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "voucher", "Voucher yang dibuat "+q.Period.label()+"; status pakai adalah kondisi saat ini", at)

	type grp struct {
		row    maRow
		brands []maRow
	}
	order := []string{}
	groups := map[string]*grp{}
	for _, r := range src {
		key := maS(r, "kategori") + "|" + maS(r, "jenis")
		g, ok := groups[key]
		if !ok {
			g = &grp{}
			groups[key] = g
			order = append(order, key)
		}
		o := maCopy(r)
		o["pakai_pct"] = maPctOf(maF(r, "dipakai"), maF(r, "voucher"))
		o["hangus_pct"] = maPctOf(maF(r, "hangus"), maF(r, "voucher"))
		if maIsTotal(r) {
			g.row = o
		} else {
			g.brands = append(g.brands, o)
		}
	}
	sort.SliceStable(order, func(i, j int) bool {
		return maF(groups[order[i]].row, "voucher") > maF(groups[order[j]].row, "voucher")
	})

	list := make([]maRow, 0, len(order))
	ins := []maInsight{}
	var smallGroups []string
	for _, key := range order {
		g := groups[key]
		if g.row == nil {
			continue
		}
		o := maCopy(g.row)
		if g.brands == nil {
			g.brands = []maRow{}
		}
		o["brands"] = g.brands
		list = append(list, o)

		name := fmt.Sprintf("%s (%s)", maS(g.row, "kategori"), strings.ToLower(maS(g.row, "jenis")))
		n := maF(g.row, "voucher")
		if n < maMinSample {
			smallGroups = append(smallGroups, fmt.Sprintf("%s: %s voucher", name, maInt(n)))
			continue
		}
		var use, miss []maBV
		for _, b := range g.brands {
			use = append(use, maBV{maS(b, "brand"), maF(b, "pakai_pct"), maF(b, "voucher")})
			miss = append(miss, maBV{maS(b, "brand"), maF(b, "belanja_tanpa_pakai"), maF(b, "voucher")})
		}
		pct := maF(g.row, "pakai_pct")
		tone := "info"
		if pct < 10 {
			tone = "warn"
		} else if pct >= 50 {
			tone = "good"
		}
		txt := fmt.Sprintf("%s dari %s voucher dipakai (%s), %s hangus, %s masih berlaku. ",
			maInt(maF(g.row, "dipakai")), maInt(n), maPct(pct), maInt(maF(g.row, "hangus")), maInt(maF(g.row, "aktif"))) +
			maRank("tingkat pakai voucher "+name, use, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, Unit: "voucher"})
		if m := maF(g.row, "belanja_tanpa_pakai"); m > 0 {
			txt += fmt.Sprintf(" %s voucher tidak dipakai padahal pemiliknya belanja selama voucher berlaku.", maInt(m))
			// peringkat kedua hanya kalau minimal dua brand cukup datanya; kalau tidak, kalimat di atas sudah menjelaskannya
			enough := 0
			for _, b := range miss {
				if b.Brand != maNoTxBrand && b.N >= maMinSample {
					enough++
				}
			}
			if enough >= 2 {
				txt += " " + maRank("jumlah voucher yang terlewat seperti itu", miss, maInt, maRankOpt{Unit: "voucher"})
			}
		}
		ins = append(ins, maInsight{tone, "Voucher " + name, txt})
	}

	notes := []string{
		"Brand voucher = brand dominan pemilik voucher dari seluruh riwayat belanjanya. Pemilik voucher yang belum pernah belanja masuk ke \"" + maNoTxBrand + "\" dan tidak diperingkat.",
		"Nilai voucher hanya menjumlahkan voucher bertipe nominal; voucher persentase tidak dijumlahkan.",
	}
	if len(smallGroups) > 0 {
		notes = append(notes, "Tidak dibuat kesimpulan karena jumlahnya kecil: "+strings.Join(smallGroups, "; ")+".")
	}
	if len(list) == 0 {
		notes = append(notes, "Tidak ada voucher yang dibuat pada periode ini.")
	}
	out["groups"] = list
	out["insights"] = ins
	out["notes"] = notes
	return out, nil
}

// ---------------------------------------------------------------------------
// birthday
// ---------------------------------------------------------------------------

func maSectionBirthday(ctx context.Context, q maReq) (map[string]interface{}, error) {
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_birthday", maArgs(maLifecycleFrom, q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "birthday", maBasisLifecycle(q), at)

	keys := []string{"members", "dob_tidak_valid", "members_lolos_email", "ultah", "ultah_lolos_email", "ultah_punya_telp", "ultah_aktif_180", "ultah_tier1_plus"}
	total := maRow{"brand": maTotalBrand, "is_total": 1}
	rows := make([]maRow, 0, len(src)+1)
	days := 30.0
	var cnt, email, emailAll, aktif []maBV
	for _, r := range src {
		o := maCopy(r)
		o["is_total"] = 0
		o["ultah_lolos_email_pct"] = maPctOf(maF(r, "ultah_lolos_email"), maF(r, "ultah"))
		o["ultah_punya_telp_pct"] = maPctOf(maF(r, "ultah_punya_telp"), maF(r, "ultah"))
		o["ultah_aktif_180_pct"] = maPctOf(maF(r, "ultah_aktif_180"), maF(r, "ultah"))
		o["members_lolos_email_pct"] = maPctOf(maF(r, "members_lolos_email"), maF(r, "members"))
		rows = append(rows, o)
		for _, k := range keys {
			total[k] = maF(total, k) + maF(r, k)
		}
		if d := maF(r, "jendela_hari"); d > 0 {
			days = d
		}
		name := maS(r, "brand")
		cnt = append(cnt, maBV{name, maF(r, "ultah"), maF(r, "members")})
		email = append(email, maBV{name, maF(o, "ultah_lolos_email_pct"), maF(r, "ultah")})
		emailAll = append(emailAll, maBV{name, maF(o, "members_lolos_email_pct"), maF(r, "members")})
		aktif = append(aktif, maBV{name, maF(o, "ultah_aktif_180_pct"), maF(r, "ultah")})
	}
	total["ultah_lolos_email_pct"] = maPctOf(maF(total, "ultah_lolos_email"), maF(total, "ultah"))
	total["ultah_punya_telp_pct"] = maPctOf(maF(total, "ultah_punya_telp"), maF(total, "ultah"))
	total["ultah_aktif_180_pct"] = maPctOf(maF(total, "ultah_aktif_180"), maF(total, "ultah"))
	total["members_lolos_email_pct"] = maPctOf(maF(total, "members_lolos_email"), maF(total, "members"))
	total["jendela_hari"] = days
	rows = append(rows, total)

	ins := []maInsight{}
	if u := maF(total, "ultah"); u > 0 {
		allE := maF(total, "ultah_lolos_email_pct")
		ins = append(ins, maInsight{"info", "Ulang tahun terdekat",
			fmt.Sprintf("%s member pembeli berulang tahun dalam %s hari setelah %s. ", maInt(u), maInt(days), maDateLabel(q.Period.To)) +
				maRank("jumlah member yang berulang tahun", cnt, maInt, maRankOpt{Focus: q.Focus})})
		ins = append(ins, maInsight{"warn", "Jangkauan email ulang tahun",
			fmt.Sprintf("Hanya %s dari %s yang lolos syarat email ulang tahun (email dan data tervalidasi), sedangkan %s punya nomor telepon. ",
				maInt(maF(total, "ultah_lolos_email")), maInt(u), maInt(maF(total, "ultah_punya_telp"))) +
				maRank("porsi yang lolos syarat email", email, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: &allE})})
		allA := maF(total, "ultah_aktif_180_pct")
		ins = append(ins, maInsight{"info", "Yang masih aktif belanja",
			maRank("porsi yang berulang tahun dan masih belanja dalam 180 hari terakhir", aktif, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: &allA})})
	}
	if m := maF(total, "members"); m > 0 {
		allM := maF(total, "members_lolos_email_pct")
		ins = append(ins, maInsight{"info", "Validasi email semua member pembeli",
			maRank("porsi member pembeli yang email dan datanya tervalidasi", emailAll, maPct, maRankOpt{Focus: q.Focus, AbsTol: 1, All: &allM})})
	}

	out["rows"] = rows
	out["insights"] = ins
	out["notes"] = []string{
		"Brand = brand dominan member. Hanya member yang pernah belanja dan punya tanggal lahir valid yang dihitung berulang tahun.",
		"Hasil voucher ulang tahun (kategori HBD) ada di bagian Voucher.",
	}
	return out, nil
}

// ---------------------------------------------------------------------------
// tier
// ---------------------------------------------------------------------------

func maSectionTier(ctx context.Context, q maReq) (map[string]interface{}, error) {
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_tier_gap", maArgs(maLifecycleFrom, q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "tier", maBasisLifecycle(q), at)

	gap := 250000.0
	type tier struct {
		row    maRow
		brands map[string]maRow
	}
	var order []float64
	tiers := map[float64]*tier{}
	bMembers := map[string]float64{}
	bDekat := map[string]float64{}
	bDekatAktif := map[string]float64{}
	bHigh := map[string]float64{}
	bLower := map[string]float64{}
	var highFrom float64 = -1
	var highName string
	for _, r := range src {
		if g := maF(r, "gap"); g > 0 {
			gap = g
		}
		id := maF(r, "tier_id")
		t, ok := tiers[id]
		if !ok {
			t = &tier{row: maRow{
				"tier_id": id, "tier_name": maS(r, "tier_name"),
				"amount_from": maF(r, "amount_from"), "next_from": r["next_from"],
			}, brands: map[string]maRow{}}
			tiers[id] = t
			order = append(order, id)
		}
		for _, k := range []string{"members", "omzet", "dekat_naik", "dekat_naik_aktif", "pasif_180", "tier_tercatat_lebih_rendah"} {
			t.row[k] = maF(t.row, k) + maF(r, k)
		}
		b := maS(r, "brand")
		t.brands[b] = r
		bMembers[b] += maF(r, "members")
		bDekat[b] += maF(r, "dekat_naik")
		bDekatAktif[b] += maF(r, "dekat_naik_aktif")
		bLower[b] += maF(r, "tier_tercatat_lebih_rendah")
	}
	sort.Slice(order, func(i, j int) bool {
		return maF(tiers[order[i]].row, "amount_from") < maF(tiers[order[j]].row, "amount_from")
	})
	// "tier menengah ke atas" = tier keempat dari bawah bila ada, supaya mengikuti Master Tier
	if len(order) >= 4 {
		hr := tiers[order[3]].row
		highFrom, highName = maF(hr, "amount_from"), maS(hr, "tier_name")
	}

	list := make([]maRow, 0, len(order))
	var totMembers, totDekat, totDekatAktif, totLower float64
	for _, id := range order {
		t := tiers[id]
		brands := make([]maRow, 0, len(q.Meta.Names))
		for _, name := range q.Meta.Names {
			r := t.brands[name]
			brands = append(brands, maRow{
				"brand": name, "members": maF(r, "members"), "omzet": maF(r, "omzet"),
				"dekat_naik": maF(r, "dekat_naik"), "dekat_naik_aktif": maF(r, "dekat_naik_aktif"),
				"pct_of_brand": maPctOf(maF(r, "members"), bMembers[name]),
			})
			if highFrom >= 0 && maF(t.row, "amount_from") >= highFrom {
				bHigh[name] += maF(r, "members")
			}
		}
		o := maCopy(t.row)
		o["brands"] = brands
		list = append(list, o)
		totMembers += maF(t.row, "members")
		totDekat += maF(t.row, "dekat_naik")
		totDekatAktif += maF(t.row, "dekat_naik_aktif")
		totLower += maF(t.row, "tier_tercatat_lebih_rendah")
	}
	for _, t := range list {
		t["pct_members"] = maPctOf(maF(t, "members"), totMembers)
	}

	brandRows := make([]maRow, 0, len(q.Meta.Names))
	var dekatBV, dekatPct, highBV []maBV
	for _, name := range q.Meta.Names {
		m := bMembers[name]
		brandRows = append(brandRows, maRow{
			"brand": name, "members": m,
			"dekat_naik": bDekat[name], "dekat_naik_aktif": bDekatAktif[name],
			"dekat_naik_aktif_pct":       maPctOf(bDekatAktif[name], m),
			"tier_tinggi":                bHigh[name],
			"tier_tinggi_pct":            maPctOf(bHigh[name], m),
			"tier_tercatat_lebih_rendah": bLower[name],
		})
		dekatBV = append(dekatBV, maBV{name, bDekatAktif[name], m})
		dekatPct = append(dekatPct, maBV{name, maPctOf(bDekatAktif[name], m), m})
		highBV = append(highBV, maBV{name, maPctOf(bHigh[name], m), m})
	}

	ins := []maInsight{}
	notes := []string{
		"Tier di sini dihitung dari total belanja member sampai " + maDateLabel(q.Period.To) + " memakai batas di Master Tier, bukan tier yang tercatat di aplikasi.",
		"Brand = brand dominan member.",
	}
	if totMembers > 0 {
		ins = append(ins, maInsight{"good", "Hampir naik tier",
			fmt.Sprintf("%s member kurang dari %s lagi untuk naik tier; %s di antaranya masih belanja dalam 180 hari terakhir. ",
				maInt(totDekat), maRp(gap), maInt(totDekatAktif)) +
				maRank("jumlah member aktif yang hampir naik tier", dekatBV, maInt, maRankOpt{Focus: q.Focus}) + " " +
				maRank("porsinya terhadap member brand", dekatPct, maPct, maRankOpt{AbsTol: 0.5})})
		if highFrom >= 0 {
			ins = append(ins, maInsight{"info", "Member tier " + highName + " ke atas",
				maRank("porsi member dengan belanja setara tier "+highName+" ke atas (≥ "+maRp(highFrom)+")", highBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 1})})
		}
		if totLower > 0 {
			notes = append(notes, fmt.Sprintf("%s member punya tier tercatat lebih rendah daripada tier menurut total belanjanya. Aturan periode tier perlu dipastikan sebelum angka ini dipakai.", maInt(totLower)))
		}
	}

	out["tiers"] = list
	out["brands"] = brandRows
	out["gap"] = gap
	out["insights"] = ins
	out["notes"] = notes
	return out, nil
}

// ---------------------------------------------------------------------------
// profile
// ---------------------------------------------------------------------------

func maSectionProfile(ctx context.Context, q maReq) (map[string]interface{}, error) {
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_profile", maArgs(q.Period.f(), q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "profile", maBasisPeriod(q), at)

	base := map[string]float64{} // dimensi|brand -> total member
	for _, r := range src {
		base[maS(r, "dimensi")+"|"+maS(r, "brand")] += maF(r, "members")
	}
	rows := make([]maRow, 0, len(src))
	var pBV, olderBV []maBV
	older := map[string]float64{}
	topAge := map[string]maRow{}
	for _, r := range src {
		o := maCopy(r)
		b := maS(r, "brand")
		tot := base[maS(r, "dimensi")+"|"+b]
		o["pct_members"] = maPctOf(maF(r, "members"), tot)
		o["avg_spend"] = maDiv(maF(r, "omzet"), maF(r, "members"))
		rows = append(rows, o)
		if maIsTotal(r) {
			continue
		}
		switch maS(r, "dimensi") {
		case "GENDER":
			if maS(r, "kelompok") == "P" {
				pBV = append(pBV, maBV{b, maF(o, "pct_members"), tot})
			}
		case "UMUR":
			if u := maF(r, "urut"); u >= 4 && u <= 6 {
				older[b] += maF(r, "members")
			}
			if maF(r, "urut") != 9 && (topAge[b] == nil || maF(r, "members") > maF(topAge[b], "members")) {
				topAge[b] = o
			}
		}
	}
	for _, name := range q.Meta.Names {
		if tot := base["UMUR|"+name]; tot > 0 {
			olderBV = append(olderBV, maBV{name, maPctOf(older[name], tot), tot})
		}
	}

	ins := []maInsight{}
	if len(pBV) > 0 {
		ins = append(ins, maInsight{"info", "Gender",
			maRank("porsi member perempuan (kode P)", pBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2})})
	}
	if len(olderBV) > 0 {
		var parts []string
		for _, name := range q.Meta.Names {
			if t := topAge[name]; t != nil && base["UMUR|"+name] >= maMinSample {
				parts = append(parts, fmt.Sprintf("%s %s (%s)", name, maS(t, "kelompok"), maPct(maF(t, "pct_members"))))
			}
		}
		txt := ""
		if len(parts) > 0 {
			txt = "Kelompok umur terbesar tiap brand: " + strings.Join(parts, " · ") + ". "
		}
		ins = append(ins, maInsight{"info", "Umur",
			txt + maRank("porsi member berumur 35 tahun ke atas", olderBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2})})
	}

	out["rows"] = rows
	out["insights"] = ins
	out["notes"] = []string{
		"Member lintas brand terhitung di tiap brand. Umur dihitung per " + maDateLabel(q.Period.To) + "; tanggal lahir kosong atau tidak masuk akal masuk ke \"TIDAK VALID\".",
		"Sebagian tanggal lahir kemungkinan diisi asal (banyak yang jatuh di tanggal seperti 1 Januari), jadi kelompok umur adalah perkiraan.",
	}
	return out, nil
}

// ---------------------------------------------------------------------------
// category
// ---------------------------------------------------------------------------

func maSectionCategory(ctx context.Context, q maReq) (map[string]interface{}, error) {
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_category", maArgs(q.Period.f(), q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "category", maBasisPeriod(q)+", baris barang dengan qty > 0", at)

	qtyBrand := map[string]float64{}
	for _, r := range src {
		qtyBrand[maS(r, "brand")] += maF(r, "qty")
	}
	rows := make([]maRow, 0, len(src))
	top := map[string][]maRow{}
	for _, r := range src {
		o := maCopy(r)
		b := maS(r, "brand")
		o["pct_qty"] = maPctOf(maF(r, "qty"), qtyBrand[b])
		o["harga_rata"] = maDiv(maF(r, "net"), maF(r, "qty"))
		rows = append(rows, o)
		if !maIsTotal(r) {
			top[b] = append(top[b], o)
		}
	}
	ins := []maInsight{}
	var parts []string
	for _, name := range q.Meta.Names {
		list := top[name]
		if len(list) == 0 || (q.Focus != "" && q.Focus != name) {
			continue
		}
		sort.SliceStable(list, func(i, j int) bool { return maF(list[i], "qty") > maF(list[j], "qty") })
		var c []string
		for i := 0; i < len(list) && i < 3; i++ {
			c = append(c, fmt.Sprintf("%s %s", maS(list[i], "kode"), maPct(maF(list[i], "pct_qty"))))
		}
		parts = append(parts, name+": "+strings.Join(c, ", "))
	}
	if len(parts) > 0 {
		ins = append(ins, maInsight{"info", "Kode barang terlaris per brand",
			"Tiga kode barang dengan qty terbesar (porsi dari qty brand) — " + strings.Join(parts, "; ") + "."})
	}

	out["rows"] = rows
	out["insights"] = ins
	out["notes"] = []string{
		"Kode = kata pertama deskripsi barang di struk. Arti tiap kode perlu dikonfirmasi ke tim produk; kolom contoh menampilkan satu deskripsi untuk membantu membacanya.",
	}
	return out, nil
}

// ---------------------------------------------------------------------------
// quality
// ---------------------------------------------------------------------------

func maSectionQuality(ctx context.Context, q maReq) (map[string]interface{}, error) {
	src, at, err := maQuery(ctx, q.Fresh, "xsp_marcomm_analytics_quality", maArgs(maLifecycleFrom, q.Period.t(), ""))
	if err != nil {
		return nil, err
	}
	out := maEnvelope(q, "quality", maBasisLifecycle(q), at)

	keys := []string{"members", "omzet", "akun_perlu_dicek", "omzet_akun_perlu_dicek", "trx_akun_perlu_dicek",
		"tidak_ada_di_master", "dob_tidak_valid", "tanpa_telp", "tanpa_kota", "email_tervalidasi", "suspend"}
	total := maRow{"brand": maTotalBrand, "is_total": 1}
	rows := make([]maRow, 0, len(src)+1)
	minStore, minHari := 8.0, 40.0
	derive := func(o maRow) {
		o["omzet_akun_perlu_dicek_pct"] = maPctOf(maF(o, "omzet_akun_perlu_dicek"), maF(o, "omzet"))
		o["tanpa_kota_pct"] = maPctOf(maF(o, "tanpa_kota"), maF(o, "members"))
		o["email_tervalidasi_pct"] = maPctOf(maF(o, "email_tervalidasi"), maF(o, "members"))
	}
	var cekBV, cekOmz, kotaBV []maBV
	for _, r := range src {
		o := maCopy(r)
		o["is_total"] = 0
		derive(o)
		rows = append(rows, o)
		for _, k := range keys {
			total[k] = maF(total, k) + maF(r, k)
		}
		if v := maF(r, "min_store"); v > 0 {
			minStore = v
		}
		if v := maF(r, "min_hari"); v > 0 {
			minHari = v
		}
		name := maS(r, "brand")
		cekBV = append(cekBV, maBV{name, maF(r, "akun_perlu_dicek"), maF(r, "members")})
		cekOmz = append(cekOmz, maBV{name, maF(o, "omzet_akun_perlu_dicek_pct"), maF(r, "members")})
		kotaBV = append(kotaBV, maBV{name, maF(o, "tanpa_kota_pct"), maF(r, "members")})
	}
	derive(total)
	rows = append(rows, total)

	ins := []maInsight{}
	if maF(total, "members") > 0 {
		if n := maF(total, "akun_perlu_dicek"); n > 0 {
			ins = append(ins, maInsight{"warn", "Akun yang perlu dicek",
				fmt.Sprintf("%s akun belanja di %s store atau lebih, atau punya %s hari belanja atau lebih; omzetnya %s (%s dari omzet member). ",
					maInt(n), maInt(minStore), maInt(minHari), maRp(maF(total, "omzet_akun_perlu_dicek")), maPct(maF(total, "omzet_akun_perlu_dicek_pct"))) +
					maRank("jumlah akun yang perlu dicek", cekBV, maInt, maRankOpt{Focus: q.Focus}) + " " +
					maRank("porsi omzet brand dari akun tersebut", cekOmz, maPct, maRankOpt{AbsTol: 0.5}) +
					" Pola seperti ini bisa berarti kartu dipakai bersama atau dipakai staf; pastikan dulu sebelum diberi treatment VIP."})
		} else {
			ins = append(ins, maInsight{"good", "Akun yang perlu dicek",
				fmt.Sprintf("Tidak ada akun yang belanja di %s store atau lebih atau punya %s hari belanja atau lebih.", maInt(minStore), maInt(minHari))})
		}
		allK := maF(total, "tanpa_kota_pct")
		ins = append(ins, maInsight{"info", "Data kota",
			maRank("porsi member pembeli tanpa data kota", kotaBV, maPct, maRankOpt{Focus: q.Focus, AbsTol: 2, All: &allK})})
	}

	out["rows"] = rows
	out["thresholds"] = maRow{"min_store": minStore, "min_hari": minHari}
	out["insights"] = ins
	out["notes"] = []string{
		"Brand = brand dominan member.",
		"Penurunan transaksi member bisa berasal dari member yang berhenti belanja atau dari kasir yang makin jarang mengisi member; lihat jumlah store pencatat di bagian Tren.",
	}
	return out, nil
}

// ---------------------------------------------------------------------------
// segment-members (daftar member; tidak di-cache karena berisi identitas)
// ---------------------------------------------------------------------------

func maSectionSegmentMembers(ctx context.Context, q maReq, r *http.Request) (map[string]interface{}, error) {
	seg := strings.ToUpper(strings.TrimSpace(marcommQ(r, "segment")))
	if seg != "" && (len(seg) != 1 || seg[0] < 'A' || seg[0] > 'I') {
		return nil, maBadRequest("segmen tidak dikenal: " + seg + " (pakai A sampai I, atau kosongkan untuk semua segmen)")
	}
	page, _ := strconv.Atoi(marcommQ(r, "page"))
	if page < 1 {
		page = 1
	}
	size, _ := strconv.Atoi(marcommQ(r, "page_size"))
	if size < 1 {
		size = 50
	}
	if size > 20000 {
		size = 20000
	}
	rows, err := marcommQuerySP(ctx, "xsp_marcomm_analytics_segment_members", maArgs(maLifecycleFrom, q.Period.t(), q.Focus,
		sql.Named("p_segment", seg),
		sql.Named("p_page", page),
		sql.Named("p_page_size", size),
	)...)
	if err != nil {
		return nil, fmt.Errorf("xsp_marcomm_analytics_segment_members: %w", err)
	}
	if rows == nil {
		rows = []maRow{}
	}
	maNormalize(rows)
	total := 0.0
	for _, row := range rows {
		total = maF(row, "total_rows")
		delete(row, "total_rows")
	}
	out := maEnvelope(q, "segment-members", maBasisLifecycle(q), time.Now())
	out["segment"] = seg
	out["page"] = page
	out["page_size"] = size
	out["total_rows"] = total
	out["rows"] = rows
	return out, nil
}

// maSectionBrandHomeMembers — daftar member tab "Brand member".
// Filter: first = brand pertama, main = brand utama, baru = 1 (member baru) / 0 (member lama); kosong = semua.
// Definisinya sama dengan maSectionBrandHome, jadi jumlah baris = angka di tabel dan matriks tab itu.
func maSectionBrandHomeMembers(ctx context.Context, q maReq, r *http.Request) (map[string]interface{}, error) {
	brand := func(param, label string) (string, error) {
		v := strings.ToUpper(strings.TrimSpace(marcommQ(r, param)))
		if v == "" {
			return "", nil
		}
		for _, n := range q.Meta.Names {
			if n == v {
				return v, nil
			}
		}
		return "", maBadRequest(label + " tidak dikenal: " + v)
	}
	first, err := brand("first", "brand pertama")
	if err != nil {
		return nil, err
	}
	main, err := brand("main", "brand utama")
	if err != nil {
		return nil, err
	}
	baruS := strings.TrimSpace(marcommQ(r, "baru"))
	baru := -1
	switch baruS {
	case "":
	case "1":
		baru = 1
	case "0":
		baru = 0
	default:
		return nil, maBadRequest("baru tidak dikenal: " + baruS + " (pakai 1 untuk member baru, 0 untuk member lama, atau kosongkan)")
	}
	page, _ := strconv.Atoi(marcommQ(r, "page"))
	if page < 1 {
		page = 1
	}
	size, _ := strconv.Atoi(marcommQ(r, "page_size"))
	if size < 1 {
		size = 50
	}
	if size > 20000 {
		size = 20000
	}
	rows, err := marcommQuerySP(ctx, "xsp_marcomm_analytics_brandhome_members",
		sql.Named("p_from_date", q.Period.f()),
		sql.Named("p_to_date", q.Period.t()),
		sql.Named("p_brand_pertama", first),
		sql.Named("p_brand_utama", main),
		sql.Named("p_baru", baru),
		sql.Named("p_page", page),
		sql.Named("p_page_size", size),
	)
	if err != nil {
		return nil, fmt.Errorf("xsp_marcomm_analytics_brandhome_members: %w", err)
	}
	if rows == nil {
		rows = []maRow{}
	}
	maNormalize(rows)
	total := 0.0
	for _, row := range rows {
		total = maF(row, "total_rows")
		delete(row, "total_rows")
	}
	out := maEnvelope(q, "brandhome-members",
		"Member yang bertransaksi "+q.Period.label()+"; brand pertama dibaca dari seluruh riwayat transaksi member", time.Now())
	out["first"] = first
	out["main"] = main
	out["baru"] = baruS
	out["page"] = page
	out["page_size"] = size
	out["total_rows"] = total
	out["rows"] = rows
	return out, nil
}
