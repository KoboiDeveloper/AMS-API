package main

import (
	"GOamsAPI/controllers"
	"GOamsAPI/database"
	"fmt"

	"log"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/rs/cors"

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

	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE"},
		AllowCredentials: true,
		// Enable Debugging for testing, consider disabling in production
		Debug: true,
	})

	handler := c.Handler(router)

	// Start the server
	// log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", os.Getenv("PORT")), handler))
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":8000"), handler))
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

	//MEMBER APIS
	router.HandleFunc("/api/member/activity", controllers.GetmemberActivity).Methods("GET")
	router.HandleFunc("/api/member/GrowthActivity", controllers.GetGrowthMemberActivity).Methods("GET")
	// AUTHORISASI/VERIVY/LOGIN/LOGOUT
	router.HandleFunc("/api/member/mobile/dashboard/Verify", controllers.GetVerify).Methods("POST")
	router.HandleFunc("/api/member/mobile/dashboard/login", controllers.GetLogin).Methods("POST")
	router.HandleFunc("/api/member/mobile/dashboard/register", controllers.GetRegisterUser).Methods("POST")
	// router.HandleFunc("/api/member/mobile/dashboard/logout", controllers.GetLogout).Methods("POST")

	//MEMBER APIS MOBILE
	router.HandleFunc("/api/member/mobile/dashboard/info", controllers.GetMemberDashboardInfo).Methods("GET")
	router.HandleFunc("/api/member/mobile/dashboard/promo", controllers.GetMemberDashboardPromo).Methods("GET")
	//promo
	router.HandleFunc("/api/member/mobile/promo/list", controllers.GetMemberPromoList).Methods("GET")
	router.HandleFunc("/api/member/mobile/promo/detail", controllers.GetMemberPromoDetail).Methods("GET")
	//location
	router.HandleFunc("/api/member/mobile/location/list", controllers.GetStoreLocationList).Methods("GET")
	router.HandleFunc("/api/member/mobile/location/detail", controllers.GetStoreLocationDetail).Methods("GET")
	//profile
	router.HandleFunc("/api/member/mobile/profile", controllers.GetMemberProfile).Methods("GET")
	router.HandleFunc("/api/member/mobile/profile", controllers.GetMemberProfileUpdate).Methods("PUT")
	//transaction
	router.HandleFunc("/api/member/mobile/transaction/history", controllers.GetMemberTransactionHistory).Methods("GET")
	//voucher
	router.HandleFunc("/api/member/mobile/voucher/redeem", controllers.CreateMemberVoucher).Methods("POST")
	router.HandleFunc("/api/member/mobile/voucher/detail", controllers.GetMemberVoucherDetail).Methods("GET")
	router.HandleFunc("/api/member/mobile/voucher", controllers.GetMemberVoucherList).Methods("GET")
	router.HandleFunc("/api/member/mobile/voucher/history", controllers.GetMemberVoucherTransactionHistoryList).Methods("GET")
	//Master
	router.HandleFunc("/api/member/mobile/provinces", controllers.GetProvincesList).Methods("GET")
	router.HandleFunc("/api/member/mobile/cities", controllers.GetCitiesList).Methods("GET")

	//NEW WEB STORE
	//Dashboard API
	//-----------Total Transactions //Total Sales //Total Offline Sales  //Total Online Sales //Last Stock Info
	router.HandleFunc("/v1.0/store/dashboard/sales", controllers.GetStoraDashboardSales).Methods("GET")
	router.HandleFunc("/v1.0/store/dashboard/salesOverviewChart", controllers.GetStoraDashboardSalesChart).Methods("GET")
	//--------List Transaction
	router.HandleFunc("/v1.0/store/dashboard/recentTrasaction", controllers.GetStoraDashboardRecentTransaction).Methods("GET")

	//--------List STIN
	//--------List Reimbust kas, Saldo Kurang
	//--------Info Setoran Harian
}

func RegisterUserRoutes(router *mux.Router) {
	router.HandleFunc("/api/users/login", controllers.GetUsers).Methods("POST")
	//router.HandleFunc("/api/users", controllers.CreateUser).Methods("POST")
	//router.HandleFunc("/api/users/{id}", controllers.GetUser).Methods("GET")
}
