package database

import (
	//"GOamsAPI/entities"
	"context"
	"database/sql"
	"fmt"
	"log"

	_ "github.com/denisenkom/go-mssqldb"
	"github.com/go-redis/redis/v8"
	//	"gorm.io/driver/postgres"
)

var Instance *sql.DB
var RbcaInstance *sql.DB
var err error

var RedisClient *redis.Client

func ConnectRedis(redisURL string) {
	// Sementara tidak dipakai. Jangan fatal agar deploy Render tetap jalan.
	if redisURL == "" {
		log.Println("Redis skipped: empty URL")
		return
	}
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Printf("Failed to parse Redis URL: %v", err)
		return
	}
	RedisClient = redis.NewClient(opt)
}

func Connect(connectionString string) {
	// Build connection string
	var err error

	// Create connection pool
	Instance, err = sql.Open("sqlserver", connectionString)
	if err != nil {
		log.Fatal("Error creating connection pool: ", err.Error())
	}
	ctx := context.Background()
	err = Instance.PingContext(ctx)
	if err != nil {
		log.Fatal(err.Error())
	}
	fmt.Printf("Connected!\n")
	// End check Koneksi

}

func ConnectRbca(connectionString string) {
	var err error

	RbcaInstance, err = sql.Open("sqlserver", connectionString)
	if err != nil {
		log.Fatal("Error creating RBCA connection pool: ", err.Error())
	}

	ctx := context.Background()
	err = RbcaInstance.PingContext(ctx)
	if err != nil {
		log.Fatal("RBCA database connection failed: ", err.Error())
	}
	fmt.Printf("Connected to RBCA database!\n")
}
