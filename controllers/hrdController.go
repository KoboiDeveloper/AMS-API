package controllers

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"GOamsAPI/database"

	"github.com/gorilla/mux"
)

// Standard filter params for every HRD getrows SP (must match sql/hrd/07_unify_getrows_params.sql)
var hrdListParamKeys = []string{
	"keywords", "from_date", "to_date", "is_active",
	"id_brand", "id_store", "brand", "store_id",
	"status", "kategori", "group", "dept", "department",
	"cabang", "id_cabang", "year", "month", "period",
	"tipe", "is_pajak", "id_mesin", "currentmonth", "tahun",
}

// Optional list filters — only sent when present so legacy getrows SPs without the arg still work.
var hrdListOptionalParamKeys = []string{"pegawai_id", "user_id"}

func runHrdSP(ctx context.Context, spName string, namedArgs ...interface{}) string {
	var jsonResultData string
	args := append(namedArgs, sql.Named("bitparam", sql.Out{Dest: &jsonResultData}))
	rows, err := database.RbcaInstance.QueryContext(ctx, spName, args...)
	if err != nil {
		log.Printf("Error executing HRD SP %s: %s", spName, err.Error())
		return rbcaErrorJSON("5000005", err.Error())
	}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
		}
	}
	return jsonResultData
}

func writeHrdSPResponse(w http.ResponseWriter, r *http.Request, spName string, jsonResult string) {
	if strings.TrimSpace(jsonResult) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, spName)
		return
	}
	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResult), r.Method, spName)
}

func hrdActor(r *http.Request) string {
	if v := rbcaParam(r, "created_by"); v != "" {
		return v
	}
	if v := rbcaParam(r, "updated_by"); v != "" {
		return v
	}
	if v := rbcaNikFromJWT(r); v != "" {
		return v
	}
	return ""
}

func hrdQuery(r *http.Request, key string) string {
	if v := rbcaParam(r, key); v != "" {
		return v
	}
	// aliases from React / legacy naming
	switch key {
	case "keywords":
		return rbcaParam(r, "search")
	case "from_date":
		if v := rbcaParam(r, "date_from"); v != "" {
			return v
		}
		return rbcaParam(r, "from")
	case "to_date":
		if v := rbcaParam(r, "date_to"); v != "" {
			return v
		}
		return rbcaParam(r, "to")
	case "id_brand":
		return rbcaParam(r, "brand_id")
	case "id_store":
		if v := rbcaParam(r, "store_id"); v != "" {
			return v
		}
		return rbcaParam(r, "id_store")
	case "tahun":
		if v := rbcaParam(r, "year"); v != "" {
			return v
		}
		return rbcaParam(r, "tahun")
	case "currentmonth":
		if v := rbcaParam(r, "month"); v != "" {
			return v
		}
		return rbcaParam(r, "currentmonth")
	}
	return ""
}

func hrdListHandler(spName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		args := make([]interface{}, 0, len(hrdListParamKeys)+len(hrdListOptionalParamKeys))
		for _, key := range hrdListParamKeys {
			args = append(args, sql.Named("p_"+key, parseOptionalString(hrdQuery(r, key))))
		}
		for _, key := range hrdListOptionalParamKeys {
			if v := hrdQuery(r, key); v != "" {
				args = append(args, sql.Named("p_"+key, parseOptionalString(v)))
			}
		}
		jsonResult := runHrdSP(ctx, spName, args...)
		writeHrdSPResponse(w, r, spName, jsonResult)
	}
}

func hrdGetHandler(spName string, idKey string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		id := mux.Vars(r)[idKey]
		if id == "" {
			id = rbcaParam(r, "id")
		}
		jsonResult := runHrdSP(ctx, spName, sql.Named("p_id", id))
		writeHrdSPResponse(w, r, spName, jsonResult)
	}
}

func hrdInsertHandler(spName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		payload, _ := json.Marshal(rbcaBodyValues(r))
		actor := hrdActor(r)
		jsonResult := runHrdSP(ctx, spName,
			sql.Named("p_payload", string(payload)),
			sql.Named("p_created_by", parseOptionalString(actor)),
			sql.Named("p_actor_nik", parseOptionalString(actor)),
		)
		writeHrdSPResponse(w, r, spName, jsonResult)
	}
}

func hrdUpdateHandler(spName string, idKey string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		id := mux.Vars(r)[idKey]
		payload, _ := json.Marshal(rbcaBodyValues(r))
		actor := hrdActor(r)
		jsonResult := runHrdSP(ctx, spName,
			sql.Named("p_id", id),
			sql.Named("p_payload", string(payload)),
			sql.Named("p_updated_by", parseOptionalString(actor)),
			sql.Named("p_actor_nik", parseOptionalString(actor)),
		)
		writeHrdSPResponse(w, r, spName, jsonResult)
	}
}

func hrdDeleteHandler(spName string, idKey string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		id := mux.Vars(r)[idKey]
		actor := hrdActor(r)
		payload, _ := json.Marshal(map[string]string{"id": id})
		jsonResult := runHrdSP(ctx, spName,
			sql.Named("p_id", id),
			sql.Named("p_payload", string(payload)),
			sql.Named("p_updated_by", parseOptionalString(actor)),
			sql.Named("p_actor_nik", parseOptionalString(actor)),
		)
		writeHrdSPResponse(w, r, spName, jsonResult)
	}
}

func hrdProcessHandler(spName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := context.Background()
		if err := pingDatabase(ctx); err != nil {
			writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
			return
		}
		body := rbcaBodyValues(r)
		if body == nil {
			body = map[string]interface{}{}
		}
		for _, k := range []string{"period", "store_id", "year", "month", "date", "tahun", "id_mesin"} {
			if v := rbcaParam(r, k); v != "" {
				body[k] = v
			}
		}
		payload, _ := json.Marshal(body)
		actor := hrdActor(r)
		jsonResult := runHrdSP(ctx, spName,
			sql.Named("p_payload", string(payload)),
			sql.Named("p_created_by", parseOptionalString(actor)),
			sql.Named("p_actor_nik", parseOptionalString(actor)),
			sql.Named("p_period", parseOptionalString(rbcaParam(r, "period"))),
			sql.Named("p_store_id", parseOptionalString(rbcaParam(r, "store_id"))),
		)
		writeHrdSPResponse(w, r, spName, jsonResult)
	}
}

func RegisterHrdEntityRoutes(r *mux.Router, path, entity string, withCRUD bool) {
	base := "/hrd/" + path
	r.HandleFunc(base, hrdListHandler("xsp_ams_new_hrd_"+entity+"_getrows")).Methods("GET")
	if !withCRUD {
		return
	}
	r.HandleFunc(base, hrdInsertHandler("xsp_ams_new_hrd_"+entity+"_insert")).Methods("POST")
	r.HandleFunc(base+"/{id}", hrdGetHandler("xsp_ams_new_hrd_"+entity+"_getrow", "id")).Methods("GET")
	r.HandleFunc(base+"/{id}", hrdUpdateHandler("xsp_ams_new_hrd_"+entity+"_update", "id")).Methods("PUT")
	r.HandleFunc(base+"/{id}", hrdDeleteHandler("xsp_ams_new_hrd_"+entity+"_delete", "id")).Methods("DELETE")
}

// RegisterHrdFormRoutes — getrow + update only (employee-info form tabs keyed by pegawai_id).
func RegisterHrdFormRoutes(r *mux.Router, path, entity string) {
	base := "/hrd/" + path
	r.HandleFunc(base+"/{id}", hrdGetHandler("xsp_ams_new_hrd_"+entity+"_getrow", "id")).Methods("GET")
	r.HandleFunc(base+"/{id}", hrdUpdateHandler("xsp_ams_new_hrd_"+entity+"_update", "id")).Methods("PUT")
}

// HrdDetailKehadiranList — store headers via AMS SP; employee calendar via legacy POS SP (dynamic columns).
func HrdDetailKehadiranList(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	idCabang := strings.TrimSpace(hrdQuery(r, "id_cabang"))
	if idCabang == "" {
		idCabang = strings.TrimSpace(hrdQuery(r, "cabang"))
	}
	if idCabang == "" {
		hrdListHandler("xsp_ams_new_hrd_detail_kehadiran_getrows")(w, r)
		return
	}

	from := hrdQuery(r, "from_date")
	to := hrdQuery(r, "to_date")
	group := hrdQuery(r, "group")
	if group == "" {
		group = "REGULER"
	}
	brand := hrdQuery(r, "brand")
	if brand == "" {
		brand = hrdQuery(r, "id_brand")
	}
	if brand == "" {
		brand = "FL"
	}
	uid := hrdQuery(r, "user_id")
	if uid == "" {
		uid = "portal"
	}

	rows, err := database.RbcaInstance.QueryContext(ctx, `
EXEC POS_SERVER.dbo.xsp_get_data_absen_manual_dan_pos_detail_export_getrows_buat_di_pages_2
  @p_from_date=@p_from_date, @p_to_date=@p_to_date, @p_group=@p_group,
  @p_id_cabang=@p_id_cabang, @p_user_id=@p_user_id, @p_brand=@p_brand`,
		sql.Named("p_from_date", parseOptionalString(from)),
		sql.Named("p_to_date", parseOptionalString(to)),
		sql.Named("p_group", group),
		sql.Named("p_id_cabang", idCabang),
		sql.Named("p_user_id", uid),
		sql.Named("p_brand", brand),
	)
	if err != nil {
		log.Printf("Error executing DK detail SP: %s", err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	defer rows.Close()

	cols, err := rows.Columns()
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	out := make([]map[string]interface{}, 0, 64)
	idx := 0
	for rows.Next() {
		raw := make([]interface{}, len(cols))
		ptrs := make([]interface{}, len(cols))
		for i := range raw {
			ptrs[i] = &raw[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			log.Printf("DK scan: %s", err.Error())
			continue
		}
		idx++
		row := map[string]interface{}{
			"id":        idx,
			"row_type":  "employee",
			"id_cabang": idCabang,
			"brand":     brand,
			"group":     group,
			"from_date": from,
			"to_date":   to,
		}
		for i, col := range cols {
			val := derefSQL(raw[i])
			switch strings.ToLower(col) {
			case "nomorindukstr":
				row["nik"] = val
				row["nick"] = val
			case "namalengkapstr":
				row["employee_name"] = val
			case "jabatan", "jabatanstr":
				row["jabatan"] = val
			case "history_total":
				row["total"] = val
			case "store_id":
				row["store_id"] = val
			case "store":
				row["store_name"] = val
			default:
				row[col] = val
			}
		}
		out = append(out, row)
	}
	payload, _ := json.Marshal(map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "success",
		"data":            out,
	})
	writeRbcaJSONResponse(w, string(payload), r.Method, "detail_kehadiran")
}

func derefSQL(v interface{}) interface{} {
	switch t := v.(type) {
	case nil:
		return nil
	case []byte:
		return string(t)
	default:
		return t
	}
}

func HrdAbsenGenerateStore(w http.ResponseWriter, r *http.Request) {
	hrdProcessHandler("xsp_ams_new_hrd_absen_generate_process")(w, r)
}

func HrdAbsenGenerateNasional(w http.ResponseWriter, r *http.Request) {
	hrdProcessHandler("xsp_ams_new_hrd_absen_generate_nasional_process")(w, r)
}

func HrdEomProcess(w http.ResponseWriter, r *http.Request) {
	hrdProcessHandler("xsp_ams_new_hrd_eom_process")(w, r)
}

func HrdMonthlyPayrollProcess(w http.ResponseWriter, r *http.Request) {
	hrdProcessHandler("xsp_ams_new_hrd_monthly_payroll_process")(w, r)
}

func HrdLookupHandler(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	lookupType := mux.Vars(r)["type"]
	if lookupType == "" {
		lookupType = rbcaParam(r, "type")
	}
	jsonResult := runHrdSP(ctx, "xsp_ams_new_hrd_lookup_getrows",
		sql.Named("p_type", lookupType),
		sql.Named("p_keywords", parseOptionalString(hrdQuery(r, "keywords"))),
		sql.Named("p_parent_id", parseOptionalString(firstNonEmpty(rbcaParam(r, "parent_id"), rbcaParam(r, "id_brand"), rbcaParam(r, "department"), rbcaParam(r, "golongan")))),
	)
	writeHrdSPResponse(w, r, "xsp_ams_new_hrd_lookup_getrows", jsonResult)
}

// HrdDashboardSummary — GET /hrd/dashboard/summary
func HrdDashboardSummary(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := pingDatabase(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	const spName = "xsp_ams_new_hrd_dashboard_summary_getrow"
	jsonResult := runHrdSP(ctx, spName,
		sql.Named("p_id_brand", parseOptionalString(firstNonEmpty(hrdQuery(r, "id_brand"), rbcaParam(r, "brand")))),
		sql.Named("p_id_cabang", parseOptionalString(firstNonEmpty(hrdQuery(r, "id_cabang"), rbcaParam(r, "cabang")))),
		sql.Named("p_days_kontrak", parseOptionalString(firstNonEmpty(rbcaParam(r, "days_kontrak"), rbcaParam(r, "days"), "30"))),
	)
	writeHrdSPResponse(w, r, spName, jsonResult)
}
