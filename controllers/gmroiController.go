package controllers

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var (
	gmroiISODateRe = regexp.MustCompile(`^(\d{4})[-/](\d{1,2})[-/](\d{1,2})`)
	gmroiDMYDateRe = regexp.MustCompile(`^(\d{1,2})[-/](\d{1,2})[-/](\d{4})`)
)

const (
	defaultGmroiSpreadsheetID = "1k4TLzb2popzMCXWDguJvRQXolqeUaM-JaQ51h0NrJD8"
	gmroiSheetName            = "GMROI"
	gmroiPictureSheetName     = "Picture"
)

func gmroiSpreadsheetID() string {
	if v := strings.TrimSpace(os.Getenv("GMROI_SPREADSHEET_ID")); v != "" {
		return v
	}
	return defaultGmroiSpreadsheetID
}

func fetchGoogleSheetCSV(spreadsheetID, sheetName string) ([][]string, error) {
	url := fmt.Sprintf(
		"https://docs.google.com/spreadsheets/d/%s/gviz/tq?tqx=out:csv&sheet=%s",
		spreadsheetID,
		sheetName,
	)
	client := &http.Client{Timeout: 120 * time.Second}
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "AMS-GMROI-Sync/1.0")
	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode >= 400 {
		body, _ := io.ReadAll(io.LimitReader(res.Body, 512))
		return nil, fmt.Errorf("google sheets HTTP %d: %s", res.StatusCode, strings.TrimSpace(string(body)))
	}
	r := csv.NewReader(res.Body)
	r.FieldsPerRecord = -1
	r.LazyQuotes = true
	return r.ReadAll()
}

func gmroiHeaderIndex(headers []string) map[string]int {
	idx := map[string]int{}
	for i, h := range headers {
		key := strings.ToUpper(strings.TrimSpace(h))
		if key != "" {
			idx[key] = i
		}
	}
	return idx
}

func gmroiCell(row []string, idx map[string]int, key string) string {
	i, ok := idx[key]
	if !ok || i < 0 || i >= len(row) {
		return ""
	}
	return strings.TrimSpace(row[i])
}

func gmroiParseNumber(raw string) float64 {
	s := strings.TrimSpace(raw)
	if s == "" || s == "-" {
		return 0
	}
	s = strings.ReplaceAll(s, " ", "")
	// ID format 1.234.567,89
	if strings.Contains(s, ".") && strings.Contains(s, ",") {
		s = strings.ReplaceAll(s, ".", "")
		s = strings.ReplaceAll(s, ",", ".")
	} else if strings.Count(s, ",") == 1 && !strings.Contains(s, ".") {
		s = strings.ReplaceAll(s, ",", ".")
	} else {
		s = strings.ReplaceAll(s, ",", "")
	}
	n, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0
	}
	return n
}

func gmroiMonthNumber(value string) int {
	key := strings.ToLower(strings.TrimSpace(value))
	if len(key) > 3 {
		key = key[:3]
	}
	months := map[string]int{
		"jan": 1, "feb": 2, "mar": 3, "apr": 4, "mei": 5, "may": 5,
		"jun": 6, "jul": 7, "agu": 8, "aug": 8, "sep": 9,
		"okt": 10, "oct": 10, "nov": 11, "des": 12, "dec": 12,
	}
	return months[key]
}

func gmroiNormalizeDate(raw, monthHint string) string {
	s := strings.TrimSpace(raw)
	if s == "" {
		return ""
	}
	hint := gmroiMonthNumber(monthHint)

	if m := gmroiISODateRe.FindStringSubmatch(s); len(m) == 4 {
		y, _ := strconv.Atoi(m[1])
		mo, _ := strconv.Atoi(m[2])
		d, _ := strconv.Atoi(m[3])
		if hint > 0 && mo != hint && d == hint && mo <= 31 {
			mo, d = hint, mo
		}
		return fmt.Sprintf("%04d-%02d-%02d", y, mo, d)
	}
	if m := gmroiDMYDateRe.FindStringSubmatch(s); len(m) == 4 {
		first, _ := strconv.Atoi(m[1])
		second, _ := strconv.Atoi(m[2])
		y, _ := strconv.Atoi(m[3])
		var mo, d int
		if hint > 0 && first == hint && second <= 31 {
			mo, d = first, second
		} else if hint > 0 && second == hint && first <= 31 {
			mo, d = second, first
		} else {
			mo, d = second, first
		}
		return fmt.Sprintf("%04d-%02d-%02d", y, mo, d)
	}
	return s
}

// RegAnalistGmroiSyncHandler pulls GMROI + Picture sheets from Google Spreadsheet once (manual sync).
func RegAnalistGmroiSyncHandler(w http.ResponseWriter, r *http.Request) {
	spreadsheetID := gmroiSpreadsheetID()
	gmroiCSV, err := fetchGoogleSheetCSV(spreadsheetID, gmroiSheetName)
	if err != nil {
		writeRbcaJSON(w, rbcaErrorJSON("5000005", "gagal ambil sheet GMROI: "+err.Error()))
		return
	}
	pictureCSV, errPic := fetchGoogleSheetCSV(spreadsheetID, gmroiPictureSheetName)
	if errPic != nil {
		// Picture optional — sync GMROI tetap jalan
		pictureCSV = nil
	}

	if len(gmroiCSV) < 2 {
		payload, _ := json.Marshal(map[string]interface{}{
			"responseCode":    "2002500",
			"responseMessage": "success",
			"data": map[string]interface{}{
				"rows":             []interface{}{},
				"pictures":         map[string]string{},
				"totalArts":        0,
				"artsWithPictures": 0,
				"sheetName":        gmroiSheetName,
				"pictureSheetName": gmroiPictureSheetName,
				"spreadsheetId":    spreadsheetID,
				"refreshedAt":      time.Now().UTC().Format(time.RFC3339),
				"pictureError":     errMsg(errPic),
			},
		})
		writeRbcaJSON(w, string(payload))
		return
	}

	idx := gmroiHeaderIndex(gmroiCSV[0])
	required := []string{"ART", "PLU", "SP", "IN", "HPP", "HJ", "TOKO", "OUT", "TEXTIL", "TAGLINE", "CLASS", "KAT", "BLN", "AGING", "NETTO", "THEMA"}
	var missing []string
	for _, h := range required {
		if _, ok := idx[h]; !ok {
			missing = append(missing, h)
		}
	}
	if len(missing) > 0 {
		writeRbcaJSON(w, rbcaErrorJSON("4002500", "header GMROI tidak lengkap: "+strings.Join(missing, ", ")))
		return
	}

	rows := make([]map[string]interface{}, 0, len(gmroiCSV)-1)
	artSet := map[string]bool{}
	for _, row := range gmroiCSV[1:] {
		art := gmroiCell(row, idx, "ART")
		plu := gmroiCell(row, idx, "PLU")
		if art == "" && plu == "" {
			continue
		}
		qtyIn := gmroiParseNumber(gmroiCell(row, idx, "IN"))
		qtyOut := gmroiParseNumber(gmroiCell(row, idx, "OUT"))
		hpp := gmroiParseNumber(gmroiCell(row, idx, "HPP"))
		netto := gmroiParseNumber(gmroiCell(row, idx, "NETTO"))
		bln := gmroiCell(row, idx, "BLN")
		aging := gmroiNormalizeDate(gmroiCell(row, idx, "AGING"), bln)
		stock := qtyIn - qtyOut
		if stock < 0 {
			stock = 0
		}
		st := 0.0
		if qtyIn > 0 {
			st = qtyOut / qtyIn * 100
		}
		recovery := 0.0
		if hpp > 0 {
			recovery = netto / hpp
		}
		if art != "" {
			artSet[art] = true
		}
		rows = append(rows, map[string]interface{}{
			"ART":          art,
			"PLU":          plu,
			"SP":           gmroiCell(row, idx, "SP"),
			"IN":           qtyIn,
			"HPP":          hpp,
			"HJ":           gmroiParseNumber(gmroiCell(row, idx, "HJ")),
			"TOKO":         gmroiCell(row, idx, "TOKO"),
			"OUT":          qtyOut,
			"TEXTIL":       gmroiCell(row, idx, "TEXTIL"),
			"TAGLINE":      gmroiCell(row, idx, "TAGLINE"),
			"CLASS":        gmroiCell(row, idx, "CLASS"),
			"KAT":          gmroiCell(row, idx, "KAT"),
			"BLN":          bln,
			"AGING":        aging,
			"NETTO":        netto,
			"THEMA":        gmroiCell(row, idx, "THEMA"),
			"STOCK":        stock,
			"SELL_THROUGH": st,
			"RECOVERY":     recovery,
		})
	}

	pictures := map[string]string{}
	if len(pictureCSV) >= 2 {
		pIdx := gmroiHeaderIndex(pictureCSV[0])
		artI, okA := pIdx["ART"]
		linkI, okL := pIdx["LINKFOTO"]
		if okA && okL {
			for _, row := range pictureCSV[1:] {
				if artI >= len(row) || linkI >= len(row) {
					continue
				}
				art := strings.TrimSpace(row[artI])
				link := strings.TrimSpace(row[linkI])
				if art != "" && link != "" {
					pictures[art] = link
				}
			}
		}
	}

	artsWithPic := 0
	for art := range artSet {
		if pictures[art] != "" {
			artsWithPic++
		}
	}

	payload, _ := json.Marshal(map[string]interface{}{
		"responseCode":    "2002500",
		"responseMessage": "success",
		"data": map[string]interface{}{
			"rows":             rows,
			"pictures":         pictures,
			"totalArts":        len(artSet),
			"artsWithPictures": artsWithPic,
			"sheetName":        gmroiSheetName,
			"pictureSheetName": gmroiPictureSheetName,
			"spreadsheetId":    spreadsheetID,
			"rowCount":         len(rows),
			"refreshedAt":      time.Now().UTC().Format(time.RFC3339),
			"pictureError":     errMsg(errPic),
		},
	})
	writeRbcaJSON(w, string(payload))
}

func errMsg(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}
