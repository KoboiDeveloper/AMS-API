package controllers

import (
	"encoding/json"
	"strings"
	"testing"
)

// strings is used for ToUpper / TrimSpace in enrichment assertion helpers.

func TestNormalizeColorKey(t *testing.T) {
	cases := []struct {
		in   string
		want string
	}{
		{"Black", "black"},
		{" Off White ", "offwhite"},
		{"DARK   BROWN", "darkbrown"},
		{"Chalk", "chalk"},
	}
	for _, tc := range cases {
		if got := normalizeColorKey(tc.in); got != tc.want {
			t.Fatalf("normalizeColorKey(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestPickMediaGatewayArticleExactAndCaseInsensitive(t *testing.T) {
	media := []mediaGatewayArticle{
		{Name: "Black Tee", Color: "Black", URL: "https://img/black.jpg"},
		{Name: "Off White Tee", Color: "Off white", URL: "https://img/offwhite.jpg"},
		{Name: "Chalk Tee", Color: "Chalk", URL: "https://img/chalk.jpg"},
	}

	picked := pickMediaGatewayArticle(map[string]interface{}{
		"color": "OFF WHITE",
	}, media)
	if picked == nil {
		t.Fatal("expected media pick")
	}
	if picked.URL != "https://img/offwhite.jpg" {
		t.Fatalf("got url %q", picked.URL)
	}
}

func TestPickMediaGatewayArticleFallbackFirst(t *testing.T) {
	media := []mediaGatewayArticle{
		{Name: "Black Tee", Color: "Black", URL: "https://img/black.jpg"},
		{Name: "Chalk Tee", Color: "Chalk", URL: "https://img/chalk.jpg"},
	}

	picked := pickMediaGatewayArticle(map[string]interface{}{
		"color":     "NoSuchColor",
		"deskripsi": "TS SAMPLE XYZ",
	}, media)
	if picked == nil {
		t.Fatal("expected fallback media")
	}
	if picked.URL != "https://img/black.jpg" {
		t.Fatalf("fallback url = %q", picked.URL)
	}
}

func TestEnrichStockByKategoriWithMediaKeepsSPColorSize(t *testing.T) {
	raw := `{
		"responseCode":"2002500",
		"responseMessage":"success",
		"store":"rcw032",
		"kategori":"101",
		"itemData":[
			{
				"article":"LIN000135W",
				"plu":"1018503250004",
				"deskripsi":"TS S/S LIN000135W Chlk",
				"color":"Chalk",
				"size":"L",
				"Price":275000,
				"stock":2
			},
			{
				"article":"LIN000135W",
				"plu":"1010104250020",
				"deskripsi":"TS S/S LIN000135W BLK",
				"color":"black",
				"size":"M",
				"Price":275000,
				"stock":0
			},
			{
				"article":"LIN000999W",
				"plu":"999",
				"deskripsi":"NO MEDIA",
				"color":"Ivory",
				"size":"S",
				"Price":100000,
				"stock":1
			}
		]
	}`

	mediaByArticle := map[string][]mediaGatewayArticle{
		"LIN000135W": {
			{Name: "Kai Kisses Black", Color: "Black", URL: "https://img/black.jpg"},
			{Name: "Kai Kisses Chalk", Color: "Chalk", URL: "https://img/chalk.jpg"},
		},
	}

	var decoded map[string]interface{}
	dec := json.NewDecoder(strings.NewReader(raw))
	dec.UseNumber()
	if err := dec.Decode(&decoded); err != nil {
		t.Fatal(err)
	}

	items := parseNewPosItemMaps(decoded["itemData"])
	out := newPosStockResponse{
		ResponseCode:    mapValueToString(decoded["responseCode"]),
		ResponseMessage: mapValueToString(decoded["responseMessage"]),
		Store:           mapValueToString(decoded["store"]),
		Kategori:        mapValueToString(decoded["kategori"]),
		ItemData:        make([]newPosStockItem, 0, len(items)),
	}

	for _, item := range items {
		article := firstNonEmpty(mapValueToString(item["article"]), mapValueToString(item["Article"]))
		spColor := firstNonEmpty(mapValueToString(item["color"]), mapValueToString(item["Color"]))
		spSize := firstNonEmpty(mapValueToString(item["size"]), mapValueToString(item["Size"]))
		media := pickMediaGatewayArticle(item, mediaByArticle[strings.ToUpper(article)])

		outItem := newPosStockItem{
			Article:   article,
			Plu:       firstNonEmpty(mapValueToString(item["plu"]), mapValueToString(item["PLU"])),
			Deskripsi: firstNonEmpty(mapValueToString(item["deskripsi"]), mapValueToString(item["description"])),
			Color:     spColor,
			Size:      spSize,
			Price:     firstNonNil(item["Price"], item["price"]),
			Stock:     firstNonNil(item["stock"], item["Stock"]),
		}
		if media != nil {
			outItem.DeskripsiB = strings.TrimSpace(media.Name)
			outItem.ImgUrl = strings.TrimSpace(media.URL)
			if outItem.Color == "" {
				outItem.Color = strings.TrimSpace(media.Color)
			}
		}
		out.ItemData = append(out.ItemData, outItem)
	}

	if len(out.ItemData) != 3 {
		t.Fatalf("item count = %d", len(out.ItemData))
	}

	chalk := out.ItemData[0]
	if chalk.Color != "Chalk" || chalk.Size != "L" || chalk.ImgUrl != "https://img/chalk.jpg" {
		t.Fatalf("chalk item = %+v", chalk)
	}

	black := out.ItemData[1]
	if black.Color != "black" || black.Size != "M" || black.ImgUrl != "https://img/black.jpg" {
		t.Fatalf("black item = %+v", black)
	}

	noMedia := out.ItemData[2]
	if noMedia.Color != "Ivory" || noMedia.Size != "S" || noMedia.ImgUrl != "" {
		t.Fatalf("no-media item = %+v", noMedia)
	}
}
