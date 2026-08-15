package controllers

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
	"unicode"
)

const (
	mediaGatewayBrand       = "clcs"
	mediaGatewayArticleURL  = "https://media-gateway.aksacode.my.id/api/v1/article"
	mediaGatewayConcurrency = 8
)

var mediaGatewayClient = &http.Client{
	Timeout: 8 * time.Second,
}

type mediaGatewayArticle struct {
	ID          int    `json:"id"`
	Name        string `json:"name"`
	Article     string `json:"article"`
	Description string `json:"description"`
	Color       string `json:"color"`
	URL         string `json:"url"`
}

type newPosStockItem struct {
	Article    string      `json:"article"`
	Plu        string      `json:"plu"`
	Deskripsi  string      `json:"deskripsi"`
	DeskripsiB string      `json:"deskripsiB"`
	Color      string      `json:"color"`
	Size       string      `json:"size"`
	ImgUrl     string      `json:"imgUrl"`
	Price      interface{} `json:"Price"`
	Stock      interface{} `json:"stock"`
}

type newPosStockResponse struct {
	ResponseCode    string            `json:"responseCode"`
	ResponseMessage string            `json:"responseMessage"`
	Store           string            `json:"store"`
	Kategori        string            `json:"kategori"`
	ItemData        []newPosStockItem `json:"itemData"`
}

func GetStockByKategori(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading stock by kategori: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "XSP_STOCK_BY_KATEGORI_GETROWS",
		sql.Named("p_store_id", strings.TrimSpace(r.FormValue("store_id"))),
		sql.Named("p_kategori", strings.TrimSpace(r.FormValue("kategori"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "XSP_STOCK_BY_KATEGORI_GETROWS")
		return
	}

	validated := validateRbcaSPResponse(jsonResultData)
	enriched, err := enrichStockByKategoriWithMedia(r.Context(), validated)
	if err != nil {
		writeRbcaJSONResponse(w, validated, r.Method, "XSP_STOCK_BY_KATEGORI_GETROWS")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(httpStatusFromRbcaResponse(validated, r.Method, "XSP_STOCK_BY_KATEGORI_GETROWS"))
	fmt.Fprint(w, enriched)
}

func GetMasterKategori(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := pingDatabase(ctx); err != nil {
		log.Fatal("Error reading master kategori: ", err.Error())
	}

	jsonResultData := runRbcaSPQuery(ctx, "XSP_MASTER_KATEGORI_GETROWS",
		sql.Named("p_store_id", strings.TrimSpace(r.FormValue("store_id"))))

	if strings.TrimSpace(jsonResultData) == "" {
		writeRbcaJSONResponse(w, rbcaErrorJSON("5000002", "empty response from database"), r.Method, "XSP_MASTER_KATEGORI_GETROWS")
		return
	}

	writeRbcaJSONResponse(w, validateRbcaSPResponse(jsonResultData), r.Method, "XSP_MASTER_KATEGORI_GETROWS")
}

func enrichStockByKategoriWithMedia(ctx context.Context, jsonResult string) (string, error) {
	var raw map[string]interface{}
	decoder := json.NewDecoder(strings.NewReader(jsonResult))
	decoder.UseNumber()
	if err := decoder.Decode(&raw); err != nil {
		return "", err
	}

	items := parseNewPosItemMaps(raw["itemData"])
	articles := uniqueNewPosArticles(items)
	mediaByArticle := fetchMediaGatewayByArticles(ctx, articles)

	out := newPosStockResponse{
		ResponseCode:    mapValueToString(raw["responseCode"]),
		ResponseMessage: mapValueToString(raw["responseMessage"]),
		Store:           mapValueToString(raw["store"]),
		Kategori:        mapValueToString(raw["kategori"]),
		ItemData:        make([]newPosStockItem, 0, len(items)),
	}

	for _, item := range items {
		article := firstNonEmpty(
			mapValueToString(item["article"]),
			mapValueToString(item["Article"]),
		)
		media := pickMediaGatewayArticle(item, mediaByArticle[strings.ToUpper(article)])
		out.ItemData = append(out.ItemData, buildNewPosStockItem(item, media))
	}

	bytes, err := json.Marshal(out)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func buildNewPosStockItem(item map[string]interface{}, media *mediaGatewayArticle) newPosStockItem {
	outItem := newPosStockItem{
		Article: firstNonEmpty(
			mapValueToString(item["article"]),
			mapValueToString(item["Article"]),
		),
		Plu: firstNonEmpty(
			mapValueToString(item["plu"]),
			mapValueToString(item["PLU"]),
		),
		Deskripsi: firstNonEmpty(
			mapValueToString(item["deskripsi"]),
			mapValueToString(item["description"]),
		),
		DeskripsiB: firstNonEmpty(
			mapValueToString(item["deskripsiB"]),
			mapValueToString(item["DeskripsiB"]),
		),
		Color: firstNonEmpty(
			mapValueToString(item["color"]),
			mapValueToString(item["Color"]),
		),
		Size: firstNonEmpty(
			mapValueToString(item["size"]),
			mapValueToString(item["Size"]),
		),
		Price: firstNonNil(item["Price"], item["price"]),
		Stock: firstNonNil(item["stock"], item["Stock"]),
	}

	// Media gateway hanya sumber gambar. Color, size, dan deskripsi tetap dari SP.
	if media != nil {
		outItem.ImgUrl = strings.TrimSpace(media.URL)
	}
	return outItem
}

func parseNewPosItemMaps(raw interface{}) []map[string]interface{} {
	switch v := raw.(type) {
	case []interface{}:
		items := make([]map[string]interface{}, 0, len(v))
		for _, item := range v {
			if m, ok := item.(map[string]interface{}); ok {
				items = append(items, m)
			}
		}
		return items
	case []map[string]interface{}:
		return v
	default:
		return nil
	}
}

func uniqueNewPosArticles(items []map[string]interface{}) []string {
	seen := make(map[string]struct{})
	articles := make([]string, 0)
	for _, item := range items {
		article := firstNonEmpty(
			mapValueToString(item["article"]),
			mapValueToString(item["Article"]),
		)
		key := strings.ToUpper(article)
		if article == "" {
			continue
		}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		articles = append(articles, article)
	}
	return articles
}

func fetchMediaGatewayByArticles(ctx context.Context, articles []string) map[string][]mediaGatewayArticle {
	result := make(map[string][]mediaGatewayArticle, len(articles))
	if len(articles) == 0 {
		return result
	}

	fetchCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()

	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, mediaGatewayConcurrency)

	for _, article := range articles {
		article := article
		wg.Add(1)
		go func() {
			defer wg.Done()

			select {
			case sem <- struct{}{}:
			case <-fetchCtx.Done():
				return
			}
			defer func() { <-sem }()

			items, err := fetchMediaGatewayArticle(fetchCtx, article)
			if err != nil || len(items) == 0 {
				return
			}

			mu.Lock()
			result[strings.ToUpper(article)] = items
			mu.Unlock()
		}()
	}

	wg.Wait()
	return result
}

func fetchMediaGatewayArticle(ctx context.Context, article string) ([]mediaGatewayArticle, error) {
	reqURL, err := url.Parse(mediaGatewayArticleURL)
	if err != nil {
		return nil, err
	}
	query := reqURL.Query()
	query.Set("brand", mediaGatewayBrand)
	query.Set("article", article)
	reqURL.RawQuery = query.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL.String(), nil)
	if err != nil {
		return nil, err
	}

	resp, err := mediaGatewayClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		io.Copy(io.Discard, resp.Body)
		return nil, fmt.Errorf("media-gateway status %d", resp.StatusCode)
	}

	var items []mediaGatewayArticle
	if err := json.NewDecoder(resp.Body).Decode(&items); err != nil {
		return nil, err
	}
	return items, nil
}

func normalizeColorKey(value string) string {
	var b strings.Builder
	b.Grow(len(value))
	for _, r := range strings.ToLower(strings.TrimSpace(value)) {
		if unicode.IsSpace(r) {
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

func pickMediaGatewayArticle(item map[string]interface{}, media []mediaGatewayArticle) *mediaGatewayArticle {
	if len(media) == 0 {
		return nil
	}

	colorHint := firstNonEmpty(
		mapValueToString(item["color"]),
		mapValueToString(item["Color"]),
	)
	if colorHint != "" {
		want := normalizeColorKey(colorHint)
		for i := range media {
			if normalizeColorKey(media[i].Color) == want {
				picked := media[i]
				return &picked
			}
		}
	}

	// Fallback: gambar pertama artikel.
	picked := media[0]
	return &picked
}

func mapValueToString(value interface{}) string {
	if value == nil {
		return ""
	}
	switch v := value.(type) {
	case string:
		return strings.TrimSpace(v)
	case json.Number:
		return strings.TrimSpace(v.String())
	default:
		s := strings.TrimSpace(fmt.Sprint(v))
		if s == "<nil>" {
			return ""
		}
		return s
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func firstNonNil(values ...interface{}) interface{} {
	for _, value := range values {
		if value != nil {
			return value
		}
	}
	return nil
}
