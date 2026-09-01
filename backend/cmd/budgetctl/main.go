package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"budgetd/internal/importer"
	"budgetd/internal/store"
)

func main() {
	dbPath := flag.String("db", filepath.Join(os.Getenv("HOME"), ".local/share/budget-ut/budget.db"), "DB path")
	flag.Parse()
	args := flag.Args()
	if len(args) == 0 {
		fmt.Println("usage: budgetctl [-db path] <import-bundle|export-bundle|export-csv|import-csv|wallets|accounts> [args]")
		os.Exit(1)
	}

	_ = os.MkdirAll(filepath.Dir(*dbPath), 0755)
	st, err := store.Open(*dbPath)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	defer st.Close()

	switch args[0] {
	case "import-bundle":
		if len(args) < 2 {
			log.Fatal("need bundle path")
		}
		counts, err := importer.ImportBundle(st, args[1])
		if err != nil {
			log.Fatalf("import: %v", err)
		}
		fmt.Printf("imported: %+v\n", counts)
	case "export-bundle":
		if len(args) < 2 {
			log.Fatal("need out path")
		}
		if err := importer.ExportBundle(st, args[1]); err != nil {
			log.Fatalf("export: %v", err)
		}
		fmt.Println("exported bundle to", args[1])
	case "export-csv":
		if len(args) < 2 {
			log.Fatal("need out path")
		}
		n, err := importer.ExportCSV(st, args[1])
		if err != nil {
			log.Fatalf("export csv: %v", err)
		}
		fmt.Printf("exported %d rows to %s\n", n, args[1])
	case "import-csv":
		if len(args) < 2 {
			log.Fatal("need in path")
		}
		n, err := importer.ImportCSV(st, args[1])
		if err != nil {
			log.Fatalf("import csv: %v", err)
		}
		fmt.Printf("imported %d rows from %s\n", n, args[1])
	case "wallets":
		w, err := st.Wallets()
		if err != nil {
			log.Fatal(err)
		}
		b, _ := json.MarshalIndent(w, "", "  ")
		fmt.Println(string(b))
	case "accounts":
		accts, err := st.Accounts()
		if err != nil {
			log.Fatal(err)
		}
		for _, a := range accts {
			fmt.Printf("%-20s %8.2f %s (kind=%d, inAssets=%v)\n", a.Name, float64(a.Balance)/100, a.Currency, a.Kind, a.InAssets)
		}
	default:
		log.Fatalf("unknown cmd %q", args[0])
	}
}
