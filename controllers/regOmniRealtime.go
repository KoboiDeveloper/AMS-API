package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/go-redis/redis/v8"
)

// RegRptOmniRtHandler — GET /regional/rpt/omni/realtime-stock?store_id=&article=
// Parity module/omni/realtime_stock.aspx → Redis Realtime_Stock:All_Store (same as
// /api/global/stock/r/store/). Not an SQL SP; stub xsp_ams_new_reg_rpt_omni_rt_getrows
// remains unused.
func RegRptOmniRtHandler(w http.ResponseWriter, r *http.Request) {
	storeID := strings.TrimSpace(firstNonEmpty(
		rbcaParam(r, "store_id"),
		rbcaParam(r, "id_store"),
		rbcaParam(r, "store"),
	))
	article := strings.TrimSpace(rbcaParam(r, "article"))

	if storeID == "" || strings.EqualFold(storeID, "PILIH STORE") || storeID == "0" {
		writeRbcaJSON(w, marshalRbcaJSON(map[string]interface{}{
			"responseCode":    "2002500",
			"responseMessage": "success",
			"data":            []interface{}{},
			"total_qty":       0,
		}))
		return
	}

	rdb := regDashRedis
	if rdb == nil {
		writeRbcaJSON(w, rbcaErrorJSON("5030001", "Redis is temporarily unavailable"))
		return
	}

	items, err := loadRealtimeStockByStore(r.Context(), rdb, storeID)
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", "gagal membaca realtime stock: "+err.Error()))
		return
	}

	totalQty := 0.0
	for _, it := range items {
		totalQty += it.Qty
	}

	filtered := items
	if article != "" {
		needle := strings.ToUpper(article)
		out := make([]ItemDetail, 0, len(items))
		for _, it := range items {
			if strings.Contains(strings.ToUpper(it.Article), needle) {
				out = append(out, it)
			}
		}
		filtered = out
	}

	rows := make([]map[string]interface{}, 0, len(filtered))
	for _, it := range filtered {
		rows = append(rows, map[string]interface{}{
			"brand":    it.Brand,
			"store_id": firstNonEmpty(it.StoreID, storeID),
			"kota":     it.Kota,
			"provinsi": it.Provinsi,
			"pulau":    it.Pulau,
			"article":  it.Article,
			"plu":      it.PLU,
			"qty":      it.Qty,
			"size":     it.Size,
			"color":    it.Color,
		})
	}

	writeRbcaJSON(w, marshalRbcaJSON(map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "success",
		"data":            rows,
		"total_qty":       totalQty,
	}))
}

func loadRealtimeStockByStore(ctx context.Context, rdb *redis.Client, storeID string) ([]ItemDetail, error) {
	pluList, err := rdb.SMembers(ctx, fmt.Sprintf("Index:Stock:Store:%s", storeID)).Result()
	if err != nil {
		return nil, err
	}
	if len(pluList) == 0 {
		return []ItemDetail{}, nil
	}

	pipe := rdb.Pipeline()
	cmds := make([]*redis.Cmd, len(pluList))
	for i, plu := range pluList {
		redisKey := fmt.Sprintf("Realtime_Stock:All_Store:%s:%s", storeID, plu)
		cmds[i] = pipe.Do(ctx, "JSON.GET", redisKey, ".")
	}
	if _, err := pipe.Exec(ctx); err != nil && err != redis.Nil {
		// Partial misses are normal; only fail on hard pipeline errors without results.
		hasAny := false
		for _, cmd := range cmds {
			if _, e := cmd.Result(); e == nil {
				hasAny = true
				break
			}
		}
		if !hasAny {
			return nil, err
		}
	}

	items := make([]ItemDetail, 0, len(pluList))
	for i, cmd := range cmds {
		data, err := cmd.Result()
		if err != nil {
			continue
		}
		jsonData, ok := data.(string)
		if !ok || strings.TrimSpace(jsonData) == "" {
			continue
		}
		var item ItemDetail
		if err := json.Unmarshal([]byte(jsonData), &item); err != nil {
			continue
		}
		item.StoreID = storeID
		if item.PLU == "" {
			item.PLU = pluList[i]
		}
		items = append(items, item)
	}
	return items, nil
}
