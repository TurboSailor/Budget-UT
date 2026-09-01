package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"budgetd/internal/api"
	"budgetd/internal/importer"
	"budgetd/internal/store"
)

var version = "0.1.0"

func main() {
	dbPath := flag.String("db", filepath.Join(os.Getenv("HOME"), ".local/share/budget-ut/budget.db"), "SQLite DB path")
	addr := flag.String("addr", "127.0.0.1:21990", "HTTP listen addr")
	seedPath := flag.String("seed", "", "initial bundle to import on first run if empty")
	flag.Parse()

	if err := os.MkdirAll(filepath.Dir(*dbPath), 0755); err != nil {
		log.Fatalf("mkdir db: %v", err)
	}

	st, err := store.Open(*dbPath)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	defer st.Close()

	if st.Setting("firstRunDone", "") != "1" && *seedPath != "" {
		if _, err := os.Stat(*seedPath); err == nil {
			log.Printf("first run: importing seed from %s", *seedPath)
			counts, err := importer.ImportBundle(st, *seedPath)
			if err != nil {
				log.Printf("seed import error: %v", err)
			} else {
				log.Printf("seeded: %v", counts)
			}
		}
	}
	go refreshRatesLoop(st)

	srv := api.NewServer(st, version, *seedPath)
	log.Printf("budgetd %s listening on %s (db=%s)", version, *addr, *dbPath)
	if err := http.ListenAndServe(*addr, srv); err != nil {
		log.Fatalf("serve: %v", err)
	}
}

// refreshRatesLoop keeps currencies.rate fresh: once at startup if the stored
// table is older than a day, then a check every 6 h. Network failures are only
// logged — FX quotes are a nicety, the ledger works offline.
func refreshRatesLoop(st *store.Store) {
	const tick = 6 * time.Hour
	for {
		if api.RatesStale(st) {
			ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
			n, source, err := api.RefreshRates(ctx, st)
			cancel()
			if err != nil {
				log.Printf("rates: refresh failed: %v", err)
			} else {
				log.Printf("rates: updated %d currencies from %s", n, source)
			}
		}
		time.Sleep(tick)
	}
}
