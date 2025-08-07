package main

import (
	"GOamsAPI/controllers"
	"GOamsAPI/database"
	"GOamsAPI/middleware"
	"fmt"
	"log"
	"net/http"

	"github.com/go-redis/redis/v8"
	"github.com/gorilla/mux"
	"github.com/rs/cors"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
	"github.com/streadway/amqp"
)

// Struktur Config untuk membaca konfigurasi dari YAML
type Config struct {
	Port             int    `mapstructure:"port"`
	ConnectionString string `mapstructure:"connection_string"`

	Redis struct {
		URL string `mapstructure:"url"`
	} `mapstructure:"redis"`

	RabbitMQ struct {
		OnlineSales struct {
			URL   string `mapstructure:"url"`
			Queue string `mapstructure:"queue"`
		} `mapstructure:"online_sales"`
	} `mapstructure:"rabbitmq"`
}

var AppConfig *Config
var redisClient *redis.Client
var rabbitConn *amqp.Connection
var rabbitChannel *amqp.Channel

// Load konfigurasi dari config.yaml
func LoadAppConfig() (*Config, error) {
	log.Println("Loading Server Configurations...")
	viper.SetConfigName("config") // Sesuai dengan nama file tanpa ekstensi
	viper.SetConfigType("yaml")   // Format file YAML
	viper.AddConfigPath(".")      // Lokasi file

	if err := viper.ReadInConfig(); err != nil {
		return nil, err
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, err
	}

	return &config, nil
}

// Fungsi untuk menghubungkan ke Redis
func connectToRedis(url string) *redis.Client {
	options, err := redis.ParseURL(url)
	if err != nil {
		logrus.Fatalf("Gagal mengonfigurasi Redis: %v", err)
	}
	return redis.NewClient(options)
}

// Fungsi untuk menghubungkan ke RabbitMQ
func connectToRabbitMQ(url string) (*amqp.Connection, *amqp.Channel, error) {
	conn, err := amqp.Dial(url)
	if err != nil {
		logrus.Errorf("Gagal terhubung ke RabbitMQ: %v", err)
		return nil, nil, err
	}

	ch, err := conn.Channel()
	if err != nil {
		conn.Close()
		logrus.Errorf("Gagal membuka channel: %v", err)
		return nil, nil, err
	}

	return conn, ch, nil
}
func main() {
	// Memuat konfigurasi
	config, err := LoadAppConfig()
	if err != nil {
		logrus.Fatal("Gagal memuat konfigurasi:", err)
	}
	AppConfig = config

	// Menghubungkan ke Database
	database.Connect(AppConfig.ConnectionString)

	// Menghubungkan ke Redis
	redisClient = connectToRedis(AppConfig.Redis.URL)
	defer redisClient.Close()

	// Menghubungkan ke RabbitMQ
	rabbitConn, rabbitChannel, err = connectToRabbitMQ(AppConfig.RabbitMQ.OnlineSales.URL)
	if err != nil {
		logrus.Fatal("Gagal menghubungkan ke RabbitMQ:", err)
	}
	defer rabbitConn.Close()
	defer rabbitChannel.Close()

	// Initialize Router
	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/", controllers.HelloWorld).Methods("GET")

	// Initialize StockKingController with RedisClient
	stockKingController := &controllers.StockKingController{
		RedisClient: redisClient,
		RabbitMQ:    rabbitChannel,
	}
	// Register Routes
	RegisterProductRoutes(router)
	RegisterUserRoutes(router)
	RegisterEssAndroidRoutes(router)
	RegisterStockRealtimeRoutes(router, stockKingController)
	RegisterEssAndroidSORoutes(router)
	RegisterShopeeStockRoutes(router)
	// RegisterRabbitmq(router)

	// CORS Middleware
	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE"},
		AllowedHeaders:   []string{"Content-Type", "Authorization"},
		AllowCredentials: true,
		Debug:            true,
	})

	// Wrap Router dengan CORS Middleware
	handler := c.Handler(router)

	// Start Server
	port := fmt.Sprintf(":%d", AppConfig.Port)
	logrus.Infof("Server berjalan di port %s", port)
	log.Fatal(http.ListenAndServe(port, handler))
}

// RABBITMQ
// func RegisterRabbitmq(router *mux.Router) {

// 	// Inisialisasi RabbitMQ
// 	rabbitClient, err := rabbitmq.NewRabbitMQClient("ereceipt_queue", "amqp://guest:guest@localhost:5672/")
// 	if err != nil {
// 		log.Fatalf("Gagal menghubungkan ke RabbitMQ: %v", err)
// 	}
// 	defer rabbitClient.Close()
// 	//END RABBIT CONNECTION

// 	http.HandleFunc("/push-email", func(w http.ResponseWriter, r *http.Request) {
// 		if r.Method != http.MethodPost {
// 			http.Error(w, "Hanya metode POST yang diizinkan", http.StatusMethodNotAllowed)
// 			return
// 		}

// 		var email rabbitmq.Email
// 		if err := json.NewDecoder(r.Body).Decode(&email); err != nil {
// 			http.Error(w, "Gagal membaca body: "+err.Error(), http.StatusBadRequest)
// 			return
// 		}

// 		if err := rabbitClient.PushEmail(email); err != nil {
// 			http.Error(w, "Gagal mengirim pesan ke RabbitMQ: "+err.Error(), http.StatusInternalServerError)
// 			return
// 		}

// 		w.WriteHeader(http.StatusOK)
// 		fmt.Fprintln(w, "Email berhasil dikirim ke RabbitMQ")
// 	})

// 	log.Println("API server berjalan di port 8080...")
// 	if err := http.ListenAndServe(":8080", nil); err != nil {
// 		log.Fatalf("Gagal menjalankan server: %v", err)
// 	}
// }

func RegisterStockRealtimeRoutes(router *mux.Router, stockKingController *controllers.StockKingController) {
	// STORE LAST STOCK
	router.HandleFunc("/api/global/stock/o/", stockKingController.GetGlobalStockOnline).Methods("GET")
	router.HandleFunc("/api/global/stock/r/store/", stockKingController.GetGlobalStockPLUStore).Methods("GET")
	// CHECKOUT IN WEB STORE
	router.HandleFunc("/api/shopping/checkout", stockKingController.PushCheckOut).Methods("POST")
	// CALLBACK EXPIRED/CANCEL/SUCCESS TRANSACTION
	router.HandleFunc("/api/shopping/transaction/callback", stockKingController.TransactionStatus).Methods("POST")

}

// ANRDOID APP - SELF SERVICES
func RegisterEssAndroidRoutes(router *mux.Router) {
	//STORE LAST STOCK
	router.HandleFunc("/api/Ess/D/ActivitysHome", controllers.GetActivityHome).Methods("GET")
}

// ANDROID APP - STOCK OPNAME STORE
func RegisterEssAndroidSORoutes(router *mux.Router) {
	//Check User exists
	router.HandleFunc("/api/SO/Store/checkuser", controllers.GetUserActive).Methods("GET")
	//insert plu saat so scan
	router.HandleFunc("/api/SO/Store/scan/{code_so}/{store_id}/{tanggal_so}/{plu}/{user_id}", controllers.UploadPluscan).Methods("POST")
	//view history plu scan
	router.HandleFunc("/api/SO/Store/history", controllers.HistoryPluscan).Methods("GET")

	router.HandleFunc("/api/SO/Store/bulkscan", controllers.BulkUploadPluscan).Methods("POST")

}

func RegisterProductRoutes(router *mux.Router) {

	router.HandleFunc("/api/Store/webshocket", controllers.GetdataTest).Methods("GET")
	//STORE LAST STOCK
	router.HandleFunc("/api/Store/LastStock", controllers.GetStoreLastStock).Methods("GET")
	router.HandleFunc("/api/products/{id}", controllers.GetProductById).Methods("GET")
	router.HandleFunc("/api/products", controllers.CreateProduct).Methods("POST")
	router.HandleFunc("/api/products/{id}", controllers.UpdateProduct).Methods("PUT")
	router.HandleFunc("/api/products/{id}", controllers.DeleteProduct).Methods("DELETE")

	///////////////////////////////////////////  SPACE MANAGEMENT
	router.HandleFunc("/api/spacex/spacemanagement", controllers.GetSpaceManagement).Methods("GET")
	router.HandleFunc("/api/spacex/spacemanagement", controllers.CreateSpaceManagement).Methods("POST")
	router.HandleFunc("/api/spacex/spacemanagement", controllers.UpdateSpaceManagement).Methods("PUT")
	router.HandleFunc("/api/spacex/spacemanagement", controllers.DeleteSpaceManagement).Methods("DELETE")

	///////////////////////////////////////////  KOMPOSISI IDEAL
	router.HandleFunc("/api/spacex/KomposisiIdealInfo", controllers.GetKomposisiIdealInfo).Methods("GET")
	router.HandleFunc("/api/spacex/KomposisiIdeal", controllers.GetKomposisiIdeal).Methods("GET")
	router.HandleFunc("/api/spacex/KomposisiIdeal", controllers.CreateKomposisiIdeal).Methods("POST")
	router.HandleFunc("/api/spacex/KomposisiIdeal", controllers.UpdateKomposisiIdeal).Methods("PUT")
	router.HandleFunc("/api/spacex/KomposisiIdeal", controllers.DeleteKomposisiIdeal).Methods("DELETE")

	/////////////////////////////////////////// DROP DOWN
	router.HandleFunc("/api/spacex/dropdown/luasToko", controllers.GetDropdownLuasToko).Methods("GET")
	router.HandleFunc("/api/spacex/dropdown/ClassVM", controllers.GetDropdownClassVM).Methods("GET")
	router.HandleFunc("/api/spacex/dropdown/Class", controllers.GetDropdownClass).Methods("GET")
	router.HandleFunc("/api/spacex/dropdown/AreaSalesVm", controllers.GetDropdownAreaSales).Methods("GET")
	router.HandleFunc("/api/spacex/dropdown/ClassVMSingle", controllers.GetDropdownClassVMSingle).Methods("GET")
	router.HandleFunc("/api/spacex/dropdown/BrandID", controllers.GetDropdownBrandID).Methods("GET")
	router.HandleFunc("/api/spacex/dropdown/BrandIDs", controllers.GetDropdownBrandIDs).Methods("GET")
	router.HandleFunc("/api/spacex/dropdown/StoreID", controllers.GetDropdownStoreID).Methods("GET")
	router.HandleFunc("/api/spacex/dropdown/ArticleByStore", controllers.GetDropdownArticleByStore).Methods("GET")

	///////////////////////////////////////////  AREA SALES
	router.HandleFunc("/api/spacex/AreaSales", controllers.GetAreaSales).Methods("GET")
	router.HandleFunc("/api/spacex/AreaSales", controllers.CreateAreaSales).Methods("POST")
	router.HandleFunc("/api/spacex/AreaSales", controllers.UpdateAreaSales).Methods("PUT")
	router.HandleFunc("/api/spacex/AreaSales", controllers.DeleteAreaSales).Methods("DELETE")
	/////
	///////////////////////////////////////////  GRAND OPENING
	router.HandleFunc("/api/spacex/GrandOpening", controllers.GetGrandOpening).Methods("GET")
	router.HandleFunc("/api/spacex/GrandOpening", controllers.CreateGrandOpening).Methods("POST")
	router.HandleFunc("/api/spacex/GrandOpening", controllers.UpdateGrandOpening).Methods("PUT")
	router.HandleFunc("/api/spacex/GrandOpening", controllers.DeleteGrandOpening).Methods("DELETE")
	///////////////////////////////////////////  GRAND OPENING VM
	router.HandleFunc("/api/spacex/GrandOpening/{id}", controllers.GetGrandOpeningDetail).Methods("GET")

	///////////////////////////////////////////  VM STORAGE - GRAND OPENING
	router.HandleFunc("/api/spacex/VmStorage/{luas_toko}", controllers.GetVmStorage).Methods("GET")
	router.HandleFunc("/api/spacex/VmStorage", controllers.CreateVmStorage).Methods("POST")
	router.HandleFunc("/api/spacex/VmStorage", controllers.UpdateVmStorage).Methods("PUT")
	router.HandleFunc("/api/spacex/VmStorage", controllers.DeleteVmStorage).Methods("DELETE")
	router.HandleFunc("/api/spacex/KategoriluasToko", controllers.GetKategoriLuasToko).Methods("GET")

	// /////////////////////////////////////////  MD BUYER - STORE GRAND OPENING
	router.HandleFunc("/api/spacex/MdBuyerGO/{id}/{brand}", controllers.GetMdBuyerGO).Methods("GET")
	router.HandleFunc("/api/spacex/MdBuyerExsistingStore", controllers.GetMdBuyerExsistingStore).Methods("GET")
	router.HandleFunc("/api/spacex/MdBuyerExsistingStoreByClass", controllers.GetMdBuyerExsistingStoreByclass).Methods("GET")
	router.HandleFunc("/api/spacex/MdBuyerExsistingStoreByDept", controllers.GetMdBuyerExsistingStoreByDept).Methods("GET")
	router.HandleFunc("/api/spacex/MdBuyerExsistingStoreDetailInventory", controllers.GetMdBuyerExsistingStoreDetailInventory).Methods("GET")
	router.HandleFunc("/api/spacex/MdBuyerExsistingStoreDetailInventoryDcScan", controllers.GetMdBuyerExsistingStoreDetailInventory_DC_SCAN).Methods("GET")
	router.HandleFunc("/api/spacex/MdBuyerExsistingStoreDetailInventoryDcScanbyClass", controllers.GetMdBuyerExsistingStoreDetailInventory_DC_SCAN_by_Class).Methods("GET")
	//dropdown
	router.HandleFunc("/api/spacex/dropdown/DropdownGOThemeFilter", controllers.GetDropdownGOThemeFilter).Methods("GET")
	//endDropdown
	router.HandleFunc("/api/spacex/MdBuyerExsistingStoreAgingbyBrand", controllers.GetMdBuyerExsistingBrandAging).Methods("GET")
	router.HandleFunc("/api/spacex/MdBuyerExsistingStoreAgingbyStore", controllers.GetMdBuyerExsistingStoreAging).Methods("GET")
	router.HandleFunc("/api/spacex/MdBuyerExsistingStoreAgingbyStoreClass", controllers.GetMdBuyerExsistingStoreClassAging).Methods("GET")

	/////////////////////////////////////////// IC TARGET SALES

	router.HandleFunc("/api/spacex/TargetSales", controllers.CreateTargetSales).Methods("POST")
	router.HandleFunc("/api/spacex/TargetSales", controllers.UpdateTargetSales).Methods("PUT")
	router.HandleFunc("/api/spacex/TargetSales", controllers.GetTargetSalesStore).Methods("GET")
	router.HandleFunc("/api/spacex/TargetSales/Popoup", controllers.GetTargetSalesStorePopupAnalisis).Methods("GET") //popuAdd for analisis

	//dasboard
	router.HandleFunc("/api/spacex/Dashboard/SalesChartDashboardDaily", controllers.GetSalesChartDashboardDaily).Methods("GET")
	router.HandleFunc("/api/spacex/Dashboard/SalesChartDashboardWeekly", controllers.GetSalesChartDashboardWeekly).Methods("GET")
	router.HandleFunc("/api/spacex/Dashboard/SalesChartDashboardMonthly", controllers.GetSalesChartDashboardMonthly).Methods("GET")
	router.HandleFunc("/api/spacex/Dashboard/TOrendahDashboard", controllers.GetTOrendahDashboard).Methods("GET")
	router.HandleFunc("/api/spacex/Dashboard/GetKurangBarang", controllers.GetKurangBarang).Methods("GET")
	router.HandleFunc("/api/spacex/Dashboard/GetTotalTokoGO", controllers.GetTotalTokoGO).Methods("GET")

	//MEMBER APIS V1.0-------------------------------------------------
	// AUTHORISASI/VERIVY/LOGIN/LOGOUT
	router.HandleFunc("/api/v1.0/member/mobile/dashboard/Verify", controllers.GetVerify).Methods("POST")
	router.HandleFunc("/api/v1.0/member/mobile/dashboard/validate", controllers.GetValidate).Methods("POST")
	router.HandleFunc("/api/v1.0/member/mobile/dashboard/registerVerify", controllers.GetRegisterVerify).Methods("POST")
	router.HandleFunc("/api/v1.0/member/mobile/dashboard/login", controllers.GetLogin).Methods("POST")
	router.HandleFunc("/api/v1.0/member/mobile/dashboard/register", controllers.GetRegisterUser1).Methods("POST")
	router.HandleFunc("/api/v1.0/member/mobile/dashboard/register/validate", controllers.GetRegisterValidate).Methods("POST")

	router.HandleFunc("/api/v1.0/member/mobile/dashboard/info", controllers.GetMemberDashboardInfo1).Methods("GET")
	router.HandleFunc("/api/v1.0/member/mobile/profile", controllers.GetMemberProfile1).Methods("GET")
	router.HandleFunc("/api/v1.0/member/mobile/profile", controllers.GetMemberProfileUpdate1).Methods("PUT")
	//END OF MEMBER APIS V1.0-------------------------------------------

	//MEMBER APIS V2.0
	router.HandleFunc("/api/v2.0/member/activity", controllers.GetmemberActivity).Methods("GET")
	router.HandleFunc("/api/v2.0/member/GrowthActivity", controllers.GetGrowthMemberActivity).Methods("GET")
	// AUTHORISASI/VERIVY/LOGIN/LOGOUT
	router.HandleFunc("/api/v2.0/member/mobile/dashboard/Verify", controllers.GetVerify).Methods("POST")
	router.HandleFunc("/api/v2.0/member/mobile/dashboard/validate", controllers.GetValidate).Methods("POST")
	router.HandleFunc("/api/v2.0/member/mobile/dashboard/registerVerify", controllers.GetRegisterVerify).Methods("POST")
	router.HandleFunc("/api/v2.0/member/mobile/dashboard/login", controllers.GetLogin).Methods("POST")
	router.HandleFunc("/api/v2.0/member/mobile/dashboard/register", controllers.GetRegisterUser).Methods("POST")
	router.HandleFunc("/api/v2.0/member/mobile/dashboard/register/validate", controllers.GetRegisterValidate).Methods("POST")
	// router.HandleFunc("/api/member/mobile/dashboard/logout", controllers.GetLogout).Methods("POST")

	//MEMBER APIS MOBILE
	//----------test dengan jwt
	router.Handle("/api/v2.0/member/mobile/dashboard/infox", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberDashboardInfo))).Methods("GET")

	// -----------
	router.Handle("/api/v2.0/member/mobile/dashboard/info", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberDashboardInfo))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/dashboard/promo", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberDashboardPromo))).Methods("GET")
	//promo
	router.Handle("/api/v2.0/member/mobile/promo/list", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberPromoList))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/promo/detail", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberPromoDetail))).Methods("GET")
	//location
	router.Handle("/api/v2.0/member/mobile/location/list", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetStoreLocationList))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/location/detail", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetStoreLocationDetail))).Methods("GET")
	//profile
	router.Handle("/api/v2.0/member/mobile/profile", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberProfile))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/profile/validate", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberProfileUpdateValidate))).Methods("PUT")
	router.Handle("/api/v2.0/member/mobile/profile", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberProfileUpdate))).Methods("PUT")
	router.Handle("/api/v2.0/member/mobile/profile/auth/1", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberAuthPinUpdate))).Methods("PUT")
	router.Handle("/api/v2.0/member/mobile/profile/auth/2", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberAuthPassUpdate))).Methods("PUT")
	router.Handle("/api/v2.0/member/mobile/profile/auth/forgot", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberAuthForgotPass))).Methods("PUT")
	//transaction
	router.Handle("/api/v2.0/member/mobile/transaction/history", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberTransactionHistory))).Methods("GET")
	//voucher
	router.Handle("/api/v2.0/member/mobile/voucher/redeem", middleware.JWTMiddleware(http.HandlerFunc(controllers.CreateMemberVoucher))).Methods("POST")
	router.Handle("/api/v2.0/member/mobile/voucher/redeem/custom", middleware.JWTMiddleware(http.HandlerFunc(controllers.CreateMemberVoucherCustom))).Methods("POST")
	router.Handle("/api/v2.0/member/mobile/voucher/detail", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberVoucherDetail))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/voucher", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberVoucherList))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/voucher/lucky", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberVoucherLuckyList))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/voucher/history", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberVoucherTransactionHistoryList))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/voucher/tukar", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberVoucherTukarList))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/voucher/tukar/redeem", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberVoucherTukarRedeemList))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/voucher/tukar/luckydraw", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberVoucherTukarLuckyRedeemList))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/voucher", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberVoucherList))).Methods("GET")
	//GIFT

	//REWARD
	router.Handle("/api/v2.0/member/mobile/reward", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberRewardList))).Methods("GET")
	//TIER
	router.Handle("/api/v2.0/member/mobile/tier/list", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMembeTierList))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/tier", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMembeTierInfo))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/point/hitory", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMembePointHistory))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/point/hitory/expired", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMembePointExpired))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/tier/hitory", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMembeTierHistory))).Methods("GET")

	//Master
	router.HandleFunc("/api/v2.0/member/mobile/provinces", controllers.GetProvincesList).Methods("GET")
	router.HandleFunc("/api/v2.0/member/mobile/cities", controllers.GetCitiesList).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/contactinfo", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetContactInfo))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/faq", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetFAQInfo))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/faq/category", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetFAQCategoryInfo))).Methods("GET")
	router.HandleFunc("/api/v2.0/member/mobile/kuya/delete", controllers.GeDeleteIDmember).Methods("POST")
	router.Handle("/api/v2.0/member/mobile/brand", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetBrandList))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/promo/category", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetPromoCategory))).Methods("GET")
	router.Handle("/api/v2.0/member/mobile/syaratKetentuan", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetSyaratKetentuan))).Methods("GET")

	//MISSION
	router.Handle("/api/v2.0/member/mobile/mission", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberMission))).Methods("GET")

	//PUSH NOTIFICATION EXPO
	router.HandleFunc("/api/member/mobile/token/notification", controllers.CreateTokenNotification).Methods("POST")

	//NEW WEB STORE
	//Dashboard API
	//-----------Total Transactions //Total Sales //Total Offline Sales  //Total Online Sales //Last Stock Info
	router.HandleFunc("/v1.0/store/dashboard/sales", controllers.GetStoraDashboardSales).Methods("GET")
	router.HandleFunc("/v1.0/store/dashboard/salesOverviewChart", controllers.GetStoraDashboardSalesChart).Methods("GET")
	//--------List Transaction
	router.HandleFunc("/v1.0/store/dashboard/recentTrasaction", controllers.GetStoraDashboardRecentTransaction).Methods("GET")
	//--------List STIN, List Reimbust kas, Info Setoran Harian
	router.HandleFunc("/v1.0/store/dashboard/taskOverview", controllers.GetStoraDashboardTaskOverview).Methods("GET")
	//--------SALES
	//-------------DCR
	router.HandleFunc("/v1.0/store/sales/dcr", controllers.GetStoreSalesDcr).Methods("GET")
	//------------SALES DETAIL
	router.HandleFunc("/v1.0/store/sales/detail", controllers.GetStoreSalesDetail).Methods("GET")
	router.HandleFunc("/v1.0/store/sales/detail/total", controllers.GetStoreSalesTotal).Methods("GET")
	router.HandleFunc("/v1.0/store/sales/detail/item", controllers.GetStoreSalesDetailItem).Methods("GET")
	router.HandleFunc("/v1.0/store/sales/detail/payment", controllers.GetStoreSalesDetailPayment).Methods("GET")
	// --------send OTP
	// router.HandleFunc("/send-otp", controllers.SendOTP).Methods("POST")
	// --------send EMAIL OTP
	router.HandleFunc("/send-mail-otp", controllers.GetEmailOTP).Methods("POST")
	router.HandleFunc("/send-mail-otp-validasi", controllers.GetEmailOTPValidasi).Methods("POST")
	router.HandleFunc("/send-mail-otp-validasi-verify", controllers.GetEmailOTPValidasiVerify).Methods("POST")
	router.HandleFunc("/send-mail-otp-verify", controllers.GetEmailOTPVerify).Methods("POST")
	router.HandleFunc("/send-wa-otp-verify", controllers.GetWAOTPVerify).Methods("POST") //generate token
	router.HandleFunc("/send-wa-otp-forgot-password", controllers.GetSendOTPForgotPassword).Methods("POST")
	router.HandleFunc("/send-email-otp-forgot-password", controllers.GetSendOTPEamilForgotPassword).Methods("POST")
	router.HandleFunc("/send-wa-otp-forgot-password-verify", controllers.GetSendOTPForgotPasswordVerify).Methods("POST")
	// --CHANGE PHONE NUMBER

	router.Handle("/api/v2.0/member/mobile/change-p/send-otp", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetVerify_new_Phone))).Methods("POST")
	router.Handle("/api/v2.0/member/mobile/change-p/verify", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetVerify_new_Phone_verify))).Methods("POST")
	router.Handle("/api/v2.0/member/mobile/change-p/send-otp-v2", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetVerify_new_Phone_ver2))).Methods("POST")
	router.Handle("/api/v2.0/member/mobile/change-p/verify-v2", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetVerify_new_Phone_verify_ver2))).Methods("POST")

	// ----------POS MODULE-------------------
	router.HandleFunc("/pos/send-otp", controllers.GetVerify_MEMBER_IN_POS).Methods("POST")
	router.HandleFunc("/pos/send-otp/verify", controllers.GetVerify_MEMBER_IN_POS_verify).Methods("POST")
	router.HandleFunc("/pos/member/redeem", controllers.CreateMemberVoucher_IN_POS).Methods("POST")
	// ----------------AMS WEB ---------------------

	router.HandleFunc("/web/send-email-otp", controllers.Web_mail_OTP).Methods("POST")
	// --------------
	router.HandleFunc("/send-mail-ereceipt", controllers.GetEreceipt).Methods("POST")
	router.HandleFunc("/birthday-mail", controllers.GetEmailBirthday).Methods("POST")
	//--------------send email Notification Pengiriman barang/ asset

	router.HandleFunc("/mutasi/notification", controllers.GetEamilMutasiNotification).Methods("POST")
}

func RegisterUserRoutes(router *mux.Router) {
	router.HandleFunc("/api/users/login", controllers.GetUsers).Methods("POST")
	//router.HandleFunc("/api/users", controllers.CreateUser).Methods("POST")
	//router.HandleFunc("/api/users/{id}", controllers.GetUser).Methods("GET")
}

func RegisterShopeeStockRoutes(router *mux.Router) {
	router.HandleFunc("/api/shopee/auth/callback", controllers.ShopeeAuthCallback).Methods("POST")
	// router.HandleFunc("/api/shopee/auth/token", controllers.ShopeeGetToken).Methods("POST")

}
