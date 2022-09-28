package controllers

import (
	"GOamsAPI/database"
	//"GOamsAPI/entities"
	"context"
	"database/sql"
	//"encoding/json"
	"fmt"
	"log"
	"net/http"

	//"github.com/gorilla/mux"
	"golang.org/x/crypto/bcrypt"
)

// func CreateUser(w http.ResponseWriter, r *http.Request) {
// 	w.Header().Set("Content-Type", "application/json")
// 	var user entities.User
// 	json.NewDecoder(r.Body).Decode(&user)
// 	var hashedPassword, err = HashPassword(user.Password)
// 	if err != nil {
// 		panic(err)
// 	}
// 	user.Password = string(hashedPassword)
// 	database.Instance.Create(&user)
// 	json.NewEncoder(w).Encode(user)
// }

func GetUsers(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check if database is alive.
	err := database.Instance.PingContext(ctx)
	if err != nil {
		log.Fatal("Error reading Employees: ", err.Error())
	}


	var JsonResultData string
	rows, err := database.Instance.QueryContext(ctx, "XSP_MASTER_USER_MAIN_VALIDATE_API",
		sql.Named("p_uid", r.FormValue("userid")),
		sql.Named("p_password", r.FormValue("password")), 
		sql.Named("bitparam", sql.Out{Dest: &JsonResultData}))

	defer rows.Close()
	var strrow string
	// Iterate through the result set.
	for rows.Next() {
		err = rows.Scan(&strrow)
	}


	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	
	fmt.Fprintf(w, string(JsonResultData))
}

func HashPassword(password string) ([]byte, error) {
	return bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
}

func VerifyPassword(hashedPassword, password string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
}

// func checkIfUserExists(userId string) bool {
// 	var user entities.User
// 	database.Instance.First(&user, userId)
// 	return user.ID != 0
// }

// func GetUser(w http.ResponseWriter, r *http.Request) {
// 	userId := mux.Vars(r)["id"]
// 	if !checkIfUserExists(userId) {
// 		json.NewEncoder(w).Encode("User Not Found!")
// 		return
// 	}
// 	var user entities.User
// 	database.Instance.First(&user, userId)
// 	w.Header().Set("Content-Type", "application/json")
// 	json.NewEncoder(w).Encode(user)
// }