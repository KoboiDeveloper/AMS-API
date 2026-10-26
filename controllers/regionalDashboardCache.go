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

	"github.com/go-redis/redis/v8"
)

const (
	regDashNotifyChannel = "reg:dash:notify"
	regDashActiveBrands  = "reg:dash:active_brands"
	regDashSnapTTL       = 120 * time.Second
	regDashMetaTTL       = 180 * time.Second
	regDashTickerMax     = 50
)

var (
	regDashRedis   *redis.Client
	regDashMu      sync.Mutex
	regDashStarted bool
)

// InitRegionalDashboardCache wires Redis for regional live dashboard.
func InitRegionalDashboardCache(rdb *redis.Client) {
	regDashRedis = rdb
}

func regDashBrandKey(brand string) string {
	b := strings.TrimSpace(strings.ToUpper(brand))
	if b == "" || b == "ALL" || b == "0" {
		return "ALL"
	}
	return b
}

func regDashAsOf(ymd string) string {
	ymd = strings.TrimSpace(ymd)
	if ymd == "" {
		return time.Now().Format("2006-01-02")
	}
	if t, err := time.Parse("2006-01-02", ymd); err == nil {
		return t.Format("2006-01-02")
	}
	return time.Now().Format("2006-01-02")
}

func regDashSnapKey(brand, asof string) string {
	return fmt.Sprintf("reg:dash:snap:%s:%s", brand, asof)
}

func regDashMapKey(brand, asof string) string {
	return fmt.Sprintf("reg:dash:map:%s:%s", brand, asof)
}

func regDashTickerKey(brand string) string {
	return fmt.Sprintf("reg:dash:ticker:%s", brand)
}

func regDashMetaKey(brand string) string {
	return fmt.Sprintf("reg:dash:meta:%s", brand)
}

func markRegDashBrandActive(ctx context.Context, brand string) {
	if regDashRedis == nil {
		return
	}
	_ = regDashRedis.SAdd(ctx, regDashActiveBrands, brand).Err()
	_ = regDashRedis.Expire(ctx, regDashActiveBrands, 24*time.Hour).Err()
}

func fetchDashboardFromSP(ctx context.Context, fromDate, toDate, brand, actor string) (map[string]interface{}, string, error) {
	const spName = "xsp_ams_new_reg_dashboard_summary_getrow"
	jsonResult := runRegSP(ctx, spName,
		sql.Named("p_from_date", parseOptionalString(fromDate)),
		sql.Named("p_to_date", parseOptionalString(toDate)),
		sql.Named("p_id_brand", parseOptionalString(brand)),
		sql.Named("p_id_cabang", parseOptionalString("")),
		sql.Named("p_actor_nik", parseOptionalString(actor)),
	)
	if strings.TrimSpace(jsonResult) == "" {
		return nil, "", fmt.Errorf("empty SP response")
	}
	validated := validateRbcaSPResponse(jsonResult)
	var envelope map[string]interface{}
	if err := json.Unmarshal([]byte(validated), &envelope); err != nil {
		return nil, validated, err
	}
	code, _ := envelope["responseCode"].(string)
	if code != "" && !strings.HasPrefix(code, "200") {
		msg, _ := envelope["responseMessage"].(string)
		return nil, validated, fmt.Errorf("%s", msg)
	}
	dataRaw, ok := envelope["data"]
	if !ok || dataRaw == nil {
		return map[string]interface{}{}, validated, nil
	}
	switch d := dataRaw.(type) {
	case map[string]interface{}:
		return d, validated, nil
	case []interface{}:
		if len(d) > 0 {
			if m, ok := d[0].(map[string]interface{}); ok {
				return m, validated, nil
			}
		}
	}
	return map[string]interface{}{}, validated, nil
}

func storeRegDashSnapshot(ctx context.Context, brand, asof string, data map[string]interface{}, lagMs int64) error {
	if regDashRedis == nil {
		return nil
	}
	started := time.Now()

	mapPayload := map[string]interface{}{
		"as_of":        asof,
		"map_pulau":    data["map_pulau"],
		"map_kota":     data["map_kota"],
		"map_hotspots": data["map_hotspots"],
	}
	snapBytes, err := json.Marshal(data)
	if err != nil {
		return err
	}
	mapBytes, err := json.Marshal(mapPayload)
	if err != nil {
		return err
	}

	pipe := regDashRedis.Pipeline()
	pipe.Set(ctx, regDashSnapKey(brand, asof), snapBytes, regDashSnapTTL)
	pipe.Set(ctx, regDashMapKey(brand, asof), mapBytes, regDashSnapTTL)

	meta := map[string]interface{}{
		"brand":        brand,
		"as_of":        asof,
		"refreshed_at": time.Now().UTC().Format(time.RFC3339),
		"version":      time.Now().UnixNano(),
		"lag_ms":       lagMs,
	}
	metaBytes, _ := json.Marshal(meta)
	pipe.Set(ctx, regDashMetaKey(brand), metaBytes, regDashMetaTTL)

	// Ticker LIST — newest first
	tickerKey := regDashTickerKey(brand)
	if raw, ok := data["ticker"]; ok && raw != nil {
		pipe.Del(ctx, tickerKey)
		switch arr := raw.(type) {
		case []interface{}:
			for i := len(arr) - 1; i >= 0; i-- {
				b, mErr := json.Marshal(arr[i])
				if mErr == nil {
					pipe.LPush(ctx, tickerKey, string(b))
				}
			}
			pipe.LTrim(ctx, tickerKey, 0, int64(regDashTickerMax-1))
			pipe.Expire(ctx, tickerKey, regDashSnapTTL)
		}
	}

	notify := map[string]interface{}{
		"brand":        brand,
		"as_of":        asof,
		"refreshed_at": meta["refreshed_at"],
		"lag_ms":       lagMs,
		"built_ms":     time.Since(started).Milliseconds(),
	}
	notifyBytes, _ := json.Marshal(notify)
	pipe.Publish(ctx, regDashNotifyChannel, string(notifyBytes))

	_, err = pipe.Exec(ctx)
	return err
}

func loadRegDashFromRedis(ctx context.Context, brand, asof string) (map[string]interface{}, map[string]interface{}, bool) {
	if regDashRedis == nil {
		return nil, nil, false
	}
	snap, err := regDashRedis.Get(ctx, regDashSnapKey(brand, asof)).Bytes()
	if err != nil || len(snap) == 0 {
		return nil, nil, false
	}
	var data map[string]interface{}
	if err := json.Unmarshal(snap, &data); err != nil {
		return nil, nil, false
	}
	meta := map[string]interface{}{}
	if mb, err := regDashRedis.Get(ctx, regDashMetaKey(brand)).Bytes(); err == nil {
		_ = json.Unmarshal(mb, &meta)
	}
	meta["cache"] = "hit"
	return data, meta, true
}

func refreshRegDashBrand(ctx context.Context, brand, asof, actor string) error {
	brandKey := regDashBrandKey(brand)
	asof = regDashAsOf(asof)
	spBrand := ""
	if brandKey != "ALL" {
		spBrand = brandKey
	}
	t0 := time.Now()
	data, _, err := fetchDashboardFromSP(ctx, asof, asof, spBrand, actor)
	if err != nil {
		return err
	}
	lag := time.Since(t0).Milliseconds()
	if err := storeRegDashSnapshot(ctx, brandKey, asof, data, lag); err != nil {
		return err
	}
	markRegDashBrandActive(ctx, brandKey)
	log.Printf("reg-dash refresh brand=%s asof=%s lag_ms=%d", brandKey, asof, lag)
	return nil
}

// StartRegionalDashboardRefresher periodically refreshes active brands (and ALL).
func StartRegionalDashboardRefresher(interval time.Duration) {
	regDashMu.Lock()
	if regDashStarted || regDashRedis == nil {
		regDashMu.Unlock()
		return
	}
	regDashStarted = true
	regDashMu.Unlock()

	if interval < 10*time.Second {
		interval = 20 * time.Second
	}

	// Seed ALL brand
	ctx := context.Background()
	markRegDashBrandActive(ctx, "ALL")
	_ = refreshRegDashBrand(ctx, "ALL", time.Now().Format("2006-01-02"), "")

	ticker := time.NewTicker(interval)
	for range ticker.C {
		listCtx, listCancel := context.WithTimeout(context.Background(), 5*time.Second)
		brands, err := regDashRedis.SMembers(listCtx, regDashActiveBrands).Result()
		listCancel()
		if err != nil || len(brands) == 0 {
			brands = []string{"ALL"}
		}
		// Cap work per tick — avoid one shared deadline killing every brand.
		if len(brands) > 6 {
			brands = brands[:6]
		}
		asof := time.Now().Format("2006-01-02")
		for _, b := range brands {
			bCtx, bCancel := context.WithTimeout(context.Background(), 55*time.Second)
			if err := refreshRegDashBrand(bCtx, b, asof, ""); err != nil {
				log.Printf("reg-dash refresh error brand=%s: %v", b, err)
			}
			bCancel()
		}
	}
}

func buildDashboardEnvelope(data map[string]interface{}, meta map[string]interface{}) string {
	if meta == nil {
		meta = map[string]interface{}{}
	}
	out := map[string]interface{}{}
	for k, v := range data {
		out[k] = v
	}
	out["_meta"] = meta
	payload := map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "success",
		"data":            out,
	}
	b, err := json.Marshal(payload)
	if err != nil {
		return rbcaErrorJSON("5000005", err.Error())
	}
	return string(b)
}

// RegionalDashboardSummary — Redis-first warm path; SQL fallback + warm cache.
func RegionalDashboardSummary(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if ctx == nil {
		ctx = context.Background()
	}
	fromDate := firstNonEmpty(regQuery(r, "from_date"), regQuery(r, "to_date"))
	toDate := firstNonEmpty(regQuery(r, "to_date"), fromDate)
	brandRaw := firstNonEmpty(regQuery(r, "id_brand"), rbcaParam(r, "brand"))
	brand := regDashBrandKey(brandRaw)
	asof := regDashAsOf(toDate)
	actor := regActor(r)
	force := strings.EqualFold(regQuery(r, "force"), "1") || strings.EqualFold(regQuery(r, "nocache"), "1")

	markRegDashBrandActive(ctx, brand)

	if !force {
		if data, meta, ok := loadRegDashFromRedis(ctx, brand, asof); ok {
			writeRbcaJSON(w, buildDashboardEnvelope(data, meta))
			return
		}
	}

	if force {
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		spBrand := ""
		if brand != "ALL" {
			spBrand = brand
		}
		spCtx, spCancel := context.WithTimeout(context.Background(), 55*time.Second)
		defer spCancel()
		t0 := time.Now()
		data, raw, err := fetchDashboardFromSP(spCtx, fromDate, toDate, spBrand, actor)
		if err != nil {
			if strings.TrimSpace(raw) != "" {
				writeRegSPResponse(w, r, "xsp_ams_new_reg_dashboard_summary_getrow", raw)
				return
			}
			writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
			return
		}
		lag := time.Since(t0).Milliseconds()
		_ = storeRegDashSnapshot(ctx, brand, asof, data, lag)
		writeRbcaJSON(w, buildDashboardEnvelope(data, map[string]interface{}{
			"cache":        "miss",
			"lag_ms":       lag,
			"refreshed_at": time.Now().UTC().Format(time.RFC3339),
			"brand":        brand,
			"as_of":        asof,
		}))
		return
	}

	// Cache miss: warm in background — don't block UI 60s+ on brand switch.
	go func() {
		warmCtx, cancel := context.WithTimeout(context.Background(), 55*time.Second)
		defer cancel()
		_ = refreshRegDashBrand(warmCtx, brand, asof, actor)
	}()

	writeRbcaJSON(w, buildDashboardEnvelope(map[string]interface{}{
		"as_of":              asof,
		"active_store_count": 0,
		"sales_today":        0,
		"sales_7d":           []interface{}{},
		"stores_top":         []interface{}{},
		"map_pulau":          []interface{}{},
		"map_kota":           []interface{}{},
		"map_hotspots":       []interface{}{},
		"ticker":             []interface{}{},
	}, map[string]interface{}{
		"cache":         "warming",
		"brand":         brand,
		"as_of":         asof,
		"refreshed_at":  time.Now().UTC().Format(time.RFC3339),
		"warming_brand": brand,
	}))
}

// RegionalDashboardStream — SSE: push snapshot when Redis notifies refresh for brand.
func RegionalDashboardStream(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}
	brand := regDashBrandKey(firstNonEmpty(regQuery(r, "id_brand"), rbcaParam(r, "brand")))
	asof := regDashAsOf(firstNonEmpty(regQuery(r, "to_date"), regQuery(r, "from_date")))
	markRegDashBrandActive(r.Context(), brand)

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	writeSSE := func(event string, payload interface{}) {
		b, err := json.Marshal(payload)
		if err != nil {
			return
		}
		fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event, string(b))
		flusher.Flush()
	}

	// Immediate warm snapshot
	if data, meta, ok := loadRegDashFromRedis(r.Context(), brand, asof); ok {
		writeSSE("snapshot", map[string]interface{}{"data": data, "meta": meta})
	} else {
		writeSSE("status", map[string]interface{}{"state": "warming", "brand": brand, "as_of": asof})
		go func() {
			_ = refreshRegDashBrand(context.Background(), brand, asof, regActor(r))
		}()
	}

	if regDashRedis == nil {
		writeSSE("status", map[string]interface{}{"state": "no_redis"})
		return
	}

	pubsub := regDashRedis.Subscribe(r.Context(), regDashNotifyChannel)
	defer pubsub.Close()
	ch := pubsub.Channel()

	heartbeat := time.NewTicker(25 * time.Second)
	defer heartbeat.Stop()

	ctx := r.Context()
	for {
		select {
		case <-ctx.Done():
			return
		case <-heartbeat.C:
			fmt.Fprintf(w, ": ping\n\n")
			flusher.Flush()
		case msg, open := <-ch:
			if !open {
				return
			}
			var notify map[string]interface{}
			if err := json.Unmarshal([]byte(msg.Payload), &notify); err != nil {
				continue
			}
			nb, _ := notify["brand"].(string)
			if regDashBrandKey(nb) != brand {
				continue
			}
			na, _ := notify["as_of"].(string)
			if na != "" {
				asof = na
			}
			if data, meta, ok := loadRegDashFromRedis(ctx, brand, asof); ok {
				writeSSE("snapshot", map[string]interface{}{"data": data, "meta": meta})
			} else {
				writeSSE("notify", notify)
			}
		}
	}
}
