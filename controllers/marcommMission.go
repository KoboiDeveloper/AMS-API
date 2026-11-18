package controllers

import (
	"database/sql"
	"net/http"
)

// Mission detail / editor parity (mission_detail.aspx.cs)

func MarcommMissionGet(w http.ResponseWriter, r *http.Request) {
	id := marcommPathID(r)
	marcommGetRowDAL(w, r, "app_member_mission", "p_id_mission", id)
}

func MarcommMissionMilestones(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_mission_detail_mailstone_getrow",
		sql.Named("p_id_mission", marcommPathID(r)),
	)
}

func MarcommMissionMembers(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_mission_detail_mailstone_member_getrow",
		sql.Named("p_id_mission", marcommPathID(r)),
		sql.Named("p_keywords", marcommQ(r, "keywords")),
	)
}

func MarcommMissionMemberBarang(w http.ResponseWriter, r *http.Request) {
	marcommList(w, r, "xsp_app_member_mission_detail_mailstone_member_dapat_barang_getrow",
		sql.Named("p_id_mission", marcommPathID(r)),
		sql.Named("p_keywords", marcommQ(r, "keywords")),
	)
}

func marcommMissionCategoryID(r *http.Request) int {
	if n := marcommQInt(r, "category_id"); n != 0 {
		return n
	}
	return marcommQInt(r, "category")
}

func MarcommMissionCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUDInsertMaybeID(w, r, "xsp_generate_mission_member_insert",
		sql.Named("p_title", marcommQ(r, "title")),
		sql.Named("p_category_id", marcommMissionCategoryID(r)),
		sql.Named("p_brand", marcommQ(r, "brand")),
		sql.Named("p_description", marcommQ(r, "description")),
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
		sql.Named("p_maxvalue", marcommQInt(r, "maxvalue")),
		sql.Named("p_survey_link", marcommQ(r, "survey_link")),
		sql.Named("p_image_url", marcommQ(r, "image_url")),
	)
}

func MarcommMissionUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_generate_mission_member_update",
		sql.Named("p_id_mission", marcommPathID(r)),
		sql.Named("p_title", marcommQ(r, "title")),
		sql.Named("p_category_id", marcommMissionCategoryID(r)),
		sql.Named("p_brand", marcommQ(r, "brand")),
		sql.Named("p_description", marcommQ(r, "description")),
		sql.Named("p_from_date", marcommQDate(r, "from_date")),
		sql.Named("p_to_date", marcommQDate(r, "to_date")),
		sql.Named("p_maxvalue", marcommQInt(r, "maxvalue")),
		sql.Named("p_survey_link", marcommQ(r, "survey_link")),
		sql.Named("p_image_url", marcommQ(r, "image_url")),
	)
}

func MarcommMissionMilestoneCreate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_generate_mission_milestone_member_insert",
		sql.Named("p_missionid", marcommPathID(r)),
		sql.Named("p_description", marcommQ(r, "description")),
		sql.Named("p_targetvalue", marcommQ(r, "targetvalue")),
		sql.Named("p_rewardcategory", marcommQ(r, "rewardcategory")),
		sql.Named("p_rewardtext", marcommQ(r, "rewardtext")),
		sql.Named("p_maxclaim", marcommQ(r, "maxclaim")),
		sql.Named("p_rewardamount", firstNonEmpty(marcommQ(r, "rewardamount"), "0")),
	)
}

func MarcommMissionMilestoneUpdate(w http.ResponseWriter, r *http.Request) {
	marcommCUD(w, r, "xsp_generate_mission_milestone_member_update",
		sql.Named("p_missionid", marcommPathID(r)),
		sql.Named("p_milestoneid", marcommPathVar(r, "mid")),
		sql.Named("p_description", marcommQ(r, "description")),
		sql.Named("p_targetvalue", marcommQ(r, "targetvalue")),
		sql.Named("p_rewardcategory", marcommQ(r, "rewardcategory")),
		sql.Named("p_rewardtext", marcommQ(r, "rewardtext")),
		sql.Named("p_maxclaim", marcommQ(r, "maxclaim")),
		sql.Named("p_rewardamount", firstNonEmpty(marcommQ(r, "rewardamount"), "0")),
	)
}

func MarcommMissionMilestoneDelete(w http.ResponseWriter, r *http.Request) {
	marcommDeleteDAL(w, r, "member_mission_milestone",
		sql.Named("p_id_mission", marcommPathID(r)),
		sql.Named("p_id_milestone", marcommPathVar(r, "mid")),
	)
}