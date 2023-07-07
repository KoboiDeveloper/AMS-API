package controllers

import (
	"GOamsAPI/database"
	"time"

	///"GOamsAPI/entities"
	"context"
	"database/sql"

	//"encoding/json"
	"fmt"
	"net/http"

	//"github.com/gorilla/mux"

	"github.com/golang-jwt/jwt/v4"
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

var jwtKey = []byte("my_secret_key")

var users = map[string]string{
	"user1": "password1",
	"user2": "password2",
}

// Create a struct that models the structure of a user, both in the request body, and in the DB
type Credentials struct {
	Password string `json:"password"`
	Username string `json:"username"`
}

type Claims struct {
	Username string `json:"username"`
	jwt.RegisteredClaims
}

func GetUsers(w http.ResponseWriter, r *http.Request) {
	//  load api dulu
	//  cek user dulu

	ctx := context.Background()
	// // Check if database is alive.
	// err := database.Instance.PingContext(ctx)
	// if err != nil {
	// 	log.Fatal("Error reading Employees: ", err.Error())
	// }

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

	// end cek user

	var creds Credentials
	//Get the JSON body and decode into credentials
	// err := json.NewDecoder(r.Body).Decode(&creds)
	// if err != nil {
	// 	// If the structure of the body is wrong, return an HTTP error
	// 	w.WriteHeader(http.StatusBadRequest)
	// 	return
	// }

	// expectedPassword, ok := users[creds.Username]

	// // If a password exists for the given user
	// // AND, if it is the same as the password we received, the we can move ahead
	// // if NOT, then we return an "Unauthorized" status
	// if !ok || expectedPassword != creds.Password {
	// 	w.WriteHeader(http.StatusUnauthorized)
	// 	return
	// }

	//Declare the expiration time of the token
	//here, we have kept it as 5 minutes
	expirationTime := time.Now().Add(5 * time.Minute)
	//Create the JWT claims, which includes the username and expiry time
	claims := &Claims{
		Username: creds.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			// In JWT, the expiry time is expressed as unix milliseconds
			ExpiresAt: jwt.NewNumericDate(expirationTime),
		},
	}

	// Declare the token with the algorithm used for signing, and the claims
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	// Create the JWT string
	tokenString, err := token.SignedString(jwtKey)
	if err != nil {
		// If there is an error in creating the JWT return an internal server error
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	// Finally, we set the client cookie for "token" as the JWT we just generated
	// we also set an expiry time which is the same as the token itself
	http.SetCookie(w, &http.Cookie{
		Name:    "token",
		Value:   tokenString,
		Expires: expirationTime,
	})

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
