package controllers

// DigitalSales — analisa barang marketplace (barang laku, retur, margin, tren).
// Sumber: TR_PRASALES_DETAIL + TR_PRASALES_HEADER + master DT_PLU (+ MARKETPLACE_AR_DETAIL
// sebagai harga realisasi bila sudah diinput). Aturan insight dihitung di sini
// supaya hanya ada satu tempat definisi ambang.

import (
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
)

// paTTL: query artikel cukup berat (~5-7 dtk), jadi cache lebih lama dari dashboard.
const paTTL = 5 * time.Minute

// Ambang insight (dikirim ke FE agar kartu bisa menjelaskan aturannya).
const (
	paReturPct     = 15.0 // retur >= 15% dari qty terjual
	paMarginPct    = 25.0 // margin < 25% (setelah komisi bila ada realisasi AR)
	paDiskonPct    = 30.0 // harga realisasi >= 30% di bawah harga master
	paGrowthUp     = 50.0 // naik >= 50% vs periode sebelumnya
	paGrowthDown   = -40.0
	paOldYears     = 2   // koleksi >= 2 tahun
	paOneMPShare   = 80.0
	paMinARLines   = 3 // minimal baris AR realisasi agar margin/diskon realisasi dipakai
	paTableTop     = 300
	paTableMax     = 800
	paDefaultMinQ  = 5
	paDimTop       = 20
	paArticleCache = "dgs:prod:v1"
)

func paF(v interface{}) float64 {
	switch t := v.(type) {
	case float64:
		return t
	case float32:
		return float64(t)
	case int64:
		return float64(t)
	case int32:
		return float64(t)
	case int:
		return float64(t)
	case string:
		f, _ := strconv.ParseFloat(strings.TrimSpace(t), 64)
		return f
	case []byte:
		f, _ := strconv.ParseFloat(strings.TrimSpace(string(t)), 64)
		return f
	}
	return 0
}

func paS(v interface{}) string {
	switch t := v.(type) {
	case string:
		return strings.TrimSpace(t)
	case []byte:
		return strings.TrimSpace(string(t))
	case nil:
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(v))
}

func paSafe(f float64) float64 {
	if math.IsNaN(f) || math.IsInf(f, 0) {
		return 0
	}
	return f
}

func paRound(f float64, d int) float64 {
	p := math.Pow(10, float64(d))
	return math.Round(paSafe(f)*p) / p
}

const (
	paFromSQL = `
		FROM pos_server.dbo.TR_PRASALES_DETAIL d WITH (NOLOCK)
		INNER JOIN pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK) ON h.ID_PRASALES_HEADER = d.ID_PRASALES_HEADER
		LEFT JOIN pos_server.dbo.DT_PLU p WITH (NOLOCK) ON p.PLU = d.PLU`
	paWhereSQL = `
		WHERE h.TANGGAL_TRANSAKSI BETWEEN CAST(@pf AS date) AND CAST(@t AS date)
		  AND ISNULL(h.STATUS_TRANSAKSI,'0') <> '2'
		  AND (@mp = '' OR h.NAMA_MP = @mp)`
	paCur   = `h.TANGGAL_TRANSAKSI >= CAST(@f AS date)`
	paPrev  = `h.TANGGAL_TRANSAKSI < CAST(@f AS date)`
	paRetur = `d.STATUS IN (2,8,9)`
)

func paSumQty(cond string) string {
	return "SUM(CASE WHEN " + cond + " THEN ISNULL(d.QTY,0) ELSE 0 END)"
}

func paSumF(cond, expr string) string {
	return "CAST(SUM(CASE WHEN " + cond + " THEN " + expr + " ELSE 0 END) AS float)"
}

func paKeyExpr(level string) string {
	if level == "plu" {
		return "d.PLU"
	}
	return "ISNULL(NULLIF(LTRIM(RTRIM(p.ARTICLE)),''), ISNULL(NULLIF(LTRIM(RTRIM(d.ARTICLE)),''), d.PLU))"
}

func paDimExpr(col string) string {
	return "ISNULL(NULLIF(LTRIM(RTRIM(" + col + ")),''),'-')"
}

type paJob struct {
	key string
	sql string
}

func paJobs(level string, allMP bool) []paJob {
	key := paKeyExpr(level)
	dim := func(name, expr string, top int) paJob {
		return paJob{name, fmt.Sprintf(`SELECT TOP %d %s AS k, %s AS qty, %s AS prev_qty,
			%s AS value, %s AS retur_qty
			%s %s GROUP BY %s HAVING %s > 0 ORDER BY %s DESC`,
			top, expr, paSumQty(paCur), paSumQty(paPrev),
			paSumF(paCur, "ISNULL(d.NET,0)"), paSumQty(paCur+" AND "+paRetur),
			paFromSQL, paWhereSQL, expr, paSumQty(paCur), paSumQty(paCur))}
	}

	jobs := []paJob{
		{"articles", fmt.Sprintf(`SELECT %[1]s AS k,
			MAX(CAST(p.DESKRIPSI AS varchar(120))) AS deskripsi, MAX(p.BRAND) AS brand, MAX(p.DEPT) AS dept,
			MAX(p.CLASS) AS cls, MAX(p.TAHUN) AS tahun,
			%[2]s AS qty, %[3]s AS prev_qty,
			%[4]s AS value, %[5]s AS prev_value,
			%[6]s AS retur_qty,
			SUM(CASE WHEN %[8]s THEN 1 ELSE 0 END) AS lines,
			%[9]s AS value_hpp, %[10]s AS hpp_total,
			%[11]s AS ar_sales, %[12]s AS ar_net, %[13]s AS ar_total, %[14]s AS ar_hpp,
			SUM(CASE WHEN %[8]s AND ar.ts > 0 THEN 1 ELSE 0 END) AS ar_lines,
			CONVERT(varchar(10), MAX(CASE WHEN %[8]s THEN h.TANGGAL_TRANSAKSI END), 23) AS last_sale
			FROM pos_server.dbo.TR_PRASALES_DETAIL d WITH (NOLOCK)
			INNER JOIN pos_server.dbo.TR_PRASALES_HEADER h WITH (NOLOCK) ON h.ID_PRASALES_HEADER = d.ID_PRASALES_HEADER
			LEFT JOIN pos_server.dbo.DT_PLU p WITH (NOLOCK) ON p.PLU = d.PLU
			LEFT JOIN (
				SELECT a.ID_TR_SALES_HEADER, a.PLU_KUYA, SUM(a.TOTAL_SALES) AS ts, SUM(a.TOTAL) AS tot
				FROM pos_server.dbo.MARKETPLACE_AR_DETAIL a WITH (NOLOCK)
				WHERE a.TOTAL_SALES > 0 AND a.ID_TR_SALES_HEADER IN (
					SELECT hh.ID_TR_SALES_HEADER FROM pos_server.dbo.TR_PRASALES_HEADER hh WITH (NOLOCK)
					WHERE hh.TANGGAL_TRANSAKSI >= CAST(@f AS date) AND hh.TANGGAL_TRANSAKSI <= CAST(@t AS date)
					  AND hh.ID_TR_SALES_HEADER IS NOT NULL AND (@mp = '' OR hh.NAMA_MP = @mp))
				GROUP BY a.ID_TR_SALES_HEADER, a.PLU_KUYA
			) ar ON ar.ID_TR_SALES_HEADER = h.ID_TR_SALES_HEADER AND ar.PLU_KUYA = d.PLU AND %[8]s
			%[7]s
			GROUP BY %[1]s HAVING %[2]s > 0 OR %[3]s > 0`,
			key, paSumQty(paCur), paSumQty(paPrev),
			paSumF(paCur, "ISNULL(d.NET,0)"), paSumF(paPrev, "ISNULL(d.NET,0)"),
			paSumQty(paCur+" AND "+paRetur),
			paWhereSQL, paCur,
			paSumF(paCur+" AND p.HPP > 0", "ISNULL(d.NET,0)"),
			paSumF(paCur+" AND p.HPP > 0", "p.HPP * ISNULL(d.QTY,0)"),
			paSumF(paCur+" AND ar.ts > 0", "ar.ts"),
			paSumF(paCur+" AND ar.ts > 0", "ISNULL(d.NET,0)"),
			paSumF(paCur+" AND ar.ts > 0 AND p.HPP > 0", "ar.tot"),
			paSumF(paCur+" AND ar.ts > 0 AND p.HPP > 0", "p.HPP * ISNULL(d.QTY,0)"))},
		dim("by_brand", paDimExpr("p.BRAND"), paDimTop),
		dim("by_class", paDimExpr("p.DEPT")+" + ' / ' + "+paDimExpr("p.CLASS"), paDimTop),
		dim("by_warna", paDimExpr("p.WARNA"), paDimTop),
		dim("by_ukuran", paDimExpr("p.UKURAN"), paDimTop),
		dim("by_tahun", paDimExpr("p.TAHUN"), 30),
		{"by_mp", fmt.Sprintf(`SELECT h.NAMA_MP AS k, %s AS qty, %s AS prev_qty, %s AS value, %s AS retur_qty,
			COUNT(DISTINCT CASE WHEN %s THEN %s END) AS articles
			%s %s GROUP BY h.NAMA_MP HAVING %s > 0 ORDER BY %s DESC`,
			paSumQty(paCur), paSumQty(paPrev), paSumF(paCur, "ISNULL(d.NET,0)"), paSumQty(paCur+" AND "+paRetur),
			paCur, key, paFromSQL, paWhereSQL, paSumQty(paCur), paSumQty(paCur))},
		{"daily", fmt.Sprintf(`SELECT CONVERT(varchar(10), h.TANGGAL_TRANSAKSI, 23) AS d, SUM(ISNULL(d.QTY,0)) AS qty,
			%s AS value, SUM(CASE WHEN %s THEN ISNULL(d.QTY,0) ELSE 0 END) AS retur_qty
			%s %s AND %s GROUP BY h.TANGGAL_TRANSAKSI ORDER BY h.TANGGAL_TRANSAKSI`,
			"CAST(SUM(ISNULL(d.NET,0)) AS float)", paRetur, paFromSQL, paWhereSQL, paCur)},
		{"retur_reason", fmt.Sprintf(`SELECT ISNULL(NULLIF(LTRIM(RTRIM(d.KATEGORI_BARANG_KEMBALI)),''),'Belum dikonfirmasi gudang') AS k,
			SUM(ISNULL(d.QTY,0)) AS qty
			%s %s AND %s AND %s
			GROUP BY ISNULL(NULLIF(LTRIM(RTRIM(d.KATEGORI_BARANG_KEMBALI)),''),'Belum dikonfirmasi gudang')
			ORDER BY SUM(ISNULL(d.QTY,0)) DESC`, paFromSQL, paWhereSQL, paCur, paRetur)},
	}
	if allMP {
		jobs = append(jobs, paJob{"key_mp", fmt.Sprintf(`SELECT %s AS k, h.NAMA_MP AS mp, SUM(ISNULL(d.QTY,0)) AS qty
			%s %s AND %s GROUP BY %s, h.NAMA_MP HAVING SUM(ISNULL(d.QTY,0)) > 0`,
			key, paFromSQL, paWhereSQL, paCur, key)})
	}
	return jobs
}

type paArt struct {
	m        map[string]interface{}
	qty      float64
	prevQty  float64
	value    float64
	retur    float64
	flags    []string
	marginP  float64
	hasMg    bool
	basis    string
	discP    float64
	hasDisc  bool
	growth   float64
	hasGrow  bool
	tahun    int
	mpCount  int
	topMP    string
	topShare float64
}

func paYear(s string) int {
	s = strings.TrimSpace(s)
	if len(s) >= 4 {
		if n, err := strconv.Atoi(s[:4]); err == nil && n > 1990 && n < 2100 {
			return n
		}
	}
	return 0
}

// DgsProductAnalysisHandler — GET /dgs/mp/analisa-barang?from_date&to_date&marketplace&level=artikel|plu&min_qty[&refresh=1]
func DgsProductAnalysisHandler() http.HandlerFunc {
	return requireDigitalSales(func(w http.ResponseWriter, r *http.Request, nik string) {
		from, to, err := dgsRange(r)
		if err != nil {
			dgsBad(w, err.Error())
			return
		}
		mp := dgsMP(r)
		q := r.URL.Query()
		level := strings.ToLower(strings.TrimSpace(q.Get("level")))
		if level != "plu" {
			level = "artikel"
		}
		minQ := dgsInt(q.Get("min_qty"), paDefaultMinQ, 1, 1000)

		cacheKey := fmt.Sprintf("%s:%s:%s:%s:%s:%d", paArticleCache, from, to, strings.ToUpper(mp), level, minQ)
		if q.Get("refresh") != "1" && regDashRedis != nil {
			if raw, e := regDashRedis.Get(r.Context(), cacheKey).Bytes(); e == nil && len(raw) > 0 {
				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("X-DGS-Cache", "hit")
				_, _ = w.Write(raw)
				return
			}
		}

		tf, _ := time.Parse("2006-01-02", from)
		tt, _ := time.Parse("2006-01-02", to)
		days := int(tt.Sub(tf).Hours()/24) + 1
		pf := tf.AddDate(0, 0, -days).Format("2006-01-02")

		jobs := paJobs(level, mp == "")
		results := make([][]map[string]interface{}, len(jobs))
		errs := make([]error, len(jobs))
		var wg sync.WaitGroup
		for i := range jobs {
			wg.Add(1)
			go func(i int) {
				defer wg.Done()
				results[i], errs[i] = dgsQuery(r.Context(), jobs[i].sql,
					sql.Named("f", from), sql.Named("pf", pf), sql.Named("t", to), sql.Named("mp", mp))
			}(i)
		}
		wg.Wait()
		res := map[string][]map[string]interface{}{}
		for i, j := range jobs {
			if errs[i] != nil {
				log.Printf("dgs product %s: %v", j.key, errs[i])
				dgsFail(w, "5000005", fmt.Sprintf("gagal memuat analisa barang (%s): %v", j.key, errs[i]))
				return
			}
			res[j.key] = results[i]
		}

		data := paBuild(res, from, to, pf, mp, level, minQ, days)
		body := marshalRbcaJSON(map[string]interface{}{"responseCode": "2002500", "responseMessage": "Success", "data": data})
		if regDashRedis != nil {
			_ = regDashRedis.Set(r.Context(), cacheKey, []byte(body), paTTL).Err()
		}
		w.Header().Set("X-DGS-Cache", "miss")
		writeRbcaJSON(w, body)
	})
}

func paBuild(res map[string][]map[string]interface{}, from, to, pf, mp, level string, minQ, days int) map[string]interface{} {
	now := time.Now().In(dgsWIB())
	minQf := float64(minQ)
	nowYear := now.Year()
	fromT, _ := time.Parse("2006-01-02", from)
	prevTo := fromT.AddDate(0, 0, -1).Format("2006-01-02")

	// MP breakdown per article (only when all marketplaces)
	type mpQty struct {
		mp  string
		qty float64
	}
	byKeyMP := map[string][]mpQty{}
	mpTotals := map[string]float64{}
	for _, row := range res["key_mp"] {
		k := paS(row["k"])
		m := paS(row["mp"])
		qv := paF(row["qty"])
		byKeyMP[k] = append(byKeyMP[k], mpQty{m, qv})
		mpTotals[m] += qv
	}

	var arts []*paArt
	var totQty, totPrevQty, totValue, totPrevValue, totRetur, totLines float64
	var sValueHPP, sHPP, sARSales, sARNet, sARTotal, sARHPP, sARLines float64
	prevArticles := 0
	for _, row := range res["articles"] {
		a := &paArt{m: row}
		a.qty = paF(row["qty"])
		a.prevQty = paF(row["prev_qty"])
		a.value = paF(row["value"])
		a.retur = paF(row["retur_qty"])
		totPrevQty += a.prevQty
		totPrevValue += paF(row["prev_value"])
		if a.prevQty > 0 {
			prevArticles++
		}
		if a.qty <= 0 {
			continue
		}
		totQty += a.qty
		totValue += a.value
		totRetur += a.retur
		totLines += paF(row["lines"])
		sValueHPP += paF(row["value_hpp"])
		sHPP += paF(row["hpp_total"])
		sARSales += paF(row["ar_sales"])
		sARNet += paF(row["ar_net"])
		sARTotal += paF(row["ar_total"])
		sARHPP += paF(row["ar_hpp"])
		sARLines += paF(row["ar_lines"])
		arts = append(arts, a)
	}
	sort.SliceStable(arts, func(i, j int) bool { return arts[i].qty > arts[j].qty })

	// ABC (Pareto) + flags
	cum := 0.0
	aCnt, bCnt, cCnt := 0, 0, 0
	flagCount := map[string]int{}
	flagQty := map[string]float64{}
	for rank, a := range arts {
		cum += a.qty
		cumPct := cum / math.Max(totQty, 1) * 100
		abc := "C"
		prevCum := (cum - a.qty) / math.Max(totQty, 1) * 100
		switch {
		case prevCum < 80:
			abc = "A"
			aCnt++
		case prevCum < 95:
			abc = "B"
			bCnt++
		default:
			cCnt++
		}
		_ = rank
		a.m["cum_pct"] = paRound(cumPct, 1)
		a.m["abc"] = abc
		a.m["share_pct"] = paRound(a.qty/math.Max(totQty, 1)*100, 2)

		// retur
		returPct := a.retur / a.qty * 100
		a.m["retur_pct"] = paRound(returPct, 1)

		// growth
		if a.prevQty > 0 {
			a.growth = (a.qty - a.prevQty) / a.prevQty * 100
			a.hasGrow = true
			a.m["growth_pct"] = paRound(a.growth, 1)
		} else {
			a.m["growth_pct"] = nil
		}

		// margin: realisasi AR (setelah komisi) bila cukup baris, jika tidak harga master
		arLines := paF(a.m["ar_lines"])
		arTotal := paF(a.m["ar_total"])
		if arLines >= paMinARLines && arTotal > 0 {
			a.marginP = (arTotal - paF(a.m["ar_hpp"])) / arTotal * 100
			a.hasMg, a.basis = true, "realisasi"
		} else if v := paF(a.m["value_hpp"]); v > 0 {
			a.marginP = (v - paF(a.m["hpp_total"])) / v * 100
			a.hasMg, a.basis = true, "harga master"
		}
		if a.hasMg {
			a.m["margin_pct"] = paRound(a.marginP, 1)
			a.m["margin_basis"] = a.basis
		} else {
			a.m["margin_pct"] = nil
			a.m["margin_basis"] = ""
		}
		// diskon realisasi vs harga master
		if arNet := paF(a.m["ar_net"]); arLines >= paMinARLines && arNet > 0 {
			a.discP = (1 - paF(a.m["ar_sales"])/arNet) * 100
			a.hasDisc = true
			a.m["disc_pct"] = paRound(a.discP, 1)
		} else {
			a.m["disc_pct"] = nil
		}
		a.tahun = paYear(paS(a.m["tahun"]))

		// marketplace spread
		a.m["mp_count"] = nil
		a.m["top_mp"] = ""
		a.m["top_mp_share"] = nil
		if mp == "" {
			list := byKeyMP[paS(a.m["k"])]
			if len(list) > 0 {
				sum, best := 0.0, mpQty{}
				for _, x := range list {
					sum += x.qty
					if x.qty > best.qty {
						best = x
					}
				}
				a.mpCount = len(list)
				a.topMP = best.mp
				a.topShare = best.qty / math.Max(sum, 1) * 100
				a.m["mp_count"] = a.mpCount
				a.m["top_mp"] = a.topMP
				a.m["top_mp_share"] = paRound(a.topShare, 1)
			}
		}

		// flags
		add := func(f string) {
			a.flags = append(a.flags, f)
			flagCount[f]++
			flagQty[f] += a.qty
		}
		if a.qty >= minQf && returPct >= paReturPct {
			add("RETUR_TINGGI")
		}
		if a.qty >= minQf && a.hasMg && a.marginP < paMarginPct {
			add("MARGIN_TIPIS")
		}
		if a.qty >= minQf && a.hasDisc && a.discP >= paDiskonPct {
			add("DISKON_DALAM")
		}
		if a.qty >= minQf && ((a.hasGrow && a.growth >= paGrowthUp) || (!a.hasGrow && a.qty >= minQf*2)) {
			add("NAIK")
		}
		if a.hasGrow && a.prevQty >= minQf && a.growth <= paGrowthDown {
			add("TURUN")
		}
		if a.qty >= minQf && a.tahun > 0 && a.tahun <= nowYear-paOldYears {
			add("KOLEKSI_LAMA")
		}
		if mp == "" && a.qty >= minQf*2 && a.mpCount == 1 {
			add("SATU_MP")
		}
		fl := make([]interface{}, len(a.flags))
		for i, f := range a.flags {
			fl[i] = f
		}
		a.m["flags"] = fl
	}

	// table rows: top by qty ∪ flagged, capped
	rows := make([]map[string]interface{}, 0, paTableTop)
	for i, a := range arts {
		if i < paTableTop || len(a.flags) > 0 {
			if len(rows) >= paTableMax {
				break
			}
			// drop heavy internals
			for _, k := range []string{"value_hpp", "hpp_total", "ar_sales", "ar_net", "ar_total", "ar_hpp", "lines"} {
				delete(a.m, k)
			}
			rows = append(rows, a.m)
		}
	}

	// Pareto curve (every 5% of articles)
	curve := []map[string]interface{}{{"pct_articles": 0, "pct_qty": 0}}
	if n := len(arts); n > 0 {
		acc := 0.0
		next := 5
		for i, a := range arts {
			acc += a.qty
			pctA := float64(i+1) / float64(n) * 100
			if int(pctA) >= next || i == n-1 {
				curve = append(curve, map[string]interface{}{
					"pct_articles": paRound(pctA, 1), "pct_qty": paRound(acc/math.Max(totQty, 1)*100, 1)})
				for int(pctA) >= next {
					next += 5
				}
			}
		}
	}

	// matrix: top 15 article × marketplace
	mpList := make([]string, 0, len(mpTotals))
	for m := range mpTotals {
		mpList = append(mpList, m)
	}
	sort.Slice(mpList, func(i, j int) bool { return mpTotals[mpList[i]] > mpTotals[mpList[j]] })
	matrix := make([]map[string]interface{}, 0, 15)
	if mp == "" {
		for i, a := range arts {
			if i >= 15 {
				break
			}
			by := map[string]interface{}{}
			for _, x := range byKeyMP[paS(a.m["k"])] {
				by[x.mp] = x.qty
			}
			matrix = append(matrix, map[string]interface{}{
				"k": a.m["k"], "deskripsi": a.m["deskripsi"], "qty": a.qty, "by_mp": by})
		}
	}

	// KPI
	kpi := map[string]interface{}{
		"qty": totQty, "prev_qty": totPrevQty,
		"value": totValue, "prev_value": totPrevValue,
		"articles": len(arts), "prev_articles": prevArticles,
		"retur_qty": totRetur, "retur_pct": paRound(totRetur/math.Max(totQty, 1)*100, 1),
		"lines": totLines, "ar_lines": sARLines,
		"ar_coverage_pct": paRound(sARLines/math.Max(totLines, 1)*100, 1),
		"margin_master_pct": nil, "margin_real_pct": nil, "disc_pct": nil,
		"abc_a": aCnt, "abc_b": bCnt, "abc_c": cCnt,
	}
	if sValueHPP > 0 {
		kpi["margin_master_pct"] = paRound((sValueHPP-sHPP)/sValueHPP*100, 1)
	}
	if sARTotal > 0 {
		kpi["margin_real_pct"] = paRound((sARTotal-sARHPP)/sARTotal*100, 1)
	}
	if sARNet > 0 {
		kpi["disc_pct"] = paRound((1-sARSales/sARNet)*100, 1)
	}

	// insight cards
	type cardDef struct{ key, title, rule, action string }
	defs := []cardDef{
		{"RETUR_TINGGI", "Retur tinggi",
			fmt.Sprintf("Retur >= %.0f%% dari qty terjual", paReturPct),
			"Cek kualitas jahitan/bahan, size chart, dan kesesuaian foto serta deskripsi. Lihat alasan retur gudang."},
		{"MARGIN_TIPIS", "Margin tipis / minus",
			fmt.Sprintf("Margin < %.0f%% (setelah komisi bila AR sudah diinput)", paMarginPct),
			"Tinjau harga jual, subsidi/voucher marketplace, dan HPP. Pertimbangkan naikkan harga atau hentikan promo."},
		{"DISKON_DALAM", "Diskon marketplace dalam",
			fmt.Sprintf("Harga realisasi >= %.0f%% di bawah harga master", paDiskonPct),
			"Cek program diskon, subsidi, dan voucher. Pastikan dalamnya diskon memang disengaja."},
		{"NAIK", "Naik tajam / baru laris",
			fmt.Sprintf("Qty naik >= %.0f%% dari periode sebelumnya, atau baru muncul dengan qty tinggi", paGrowthUp),
			"Pastikan stok dan size tersedia, tambah iklan atau promosi, dan replikasi ke marketplace lain."},
		{"TURUN", "Turun tajam",
			fmt.Sprintf("Qty turun >= %.0f%% dari periode sebelumnya", -paGrowthDown),
			"Cek harga vs kompetitor, rating, stok/size putus, dan faktor musim."},
		{"KOLEKSI_LAMA", "Koleksi lama masih laku",
			fmt.Sprintf("Tahun koleksi <= %d (>= %d tahun)", nowYear-paOldYears, paOldYears),
			"Pertimbangkan re-order atau produksi ulang, atau jadikan produk andalan."},
	}
	if mp == "" {
		defs = append(defs, cardDef{"SATU_MP", "Hanya laku di satu marketplace",
			fmt.Sprintf("Qty >= %d dan hanya terjual di 1 marketplace", minQ*2),
			"Coba listing di marketplace lain, atau cari tahu mengapa tidak laku di marketplace lain."})
	}
	cards := make([]map[string]interface{}, 0, len(defs))
	for _, d := range defs {
		cards = append(cards, map[string]interface{}{
			"key": d.key, "title": d.title, "rule": d.rule, "action": d.action,
			"count": flagCount[d.key], "qty": flagQty[d.key]})
	}

	return map[string]interface{}{
		"from_date": from, "to_date": to, "prev_from_date": pf,
		"prev_to_date": prevTo,
		"days":         days, "marketplace": mp, "level": level, "min_qty": minQ,
		"built_at": now.Format("2006-01-02 15:04:05"),
		"kpi":      kpi, "cards": cards, "articles": rows, "articles_total": len(arts),
		"pareto_curve": curve, "matrix": matrix, "mp_list": mpList,
		"by_brand": res["by_brand"], "by_class": res["by_class"], "by_warna": res["by_warna"],
		"by_ukuran": res["by_ukuran"], "by_tahun": res["by_tahun"], "by_mp": res["by_mp"],
		"daily": res["daily"], "retur_reason": res["retur_reason"],
	}
}
