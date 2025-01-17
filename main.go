package main

import (
	"GOamsAPI/controllers"
	"GOamsAPI/database"
	"GOamsAPI/middleware"
	"encoding/json"
	"fmt"
	"time"

	"log"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/rs/cors"

	// "github.com/gorilla/websocket"
	"github.com/spf13/viper"
)

type Config struct {
	Port             string `mapstructure:"port"`
	ConnectionString string `mapstructure:"connection_string"`
}

// test
var AppConfig *Config

func LoadAppConfig() {
	log.Println("Loading Server Configurations...")
	viper.AddConfigPath("./configs")
	viper.SetConfigName("confuck") // Register config file name (no extension)
	viper.SetConfigType("json")    // Look for specific type

	err := viper.ReadInConfig()

	if err != nil {
		log.Fatal(err)
	}
	err = viper.Unmarshal(&AppConfig)
	if err != nil {
		log.Fatal(err)
	}
}

// start check and ricek
// Struktur data untuk transaksi
// type Transaction struct {
// 	ID        uint      `json:"id"`
// 	Amount    float64   `json:"amount"`
// 	CreatedAt time.Time `json:"created_at"`
// }

// var (
// 	upgrader     = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}
// 	lastCheck    time.Time
// 	notification = make(chan Transaction)
// )

// Handler WebSocket
// func wsHandler(w http.ResponseWriter, r *http.Request) {
// 	conn, err := upgrader.Upgrade(w, r, nil)
// 	if err != nil {
// 		log.Printf("Gagal upgrade ke WebSocket: %v", err)
// 		return
// 	}
// 	defer conn.Close()

// 	// Kirim notifikasi real-time ke WebSocket client
// 	for txn := range notification {
// 		message, _ := json.Marshal(txn)
// 		err := conn.WriteMessage(websocket.TextMessage, message)
// 		if err != nil {
// 			log.Printf("Gagal mengirim pesan WebSocket: %v", err)
// 			break
// 		}
// 	}
// }

// Monitor transaksi baru melalui Fetch API
func monitorDatabase() {
	apiURL := "/api/Store/webshocket" // Ganti dengan URL API Anda

	for {
		time.Sleep(5 * time.Second) // Interval pengecekan (5 detik)

		// Tambahkan parameter `since` ke URL
		url := fmt.Sprintf("%s?since=%s", apiURL, lastCheck.Format(time.RFC3339))
		resp, err := http.Get(url)
		if err != nil {
			log.Printf("Gagal mengambil data dari API: %v", err)
			continue
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			log.Printf("Response API error: %d", resp.StatusCode)
			continue
		}

		// Decode response JSON
		var transactions []Transaction
		if err := json.NewDecoder(resp.Body).Decode(&transactions); err != nil {
			log.Printf("Gagal decode data JSON: %v", err)
			continue
		}

		// Kirim notifikasi dan push ke endpoint jika ada transaksi baru
		for _, txn := range transactions {
			notification <- txn // Kirim ke WebSocket
			// --pushToEndpoint(txn)       // Kirim ke endpoint lain
			log.Fatal("message", txn)
			lastCheck = txn.CreatedAt // Perbarui waktu pengecekan
		}
	}
}

//end cek and ricek

func main() {
	// Load Configurations from config.json using Viper
	LoadAppConfig()

	// Initialize Database
	database.Connect(AppConfig.ConnectionString)

	// Initialize the router
	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/", controllers.HelloWorld).Methods("GET")

	// Register Routes
	RegisterProductRoutes(router)
	RegisterUserRoutes(router)
	RegisterEssAndroidRoutes(router)
	RegisterEssAndroidSORoutes(router)

	router.Use(mux.CORSMethodMiddleware(router))

	// Inisialisasi waktu terakhir pengecekan
	//lastCheck = time.Now()

	// Endpoint WebSocket
	//http.HandleFunc("/ws", wsHandler)

	// Jalankan fungsi monitorDatabase di background
	//go monitorDatabase()

	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"}, // Replace "*" with allowed domains
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE"},
		AllowedHeaders:   []string{"Content-Type", "Authorization"},
		AllowCredentials: true,
		Debug:            true,
	})

	// Wrap the router with CORS middleware
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin == "" {
			log.Println("Request does not contain an Origin header, handling without CORS")
			router.ServeHTTP(w, r)
		} else {
			log.Printf("Handling request with Origin: %s\n", origin)
			c.Handler(router).ServeHTTP(w, r)
		}
	})

	// Start the server
	// log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", os.Getenv("PORT")), handler))
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":8001"), handler))
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
	router.HandleFunc("/api/v1.0/member/mobile/dashboard/validate", controllers.GetValidate).Methods("POST")
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
	router.Handle("/api/v2.0/member/mobile/profile", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberProfileUpdate))).Methods("PUT")
	router.Handle("/api/v2.0/member/mobile/profile/auth/1", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberAuthPinUpdate))).Methods("PUT")
	router.Handle("/api/v2.0/member/mobile/profile/auth/2", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberAuthPassUpdate))).Methods("PUT")
	router.Handle("/api/v2.0/member/mobile/profile/auth/forgot", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberAuthForgotPass))).Methods("PUT")
	//transaction
	router.Handle("/api/v2.0/member/mobile/transaction/history", middleware.JWTMiddleware(http.HandlerFunc(controllers.GetMemberTransactionHistory))).Methods("GET")
	//voucher
	router.Handle("/api/v2.0/member/mobile/voucher/redeem", middleware.JWTMiddleware(http.HandlerFunc(controllers.CreateMemberVoucher))).Methods("POST")
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

	//--------------send email Notification Pengiriman barang/ asset

	router.HandleFunc("/mutasi/notification", controllers.GetEamilMutasiNotification).Methods("POST")
}

func RegisterUserRoutes(router *mux.Router) {
	router.HandleFunc("/api/users/login", controllers.GetUsers).Methods("POST")
	//router.HandleFunc("/api/users", controllers.CreateUser).Methods("POST")
	//router.HandleFunc("/api/users/{id}", controllers.GetUser).Methods("GET")
}
