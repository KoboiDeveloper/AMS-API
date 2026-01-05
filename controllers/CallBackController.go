package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/go-redis/redis/v8"
	"github.com/sirupsen/logrus"
	"github.com/streadway/amqp"
	"gopkg.in/gomail.v2"
)

type c_StockKingController struct {
	RedisClient *redis.Client
	RabbitMQ    *amqp.Channel
	QueueName   string
}

// Struktur response JSON
type c_StockResponse struct {
	ItemDetail []ItemDetail `json:"itemDetail"`
}

type c_ItemDetail struct {
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
func (c *c_StockKingController) c_GetGlobalStockPLUStore(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	storeID := r.URL.Query().Get("store") // Ambil parameter store

	if storeID == "" {
		http.Error(w, `{"error": "store parameter is required"}`, http.StatusBadRequest)
		return
	}

	// Cek apakah Store ID ada di index Redis
	isMember, err := c.RedisClient.SIsMember(ctx, "Index:Stores", storeID).Result()
	if err != nil || !isMember {
		logrus.Warnf("Store ID tidak ditemukan di index: %s", storeID)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"itemDetail": []}`)) // Return array kosong jika tidak ada data
		return
	}

	// Ambil semua PLU terkait Store ID menggunakan Redis KEYS atau Lua Script
	keysPattern := fmt.Sprintf("Realtime_Stock:All_Store:%s:*", storeID)
	keys, err := c.RedisClient.Keys(ctx, keysPattern).Result() // Bisa diganti dengan SCAN via Lua
	if err != nil || len(keys) == 0 {
		logrus.Warnf("Tidak ada data stok untuk Store ID: %s", storeID)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"itemDetail": []}`))
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

	// Parsing JSON hasil batch GET
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

		stockItems = append(stockItems, item)
	}

	// Buat response JSON
	response := StockResponse{ItemDetail: stockItems}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// Handler API untuk mendapatkan stok berdasarkan store ID, dengan filter article, size, dan color
func (c *c_StockKingController) c_GetGlobalStockOnline_DENGAN_STORE(w http.ResponseWriter, r *http.Request) {
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

func (c *c_StockKingController) c_GetGlobalStockOnline(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	article := r.URL.Query().Get("article")
	size := r.URL.Query().Get("size")
	color := r.URL.Query().Get("color")

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

				// Filter berdasarkan size & color
				if (size == "" || item.Size == size) && (color == "" || item.Color == color) {
					// Ambil Store ID dari key Redis
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

func (c *c_StockKingController) c_PushCheckOut(w http.ResponseWriter, r *http.Request) {
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
			//KirimEmailCheckout("heru.it@amscorp.co.id", "xxxxx")
		}
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": "Checkout berhasil"})
}

// rabbit checkout
// Fungsi untuk mengirim satu pesan ke RabbitMQ
func c_PublishMessage(ch *amqp.Channel, queueName string, message []byte) error {
	return ch.Publish(
		"", queueName, false, false,
		amqp.Publishing{
			ContentType: "application/json",
			Body:        message,
		},
	)
}

func c_SendCheckoutToRabbitMQ(ch *amqp.Channel, itemDetails []struct {
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
func c_KirimEmailCheckout(to string, otp string) error {
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
                <div class="info-item">Status: <span style="color: #FFA500; font-weight: bold;">Menunggu Pembayaran</span>/  <span style="color: #ed2323; font-weight: bold;">Transaksi Dibatalkan</span> / <span style="color: #1dbf2b; font-weight: bold;">Pembayaran Sukses</span></div>
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
	`, otp)

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
