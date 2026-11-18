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

	"GOamsAPI/database"

	"github.com/gorilla/mux"
)

const marcommExportTimeout = 300 * time.Second

const (
	marcommSPMember = "cek_transaksi_member_febita"
	marcommSPSales  = "xsp_febita_all_transacrtion_getrows_by_date"
)

func marcommQuery(r *http.Request, key string) string {
	if v := strings.TrimSpace(rbcaParam(r, key)); v != "" {
		return v
	}
	switch key {
	case "from_date":
		return firstNonEmpty(rbcaParam(r, "date_from"), rbcaParam(r, "from"))
	case "to_date":
		return firstNonEmpty(rbcaParam(r, "date_to"), rbcaParam(r, "to"))
	}
	return ""
}

func marcommParseDate(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	for _, layout := range []string{"2006-01-02", "2006/01/02", "02/01/2006"} {
		if t, err := time.Parse(layout, s); err == nil {
			return t, nil
		}
	}
	return time.Time{}, fmt.Errorf("invalid date %q", s)
}

// marcommDashDate formats a date for POS marcomm SPs (ASP daterangepicker: DD/MM/YYYY).
func marcommDashDate(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return s
	}
	if t, err := marcommParseDate(s); err == nil {
		return t.Format("02/01/2006")
	}
	return s
}

// marcommQDate reads a query/body date and normalizes to DD/MM/YYYY for POS SPs.
func marcommQDate(r *http.Request, key string) string {
	return marcommDashDate(marcommQ(r, key))
}

// marcommSlashYMD formats a date as yyyy/MM/dd — matches Tools/Rpt ASP date pickers
// (generate_voucher_list, voucher_used).
func marcommSlashYMD(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return s
	}
	if t, err := marcommParseDate(s); err == nil {
		return t.Format("2006/01/02")
	}
	return s
}

func marcommQDateSlashYMD(r *http.Request, key string) string {
	return marcommSlashYMD(marcommQ(r, key))
}

func marcommPingPOS(ctx context.Context) error {
	if database.Instance == nil {
		return fmt.Errorf("database unavailable")
	}
	return database.Instance.PingContext(ctx)
}

func marcommQuerySP(ctx context.Context, spName string, args ...interface{}) ([]map[string]interface{}, error) {
	c, cancel := context.WithTimeout(ctx, marcommExportTimeout)
	defer cancel()
	rows, err := database.Instance.QueryContext(c, spName, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return dgsScanRows(rows)
}

func writeMarcommJSON(w http.ResponseWriter, status int, payload interface{}) {
	b, err := json.Marshal(payload)
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	fmt.Fprint(w, string(b))
}

func marcommWriteRowsOK(w http.ResponseWriter, rows []map[string]interface{}) {
	if rows == nil {
		rows = []map[string]interface{}{}
	}
	b, err := json.Marshal(map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "OK",
		"data":              rows,
	})
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	writeRbcaJSON(w, string(b))
}

func marcommWriteObjectOK(w http.ResponseWriter, data interface{}) {
	if data == nil {
		data = map[string]interface{}{}
	}
	b, err := json.Marshal(map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "OK",
		"data":              data,
	})
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	writeRbcaJSON(w, string(b))
}

func marcommWriteEmptyOK(w http.ResponseWriter) {
	marcommWriteObjectOK(w, map[string]interface{}{})
}

func marcommQ(r *http.Request, key string) string {
	if v := strings.TrimSpace(rbcaParam(r, key)); v != "" {
		return v
	}
	switch key {
	case "keywords":
		return rbcaParam(r, "search")
	case "from_date":
		return marcommQuery(r, "from_date")
	case "to_date":
		return marcommQuery(r, "to_date")
	}
	return ""
}

func marcommExecSP(ctx context.Context, spName string, args ...interface{}) error {
	c, cancel := context.WithTimeout(ctx, marcommExportTimeout)
	defer cancel()
	_, err := database.Instance.ExecContext(c, spName, args...)
	return err
}

func marcommQueryGetRow(ctx context.Context, spName string, args ...interface{}) (map[string]interface{}, error) {
	rows, err := marcommQuerySP(ctx, spName, args...)
	if err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return map[string]interface{}{}, nil
	}
	return rows[0], nil
}

func marcommList(w http.ResponseWriter, r *http.Request, sp string, args ...interface{}) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	rows, err := marcommQuerySP(ctx, sp, args...)
	if err != nil {
		log.Printf("marcomm %s: %s", sp, err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	marcommWriteRowsOK(w, rows)
}

func marcommPathID(r *http.Request) string {
	if id := mux.Vars(r)["id"]; id != "" {
		return id
	}
	return marcommQ(r, "id")
}

func marcommPathVar(r *http.Request, key string) string {
	if v := mux.Vars(r)[key]; v != "" {
		return v
	}
	return marcommQ(r, key)
}

func marcommDALGetRowSP(dalKey string) string {
	return "xsp_" + dalKey + "_getrow"
}

func marcommDALDeleteSP(dalKey string) string {
	return "xsp_" + dalKey + "_delete"
}

func marcommGetRowSP(w http.ResponseWriter, r *http.Request, sp string, args ...interface{}) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	row, err := marcommQueryGetRow(ctx, sp, args...)
	if err != nil {
		log.Printf("marcomm getrow %s: %s", sp, err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	marcommWriteObjectOK(w, row)
}

func marcommGetRowDAL(w http.ResponseWriter, r *http.Request, dalKey, param, value string) {
	marcommGetRowSP(w, r, marcommDALGetRowSP(dalKey), sql.Named(param, value))
}

func marcommDeleteDAL(w http.ResponseWriter, r *http.Request, dalKey string, args ...interface{}) {
	marcommCUD(w, r, marcommDALDeleteSP(dalKey), args...)
}

func marcommBoolish(r *http.Request, key string) interface{} {
	v := strings.ToLower(strings.TrimSpace(marcommQ(r, key)))
	switch v {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	}
	if v == "" {
		return false
	}
	return marcommQ(r, key)
}

func marcommBodyStringSlice(r *http.Request, key string) []string {
	body := rbcaBodyValues(r)
	if body == nil {
		return nil
	}
	raw, ok := body[key]
	if !ok || raw == nil {
		return nil
	}
	switch v := raw.(type) {
	case []interface{}:
		out := make([]string, 0, len(v))
		for _, item := range v {
			s := strings.TrimSpace(fmt.Sprint(item))
			if s != "" {
				out = append(out, s)
			}
		}
		return out
	case []string:
		out := make([]string, 0, len(v))
		for _, s := range v {
			s = strings.TrimSpace(s)
			if s != "" {
				out = append(out, s)
			}
		}
		return out
	default:
		s := strings.TrimSpace(fmt.Sprint(v))
		if s != "" {
			return []string{s}
		}
	}
	return nil
}

func marcommCUDInsertMaybeID(w http.ResponseWriter, r *http.Request, sp string, args ...interface{}) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	var newID sql.NullInt64
	argsOut := append(append([]interface{}{}, args...), sql.Named("p_id", sql.Out{Dest: &newID}))
	if err := marcommExecSP(ctx, sp, argsOut...); err != nil {
		if err2 := marcommExecSP(ctx, sp, args...); err2 != nil {
			log.Printf("marcomm insert %s: %s", sp, err2.Error())
			writeRbcaJSON(w, rbcaErrorJSON("5000005", err2.Error()))
			return
		}
		marcommWriteEmptyOK(w)
		return
	}
	if newID.Valid && newID.Int64 > 0 {
		marcommWriteObjectOK(w, map[string]interface{}{"id": newID.Int64})
		return
	}
	marcommWriteEmptyOK(w)
}

// MarcommExportDataMember — GET /api/v1/marcomm/export-data-member
// Legacy parity: export_data_member.aspx (Member + Sales sheets).
func MarcommExportDataMember(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}

	fromStr := marcommQuery(r, "from_date")
	toStr := marcommQuery(r, "to_date")
	if fromStr == "" || toStr == "" {
		writeRbcaJSON(w, rbcaErrorJSON("4002500", "from_date and to_date are required (YYYY-MM-DD)"))
		return
	}
	fromDate, err := marcommParseDate(fromStr)
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("4002500", "from_date is not a valid date (YYYY-MM-DD)"))
		return
	}
	toDate, err := marcommParseDate(toStr)
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("4002500", "to_date is not a valid date (YYYY-MM-DD)"))
		return
	}
	if toDate.Before(fromDate) {
		writeRbcaJSON(w, rbcaErrorJSON("4002500", "to_date must be on or after from_date"))
		return
	}

	member, err := marcommQuerySP(ctx, marcommSPMember)
	if err != nil {
		log.Printf("MarcommExportDataMember %s: %s", marcommSPMember, err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}

	sales, err := marcommQuerySP(ctx, marcommSPSales,
		sql.Named("p_from_date", fromDate),
		sql.Named("p_to_date", toDate),
	)
	if err != nil {
		log.Printf("MarcommExportDataMember %s: %s", marcommSPSales, err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}

	if member == nil {
		member = []map[string]interface{}{}
	}
	if sales == nil {
		sales = []map[string]interface{}{}
	}

	marcommWriteObjectOK(w, map[string]interface{}{
		"member":    member,
		"sales":     sales,
		"from_date": fromDate.Format("2006-01-02"),
		"to_date":   toDate.Format("2006-01-02"),
	})
}

// MarcommExportDataMemberMeta — GET /api/v1/marcomm/export-data-member/meta
func MarcommExportDataMemberMeta(w http.ResponseWriter, r *http.Request) {
	writeMarcommJSON(w, http.StatusOK, map[string]interface{}{
		"endpoint":   "GET /api/v1/marcomm/export-data-member",
		"auth":       "JWT (Authorization: Bearer …)",
		"database":   "POS_SERVER (database.Instance)",
		"timeout_s":  int(marcommExportTimeout / time.Second),
		"query_params": map[string]string{
			"from_date": "required, YYYY-MM-DD (also accepts YYYY/MM/DD)",
			"to_date":   "required, YYYY-MM-DD (also accepts YYYY/MM/DD)",
		},
		"aliases": map[string][]string{
			"from_date": {"date_from", "from"},
			"to_date":   {"date_to", "to"},
		},
		"stored_procedures": []map[string]string{
			{"sheet": "Member", "name": marcommSPMember, "params": "none"},
			{"sheet": "Sales", "name": marcommSPSales, "params": "@p_from_date, @p_to_date"},
		},
		"response_fields": []string{"member", "sales", "from_date", "to_date"},
	})
}