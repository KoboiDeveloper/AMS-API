package controllers

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

// Notification editor parity (mNotifDetail.aspx.cs)

func MarcommNotificationGet(w http.ResponseWriter, r *http.Request) {
	marcommGetRowDAL(w, r, "app_member_notification_header", "p_id", marcommPathID(r))
}

func MarcommNotificationCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUDInsertMaybeID(w, r, "xsp_app_member_notification_header_insert",
		sql.Named("p_title", marcommQ(r, "title")),
		sql.Named("p_keterangan", marcommQ(r, "keterangan")),
	)
}

func MarcommNotificationUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_app_member_notification_header_update",
		sql.Named("p_id", marcommPathID(r)),
		sql.Named("p_title", marcommQ(r, "title")),
		sql.Named("p_keterangan", marcommQ(r, "keterangan")),
	)
}

func MarcommNotificationMembers(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_notification_detail_getrows",
		sql.Named("p_id_notification", marcommPathID(r)),
		sql.Named("p_keywords", ""),
	)
}

func MarcommNotificationMemberPool(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_notification_load_member_token_getrows",
		sql.Named("p_id_notification", marcommPathID(r)),
		sql.Named("p_keywords", marcommQ(r, "keywords")),
	)
}

func MarcommNotificationAddMembers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	notifID := marcommPathID(r)
	type memberPair struct {
		ID    string
		Token string
	}
	var pairs []memberPair
	if body := rbcaBodyValues(r); body != nil {
		if raw, ok := body["members"].([]interface{}); ok {
			for _, item := range raw {
				if m, ok := item.(map[string]interface{}); ok {
					pairs = append(pairs, memberPair{
						ID: firstNonEmpty(
							strings.TrimSpace(fmt.Sprint(m["id_member"])),
							strings.TrimSpace(fmt.Sprint(m["p_id_member"])),
						),
						Token: firstNonEmpty(
							strings.TrimSpace(fmt.Sprint(m["token_member"])),
							strings.TrimSpace(fmt.Sprint(m["p_token_member"])),
						),
					})
				}
			}
		}
	}
	if len(pairs) == 0 {
		pairs = append(pairs, memberPair{
			ID:    firstNonEmpty(marcommQ(r, "id_member"), marcommQ(r, "p_id_member")),
			Token: firstNonEmpty(marcommQ(r, "token_member"), marcommQ(r, "p_token_member")),
		})
	}
	for i := range pairs {
		if pairs[i].ID == "" {
			continue
		}
		if err := marcommExecSP(ctx, "xsp_app_member_notification_detail_insert",
			sql.Named("p_id_notification", notifID),
			sql.Named("p_id_member", pairs[i].ID),
			sql.Named("p_token_member", pairs[i].Token),
		); err != nil {
			log.Printf("marcomm notif add member: %s", err.Error())
			writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
			return
		}
	}
	marcommWriteEmptyOK(w)
}

func MarcommNotificationRemoveMember(w http.ResponseWriter, r *http.Request) {
	detailID := firstNonEmpty(marcommQ(r, "detail_id"), marcommQ(r, "p_id"))
	marcommDeleteDAL(w, r, "app_member_notification_detail",
		sql.Named("p_id", detailID),
		sql.Named("p_id_member", marcommPathVar(r, "memberId")),
	)
}

// MarcommNotificationSend — legacy loads jsonResult from app_member_push_notification_send then POSTs to Expo.
func MarcommNotificationSend(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := marcommPingPOS(ctx); err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000001", "database unavailable"))
		return
	}
	row, err := marcommQueryGetRow(ctx, marcommDALGetRowSP("app_member_push_notification_send"),
		sql.Named("p_id_notification", marcommPathID(r)),
	)
	if err != nil {
		log.Printf("marcomm notif send getrow: %s", err.Error())
		writeRbcaJSON(w, rbcaErrorJSON("5000005", err.Error()))
		return
	}
	jsonPayload := ""
	for _, k := range []string{"jsonResult", "jsonresult", "JSONRESULT"} {
		if v, ok := row[k]; ok && v != nil {
			jsonPayload = strings.TrimSpace(fmt.Sprint(v))
			break
		}
	}
	out := map[string]interface{}{
		"push_payload": jsonPayload,
	}
	if jsonPayload != "" {
		client := &http.Client{Timeout: 60 * time.Second}
		req, reqErr := http.NewRequestWithContext(ctx, http.MethodPost, "https://exp.host/--/api/v2/push/send", bytes.NewBufferString(jsonPayload))
		if reqErr == nil {
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("Accept", "application/json")
			resp, doErr := client.Do(req)
			if doErr != nil {
				out["expo_error"] = doErr.Error()
			} else {
				defer resp.Body.Close()
				body, _ := io.ReadAll(resp.Body)
				out["expo_status"] = resp.StatusCode
				var expoJSON interface{}
				if json.Unmarshal(body, &expoJSON) == nil {
					out["expo_response"] = expoJSON
				} else {
					out["expo_response"] = string(body)
				}
			}
		} else {
			out["expo_error"] = reqErr.Error()
		}
	}
	marcommWriteObjectOK(w, out)
}