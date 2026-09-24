package controllers

import (
	"GOamsAPI/database"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/sirupsen/logrus"
	"github.com/streadway/amqp"
	"gopkg.in/gomail.v2"
)

type StockKingController struct {
	RedisClient *redis.Client
	RabbitMQ    *amqp.Channel
	QueueName   string
}

func (c *StockKingController) redisUnavailable(w http.ResponseWriter) bool {
	if c == nil || c.RedisClient == nil {
		logrus.Warn("Redis dinonaktifkan sementara")
		w.Header().Set("Content-Type", "application/json")
		http.Error(w, `{"error": "Redis is temporarily disabled"}`, http.StatusServiceUnavailable)
		return true
	}
	return false
}

// Struktur response JSON
type StockResponse struct {
	ItemDetail []ItemDetail `json:"itemDetail"`
}

type ItemDetail struct {
	Brand       string  `json:"brand"`
	StoreID     string  `json:"store_id"`
	Kota        string  `json:"kota"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	Provinsi    string  `json:"provinsi"`
	Pulau       string  `json:"pulau"`
	Star_Seller string  `json:"star_seller"`
	Article     string  `json:"article"`
	PLU         string  `json:"plu"`
	Qty         float64 `json:"qty"`
	Size        string  `json:"size"`
	Color       string  `json:"color"`
}

// Handler API untuk mendapatkan stok berdasarkan store ID
func (c *StockKingController) GetGlobalStockPLUStore(w http.ResponseWriter, r *http.Request) {
	if c.redisUnavailable(w) {
		return
	}
	ctx := context.Background()
	storeID := r.URL.Query().Get("store") // Ambil parameter store

	if storeID == "" {
		http.Error(w, `{"error": "store parameter is required"}`, http.StatusBadRequest)
		return
	}

	// Ambil daftar PLU dari Index:Stock:Store:{storeID}
	pluList, err := c.RedisClient.SMembers(ctx, fmt.Sprintf("Index:Stock:Store:%s", storeID)).Result()
	if err != nil || len(pluList) == 0 {
		logrus.Warnf("Tidak ada data stok untuk Store ID: %s", storeID)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"itemDetail": []}`)) // Return array kosong jika tidak ada data
		return
	}

	// Gunakan Redis Pipeline untuk batch JSON.GET berdasarkan PLU
	pipe := c.RedisClient.Pipeline()
	cmds := make([]*redis.Cmd, len(pluList))

	for i, plu := range pluList {
		redisKey := fmt.Sprintf("Realtime_Stock:All_Store:%s:%s", storeID, plu)
		cmds[i] = pipe.Do(ctx, "JSON.GET", redisKey, ".")
	}

	_, err = pipe.Exec(ctx)
	if err != nil {
		logrus.Errorf("Gagal mengambil data dengan JSON.GET: %v", err)
		http.Error(w, `{"error": "internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Parsing JSON hasil batch GET
	var stockItems []ItemDetail

	for i, cmd := range cmds {
		data, err := cmd.Result()
		if err != nil {
			logrus.Warnf("Gagal mengambil data dari Redis: %s, error: %v", pluList[i], err)
			continue
		}

		jsonData, ok := data.(string)
		if !ok {
			logrus.Warnf("Data bukan string dari Redis: %s", pluList[i])
			continue
		}

		var item ItemDetail
		if err := json.Unmarshal([]byte(jsonData), &item); err != nil {
			logrus.Warnf("Gagal parsing JSON dari Redis: %s, error: %v", pluList[i], err)
			continue
		}

		// Pastikan Store ID ada dalam hasil response
		item.StoreID = storeID
		stockItems = append(stockItems, item)
	}

	// Buat response JSON
	response := StockResponse{ItemDetail: stockItems}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// Fungsi Worker untuk mengambil data JSON dari Redis
func (c *StockKingController) processKeys(ctx context.Context, keyChan <-chan string, resultChan chan<- ItemDetail) {
	pipe := c.RedisClient.Pipeline()
	cmds := make(map[string]*redis.Cmd)

	for key := range keyChan {
		cmd := pipe.Do(ctx, "JSON.GET", key, ".")
		cmds[key] = cmd
	}

	_, err := pipe.Exec(ctx)
	if err != nil {
		logrus.Errorf("Gagal menjalankan pipeline Redis: %v", err)
		return
	}

	for key, cmd := range cmds {
		data, err := cmd.Result()
		if err != nil {
			logrus.Warnf("Gagal mengambil data dari Redis: %s, error: %v", key, err)
			continue
		}

		jsonData, ok := data.(string)
		if !ok {
			logrus.Warnf("Data bukan string dari Redis: %s", key)
			continue
		}

		var item ItemDetail
		if err := json.Unmarshal([]byte(jsonData), &item); err != nil {
			logrus.Warnf("Gagal parsing JSON dari Redis: %s, error: %v", key, err)
			continue
		}

		// Ambil Store ID dari key jika tidak ada di JSON
		parts := strings.Split(key, ":")
		if len(parts) >= 4 {
			item.StoreID = parts[2]
		}

		resultChan <- item
	}
}

// Handler API untuk mendapatkan stok berdasarkan store ID, dengan filter article, size, dan color
func (c *StockKingController) GetGlobalStockOnline_DENGAN_STORE(w http.ResponseWriter, r *http.Request) {
	if c.redisUnavailable(w) {
		return
	}
	ctx := context.Background()
	storeID := r.URL.Query().Get("store") // Ambil parameter store

	if storeID == "" {
		http.Error(w, `{"error": "store parameter is required"}`, http.StatusBadRequest)
		return
	}

	article := r.URL.Query().Get("article")
	size := r.URL.Query().Get("size")
	color := r.URL.Query().Get("color")

	// Cek apakah Store ID ada di index Redis
	isMember, err := c.RedisClient.SIsMember(ctx, "Index:Stores", storeID).Result()
	if err != nil || !isMember {
		logrus.Warnf("Store ID tidak ditemukan di index: %s", storeID)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"itemDetail": []}`)) // Return array kosong jika tidak ada data
		return
	}

	// Ambil semua PLU terkait Store ID menggunakan Redis SCAN
	keysPattern := fmt.Sprintf("Realtime_Stock:All_Store:%s:*", storeID)
	var cursor uint64
	var keys []string

	for {
		var tempKeys []string
		tempKeys, cursor, err = c.RedisClient.Scan(ctx, cursor, keysPattern, 1000).Result()
		if err != nil {
			logrus.Errorf("Gagal melakukan SCAN Redis: %v", err)
			http.Error(w, `{"error": "internal server error"}`, http.StatusInternalServerError)
			return
		}

		keys = append(keys, tempKeys...)
		if cursor == 0 {
			break
		}
	}

	if len(keys) == 0 {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"itemDetail": []}`)) // Jika tidak ada data, return array kosong
		return
	}

	// Gunakan Redis Pipeline untuk batch JSON.GET
	pipe := c.RedisClient.Pipeline()
	cmds := make([]*redis.Cmd, len(keys))

	for i, key := range keys {
		cmds[i] = pipe.Do(ctx, "JSON.GET", key, ".")
	}

	_, err = pipe.Exec(ctx)
	if err != nil {
		logrus.Errorf("Gagal mengambil data dengan JSON.GET: %v", err)
		http.Error(w, `{"error": "internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Parsing JSON hasil batch GET dan filter berdasarkan parameter
	var stockItems []ItemDetail

	for i, cmd := range cmds {
		data, err := cmd.Result()
		if err != nil {
			logrus.Warnf("Gagal mengambil data dari Redis: %s, error: %v", keys[i], err)
			continue
		}

		jsonData, ok := data.(string)
		if !ok {
			logrus.Warnf("Data bukan string dari Redis: %s", keys[i])
			continue
		}

		var item ItemDetail
		if err := json.Unmarshal([]byte(jsonData), &item); err != nil {
			logrus.Warnf("Gagal parsing JSON dari Redis: %s, error: %v", keys[i], err)
			continue
		}

		// Ambil Store ID dari key jika tidak ada di JSON
		parts := strings.Split(keys[i], ":")
		if len(parts) >= 4 {
			item.StoreID = parts[2]
		}

		// Filter berdasarkan parameter yang diberikan
		if (article == "" || item.Article == article) &&
			(size == "" || item.Size == size) &&
			(color == "" || item.Color == color) {
			stockItems = append(stockItems, item)
		}
	}

	// Buat response JSON
	response := StockResponse{ItemDetail: stockItems}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

func (c *StockKingController) GetGlobalStockOnline(w http.ResponseWriter, r *http.Request) {
	if c.redisUnavailable(w) {
		return
	}
	ctx := context.Background()

	article := r.URL.Query().Get("article")
	size := r.URL.Query().Get("size")
	color := r.URL.Query().Get("color")
	provinsi := r.URL.Query().Get("provinsi")

	if article == "" {
		http.Error(w, `{"error": "article parameter is required"}`, http.StatusBadRequest)
		return
	}

	var cursor uint64
	var matchPattern = "Realtime_Stock:All_Store:*:*"
	var stockItems []ItemDetail

	// Looping SCAN untuk mendapatkan semua kunci yang cocok
	for {
		keys, nextCursor, err := c.RedisClient.Scan(ctx, cursor, matchPattern, 5000).Result() // Scan lebih banyak per batch
		if err != nil {
			logrus.Errorf("Gagal melakukan SCAN Redis: %v", err)
			http.Error(w, `{"error": "internal server error"}`, http.StatusInternalServerError)
			return
		}

		if len(keys) == 0 {
			break
		}

		// Pipeline untuk batch JSON.GET hanya article (lebih cepat)
		pipe := c.RedisClient.Pipeline()
		cmds := make([]*redis.Cmd, 0)

		for _, key := range keys {
			cmd := pipe.Do(ctx, "JSON.GET", key, "$.article") // Ambil hanya article
			cmds = append(cmds, cmd)
		}

		_, err = pipe.Exec(ctx)
		if err != nil {
			logrus.Errorf("Gagal mendapatkan data dari Redis: %v", err)
			http.Error(w, `{"error": "internal server error"}`, http.StatusInternalServerError)
			return
		}

		// Filter hanya key yang sesuai dengan article
		validKeys := []string{}
		for i, cmd := range cmds {
			data, err := cmd.Result()
			if err != nil || data == nil {
				continue
			}

			jsonData, ok := data.(string)
			if !ok {
				continue
			}

			// Parsing hanya article
			var articleArray []string
			if err := json.Unmarshal([]byte(jsonData), &articleArray); err != nil {
				continue
			}

			if len(articleArray) > 0 && articleArray[0] == article {
				validKeys = append(validKeys, keys[i])
			}
		}

		// Batch GET semua data JSON yang valid
		if len(validKeys) > 0 {
			mgetCmds := c.RedisClient.Pipeline()
			fullDataCmds := make([]*redis.Cmd, 0)

			for _, key := range validKeys {
				cmd := mgetCmds.Do(ctx, "JSON.GET", key, ".")
				fullDataCmds = append(fullDataCmds, cmd)
			}

			_, err = mgetCmds.Exec(ctx)
			if err != nil {
				logrus.Errorf("Gagal mendapatkan JSON dari Redis: %v", err)
				continue
			}

			// Parsing JSON hasil batch GET
			for i, cmd := range fullDataCmds {
				data, err := cmd.Result()
				if err != nil || data == nil {
					continue
				}

				jsonData, ok := data.(string)
				if !ok {
					continue
				}

				var item ItemDetail
				if err := json.Unmarshal([]byte(jsonData), &item); err != nil {
					continue
				}

				jabodetabekCities := map[string]bool{
					"JAKARTA":   true,
					"BOGOR":     true,
					"DEPOK":     true,
					"TANGERANG": true,
					"BEKASI":    true,
					"SAMARINDA": true,
				}

				// Filter berdasarkan size & color
				if (size == "" || item.Size == size) &&
					(color == "" || item.Color == color) &&
					((provinsi == "ALL" || item.Provinsi == provinsi) ||
						(provinsi == "JABODETABEK" && jabodetabekCities[item.Kota])) { // Ambil Store ID dari key Redis
					parts := strings.Split(validKeys[i], ":")
					if len(parts) >= 4 {
						item.StoreID = parts[2] // Store ID ada di bagian ke-3 dari key
					}
					stockItems = append(stockItems, item)
				}
			}
		}

		// Cek apakah sudah selesai SCAN
		if nextCursor == 0 {
			break
		}
		cursor = nextCursor
	}

	// Fetch store location data from external API
	storeLocationMap := make(map[string]struct {
		Latitude  float64
		Longitude float64
	})

	client := &http.Client{}
	apiURL := "https://golangapi-j5iu.onrender.com/api/shop/store"
	resp, err := client.Get(apiURL)
	if err != nil {
		logrus.Warnf("Gagal mengambil data store location dari API: %v", err)
	} else {
		defer resp.Body.Close()

		if resp.StatusCode == http.StatusOK {
			var apiResponse struct {
				Message string `json:"message"`
				Data    []struct {
					Store     string  `json:"store"`
					Kota      string  `json:"kota"`
					Latitude  float64 `json:"latitude"`
					Longitude float64 `json:"longitude"`
				} `json:"data"`
			}

			if err := json.NewDecoder(resp.Body).Decode(&apiResponse); err != nil {
				logrus.Warnf("Gagal parsing response dari API store location: %v", err)
			} else {
				// Build map of store_id -> {latitude, longitude}
				for _, store := range apiResponse.Data {
					storeLocationMap[store.Store] = struct {
						Latitude  float64
						Longitude float64
					}{
						Latitude:  store.Latitude,
						Longitude: store.Longitude,
					}
				}
			}
		}
	}

	// Populate latitude and longitude for each stock item
	for i := range stockItems {
		if location, exists := storeLocationMap[stockItems[i].StoreID]; exists {
			stockItems[i].Latitude = location.Latitude
			stockItems[i].Longitude = location.Longitude
		}
	}

	// Buat response JSON
	response := StockResponse{ItemDetail: stockItems}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

func (c *StockKingController) GetVariantByArticle(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	article := r.URL.Query().Get("article")

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_realtime_stock_variant_by_article_getrows",
		sql.Named("p_article", article),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))

}

// GetCatalogHargaDiskon — harga & diskon catalog
// SP: xsp_catalog_get_data_harga_dan_diskon_getrows (@p_tipe, @p_id_store, @bitparam)
func (c *StockKingController) GetCatalogHargaDiskon(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	if err := database.Instance.PingContext(ctx); err != nil {
		log.Fatal("Error reading catalog harga diskon: ", err.Error())
	}

	tipe := strings.TrimSpace(r.URL.Query().Get("tipe"))
	if tipe == "" {
		tipe = strings.TrimSpace(r.URL.Query().Get("p_tipe"))
	}
	if tipe == "" {
		tipe = "catalog"
	}

	storeID := strings.TrimSpace(r.URL.Query().Get("id_store"))
	if storeID == "" {
		storeID = strings.TrimSpace(r.URL.Query().Get("p_id_store"))
	}
	if storeID == "" {
		storeID = strings.TrimSpace(r.URL.Query().Get("store"))
	}

	var pStore interface{}
	if storeID == "" {
		pStore = nil
	} else {
		pStore = storeID
	}

	var jsonResultData string
	_, err := database.Instance.QueryContext(ctx, "xsp_catalog_get_data_harga_dan_diskon_getrows",
		sql.Named("p_tipe", tipe),
		sql.Named("p_id_store", pStore),
		sql.Named("bitparam", sql.Out{Dest: &jsonResultData}),
	)
	if err != nil {
		log.Println("catalog harga diskon SP error:", err.Error())
		w.Header().Set("Content-Type", "application/json")
		http.Error(w, `{"error": "failed to execute catalog harga diskon"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(jsonResultData))
}

func (c *StockKingController) PushCheckOut(w http.ResponseWriter, r *http.Request) {
	if c.redisUnavailable(w) {
		return
	}
	var request struct {
		ItemDetail []struct {
			ID_TRANSAKSI   string `json:"ID_TRANSAKSI"`
			ID             int    `json:"ID"`
			Store          string `json:"STORE"`
			NamaCustomer   string `json:"NAMA_CUSTOMER"`
			PLU            string `json:"PLU"`
			Qty            int32  `json:"QTY"`
			ExpiredDate    string `json:"EXPIRED_DATE"`
			StatusBayar    string `json:"STATUS_BAYAR"`
			TipePengiriman string `json:"TIPE_PENGIRIMAN"`
		} `json:"itemDetail"`
	}

	if c.RabbitMQ == nil {
		logrus.Error("❌ RabbitMQ belum diinisialisasi")
		http.Error(w, "Server error: RabbitMQ tidak tersedia", http.StatusInternalServerError)
		return
	}
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		http.Error(w, "Invalid JSON input", http.StatusBadRequest)
		return
	}

	ctx := context.Background()
	redisClient := c.RedisClient // Redis client dari controller

	var checkoutItems []struct {
		ID_TRANSAKSI   string `json:"ID_TRANSAKSI"`
		ID             int    `json:"ID"`
		Store          string `json:"STORE"`
		NamaCustomer   string `json:"NAMA_CUSTOMER"`
		PLU            string `json:"PLU"`
		Qty            int32  `json:"QTY"`
		ExpiredDate    string `json:"EXPIRED_DATE"`
		StatusBayar    string `json:"STATUS_BAYAR"`
		TipePengiriman string `json:"TIPE_PENGIRIMAN"`
	}

	for _, item := range request.ItemDetail {
		redisKey := fmt.Sprintf("Realtime_Stock:All_Store:%s:%s", item.Store, item.PLU)

		// Ambil qty dari Redis
		redisResult, err := redisClient.Do(ctx, "JSON.GET", redisKey, "$.qty").Result()
		if err != nil {
			logrus.Warnf("⚠️ Gagal mengambil qty dari Redis untuk key %s: %v", redisKey, err)
			continue
		}

		var redisQty int32
		switch v := redisResult.(type) {
		case string:
			var parsedQty []int32
			if err := json.Unmarshal([]byte(v), &parsedQty); err != nil {
				logrus.Warnf("⚠️ Gagal mengurai JSON dari Redis: %v", err)
				continue
			}
			if len(parsedQty) > 0 {
				redisQty = parsedQty[0]
			}
		case float64:
			redisQty = int32(v)
		case int64:
			redisQty = int32(v)
		default:
			logrus.Warnf("⚠️ Tipe data tidak dikenal dari JSON.GET: %T, data: %v", v, v)
			continue
		}

		// **Skip jika qty sudah 0**
		if redisQty <= 0 {
			logrus.Warnf("⏩ Stok habis (0), lewati: StoreID=%s, PLU=%s", item.Store, item.PLU)
			continue
		}

		// **Skip jika stok tidak cukup**
		if redisQty < item.Qty {
			logrus.Warnf("⛔ Stok tidak cukup! StoreID=%s, PLU=%s, Stok tersedia=%d, Diminta=%d", item.Store, item.PLU, redisQty, item.Qty)
			continue
		}

		// **Kurangi stok**
		newQty := redisQty - item.Qty

		_, err = redisClient.Do(ctx, "JSON.SET", redisKey, "$.qty", newQty).Result()
		if err != nil {
			logrus.Warnf("⚠️ Gagal mengupdate qty di Redis untuk key %s: %v", redisKey, err)
			continue
		}

		logrus.Infof("✅ Stok dikurangi: StoreID=%s, PLU=%s, Qty lama=%d, Qty baru=%d", item.Store, item.PLU, redisQty, newQty)

		// Simpan item yang berhasil diproses untuk dikirim ke RabbitMQ
		checkoutItems = append(checkoutItems, item)
	}

	// Jika ada item yang berhasil diproses, kirim ke RabbitMQ
	if len(checkoutItems) > 0 {
		err := SendCheckoutToRabbitMQ(c.RabbitMQ, checkoutItems)
		if err != nil {
			logrus.Errorf("❌ Gagal mengirim checkout ke RabbitMQ: %v", err)
		} else {
			logrus.Info("✅ Berhasil mengirim checkout ke RabbitMQ")

			// Fetch store data untuk mendapatkan email
			storeMap, err := fetchStoreData()
			if err != nil {
				logrus.Warnf("⚠️ Gagal mengambil data store: %v, akan skip pengiriman email", err)
			}

			// Kelompokkan items berdasarkan STORE
			itemsByStore := make(map[string][]struct {
				PLU         string `json:"PLU"`
				Qty         int32  `json:"QTY"`
				ExpiredDate string `json:"EXPIRED_DATE"`
			})

			var transactionID, customerName, tipePengiriman, statusBayar, statusBayarEmail string
			for _, item := range checkoutItems {
				// Set transaction info dari item pertama
				if transactionID == "" {
					transactionID = item.ID_TRANSAKSI
					customerName = item.NamaCustomer
					tipePengiriman = item.TipePengiriman
					statusBayar = item.StatusBayar

					// Determine status bayar email label
					switch item.StatusBayar {
					case "BELUM_BAYAR":
						statusBayarEmail = "Menunggu Pembayaran"
					case "PAYMENT_SUCCESS":
						statusBayarEmail = "Pembayaran Sukses"
					case "CANCEL":
						statusBayarEmail = "Transaksi Dibatalkan"
					case "EXPIRED":
						statusBayarEmail = "Payment Expired"
					default:
						statusBayarEmail = item.StatusBayar
					}
				}

				// Group by store
				itemsByStore[item.Store] = append(itemsByStore[item.Store], struct {
					PLU         string `json:"PLU"`
					Qty         int32  `json:"QTY"`
					ExpiredDate string `json:"EXPIRED_DATE"`
				}{
					PLU:         item.PLU,
					Qty:         item.Qty,
					ExpiredDate: item.ExpiredDate,
				})
			}

			// Kirim email untuk setiap store
			for storeID, items := range itemsByStore {
				storeInfo, exists := storeMap[storeID]
				if !exists {
					logrus.Warnf("⚠️ Store %s tidak ditemukan di data store, skip email", storeID)
					continue
				}

				if storeInfo.Email == "" {
					logrus.Warnf("⚠️ Store %s tidak memiliki email, skip email", storeID)
					continue
				}

				// Kirim email menggunakan V2
				err := KirimEmailCheckoutV2(storeID, storeInfo.Email, transactionID, customerName, tipePengiriman, statusBayar, statusBayarEmail, items)
				if err != nil {
					logrus.Errorf("❌ Gagal mengirim email ke store %s (%s): %v", storeID, storeInfo.Email, err)
				} else {
					logrus.Infof("✅ Berhasil mengirim email checkout ke store %s (%s) dengan %d item", storeID, storeInfo.Email, len(items))
				}
			}
		}
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": "Checkout berhasil"})
}

// rabbit checkout
// Fungsi untuk mengirim satu pesan ke RabbitMQ
func PublishMessage(ch *amqp.Channel, queueName string, message []byte) error {
	return ch.Publish(
		"", queueName, false, false,
		amqp.Publishing{
			ContentType: "application/json",
			Body:        message,
		},
	)
}

func SendCheckoutToRabbitMQ(ch *amqp.Channel, itemDetails []struct {
	ID_TRANSAKSI   string `json:"ID_TRANSAKSI"`
	ID             int    `json:"ID"`
	Store          string `json:"STORE"`
	NamaCustomer   string `json:"NAMA_CUSTOMER"`
	PLU            string `json:"PLU"`
	Qty            int32  `json:"QTY"`
	ExpiredDate    string `json:"EXPIRED_DATE"`
	StatusBayar    string `json:"STATUS_BAYAR"`
	TipePengiriman string `json:"TIPE_PENGIRIMAN"`
}) error {
	queueName := "SALES" // Nama antrian RabbitMQ

	for _, item := range itemDetails {
		// Konversi setiap item menjadi JSON
		messageBytes, err := json.Marshal(item)
		if err != nil {
			log.Printf("❌ Gagal mengonversi item ke JSON: %v\n", err)
			continue
		}

		// Kirim pesan ke RabbitMQ
		err = PublishMessage(ch, queueName, messageBytes)
		if err != nil {
			log.Printf("❌ Gagal mengirim pesan ke RabbitMQ untuk item ID=%d: %v\n", item.ID, err)
			continue
		} else {
			log.Printf("✅ Berhasil mengirim item ID=%d ke antrian SALES\n", item.ID)
		}
	}

	return nil
}

// end rabbit checkout
// kirim email checout ke Store
func KirimEmailCheckout(to string, warna_status, Status string) error {
	// Konfigurasi SMTP
	smtpHost := "mail.amscorp.co.id"
	smtpPort := 587
	senderEmail := "noreply@amscorp.co.id" // Ganti dengan email Anda
	senderPassword := "Manisasamasin123"   // Ganti dengan password email Anda

	// Template email
	subject := "[ORDER ONLINE]-Transaksi Website Celcius"
	body := fmt.Sprintf(`
	<html>
<head>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f9f9f9;
            margin: 0;
            padding: 0;
        }
        .email-container {
            max-width: 600px;
            margin: 20px auto;
            background-color: #ffffff;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        .header {
            background-color: #08255d;
            color: #ffffff;
            padding: 20px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 24px;
        }
        .content {
            padding: 20px;
            line-height: 1.6;
            color: #333333;
        }
        .info-box {
            margin: 20px 0;
            padding: 15px;
            background-color: #f4fdf4;
            border: 1px dashed #4CAF50;
            border-radius: 8px;
        }
        .info-item {
            margin: 5px 0;
            font-weight: bold;
        }
        .footer {
            background-color: #f1f1f1;
            color: #666666;
            text-align: center;
            padding: 10px;
            font-size: 12px;
        }
        .footer a {
            color: #4CAF50;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div style="padding-bottom:20px"> 
        <center>
            <img src="https://web.amscorp.id:3060/images/ams_logo_white.png" width="170px" alt="Logo" />
        </center>
    </div>
    <div class="email-container">
        <div class="header">
            <h1>Informasi Pemesanan Anda</h1>
        </div>
        <div class="content">
            <p>Halo,</p>
            <p>Terima kasih atas pesanan Anda. Berikut adalah detail pesanan Anda:</p>
            <div class="info-box">
                <div class="info-item">Nomor Pemesanan: <span>#12345678</span></div>
                <div class="info-item">Status: <span style="color: %s; font-weight: bold;">%s</span></div>
                <div class="info-item">Nama Barang: <span>Nama Barang Anda</span></div>
                <div class="info-item">Jumlah Barang: <span>2</span></div>
                <div class="info-item">Nama Pemesan: <span>John Doe</span></div>
                <div class="info-item">Alamat: <span>Jl. Contoh Alamat No. 123, Jakarta</span></div>
            </div>
            <p>Silakan lakukan pembayaran sesegera mungkin untuk menghindari pembatalan pesanan.</p>
            <p>Terima kasih,</p>
            <p><strong>AMSCORP</strong></p>
        </div>
        <div class="footer">
            <p>Email ini dikirimkan secara otomatis, harap tidak membalas.</p>
        </div>
    </div>
</body>
</html> 
	`, warna_status, Status)

	// Membuat email
	m := gomail.NewMessage()
	m.SetHeader("From", senderEmail)
	m.SetHeader("To", to)
	m.SetHeader("Subject", subject)
	m.SetBody("text/html", body)

	// Mengirim email
	d := gomail.NewDialer(smtpHost, smtpPort, senderEmail, senderPassword)
	return d.DialAndSend(m)
}

//end kirim email checkout

// Helper function untuk fetch store data dari API
type StoreInfo struct {
	Store     string  `json:"store"`
	Email     string  `json:"email"`
	Kota      string  `json:"kota"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

func fetchStoreData() (map[string]StoreInfo, error) {
	storeMap := make(map[string]StoreInfo)

	client := &http.Client{
		Timeout: 15 * time.Second,
	}

	// Use external API only to avoid localhost connection issues
	apiURL := "https://golangapi-j5iu.onrender.com/api/shop/store"

	resp, err := client.Get(apiURL)
	if err != nil {
		logrus.Warnf("⚠️ Gagal mengambil data store dari API %s: %v", apiURL, err)
		return storeMap, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		err := fmt.Errorf("API returned status code %d", resp.StatusCode)
		logrus.Warnf("⚠️ API store mengembalikan status code %d", resp.StatusCode)
		return storeMap, err
	}

	var apiResponse struct {
		Message string      `json:"message"`
		Data    []StoreInfo `json:"data"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&apiResponse); err != nil {
		logrus.Warnf("⚠️ Gagal parsing response dari API store: %v", err)
		return storeMap, err
	}

	// Build map of store_id -> StoreInfo
	for _, store := range apiResponse.Data {
		storeMap[store.Store] = store
	}

	logrus.Infof("✅ Berhasil mengambil data store dari API, total: %d store", len(storeMap))
	return storeMap, nil
}

// KirimEmailCheckoutV2 - Mengirim email checkout dengan detail item per store
func KirimEmailCheckoutV2(storeID, storeEmail, transactionID, customerName, tipePengiriman, statusBayar, statusBayarEmail string, items []struct {
	PLU         string `json:"PLU"`
	Qty         int32  `json:"QTY"`
	ExpiredDate string `json:"EXPIRED_DATE"`
}) error {
	// Konfigurasi SMTP
	smtpHost := "mail.amscorp.co.id"
	smtpPort := 587
	senderEmail := "noreply@amscorp.co.id"
	senderPassword := "Manisasamasin123"

	// Determine status color based on tipe pengiriman
	tipePengirimanColor := "#08255d"
	tipePengirimanLabel := tipePengiriman
	if tipePengiriman == "HOME_DELIVERY" {
		tipePengirimanColor = "#4CAF50"
		tipePengirimanLabel = "Home Delivery"
	}

	// Determine status bayar color
	statusBayarColor := "#08255d"
	if statusBayar == "BELUM_BAYAR" {
		statusBayarColor = "#FFA500"
	} else if statusBayar == "PAYMENT_SUCCESS" {
		statusBayarColor = "#1dbf2b"
	} else if statusBayar == "CANCEL" || statusBayar == "EXPIRED" {
		statusBayarColor = "#ed2323"
	}

	// Build items table HTML
	itemsTableHTML := ""
	totalQty := int32(0)
	if len(items) > 0 {
		for _, item := range items {
			totalQty += item.Qty
			itemsTableHTML += fmt.Sprintf(`
			<tr style="border-bottom: 1px solid #e0e0e0;">
				<td style="padding: 12px; text-align: left;">%s</td>
				<td style="padding: 12px; text-align: center;">%d</td>
				<td style="padding: 12px; text-align: center;">%s</td>
			</tr>`, item.PLU, item.Qty, item.ExpiredDate)
		}
		itemsTableHTML += fmt.Sprintf(`
							<tr class="total-row">
								<td style="text-align: right; font-weight: 600;">Total:</td>
								<td style="text-align: center; font-weight: 600;">%d</td>
								<td></td>
							</tr>`, totalQty)
	} else {
		// Jika tidak ada items (untuk callback status update)
		itemsTableHTML = `
			<tr>
				<td colspan="3" style="padding: 20px; text-align: center; color: #666666;">
					<p style="margin: 0;">Notifikasi Update Status Pembayaran</p>
					<p style="margin: 5px 0 0 0; font-size: 12px;">Detail item tidak tersedia untuk notifikasi status ini.</p>
				</td>
			</tr>`
		totalQty = 0
	}

	// Template email
	subject := fmt.Sprintf("[ORDER ONLINE] - Transaksi %s - Store %s", transactionID, storeID)
	body := fmt.Sprintf(`
	<!DOCTYPE html>
	<html>
	<head>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<style>
			body {
				font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
				background-color: #f5f5f5;
				margin: 0;
				padding: 0;
			}
			.email-wrapper {
				max-width: 650px;
				margin: 20px auto;
				background-color: #ffffff;
				border-radius: 10px;
				box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
				overflow: hidden;
			}
			.header {
				background: linear-gradient(135deg, #08255d 0%%, #1a4a8a 100%%);
				color: #ffffff;
				padding: 30px 20px;
				text-align: center;
			}
			.header h1 {
				margin: 0;
				font-size: 24px;
				font-weight: 600;
			}
			.content {
				padding: 30px;
				color: #333333;
			}
			.info-card {
				background-color: #f8f9fa;
				border-left: 4px solid #08255d;
				padding: 20px;
				margin: 20px 0;
				border-radius: 5px;
			}
			.info-row {
				display: flex;
				justify-content: space-between;
				padding: 8px 0;
				border-bottom: 1px solid #e0e0e0;
			}
			.info-row:last-child {
				border-bottom: none;
			}
			.info-label {
				font-weight: 600;
				color: #555555;
				min-width: 150px;
			}
			.info-value {
				color: #333333;
				text-align: right;
				flex: 1;
			}
			.badge {
				display: inline-block;
				padding: 5px 12px;
				border-radius: 20px;
				font-size: 12px;
				font-weight: 600;
				color: #ffffff;
			}
			.items-section {
				margin: 25px 0;
			}
			.section-title {
				font-size: 18px;
				font-weight: 600;
				color: #08255d;
				margin-bottom: 15px;
				padding-bottom: 10px;
				border-bottom: 2px solid #08255d;
			}
			.items-table {
				width: 100%%;
				border-collapse: collapse;
				margin-top: 15px;
				background-color: #ffffff;
				box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
			}
			.items-table th {
				background-color: #08255d;
				color: #ffffff;
				padding: 12px;
				text-align: left;
				font-weight: 600;
				font-size: 14px;
			}
			.items-table th:nth-child(2),
			.items-table th:nth-child(3) {
				text-align: center;
			}
			.items-table td {
				padding: 12px;
				font-size: 14px;
			}
			.items-table tbody tr:hover {
				background-color: #f5f5f5;
			}
			.total-row {
				background-color: #f8f9fa;
				font-weight: 600;
			}
			.footer {
				background-color: #f1f1f1;
				color: #666666;
				text-align: center;
				padding: 20px;
				font-size: 12px;
				border-top: 1px solid #e0e0e0;
			}
			.footer a {
				color: #08255d;
				text-decoration: none;
			}
		</style>
	</head>
	<body>
		<div style="padding: 20px 0; text-align: center;">
			<img src="https://web.amscorp.id:3060/images/ams_logo_white.png" width="170px" alt="AMS Logo" style="margin-bottom: 10px;" />
		</div>
		<div class="email-wrapper">
			<div class="header">
				<h1>📦	<div style="font-color: black;"> Notifikasi Order Online </div> </h1>
			</div>
			<div class="content">
				<p style="font-size: 16px; margin-bottom: 20px;">Halo Tim Store <strong>%s</strong>,</p>
				<p style="margin-bottom: 25px;">Anda menerima order baru dari website Celcius. Berikut detail pesanan:</p>
				
				<div class="info-card">
					<div class="info-row">
						<span class="info-label">ID Transaksi:</span>
						<span class="info-value"><strong>%s</strong></span>
					</div>
					<div class="info-row">
						<span class="info-label">Nama Customer:</span>
						<span class="info-value"><strong>%s</strong></span>
					</div>
					<div class="info-row">
						<span class="info-label">Status Pembayaran:</span>
						<span class="info-value">
							<span class="badge" style="background-color: %s;">%s</span>
						</span>
					</div>
					<div class="info-row">
						<span class="info-label">Tipe Pengiriman:</span>
						<span class="info-value">
							<span class="badge" style="background-color: %s;">%s</span>
						</span>
					</div>
					<div class="info-row">
						<span class="info-label">Store ID:</span>
						<span class="info-value"><strong>%s</strong></span>
					</div>
				</div>
				
				<div class="items-section">
					<div class="section-title">📋 Detail Item Pesanan</div>
					<table class="items-table">
						<thead>
							<tr>
								<th>PLU</th>
								<th>Qty</th>
								<th>Expired Date</th>
							</tr>
						</thead>
						<tbody>
							%s
						</tbody>
					</table>
				</div>
				
				<div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 5px;">
					<p style="margin: 0; font-size: 14px; color: #856404;">
						<strong>⚠️ Perhatian:</strong> Silakan siapkan barang sesuai dengan detail di atas. Pastikan expired date sesuai dan barang dalam kondisi baik.
					</p>
				</div>
				
				<p style="margin-top: 25px;">Terima kasih atas perhatiannya.</p>
				<p style="margin-top: 10px;"><strong>AMSCORP - OmniChannel Team</strong></p>
			</div>
			<div class="footer">
				<p>Email ini dikirimkan secara otomatis, harap tidak membalas email ini.</p>
				<p style="margin-top: 5px;">
					<a href="https://amscorp.id">www.amscorp.id</a> | 
					<a href="mailto:support@amscorp.co.id">support@amscorp.co.id</a>
				</p>
			</div>
		</div>
	</body>
	</html>`, storeID, transactionID, customerName, statusBayarColor, statusBayarEmail, tipePengirimanColor, tipePengirimanLabel, storeID, itemsTableHTML)

	// Membuat email
	m := gomail.NewMessage()
	m.SetHeader("From", senderEmail)
	m.SetHeader("To", storeEmail)
	m.SetHeader("Subject", subject)
	m.SetBody("text/html", body)

	// Mengirim email
	d := gomail.NewDialer(smtpHost, smtpPort, senderEmail, senderPassword)
	return d.DialAndSend(m)
}

// START CALLBACK SAAT CANCEL TRANSAKSI
func (c *StockKingController) TransactionStatus(w http.ResponseWriter, r *http.Request) {
	if c.redisUnavailable(w) {
		return
	}
	// Struktur data request yang sesuai dengan format JSON yang diberikan
	var request struct {
		Transaction struct {
			ID_TRANSAKSI string `json:"ID_TRANSAKSI"`
			Store        string `json:"STORE"`
			StatusBayar  string `json:"STATUS_BAYAR"`
		} `json:"transaction"`
	}

	// Validasi apakah RabbitMQ sudah diinisialisasi
	if c.RabbitMQ == nil {
		logrus.Error("❌ RabbitMQ belum diinisialisasi")
		http.Error(w, "Server error: RabbitMQ tidak tersedia", http.StatusInternalServerError)
		return
	}

	// Decode body request
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		http.Error(w, "Invalid JSON input", http.StatusBadRequest)
		return
	}

	// Validasi apakah semua field yang dibutuhkan ada
	if request.Transaction.ID_TRANSAKSI == "" || request.Transaction.Store == "" || request.Transaction.StatusBayar == "" {
		http.Error(w, `{"error": "missing required fields"}`, http.StatusBadRequest)
		return
	}

	// Buat koneksi Redis (atau gunakan koneksi yang sudah ada)
	redisClient := c.RedisClient // Redis client dari controller

	// Cek koneksi Redis
	ctx := context.Background()
	_, err := redisClient.Ping(ctx).Result()
	if err != nil {
		logrus.Errorf("❌ Gagal terhubung ke Redis: %v", err)
		http.Error(w, "Server error: gagal terhubung ke Redis", http.StatusInternalServerError)
		return
	}

	// Cek apakah transaksi sudah ada di Redis
	cacheKey := fmt.Sprintf("transaction:%s", request.Transaction.ID_TRANSAKSI)
	exists, err := redisClient.Exists(ctx, cacheKey).Result()
	if err != nil {
		http.Error(w, "Server error: gagal cek duplikasi transaksi", http.StatusInternalServerError)
		return
	}

	if exists == 0 {
		// Jika transaksi tidak ada, simpan data transaksi baru ke Redis dengan TTL 24 jam
		err = redisClient.Set(ctx, cacheKey, request.Transaction.StatusBayar, 24*time.Hour).Err()
		if err != nil {
			logrus.Errorf("❌ Gagal menyimpan transaksi baru di Redis: %v", err)
			http.Error(w, "Server error: gagal menyimpan transaksi baru di Redis", http.StatusInternalServerError)
			return
		}
		logrus.Infof("✅ Transaksi %s berhasil disimpan di Redis", request.Transaction.ID_TRANSAKSI)

		// Menentukan queueName berdasarkan StatusBayar
		var queueName string
		var status_bayar_email string
		switch request.Transaction.StatusBayar {
		case "CANCEL":
			queueName = "SALES_PAYMENT_CANCEL"
			status_bayar_email = "Transaksi Dibatalkan"
		case "PAYMENT_SUCCESS":
			queueName = "SALES_PAYMENT_SUCCESS"
			status_bayar_email = "Pembayaran Sukses"
		case "EXPIRED":
			queueName = "SALES_PAYMENT_EXPIRED"
			status_bayar_email = "Payment Expired"
		default:
			logrus.Errorf("❌ Status pembayaran tidak valid: %s", request.Transaction.StatusBayar)
			http.Error(w, `{"error": "invalid StatusBayar"}`, http.StatusBadRequest)
			return
		}
		// Kirim email menggunakan V2
		// Fetch store data untuk mendapatkan email
		storeMap, err := fetchStoreData()
		if err != nil {
			logrus.Warnf("⚠️ Gagal mengambil data store: %v, akan skip pengiriman email", err)
		} else {
			storeInfo, exists := storeMap[request.Transaction.Store]
			if exists && storeInfo.Email != "" {
				// Untuk callback, kita tidak punya detail item, jadi kirim email dengan items kosong
				// atau bisa query database untuk mendapatkan detail item
				emptyItems := []struct {
					PLU         string `json:"PLU"`
					Qty         int32  `json:"QTY"`
					ExpiredDate string `json:"EXPIRED_DATE"`
				}{}

				err := KirimEmailCheckoutV2(
					request.Transaction.Store,
					storeInfo.Email,
					request.Transaction.ID_TRANSAKSI,
					"", // Customer name tidak tersedia di callback
					"", // Tipe pengiriman tidak tersedia di callback
					request.Transaction.StatusBayar,
					status_bayar_email,
					emptyItems,
				)
				if err != nil {
					logrus.Errorf("❌ Gagal mengirim email ke store %s (%s): %v", request.Transaction.Store, storeInfo.Email, err)
				} else {
					logrus.Infof("✅ Berhasil mengirim email status update ke store %s (%s)", request.Transaction.Store, storeInfo.Email)
				}
			} else {
				logrus.Warnf("⚠️ Store %s tidak ditemukan atau tidak memiliki email, skip email", request.Transaction.Store)
			}
		}

		// Konversi data transaksi ke JSON
		messageBytes, err := json.Marshal(request.Transaction)
		if err != nil {
			log.Printf("❌ Gagal mengonversi transaksi ke JSON: %v\n", err)
			http.Error(w, "Server error: gagal mengonversi transaksi", http.StatusInternalServerError)
			return
		}

		// Kirim pesan ke RabbitMQ
		err = PublishMessage(c.RabbitMQ, queueName, messageBytes)
		if err != nil {
			log.Printf("❌ Gagal mengirim pesan ke RabbitMQ untuk transaksi %s: %v\n", request.Transaction.ID_TRANSAKSI, err)
			http.Error(w, `{"error": "failed to publish message to RabbitMQ"}`, http.StatusInternalServerError)
			return
		}

		// Log keberhasilan dan kirim respon sukses
		log.Printf("✅ Berhasil mengirim transaksi %s ke antrian %s\n", request.Transaction.ID_TRANSAKSI, queueName)

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"message": "Transaction processed successfully"}`))
		return
	}

	// Ambil status bayar dari Redis
	currentStatusBayar, err := redisClient.Get(ctx, cacheKey).Result()
	if err != nil {
		http.Error(w, "Server error: gagal mengambil status bayar dari Redis", http.StatusInternalServerError)
		return
	}

	// Jika status bayar sudah ada dan sama dengan yang diterima, hentikan proses
	if currentStatusBayar == request.Transaction.StatusBayar {
		http.Error(w, `{"error": "status bayar sudah sama"}`, http.StatusBadRequest)
		return
	}

	// Simpan status bayar di Redis dengan TTL 24 jam
	err = redisClient.Set(ctx, cacheKey, request.Transaction.StatusBayar, 24*time.Hour).Err()
	if err != nil {
		logrus.Errorf("❌ Gagal menyimpan status bayar di Redis: %v", err)
		http.Error(w, "Server error: gagal menyimpan status bayar di Redis", http.StatusInternalServerError)
		return
	}
	logrus.Infof("✅ Status bayar %s berhasil diperbarui di Redis", request.Transaction.StatusBayar)

	// Menentukan queueName berdasarkan StatusBayar
	var queueName string
	var status_bayar_email string
	switch request.Transaction.StatusBayar {
	case "CANCEL":
		queueName = "SALES_PAYMENT_CANCEL"
		status_bayar_email = "Transaksi Dibatalkan"
	case "PAYMENT_SUCCESS":
		queueName = "SALES_PAYMENT_SUCCESS"
		status_bayar_email = "Pembayaran Sukses"
	case "EXPIRED":
		queueName = "SALES_PAYMENT_EXPIRED"
		status_bayar_email = "Payment Expired"
	default:
		logrus.Errorf("❌ Status pembayaran tidak valid: %s", request.Transaction.StatusBayar)
		http.Error(w, `{"error": "invalid StatusBayar"}`, http.StatusBadRequest)
		return
	}

	// Kirim email menggunakan V2
	// Fetch store data untuk mendapatkan email
	storeMap, err := fetchStoreData()
	if err != nil {
		logrus.Warnf("⚠️ Gagal mengambil data store: %v, akan skip pengiriman email", err)
	} else {
		storeInfo, exists := storeMap[request.Transaction.Store]
		if exists && storeInfo.Email != "" {
			// Untuk callback, kita tidak punya detail item, jadi kirim email dengan items kosong
			emptyItems := []struct {
				PLU         string `json:"PLU"`
				Qty         int32  `json:"QTY"`
				ExpiredDate string `json:"EXPIRED_DATE"`
			}{}

			err := KirimEmailCheckoutV2(
				request.Transaction.Store,
				storeInfo.Email,
				request.Transaction.ID_TRANSAKSI,
				"", // Customer name tidak tersedia di callback
				"", // Tipe pengiriman tidak tersedia di callback
				request.Transaction.StatusBayar,
				status_bayar_email,
				emptyItems,
			)
			if err != nil {
				logrus.Errorf("❌ Gagal mengirim email ke store %s (%s): %v", request.Transaction.Store, storeInfo.Email, err)
			} else {
				logrus.Infof("✅ Berhasil mengirim email status update ke store %s (%s)", request.Transaction.Store, storeInfo.Email)
			}
		} else {
			logrus.Warnf("⚠️ Store %s tidak ditemukan atau tidak memiliki email, skip email", request.Transaction.Store)
		}
	}

	// Konversi data transaksi ke JSON
	messageBytes, err := json.Marshal(request.Transaction)
	if err != nil {
		log.Printf("❌ Gagal mengonversi transaksi ke JSON: %v\n", err)
		http.Error(w, "Server error: gagal mengonversi transaksi", http.StatusInternalServerError)
		return
	}

	// Kirim pesan ke RabbitMQ
	err = PublishMessage(c.RabbitMQ, queueName, messageBytes)
	if err != nil {
		log.Printf("❌ Gagal mengirim pesan ke RabbitMQ untuk transaksi %s: %v\n", request.Transaction.ID_TRANSAKSI, err)
		http.Error(w, `{"error": "failed to publish message to RabbitMQ"}`, http.StatusInternalServerError)
		return
	}

	// Log keberhasilan dan kirim respon sukses
	log.Printf("✅ Berhasil mengirim transaksi %s ke antrian %s\n", request.Transaction.ID_TRANSAKSI, queueName)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"message": "Transaction processed successfully"}`))
}

func (c *StockKingController) TransactionReport(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading SpaceX: ", err.Error())
	}

	var JsonResultData string
	database.Instance.QueryContext(ctx, "xsp_omnichannel_get_order_report",

		sql.Named("store_id", r.FormValue("storeID")),
		sql.Named("status_csv", r.FormValue("statusCSV")),
		sql.Named("date_from", r.FormValue("fromDate")),
		sql.Named("date_to", r.FormValue("toDate")),
		sql.Named("q", r.FormValue("keywords")),
		sql.Named("page", r.FormValue("page")),
		sql.Named("page_size", r.FormValue("pageSize")),
		sql.Named("sort", r.FormValue("sort")),
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	w.Header().Set("Content-Type", "application/json")
	//w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, string(JsonResultData))
	//json.NewEncoder(w).Encode(products)
}
