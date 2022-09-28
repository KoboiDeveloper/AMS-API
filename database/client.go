package database

import (
	//"GOamsAPI/entities"
	"context"
	"database/sql"
	"fmt"
	"log"

	_ "github.com/denisenkom/go-mssqldb"
	//	"gorm.io/driver/postgres"
)

var Instance *sql.DB
var err error

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

 