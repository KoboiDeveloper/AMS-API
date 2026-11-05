package controllers

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"GOamsAPI/database"
)

const nasionalCalcWorkers = 8
const nasionalDetailWorkers = 6

type nasionalEmp struct {
	Nik            string `json:"nik"`
	EmployeeName   string `json:"employee_name"`
	Jabatan        string `json:"jabatan"`
	DeptID         string `json:"dept_id"`
	DepartmentName string `json:"department_name"`
}

type nasionalCounts struct {
	KR, KD, KW, KH int
	TR, TW, TH, TR2 int
	Izin, Sakit, Cuti, Alfa int
	LW, LWK, LHD int
	Nama, Jabatan string
}

// HrdAbsenNasionalList — parallel per-nik calc (no stamp/cache).
func HrdAbsenNasionalList(w http.ResponseWriter, r *http.Request) {
	started := time.Now()
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}

	from := strings.TrimSpace(hrdQuery(r, "from_date"))
	to := strings.TrimSpace(hrdQuery(r, "to_date"))
	cabang := strings.TrimSpace(hrdQuery(r, "id_cabang"))
	if cabang == "" {
		cabang = strings.TrimSpace(hrdQuery(r, "cabang"))
	}
	if cabang == "" {
		cabang = "1"
	}
	group := strings.TrimSpace(hrdQuery(r, "group"))
	if group == "" {
		group = "ALL"
	}
	dept := strings.TrimSpace(hrdQuery(r, "dept"))
	if dept == "" {
		dept = strings.TrimSpace(hrdQuery(r, "department"))
	}
	if dept == "" || strings.EqualFold(dept, "ALL") {
		dept = "216216"
	}
	uid := strings.TrimSpace(hrdQuery(r, "user_id"))
	if uid == "" {
		uid = "portal"
	}
	if from == "" || to == "" {
		writeRbcaJSON(w, rbcaErrorJSON("4002500", "from_date and to_date are required"))
		return
	}

	empJSON := runHrdSP(ctx, "dbo.xsp_ams_new_hrd_absen_report_nasional_emp_getrows",
		sql.Named("p_id_cabang", cabang),
		sql.Named("p_dept", dept),
		sql.Named("p_group", group),
	)
	empJSON = validateRbcaSPResponse(empJSON)
	var empWrap struct {
		ResponseCode string        `json:"responseCode"`
		Message      string        `json:"responseMessage"`
		Data         []nasionalEmp `json:"data"`
	}
	if err := json.Unmarshal([]byte(empJSON), &empWrap); err != nil || empWrap.ResponseCode != "2002500" {
		writeRbcaJSONResponse(w, empJSON, r.Method, "absen_nasional_list")
		return
	}

	if _, err := database.RbcaInstance.ExecContext(ctx,
		`DELETE FROM POS_SERVER.dbo.kehadiran_nasional_report WHERE user_id=@uid`,
		sql.Named("uid", uid),
	); err != nil {
		log.Printf("nasional clear knr: %v", err)
	}

	emps := empWrap.Data
	out := make([]json.RawMessage, len(emps))
	errCh := make(chan string, 1)
	sem := make(chan struct{}, nasionalCalcWorkers)
	var wg sync.WaitGroup

	for i, emp := range emps {
		i, emp := i, emp
		wg.Add(1)
		go func() {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			one := runHrdSP(ctx, "dbo.xsp_ams_new_hrd_absen_report_nasional_calc_nik",
				sql.Named("p_from_date", from),
				sql.Named("p_to_date", to),
				sql.Named("p_nik", emp.Nik),
				sql.Named("p_user_id", uid),
				sql.Named("p_dept", emp.DeptID),
				sql.Named("p_employee_name", emp.EmployeeName),
				sql.Named("p_jabatan", emp.Jabatan),
				sql.Named("p_department_name", emp.DepartmentName),
			)
			one = validateRbcaSPResponse(one)
			var wrap struct {
				ResponseCode string          `json:"responseCode"`
				Message      string          `json:"responseMessage"`
				Data         json.RawMessage `json:"data"`
			}
			if err := json.Unmarshal([]byte(one), &wrap); err != nil || wrap.ResponseCode != "2002500" || len(wrap.Data) == 0 {
				select {
				case errCh <- fmt.Sprintf("calc %s: %s", emp.Nik, wrap.Message):
				default:
				}
				return
			}
			var row map[string]interface{}
			if err := json.Unmarshal(wrap.Data, &row); err == nil {
				row["id"] = i + 1
				row["id_cabang"] = cabang
				row["group"] = group
				row["from_date"] = from
				row["to_date"] = to
				if b, err := json.Marshal(row); err == nil {
					out[i] = b
					return
				}
			}
			out[i] = wrap.Data
		}()
	}
	wg.Wait()

	select {
	case msg := <-errCh:
		writeRbcaJSON(w, rbcaErrorJSON("4002500", msg))
		return
	default:
	}

	rows := make([]json.RawMessage, 0, len(out))
	for _, r := range out {
		if len(r) > 0 {
			rows = append(rows, r)
		}
	}
	payload, _ := json.Marshal(map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "success",
		"data":            rows,
		"meta": map[string]interface{}{
			"elapsed_ms": time.Since(started).Milliseconds(),
			"employees":  len(rows),
			"workers":    nasionalCalcWorkers,
		},
	})
	writeRbcaJSONResponse(w, string(payload), r.Method, "absen_nasional_list")
}

func loadNasionalCounts(ctx context.Context, from, to, nik, uid string) (nasionalCounts, error) {
	var c nasionalCounts
	err := database.RbcaInstance.QueryRowContext(ctx, `
SELECT TOP 1
  ISNULL(kehadiran_reguler,0), ISNULL(kehadiran,0), ISNULL(kehadiran_weekend,0), ISNULL(kehadiran_holiday,0),
  ISNULL(transport,0)+ISNULL(transport2,0)+ISNULL(transport3,0),
  ISNULL(transport_weekend,0), ISNULL(transport_holiday,0), ISNULL(transport2,0),
  ISNULL(izin,0), ISNULL(sakit,0), ISNULL(cuti,0), ISNULL(alfa,0),
  ISNULL(lembur,0), ISNULL(lembur_weekend,0), ISNULL(lembur_holiday,0)
FROM POS_SERVER.dbo.kehadiran_nasional_report WITH (NOLOCK)
WHERE user_id=@uid AND nik=@nik`,
		sql.Named("uid", uid), sql.Named("nik", nik),
	).Scan(&c.KR, &c.KD, &c.KW, &c.KH, &c.TR, &c.TW, &c.TH, &c.TR2, &c.Izin, &c.Sakit, &c.Cuti, &c.Alfa, &c.LW, &c.LWK, &c.LHD)
	if err == sql.ErrNoRows {
		/* counts will stay 0 — section gates skip heavy UDFs */
		err = nil
	}
	if err != nil {
		return c, err
	}
	_ = database.RbcaInstance.QueryRowContext(ctx, `
SELECT TOP 1 a.NamaLengkapStr, f.JabatanStr
FROM hris.dbo.tblpegawai a WITH (NOLOCK)
LEFT JOIN hris.dbo.tblpegawaijabatan b WITH (NOLOCK) ON b.PegawaiIDLng=a.PegawaiIDLng
LEFT JOIN hris.dbo.tbljabatan f WITH (NOLOCK) ON f.JabatanIDLng=b.JabatanIDLng
WHERE a.NomorIndukStr=@nik`,
		sql.Named("nik", nik),
	).Scan(&c.Nama, &c.Jabatan)
	_ = from
	_ = to
	return c, nil
}

func nasionalDetailSection(ctx context.Context, from, to, nik, section string, tr int) string {
	raw := runHrdSP(ctx, "dbo.xsp_ams_new_hrd_absen_report_nasional_detail_section",
		sql.Named("p_from_date", from),
		sql.Named("p_to_date", to),
		sql.Named("p_nik", nik),
		sql.Named("p_section", section),
		sql.Named("p_tr", tr),
	)
	raw = validateRbcaSPResponse(raw)
	var wrap struct {
		ResponseCode string `json:"responseCode"`
		HTML         string `json:"html"`
	}
	if err := json.Unmarshal([]byte(raw), &wrap); err != nil || wrap.ResponseCode != "2002500" {
		return "-"
	}
	if wrap.HTML == "" {
		return "-"
	}
	return wrap.HTML
}

// HrdAbsenNasionalDetail — skip-zero + parallel sections, no cache.
func HrdAbsenNasionalDetail(w http.ResponseWriter, r *http.Request) {
	started := time.Now()
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}

	from := strings.TrimSpace(hrdQuery(r, "from_date"))
	to := strings.TrimSpace(hrdQuery(r, "to_date"))
	group := strings.TrimSpace(hrdQuery(r, "group"))
	if group == "" {
		group = "ALL"
	}
	dept := strings.TrimSpace(hrdQuery(r, "dept"))
	if dept == "" {
		dept = strings.TrimSpace(hrdQuery(r, "department"))
	}
	nik := strings.TrimSpace(hrdQuery(r, "nik"))
	uid := strings.TrimSpace(hrdQuery(r, "user_id"))
	if uid == "" {
		uid = "portal"
	}
	if from == "" || to == "" || nik == "" || dept == "" {
		writeRbcaJSON(w, rbcaErrorJSON("4002500", "from_date, to_date, dept, and nik are required"))
		return
	}

	counts, err := loadNasionalCounts(ctx, from, to, nik, uid)
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}

	type job struct {
		key string
		sec string
		tr  int
		def string
		run bool
	}
	jobs := []job{
		{key: "content_kehadiran_reguler", sec: "kr", run: counts.KR > 0, def: "-"},
		{key: "content_disiplin_wd", sec: "d_wd", run: counts.KD > 0 || counts.TR2 > 0,
			def: `-<br/> <hr class="divider">Special Activity <hr class="divider">-<br/> <hr class="divider">Dinas Weekday <hr class="divider">-<p/>`},
		{key: "content_disiplin_wk", sec: "d_wk", run: counts.KW > 0,
			def: `-<br/> <hr class="divider">Dinas Weekend <hr class="divider">-<p/>`},
		{key: "content_disiplin_hd", sec: "d_hd", run: counts.KH > 0,
			def: `-<br/> <hr class="divider">Dinas Holiday <hr class="divider">-<p/>`},
		{key: "content_transport_wd", sec: "t_wd", tr: counts.TR, run: counts.TR > 0,
			def: `<p> Reguler<hr class="divider">- <hr class="divider">   (In = Out) <hr class="divider">-<br/> <hr class="divider">Special Activity <hr class="divider">-<br/> <hr class="divider">Dinas Weekday <hr class="divider">-<p/>`},
		{key: "content_transport_wk", sec: "t_wk", run: counts.TW > 0,
			def: `-<br/> <hr class="divider">Dinas Weekend <hr class="divider">-<p/>`},
		{key: "content_transport_hd", sec: "t_hd", run: counts.TH > 0,
			def: `-<br/> <hr class="divider">Dinas Holiday <hr class="divider">-<p/>`},
		{key: "content_izin", sec: "izin", run: counts.Izin > 0,
			def: `<p> Tidak Masuk Kerja<hr class="divider">-<br/> <hr class="divider">Telat/Meninggalkan Ruangan <hr class="divider">-<p/>`},
		{key: "content_sakit", sec: "sakit", run: counts.Sakit > 0, def: "-"},
		{key: "content_cuti", sec: "cuti", run: counts.Cuti > 0,
			def: `-<br/> <hr class="divider">Cuti Melahirkan <hr class="divider">-<br/> <hr class="divider">Cuti Khusus <hr class="divider">-`},
		{key: "content_lembur_wd", sec: "l_wd", run: counts.LW > 0, def: "-"},
		{key: "content_lembur_wk", sec: "l_wk", run: counts.LWK > 0, def: "-"},
		{key: "content_lembur_hd", sec: "l_hd", run: counts.LHD > 0, def: "-"},
		{key: "content_alfa", sec: "alfa", run: counts.Alfa > 0, def: "-"},
	}

	htmls := make(map[string]string, len(jobs))
	var mu sync.Mutex
	sem := make(chan struct{}, nasionalDetailWorkers)
	var wg sync.WaitGroup
	for _, j := range jobs {
		j := j
		if !j.run {
			htmls[j.key] = j.def
			continue
		}
		wg.Add(1)
		go func() {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			h := nasionalDetailSection(ctx, from, to, nik, j.sec, j.tr)
			mu.Lock()
			htmls[j.key] = h
			mu.Unlock()
		}()
	}
	wg.Wait()

	data := map[string]interface{}{
		"dept_id":                   dept,
		"nik":                       nik,
		"employee_name":             counts.Nama,
		"jabatan":                   counts.Jabatan,
		"content_kehadiran_reguler": htmls["content_kehadiran_reguler"],
		"content_disiplin_wd":       htmls["content_disiplin_wd"],
		"content_disiplin_wk":       htmls["content_disiplin_wk"],
		"content_disiplin_hd":       htmls["content_disiplin_hd"],
		"content_transport_wd":      htmls["content_transport_wd"],
		"content_transport_wk":      htmls["content_transport_wk"],
		"content_transport_hd":      htmls["content_transport_hd"],
		"content_izin":              htmls["content_izin"],
		"content_sakit":             htmls["content_sakit"],
		"content_cuti":              htmls["content_cuti"],
		"content_lembur_wd":         htmls["content_lembur_wd"],
		"content_lembur_wk":         htmls["content_lembur_wk"],
		"content_lembur_hd":         htmls["content_lembur_hd"],
		"content_alfa":              htmls["content_alfa"],
		"from_date":                 from,
		"to_date":                   to,
		"group":                     group,
	}
	payload, _ := json.Marshal(map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "success",
		"data":            data,
		"meta": map[string]interface{}{
			"elapsed_ms": time.Since(started).Milliseconds(),
		},
	})
	writeRbcaJSONResponse(w, string(payload), r.Method, "absen_nasional_detail")
}
