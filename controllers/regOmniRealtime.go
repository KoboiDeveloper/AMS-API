package controllers

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"

	"GOamsAPI/database"
)

const (
	regOmniRtCachePrefix      = "reg:omni:rt:store:"
	regOmniRtClosingCursorKey = "reg:omni:rt:closing_cursor"
	regOmniRtCacheTTL         = 6 * time.Hour
	regOmniRtBuildTimeout     = 8 * time.Minute
	regOmniRtClosingPollEvery = 90 * time.Second
)

var (
	regOmniRtMu             sync.Mutex
	regOmniRtStarted        bool
	regOmniRtClosingStarted bool
	regOmniRtBuilding       = map[string]bool{}
	regOmniRtWIB            = time.FixedZone("WIB", 7*3600)
)

type regOmniRtCachePayload struct {
	ResponseCode    string        `json:"responseCode"`
	ResponseMessage string        `json:"responseMessage"`
	Data            []interface{} `json:"data"`
	TotalQty        float64       `json:"total_qty"`
	Source          string        `json:"source"`
	BuiltAt         string        `json:"built_at"`
	StoreID         string        `json:"store_id"`
	Brand           string        `json:"brand"`
	Kota            string        `json:"kota"`
	CloseDate       string        `json:"close_date"`
	MovementFrom    string        `json:"movement_from"`
	ClosingUlangAt  string        `json:"closing_ulang_at,omitempty"`
	RowCount        int           `json:"row_count"`
}

func regOmniRtCacheKey(storeID string) string {
	return regOmniRtCachePrefix + strings.ToUpper(strings.TrimSpace(storeID))
}

// RegRptOmniRtHandler — GET /regional/rpt/omni/realtime-stock?store_id=&refresh=
// Reads Redis cache filled by warmer / refresh. Does NOT auto-run slow SQL on miss.
func RegRptOmniRtHandler(w http.ResponseWriter, r *http.Request) {
	storeID := strings.TrimSpace(firstNonEmpty(
		rbcaParam(r, "store_id"),
		rbcaParam(r, "id_store"),
		rbcaParam(r, "store"),
	))
	refresh := strings.EqualFold(rbcaParam(r, "refresh"), "1") ||
		strings.EqualFold(rbcaParam(r, "reload"), "1") ||
		strings.EqualFold(rbcaParam(r, "refresh"), "true")

	if storeID == "" || strings.EqualFold(storeID, "PILIH STORE") || storeID == "0" {
		writeRbcaJSON(w, marshalRbcaJSON(map[string]interface{}{
			"responseCode":    "2002500",
			"responseMessage": "success",
			"data":            []interface{}{},
			"total_qty":       0,
			"source":          "none",
		}))
		return
	}

	if refresh {
		payload, err := rebuildRegOmniRtStore(r.Context(), storeID)
		if err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000005", "gagal rebuild realtime stock: "+err.Error()))
			return
		}
		writeRbcaJSON(w, marshalRbcaJSON(payloadToMap(payload)))
		return
	}

	if cached, ok := getRegOmniRtCache(r.Context(), storeID); ok {
		cached.Source = "cache"
		m := payloadToMap(cached)
		if wm, okWM := fetchRegOmniClosingUlangAt(r.Context(), storeID); okWM {
			if isRegOmniClosingUlangStale(cached.ClosingUlangAt, wm) {
				m["stale"] = true
				m["closing_ulang_at_log"] = wm.In(regOmniRtWIB).Format(time.RFC3339)
				if msg, _ := m["responseMessage"].(string); msg == "" || msg == "success" {
					m["responseMessage"] = "Cache stale setelah closing ulang — rebuild berjalan di background."
				}
				enqueueRegOmniRtRebuild(storeID, "closing-ulang-get")
			}
		}
		writeRbcaJSON(w, marshalRbcaJSON(m))
		return
	}

	building := isRegOmniRtBuilding(storeID)
	msg := "Belum di-cache. Tunggu background warmer atau klik Reload (bisa 2–3 menit)."
	if building {
		msg = "Sedang di-build oleh warmer/reload. Coba lagi sebentar."
	}
	writeRbcaJSON(w, marshalRbcaJSON(map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": msg,
		"data":            []interface{}{},
		"total_qty":       0,
		"source":          "miss",
		"building":        building,
		"store_id":        storeID,
	}))
}

func payloadToMap(p regOmniRtCachePayload) map[string]interface{} {
	m := map[string]interface{}{
		"responseCode":    p.ResponseCode,
		"responseMessage": p.ResponseMessage,
		"data":            p.Data,
		"total_qty":       p.TotalQty,
		"source":          p.Source,
		"built_at":        p.BuiltAt,
		"store_id":        p.StoreID,
		"brand":           p.Brand,
		"kota":            p.Kota,
		"close_date":      p.CloseDate,
		"movement_from":   p.MovementFrom,
		"row_count":       p.RowCount,
	}
	if strings.TrimSpace(p.ClosingUlangAt) != "" {
		m["closing_ulang_at"] = p.ClosingUlangAt
	}
	return m
}

// RegRptOmniRtCacheListHandler — GET /regional/rpt/omni/realtime-stock/cache
// Lists stores already present in Redis cache (optional ?brand=).
func RegRptOmniRtCacheListHandler(w http.ResponseWriter, r *http.Request) {
	brandFilter := strings.ToUpper(strings.TrimSpace(firstNonEmpty(
		rbcaParam(r, "brand"),
		rbcaParam(r, "id_brand"),
	)))
	if brandFilter == "0" || brandFilter == "ALL" || brandFilter == "*" {
		brandFilter = ""
	}

	if regDashRedis == nil {
		writeRbcaJSON(w, rbcaErrorJSON("5030001",
			"Redis API belum connect. Set Coolify env REDIS_URL=rediss://default:***@103.227.145.123:16379/0 lalu redeploy (jangan pakai Redis Cloud lama)."))
		return
	}

	ctx := r.Context()
	rows := make([]map[string]interface{}, 0, 128)
	var cursor uint64
	for {
		keys, next, err := regDashRedis.Scan(ctx, cursor, regOmniRtCachePrefix+"*", 200).Result()
		if err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000005", "gagal scan cache: "+err.Error()))
			return
		}
		for _, key := range keys {
			raw, err := regDashRedis.Get(ctx, key).Bytes()
			if err != nil || len(raw) == 0 {
				continue
			}
			var p regOmniRtCachePayload
			if err := json.Unmarshal(raw, &p); err != nil {
				continue
			}
			storeID := strings.TrimSpace(p.StoreID)
			if storeID == "" {
				storeID = strings.TrimPrefix(key, regOmniRtCachePrefix)
			}
			brand := strings.TrimSpace(p.Brand)
			kota := strings.TrimSpace(p.Kota)
			if brand == "" || kota == "" {
				b, k := brandKotaFromOmniRtData(p.Data)
				if brand == "" {
					brand = b
				}
				if kota == "" {
					kota = k
				}
			}
			if brandFilter != "" && !strings.EqualFold(brand, brandFilter) {
				continue
			}
			rowCount := p.RowCount
			if rowCount == 0 {
				rowCount = len(p.Data)
			}
			row := map[string]interface{}{
				"store_id":      storeID,
				"brand":         brand,
				"kota":          kota,
				"close_date":    p.CloseDate,
				"movement_from": p.MovementFrom,
				"built_at":      p.BuiltAt,
				"total_qty":     p.TotalQty,
				"row_count":     rowCount,
			}
			if strings.TrimSpace(p.ClosingUlangAt) != "" {
				row["closing_ulang_at"] = p.ClosingUlangAt
			}
			rows = append(rows, row)
		}
		cursor = next
		if cursor == 0 {
			break
		}
	}

	// sort by brand, store
	sortOmniRtCacheRows(rows)

	writeRbcaJSON(w, marshalRbcaJSON(map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "success",
		"data":            rows,
		"count":           len(rows),
	}))
}

func brandKotaFromOmniRtData(data []interface{}) (brand, kota string) {
	for _, row := range data {
		m, ok := row.(map[string]interface{})
		if !ok {
			continue
		}
		if brand == "" {
			brand = jsonStringField(m, "brand", "Brand")
		}
		if kota == "" {
			kota = jsonStringField(m, "kota", "Kota")
		}
		if brand != "" && kota != "" {
			return brand, kota
		}
	}
	return brand, kota
}

func sortOmniRtCacheRows(rows []map[string]interface{}) {
	sort.Slice(rows, func(i, j int) bool {
		bi, _ := rows[i]["brand"].(string)
		bj, _ := rows[j]["brand"].(string)
		si, _ := rows[i]["store_id"].(string)
		sj, _ := rows[j]["store_id"].(string)
		biu, bju := strings.ToUpper(bi), strings.ToUpper(bj)
		if biu != bju {
			return biu < bju
		}
		return strings.ToUpper(si) < strings.ToUpper(sj)
	})
}

func jsonStringField(m map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			switch t := v.(type) {
			case string:
				return strings.TrimSpace(t)
			default:
				b, err := json.Marshal(t)
				if err == nil {
					s := strings.Trim(string(b), `"`)
					if s != "null" {
						return s
					}
				}
			}
		}
	}
	return ""
}

func getRegOmniRtCache(ctx context.Context, storeID string) (regOmniRtCachePayload, bool) {
	var out regOmniRtCachePayload
	if regDashRedis == nil {
		return out, false
	}
	raw, err := regDashRedis.Get(ctx, regOmniRtCacheKey(storeID)).Bytes()
	if err != nil || len(raw) == 0 {
		return out, false
	}
	if err := json.Unmarshal(raw, &out); err != nil {
		return out, false
	}
	if out.ResponseCode == "" {
		out.ResponseCode = "2002500"
	}
	return out, true
}

func setRegOmniRtCache(ctx context.Context, payload regOmniRtCachePayload) {
	if regDashRedis == nil {
		return
	}
	b, err := json.Marshal(payload)
	if err != nil {
		return
	}
	_ = regDashRedis.Set(ctx, regOmniRtCacheKey(payload.StoreID), b, regOmniRtCacheTTL).Err()
}

func isRegOmniRtBuilding(storeID string) bool {
	regOmniRtMu.Lock()
	defer regOmniRtMu.Unlock()
	return regOmniRtBuilding[strings.ToUpper(strings.TrimSpace(storeID))]
}

func markRegOmniRtBuilding(storeID string, on bool) bool {
	key := strings.ToUpper(strings.TrimSpace(storeID))
	regOmniRtMu.Lock()
	defer regOmniRtMu.Unlock()
	if on {
		if regOmniRtBuilding[key] {
			return false
		}
		regOmniRtBuilding[key] = true
		return true
	}
	delete(regOmniRtBuilding, key)
	return true
}

func rebuildRegOmniRtStore(parent context.Context, storeID string) (regOmniRtCachePayload, error) {
	if !markRegOmniRtBuilding(storeID, true) {
		// Another build in flight — wait briefly for cache
		deadline := time.Now().Add(30 * time.Second)
		for time.Now().Before(deadline) {
			time.Sleep(2 * time.Second)
			if cached, ok := getRegOmniRtCache(parent, storeID); ok {
				cached.Source = "cache"
				return cached, nil
			}
			if !isRegOmniRtBuilding(storeID) {
				break
			}
		}
		return regOmniRtCachePayload{}, errRegOmniRtBusy
	}
	defer markRegOmniRtBuilding(storeID, false)

	ctx, cancel := context.WithTimeout(context.Background(), regOmniRtBuildTimeout)
	defer cancel()

	args := make([]interface{}, 0, len(regListParamKeys))
	for _, key := range regListParamKeys {
		switch key {
		case "store_id", "id_store":
			args = append(args, sql.Named("p_"+key, parseOptionalString(storeID)))
		default:
			args = append(args, sql.Named("p_"+key, nil))
		}
	}
	jsonResult := runRegSP(ctx, "xsp_ams_new_reg_rpt_omni_rt_getrows", args...)
	if strings.TrimSpace(jsonResult) == "" {
		return regOmniRtCachePayload{}, errRegOmniRtEmpty
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &parsed); err != nil {
		return regOmniRtCachePayload{}, err
	}
	code, _ := parsed["responseCode"].(string)
	if code != "" && code != "2002500" {
		msg, _ := parsed["responseMessage"].(string)
		if msg == "" {
			msg = "SP error"
		}
		return regOmniRtCachePayload{}, &regOmniRtError{msg}
	}

	data := []interface{}{}
	switch v := parsed["data"].(type) {
	case []interface{}:
		data = v
	case nil:
		data = []interface{}{}
	}

	totalQty := 0.0
	switch v := parsed["total_qty"].(type) {
	case float64:
		totalQty = v
	case json.Number:
		f, _ := v.Float64()
		totalQty = f
	case string:
		var f float64
		_ = json.Unmarshal([]byte(v), &f)
		totalQty = f
	default:
		for _, row := range data {
			m, ok := row.(map[string]interface{})
			if !ok {
				continue
			}
			switch q := m["qty"].(type) {
			case float64:
				totalQty += q
			}
		}
	}

	brand, kota := brandKotaFromOmniRtData(data)
	closingUlangAt := ""
	if wm, ok := fetchRegOmniClosingUlangAt(ctx, storeID); ok {
		closingUlangAt = wm.In(regOmniRtWIB).Format(time.RFC3339)
	}
	payload := regOmniRtCachePayload{
		ResponseCode:    "2002500",
		ResponseMessage: "success",
		Data:            data,
		TotalQty:        totalQty,
		Source:          "sql",
		BuiltAt:         time.Now().In(regOmniRtWIB).Format(time.RFC3339),
		StoreID:         strings.ToUpper(strings.TrimSpace(storeID)),
		Brand:           brand,
		Kota:            kota,
		CloseDate:       jsonStringField(parsed, "close_date", "CLOSE_DATE"),
		MovementFrom:    jsonStringField(parsed, "movement_from", "MOVEMENT_FROM"),
		ClosingUlangAt:  closingUlangAt,
		RowCount:        len(data),
	}
	setRegOmniRtCache(ctx, payload)
	return payload, nil
}

type regOmniRtError struct{ msg string }

func (e *regOmniRtError) Error() string { return e.msg }

var (
	errRegOmniRtBusy  = &regOmniRtError{"rebuild sedang berjalan untuk store ini"}
	errRegOmniRtEmpty = &regOmniRtError{"empty response from database"}
)

func fetchRegOmniClosingUlangAt(ctx context.Context, storeID string) (time.Time, bool) {
	if database.Instance == nil {
		return time.Time{}, false
	}
	storeID = strings.TrimSpace(storeID)
	if storeID == "" {
		return time.Time{}, false
	}
	var ts sql.NullTime
	err := database.Instance.QueryRowContext(ctx, `
		SELECT MAX(TANGGAL_CLOSING)
		FROM dbo.LOG_CLOSING_ULANG WITH (NOLOCK)
		WHERE STORE_ID = @store
	`, sql.Named("store", storeID)).Scan(&ts)
	if err != nil || !ts.Valid {
		return time.Time{}, false
	}
	return ts.Time, true
}

func fetchRegOmniClosingUlangGlobalMax(ctx context.Context) (time.Time, bool) {
	if database.Instance == nil {
		return time.Time{}, false
	}
	var ts sql.NullTime
	err := database.Instance.QueryRowContext(ctx, `
		SELECT MAX(TANGGAL_CLOSING)
		FROM dbo.LOG_CLOSING_ULANG WITH (NOLOCK)
	`).Scan(&ts)
	if err != nil || !ts.Valid {
		return time.Time{}, false
	}
	return ts.Time, true
}

type regOmniClosingUlangEvent struct {
	StoreID string
	At      time.Time
}

func listRegOmniClosingUlangSince(ctx context.Context, since time.Time) ([]regOmniClosingUlangEvent, error) {
	out := make([]regOmniClosingUlangEvent, 0)
	if database.Instance == nil {
		return out, nil
	}
	rows, err := database.Instance.QueryContext(ctx, `
		SELECT STORE_ID, MAX(TANGGAL_CLOSING) AS ts
		FROM dbo.LOG_CLOSING_ULANG WITH (NOLOCK)
		WHERE TANGGAL_CLOSING > @since
		GROUP BY STORE_ID
		ORDER BY MAX(TANGGAL_CLOSING)
	`, sql.Named("since", since))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var sid string
		var ts time.Time
		if err := rows.Scan(&sid, &ts); err != nil {
			continue
		}
		sid = strings.TrimSpace(sid)
		if sid == "" {
			continue
		}
		out = append(out, regOmniClosingUlangEvent{StoreID: sid, At: ts})
	}
	return out, rows.Err()
}

func parseRegOmniRtTime(s string) (time.Time, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Time{}, false
	}
	formats := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02 15:04:05.9999999",
		"2006-01-02 15:04:05.999",
		"2006-01-02 15:04:05",
		"2006-01-02T15:04:05",
	}
	for _, f := range formats {
		if t, err := time.ParseInLocation(f, s, regOmniRtWIB); err == nil {
			return t, true
		}
		if t, err := time.Parse(f, s); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

func isRegOmniClosingUlangStale(cacheAt string, logAt time.Time) bool {
	if logAt.IsZero() {
		return false
	}
	cached, ok := parseRegOmniRtTime(cacheAt)
	if !ok {
		return true
	}
	// allow tiny clock skew
	return logAt.After(cached.Add(500 * time.Millisecond))
}

func getRegOmniClosingCursor(ctx context.Context) (time.Time, bool) {
	if regDashRedis == nil {
		return time.Time{}, false
	}
	raw, err := regDashRedis.Get(ctx, regOmniRtClosingCursorKey).Result()
	if err != nil || strings.TrimSpace(raw) == "" {
		return time.Time{}, false
	}
	return parseRegOmniRtTime(raw)
}

func setRegOmniClosingCursor(ctx context.Context, t time.Time) {
	if regDashRedis == nil || t.IsZero() {
		return
	}
	_ = regDashRedis.Set(ctx, regOmniRtClosingCursorKey, t.UTC().Format(time.RFC3339Nano), 0).Err()
}

func enqueueRegOmniRtRebuild(storeID, reason string) {
	storeID = strings.TrimSpace(storeID)
	if storeID == "" {
		return
	}
	go func(sid, why string) {
		start := time.Now()
		_, err := rebuildRegOmniRtStore(context.Background(), sid)
		if err != nil {
			log.Printf("reg omni rt rebuild (%s): %s FAIL %v (%s)", why, sid, err, time.Since(start).Round(time.Second))
			return
		}
		log.Printf("reg omni rt rebuild (%s): %s OK (%s)", why, sid, time.Since(start).Round(time.Second))
	}(storeID, reason)
}

// StartRegOmniClosingUlangPoller watches LOG_CLOSING_ULANG and rebuilds affected store caches.
func StartRegOmniClosingUlangPoller() {
	regOmniRtMu.Lock()
	if regOmniRtClosingStarted {
		regOmniRtMu.Unlock()
		return
	}
	regOmniRtClosingStarted = true
	regOmniRtMu.Unlock()

	go func() {
		log.Printf("reg omni rt closing-ulang poller: started (every %s)", regOmniRtClosingPollEvery)
		for {
			if regDashRedis == nil || database.Instance == nil {
				time.Sleep(30 * time.Second)
				continue
			}
			ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
			cursor, ok := getRegOmniClosingCursor(ctx)
			if !ok {
				if mx, okMx := fetchRegOmniClosingUlangGlobalMax(ctx); okMx {
					setRegOmniClosingCursor(ctx, mx)
					log.Printf("reg omni rt closing-ulang poller: init cursor=%s", mx.In(regOmniRtWIB).Format(time.RFC3339))
				}
				cancel()
				time.Sleep(regOmniRtClosingPollEvery)
				continue
			}

			events, err := listRegOmniClosingUlangSince(ctx, cursor)
			cancel()
			if err != nil {
				log.Printf("reg omni rt closing-ulang poller: query FAIL %v", err)
				time.Sleep(regOmniRtClosingPollEvery)
				continue
			}
			if len(events) == 0 {
				time.Sleep(regOmniRtClosingPollEvery)
				continue
			}

			maxSeen := cursor
			for _, ev := range events {
				if ev.At.After(maxSeen) {
					maxSeen = ev.At
				}
				cached, hit := getRegOmniRtCache(context.Background(), ev.StoreID)
				if hit && !isRegOmniClosingUlangStale(cached.ClosingUlangAt, ev.At) {
					continue
				}
				// Only rebuild stores we already cache (or always rebuild — prefer always so warmer seed is fresh)
				log.Printf("reg omni rt closing-ulang: store=%s at=%s → rebuild",
					ev.StoreID, ev.At.In(regOmniRtWIB).Format(time.RFC3339))
				start := time.Now()
				_, err := rebuildRegOmniRtStore(context.Background(), ev.StoreID)
				if err != nil {
					log.Printf("reg omni rt closing-ulang: %s FAIL %v (%s)", ev.StoreID, err, time.Since(start).Round(time.Second))
				} else {
					log.Printf("reg omni rt closing-ulang: %s OK (%s)", ev.StoreID, time.Since(start).Round(time.Second))
				}
				time.Sleep(1 * time.Second)
			}
			if maxSeen.After(cursor) {
				setRegOmniClosingCursor(context.Background(), maxSeen)
			}
			time.Sleep(regOmniRtClosingPollEvery)
		}
	}()
}

// StartRegOmniRealtimeWarmer rolls through active stores, rebuilds Redis cache one at a time.
func StartRegOmniRealtimeWarmer() {
	regOmniRtMu.Lock()
	if regOmniRtStarted {
		regOmniRtMu.Unlock()
		return
	}
	regOmniRtStarted = true
	regOmniRtMu.Unlock()

	go func() {
		log.Printf("reg omni rt warmer: started (serial, TTL=%s)", regOmniRtCacheTTL)
		for {
			if regDashRedis == nil {
				time.Sleep(30 * time.Second)
				continue
			}
			stores := listRegOmniRtStoreIDs()
			if len(stores) == 0 {
				log.Printf("reg omni rt warmer: no stores, sleep 5m")
				time.Sleep(5 * time.Minute)
				continue
			}
			for _, sid := range stores {
				if regDashRedis == nil {
					break
				}
				// Skip if cache still fresh enough (< half TTL)
				if cached, ok := getRegOmniRtCache(context.Background(), sid); ok && cached.BuiltAt != "" {
					if t, err := time.Parse(time.RFC3339, cached.BuiltAt); err == nil {
						if time.Since(t) < regOmniRtCacheTTL/2 {
							continue
						}
					}
				}
				start := time.Now()
				_, err := rebuildRegOmniRtStore(context.Background(), sid)
				if err != nil {
					log.Printf("reg omni rt warmer: %s FAIL %v (%s)", sid, err, time.Since(start).Round(time.Second))
				} else {
					log.Printf("reg omni rt warmer: %s OK (%s)", sid, time.Since(start).Round(time.Second))
				}
				// tiny pause between stores
				time.Sleep(2 * time.Second)
			}
			// after full pass, brief pause before rolling again
			time.Sleep(1 * time.Minute)
		}
	}()
}

func listRegOmniRtStoreIDs() []string {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Prefer POS DB — active stores with kota label source
	if database.Instance != nil {
		rows, err := database.Instance.QueryContext(ctx, `
			SELECT TOP (800) Store_ID
			FROM dbo.DT_Store WITH (NOLOCK)
			WHERE Store_ID IS NOT NULL
			  AND LTRIM(RTRIM(Store_ID)) <> ''
			  AND UPPER(LTRIM(RTRIM(ISNULL(Store_Brand_ID, '')))) NOT IN (
			      'AEESHA','ART VISUAL','CELCIUS KIDS','DC','DC OLD','GA',
			      'MINISTORE','POS TES','KW2','WOL','TEST'
			  )
			ORDER BY Store_ID
		`)
		if err == nil && rows != nil {
			defer rows.Close()
			out := make([]string, 0, 256)
			for rows.Next() {
				var id string
				if err := rows.Scan(&id); err != nil {
					continue
				}
				id = strings.TrimSpace(id)
				if id != "" {
					out = append(out, id)
				}
			}
			if len(out) > 0 {
				return out
			}
		}
	}

	// Fallback: RBCA lookup SP
	jsonResult := runRegSP(ctx, "xsp_ams_new_reg_lookup_getrows",
		sql.Named("p_type", "store_all"),
		sql.Named("p_keywords", nil),
		sql.Named("p_parent_id", nil),
		sql.Named("p_actor_nik", nil),
	)
	var parsed map[string]interface{}
	if err := json.Unmarshal([]byte(jsonResult), &parsed); err != nil {
		return nil
	}
	data, _ := parsed["data"].([]interface{})
	out := make([]string, 0, len(data))
	for _, row := range data {
		m, ok := row.(map[string]interface{})
		if !ok {
			continue
		}
		v, _ := m["value"].(string)
		v = strings.TrimSpace(v)
		if v != "" {
			out = append(out, v)
		}
	}
	return out
}
