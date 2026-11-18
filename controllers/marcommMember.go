package controllers

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"
)

// --- Member CMS lists ---

func MarcommMemberTransactions(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_get_member_dashboard_transaction_list_getrows",
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
		sql.Named("p_category_voucher", firstNonEmpty(marcommQ(r, "category_voucher"), marcommQ(r, "category"))),
		sql.Named("p_brand", marcommQ(r, "brand")),
		sql.Named("p_keywords", marcommQ(r, "keywords")),
	)
}

func MarcommMemberTransactionsBadge(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	row, err := marcommQueryGetRow(ctx, "xsp_app_member_badge_total_transaction_getrow",
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
	)
	if err != nil {
		log.Printf("marcomm member transactions badge: %s", err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	marcommWriteObjectOK(w, row)
}

func MarcommMemberRpt(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_get_member_markomm_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
	)
}

func MarcommPromoList(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_promo_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
	)
}

func MarcommAppVouchers(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_voucher_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
	)
}

func MarcommGifts(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_gift_list_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
	)
}

func MarcommMissions(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_get_member_mission_getrows",
		sql.Named("p_keywords", marcommQ(r, "keywords")),
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
	)
}

func MarcommNotifications(w http.ResponseWriter, r *http.Request) {
	// Live SP has no parameters (ASP Hashtable p_keywords is ignored by DAL/legacy SP).
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	rows, err := marcommQuerySP(ctx, "xsp_app_member_notification_header_getrows")
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	kw := strings.ToLower(strings.TrimSpace(marcommQ(r, "keywords")))
	if kw != "" && rows != nil {
		filtered := make([]map[string]interface{}, 0, len(rows))
		for _, row := range rows {
			blob := strings.ToLower(fmt.Sprint(row["TITLE"], " ", row["title"], " ", row["KETERANGAN"], " ", row["keterangan"], " ", row["ID"], " ", row["id"]))
			if strings.Contains(blob, kw) {
				filtered = append(filtered, row)
			}
		}
		rows = filtered
	}
	marcommWriteRowsOK(w, rows)
}

func marcommRowStringCI(row map[string]interface{}, names ...string) string {
	byLower := make(map[string]interface{}, len(row))
	for k, v := range row {
		byLower[strings.ToLower(k)] = v
	}
	for _, name := range names {
		if v, ok := byLower[strings.ToLower(name)]; ok && v != nil {
			s := strings.TrimSpace(fmt.Sprint(v))
			if s != "" {
				return s
			}
		}
	}
	return ""
}

func marcommDashChartFromRow(row map[string]interface{}, jsonCols ...string) interface{} {
	raw := marcommRowStringCI(row, jsonCols...)
	if raw == "" {
		return []interface{}{}
	}
	var parsed interface{}
	if json.Unmarshal([]byte(raw), &parsed) == nil {
		return parsed
	}
	return raw
}

func marcommDashboardChart(ctx context.Context, fromSP, toSP, sp string, jsonCols ...string) interface{} {
	row, err := marcommQueryGetRow(ctx, sp,
		sql.Named("p_from_date", fromSP),
		sql.Named("p_to_date", toSP),
	)
	if err != nil {
		log.Printf("marcomm dashboard %s: %s", sp, err.Error())
		return []interface{}{}
	}
	return marcommDashChartFromRow(row, jsonCols...)
}

// MarcommDashboardSummary — GET /marcomm/dashboard/summary
func MarcommDashboardSummary(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	from := marcommQ(r, "from_date")
	to := marcommQ(r, "to_date")
	// Default like Marketing.aspx first load when dates missing (avoid SP date conversion errors).
	if strings.TrimSpace(from) == "" || strings.TrimSpace(to) == "" {
		now := time.Now()
		from = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location()).Format("2006-01-02")
		to = now.Format("2006-01-02")
	}
	fromSP := marcommDashDate(from)
	toSP := marcommDashDate(to)
	out := map[string]interface{}{
		"from_date": from,
		"to_date":   to,
	}

	if badge, err := marcommQueryGetRow(ctx, "xsp_app_dashboard_member_badge_total_chart_getrow",
		sql.Named("p_from_date", fromSP),
		sql.Named("p_to_date", toSP),
	); err == nil {
		out["badge"] = badge
	} else {
		log.Printf("marcomm dashboard badge: %s", err.Error())
		out["badge"] = map[string]interface{}{}
	}

	if rows, err := marcommQuerySP(ctx, "xsp_app_dashboard_member_top_brand_contributor_getrows",
		sql.Named("p_from_date", fromSP),
		sql.Named("p_to_date", toSP),
	); err == nil {
		out["top_brand_contributors"] = rows
	} else {
		log.Printf("marcomm dashboard top brand: %s", err.Error())
		out["top_brand_contributors"] = []map[string]interface{}{}
	}

	out["charts"] = map[string]interface{}{
		"member_activity": marcommDashboardChart(ctx, fromSP, toSP,
			"xsp_app_dashboard_member_Activity_chart_getrow", "DataMemberActivity"),
		"member_activity_daily": marcommDashboardChart(ctx, fromSP, toSP,
			"xsp_app_dashboard_member_Activity_chart_daily_getrow", "DataMemberActivityDaily"),
		"member_growth": marcommDashboardChart(ctx, fromSP, toSP,
			"xsp_app_dashboard_member_Activity_growth_member_chart_getrow", "DataMemberActivityGrowth"),
		"member_growth_daily": marcommDashboardChart(ctx, fromSP, toSP,
			"xsp_app_dashboard_member_Activity_growth_member_chart_daily_getrow", "DataMemberActivityGrowthDaily"),
		"member_location": marcommDashboardChart(ctx, fromSP, toSP,
			"xsp_app_dashboard_member_location_chart_getrow", "member_location", "DataLocationChart"),
	}
	marcommWriteObjectOK(w, out)
}