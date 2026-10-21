// sqlrun: helper CLI untuk menjalankan script/query T-SQL ke POS_SERVER atau RBACESS.
// Kredensial dibaca dari config.yaml (connection_string / rbac_connection_string).
//
// Contoh:
//
//	go run ./tools/sqlrun -db rbac -q "select top 5 * from RBAC_Module"
//	go run ./tools/sqlrun -db rbac -f sql/hrd/001_xxx.sql      (batch dipisah baris "GO")
package main

import (
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"regexp"
	"strings"

	_ "github.com/denisenkom/go-mssqldb"
)

func readConfig(key string) string {
	raw, err := os.ReadFile("config.yaml")
	if err != nil {
		fmt.Fprintln(os.Stderr, "cannot read config.yaml:", err)
		os.Exit(2)
	}
	re := regexp.MustCompile(`(?m)^` + regexp.QuoteMeta(key) + `:\s*"(.*)"\s*$`)
	m := re.FindStringSubmatch(string(raw))
	if len(m) < 2 {
		fmt.Fprintln(os.Stderr, "config key not found:", key)
		os.Exit(2)
	}
	return m[1]
}

func printRows(rows *sql.Rows, maxRows int) {
	cols, _ := rows.Columns()
	n := 0
	for rows.Next() {
		vals := make([]interface{}, len(cols))
		ptrs := make([]interface{}, len(cols))
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			fmt.Println("scan error:", err)
			return
		}
		rec := map[string]interface{}{}
		for i, c := range cols {
			switch v := vals[i].(type) {
			case []byte:
				rec[c] = string(v)
			default:
				rec[c] = v
			}
		}
		b, _ := json.Marshal(rec)
		fmt.Println(string(b))
		n++
		if maxRows > 0 && n >= maxRows {
			fmt.Println("... (truncated)")
			break
		}
	}
}

func main() {
	dbName := flag.String("db", "rbac", "rbac | pos")
	query := flag.String("q", "", "query")
	file := flag.String("f", "", "sql file (batches separated by GO)")
	maxRows := flag.Int("max", 500, "max rows printed per result set")
	flag.Parse()

	key := "rbac_connection_string"
	if *dbName == "pos" {
		key = "connection_string"
	}
	db, err := sql.Open("sqlserver", readConfig(key))
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer db.Close()

	script := *query
	if *file != "" {
		b, err := os.ReadFile(*file)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		script = string(b)
	}
	if strings.TrimSpace(script) == "" {
		fmt.Fprintln(os.Stderr, "nothing to run")
		os.Exit(2)
	}

	goRe := regexp.MustCompile(`(?im)^\s*GO\s*$`)
	batches := goRe.Split(script, -1)
	failed := false
	for i, batch := range batches {
		if strings.TrimSpace(batch) == "" {
			continue
		}
		rows, err := db.Query(batch)
		if err != nil {
			fmt.Printf("[batch %d] ERROR: %v\n", i+1, err)
			failed = true
			continue
		}
		for {
			printRows(rows, *maxRows)
			if !rows.NextResultSet() {
				break
			}
			fmt.Println("--- next result set ---")
		}
		if err := rows.Err(); err != nil {
			fmt.Printf("[batch %d] ERROR: %v\n", i+1, err)
			failed = true
		}
		rows.Close()
	}
	if failed {
		os.Exit(1)
	}
}
