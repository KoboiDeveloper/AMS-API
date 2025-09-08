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

// Struktur response JSON
type StockResponse struct {
	ItemDetail []ItemDetail `json:"itemDetail"`
}

type ItemDetail struct {
	Brand       string  `json:"brand"`
	StoreID     string  `json:"store_id"`
	Kota        string  `json:"kota"`
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

	// Buat response JSON
	response := StockResponse{ItemDetail: stockItems}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

func (c *StockKingController) PushCheckOut(w http.ResponseWriter, r *http.Request) {
	var request struct {
		ItemDetail []struct {
			ID_TRANSAKSI string `json:"ID_TRANSAKSI"`
			ID           int    `json:"ID"`
			Store        string `json:"STORE"`
			NamaCustomer string `json:"NAMA_CUSTOMER"`
			PLU          string `json:"PLU"`
			Qty          int32  `json:"QTY"`
			ExpiredDate  string `json:"EXPIRED_DATE"`
			StatusBayar  string `json:"STATUS_BAYAR"`
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
		ID_TRANSAKSI string `json:"ID_TRANSAKSI"`
		ID           int    `json:"ID"`
		Store        string `json:"STORE"`
		NamaCustomer string `json:"NAMA_CUSTOMER"`
		PLU          string `json:"PLU"`
		Qty          int32  `json:"QTY"`
		ExpiredDate  string `json:"EXPIRED_DATE"`
		StatusBayar  string `json:"STATUS_BAYAR"`
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
			KirimEmailCheckout("heru.it@amscorp.co.id", "#FFA500", "Menunggu Pembayaran")
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
	ID_TRANSAKSI string `json:"ID_TRANSAKSI"`
	ID           int    `json:"ID"`
	Store        string `json:"STORE"`
	NamaCustomer string `json:"NAMA_CUSTOMER"`
	PLU          string `json:"PLU"`
	Qty          int32  `json:"QTY"`
	ExpiredDate  string `json:"EXPIRED_DATE"`
	StatusBayar  string `json:"STATUS_BAYAR"`
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

// START CALLBACK SAAT CANCEL TRANSAKSI
func (c *StockKingController) TransactionStatus(w http.ResponseWriter, r *http.Request) {
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
		var warna_status string
		switch request.Transaction.StatusBayar {
		case "CANCEL":
			queueName = "SALES_PAYMENT_CANCEL"
			status_bayar_email = "Transaksi Dibatalkan"
			warna_status = "#ed2323"
		case "PAYMENT_SUCCESS":
			queueName = "SALES_PAYMENT_SUCCESS"
			status_bayar_email = "Pembayaran Sukses"
			warna_status = "#1dbf2b"
		case "EXPIRED":
			queueName = "SALES_PAYMENT_EXPIRED"
			status_bayar_email = "Payment Expired"
			warna_status = "#ed2323"
		default:
			logrus.Errorf("❌ Status pembayaran tidak valid: %s", request.Transaction.StatusBayar)
			http.Error(w, `{"error": "invalid StatusBayar"}`, http.StatusBadRequest)
			return
		}
		KirimEmailCheckout("heru.it@amscorp.co.id", warna_status, status_bayar_email)

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
	var warna_status string
	switch request.Transaction.StatusBayar {
	case "CANCEL":
		queueName = "SALES_PAYMENT_CANCEL"
		status_bayar_email = "Transaksi Dibatalkan"
		warna_status = "#ed2323"
	case "PAYMENT_SUCCESS":
		queueName = "SALES_PAYMENT_SUCCESS"
		status_bayar_email = "Pembayaran Sukses"
		warna_status = "#1dbf2b"
	case "EXPIRED":
		queueName = "SALES_PAYMENT_EXPIRED"
		status_bayar_email = "Payment Expired"
		warna_status = "#ed2323"
	default:
		logrus.Errorf("❌ Status pembayaran tidak valid: %s", request.Transaction.StatusBayar)
		http.Error(w, `{"error": "invalid StatusBayar"}`, http.StatusBadRequest)
		return
	}

	KirimEmailCheckout("heru.it@amscorp.co.id", warna_status, status_bayar_email)

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
