// Package api exposes the REST endpoints defined in docs/DATA-MODEL.md.
package api

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"budgetd/internal/importer"
	"budgetd/internal/model"
	"budgetd/internal/store"
)

type Server struct {
	st      *store.Store
	version string
	seed    string // bundle shipped with the click, used by /api/reset
	mux     *http.ServeMux
}

func NewServer(st *store.Store, version, seed string) *Server {
	s := &Server{st: st, version: version, seed: seed, mux: http.NewServeMux()}
	s.routes()
	return s
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Minimal request log
	t0 := time.Now()
	s.mux.ServeHTTP(w, r)
	log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(t0))
}

func (s *Server) routes() {
	m := s.mux
	m.HandleFunc("/api/health", s.handleHealth)
	m.HandleFunc("/api/bootstrap", s.handleBootstrap)
	m.HandleFunc("/api/overview", s.handleOverview)
	m.HandleFunc("/api/calendar", s.handleCalendar)
	m.HandleFunc("/api/tx", s.handleTx)
	m.HandleFunc("/api/tx/", s.handleTxItem)
	m.HandleFunc("/api/accounts", s.handleAccounts)
	m.HandleFunc("/api/accounts/", s.handleAccountItem)
	m.HandleFunc("/api/categories", s.handleCategories)
	m.HandleFunc("/api/categories/", s.handleCategoryItem)
	m.HandleFunc("/api/subcategories", s.handleSubcategories)
	m.HandleFunc("/api/subcategories/", s.handleSubcategoryItem)
	m.HandleFunc("/api/budgets", s.handleBudgets)
	m.HandleFunc("/api/budgets/status", s.handleBudgetStatus)
	m.HandleFunc("/api/budgets/", s.handleBudgetItem)
	m.HandleFunc("/api/stats", s.handleStats)
	m.HandleFunc("/api/recurring", s.handleRecurring)
	m.HandleFunc("/api/recurring/run", s.handleRecurringRun)
	m.HandleFunc("/api/recurring/", s.handleRecurringItem)
	m.HandleFunc("/api/settings", s.handleSettings)
	m.HandleFunc("/api/export/bundle", s.handleExportBundle)
	m.HandleFunc("/api/export/csv", s.handleExportCSV)
	m.HandleFunc("/api/import/bundle", s.handleImportBundle)
	m.HandleFunc("/api/import/csv", s.handleImportCSV)
	m.HandleFunc("/api/reset", s.handleReset)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":       true,
		"version":  s.version,
		"imported": s.st.Setting("firstRunDone", "") == "1",
		"time":     time.Now().UTC().Format(time.RFC3339),
	})
}

func (s *Server) handleBootstrap(w http.ResponseWriter, r *http.Request) {
	settings, _ := s.st.AllSettings()
	curs, _ := s.st.Currencies()
	groups, _ := s.st.Groups()
	accts, _ := s.st.Accounts()
	bills, _ := s.st.Bills()
	cats, _ := s.st.Categories()
	subs, _ := s.st.Subcategories()
	budgets, _ := s.st.Budgets()
	wallets, _ := s.st.Wallets()

	writeJSON(w, http.StatusOK, map[string]any{
		"settings":      settings,
		"currencies":    curs,
		"groups":        groups,
		"accounts":      accts,
		"bills":         bills,
		"categories":    cats,
		"subcategories": subs,
		"budgets":       budgets,
		"wallets":       wallets,
	})
}

func (s *Server) handleOverview(w http.ResponseWriter, r *http.Request) {
	day := r.URL.Query().Get("date")
	if day == "" {
		day = time.Now().In(s.st.Zone()).Format("2006-01-02")
	}
	exp, inc, items, err := s.st.Overview(day)
	if err != nil {
		errJSON(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"date":         day,
		"expenseMinor": exp,
		"incomeMinor":  inc,
		"items":        items,
	})
}

func (s *Server) handleCalendar(w http.ResponseWriter, r *http.Request) {
	month := r.URL.Query().Get("month")
	if month == "" {
		month = time.Now().In(s.st.Zone()).Format("2006-01")
	}
	days, err := s.st.Calendar(month)
	if err != nil {
		errJSON(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"month": month, "days": days})
}

func (s *Server) handleTx(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		f := store.TxFilter{
			From:        r.URL.Query().Get("from"),
			To:          r.URL.Query().Get("to"),
			Account:     r.URL.Query().Get("account"),
			Category:    r.URL.Query().Get("category"),
			Subcategory: r.URL.Query().Get("subcategory"),
			Q:           r.URL.Query().Get("q"),
			Limit:       atoiDef(r.URL.Query().Get("limit"), 100),
			Offset:      atoiDef(r.URL.Query().Get("offset"), 0),
		}
		if k := r.URL.Query().Get("kind"); k != "" {
			if ki, err := strconv.Atoi(k); err == nil {
				f.Kind = &ki
			}
		}
		total, items, err := s.st.ListTx(f)
		if err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"total": total, "items": items})
	case http.MethodPost:
		var t model.Tx
		if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		if err := s.st.InsertTx(&t); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusCreated, t)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleTxItem(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/api/tx/")
	if id == "" {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	switch r.Method {
	case http.MethodGet:
		t, err := s.st.TxByID(id)
		if err != nil {
			errJSON(w, http.StatusNotFound, err)
			return
		}
		writeJSON(w, http.StatusOK, t)
	case http.MethodPut, http.MethodPatch:
		var patch map[string]any
		if err := json.NewDecoder(r.Body).Decode(&patch); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		updated, err := s.st.UpdateTx(id, patch)
		if err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, updated)
	case http.MethodDelete:
		if err := s.st.DeleteTx(id); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleAccounts(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		accts, err := s.st.Accounts()
		if err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, accts)
	case http.MethodPost:
		var a model.Account
		if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		if a.ID == "" {
			a.ID = store.NewID()
		}
		if a.Currency == "" {
			a.Currency = s.st.SystemCurrency()
		}
		if a.Color == "" {
			a.Color = "FEDB5A"
		}
		if err := s.st.SaveAccount(&a); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusCreated, a)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleAccountItem(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/api/accounts/")
	switch r.Method {
	case http.MethodGet:
		a, err := s.st.Account(id)
		if err != nil {
			errJSON(w, http.StatusNotFound, err)
			return
		}
		writeJSON(w, http.StatusOK, a)
	case http.MethodPut:
		var a model.Account
		if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		a.ID = id
		if err := s.st.SaveAccount(&a); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, a)
	case http.MethodDelete:
		if err := s.st.DeleteAccount(id); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleCategories(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		cats, err := s.st.Categories()
		if err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, cats)
	case http.MethodPost:
		var c model.Category
		if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		if c.ID == "" {
			c.ID = store.NewID()
		}
		if c.BillID == "" {
			c.BillID = s.st.Setting("billId", "")
		}
		if c.Color == "" {
			c.Color = "FEDB5A"
		}
		if c.Icon == "" {
			c.Icon = "daily_0"
		}
		if err := s.st.SaveCategory(&c); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusCreated, c)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleCategoryItem(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/api/categories/")
	switch r.Method {
	case http.MethodPut:
		var c model.Category
		if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		c.ID = id
		if err := s.st.SaveCategory(&c); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, c)
	case http.MethodDelete:
		if err := s.st.DeleteCategory(id); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleSubcategories(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		subs, err := s.st.Subcategories()
		if err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, subs)
	case http.MethodPost:
		var sc model.Subcategory
		if err := json.NewDecoder(r.Body).Decode(&sc); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		if sc.ID == "" {
			sc.ID = store.NewID()
		}
		if err := s.st.SaveSubcategory(&sc); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusCreated, sc)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleSubcategoryItem(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/api/subcategories/")
	switch r.Method {
	case http.MethodPut:
		var sc model.Subcategory
		if err := json.NewDecoder(r.Body).Decode(&sc); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		sc.ID = id
		if err := s.st.SaveSubcategory(&sc); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, sc)
	case http.MethodDelete:
		if err := s.st.DeleteSubcategory(id); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleBudgets(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		b, err := s.st.Budgets()
		if err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, b)
	case http.MethodPost:
		var b model.Budget
		if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		if b.ID == "" {
			b.ID = store.NewID()
		}
		if b.Currency == "" {
			b.Currency = s.st.SystemCurrency()
		}
		if b.StartDate == "" {
			b.StartDate = time.Now().In(s.st.Zone()).Format("2006-01-02")
		}
		if err := s.st.SaveBudget(&b); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusCreated, b)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleBudgetStatus(w http.ResponseWriter, r *http.Request) {
	at := r.URL.Query().Get("at")
	if at == "" {
		at = time.Now().In(s.st.Zone()).Format("2006-01-02")
	}
	statuses, err := s.st.BudgetStatuses(at)
	if err != nil {
		errJSON(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, statuses)
}

func (s *Server) handleBudgetItem(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/api/budgets/")
	switch r.Method {
	case http.MethodPut:
		var b model.Budget
		if err := json.NewDecoder(r.Body).Decode(&b); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		b.ID = id
		if err := s.st.SaveBudget(&b); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, b)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleStats(w http.ResponseWriter, r *http.Request) {
	from := r.URL.Query().Get("from")
	to := r.URL.Query().Get("to")
	group := r.URL.Query().Get("group")
	if from == "" || to == "" {
		// default current month
		now := time.Now().In(s.st.Zone())
		from = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location()).Format("2006-01-02")
		to = now.Format("2006-01-02")
	}
	rows, err := s.st.Stats(from, to, group)
	if err != nil {
		errJSON(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, rows)
}

func (s *Server) handleRecurring(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		recs, err := s.st.Recurring()
		if err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, recs)
	case http.MethodPost:
		var rec model.Recurring
		if err := json.NewDecoder(r.Body).Decode(&rec); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		if rec.ID == "" {
			rec.ID = store.NewID()
		}
		if rec.Currency == "" {
			rec.Currency = s.st.SystemCurrency()
		}
		if err := s.st.SaveRecurring(&rec); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusCreated, rec)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleRecurringRun(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	var body struct {
		Today string `json:"today"`
	}
	_ = json.NewDecoder(r.Body).Decode(&body)
	n, err := s.st.RunRecurring(body.Today)
	if err != nil {
		errJSON(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"created": n})
}

func (s *Server) handleRecurringItem(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/api/recurring/")
	switch r.Method {
	case http.MethodPut:
		var rec model.Recurring
		if err := json.NewDecoder(r.Body).Decode(&rec); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		rec.ID = id
		if err := s.st.SaveRecurring(&rec); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, rec)
	case http.MethodDelete:
		if err := s.st.DeleteRecurring(id); err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleSettings(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		all, err := s.st.AllSettings()
		if err != nil {
			errJSON(w, http.StatusInternalServerError, err)
			return
		}
		writeJSON(w, http.StatusOK, all)
	case http.MethodPut, http.MethodPost:
		var kv map[string]string
		if err := json.NewDecoder(r.Body).Decode(&kv); err != nil {
			errJSON(w, http.StatusBadRequest, err)
			return
		}
		for k, v := range kv {
			_ = s.st.SetSetting(k, v)
		}
		all, _ := s.st.AllSettings()
		writeJSON(w, http.StatusOK, all)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *Server) handleExportBundle(w http.ResponseWriter, r *http.Request) {
	tmp := filepath.Join(os.TempDir(), "budget-bundle-export.json")
	if err := importer.ExportBundle(s.st, tmp); err != nil {
		errJSON(w, http.StatusInternalServerError, err)
		return
	}
	defer os.Remove(tmp)
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Content-Disposition", `attachment; filename="budget-bundle.json"`)
	f, _ := os.Open(tmp)
	defer f.Close()
	_, _ = io.Copy(w, f)
}

func (s *Server) handleExportCSV(w http.ResponseWriter, r *http.Request) {
	tmp := filepath.Join(os.TempDir(), "budget-export.csv")
	if _, err := importer.ExportCSV(s.st, tmp); err != nil {
		errJSON(w, http.StatusInternalServerError, err)
		return
	}
	defer os.Remove(tmp)
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="budget-export.csv"`)
	f, _ := os.Open(tmp)
	defer f.Close()
	_, _ = io.Copy(w, f)
}

func (s *Server) handleImportBundle(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		Path string `json:"path"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Path == "" {
		errJSON(w, http.StatusBadRequest, errors.New("missing path"))
		return
	}
	counts, err := importer.ImportBundle(s.st, req.Path)
	if err != nil {
		errJSON(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, counts)
}

func (s *Server) handleImportCSV(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		Path string `json:"path"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Path == "" {
		errJSON(w, http.StatusBadRequest, errors.New("missing path"))
		return
	}
	n, err := importer.ImportCSV(s.st, req.Path)
	if err != nil {
		errJSON(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"imported": n})
}

// ---- helpers ----

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func errJSON(w http.ResponseWriter, code int, err error) {
	writeJSON(w, code, map[string]any{"error": err.Error()})
}

func atoiDef(s string, def int) int {
	if s == "" {
		return def
	}
	if n, err := strconv.Atoi(s); err == nil {
		return n
	}
	return def
}

// handleReset wipes the database and re-imports the bundle shipped with the
// app (or an explicit path), so a broken/partial import can be redone from the
// original backup without reinstalling.
func (s *Server) handleReset(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		Path string `json:"path"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	path := req.Path
	if path == "" {
		path = s.seed
	}
	if path == "" {
		errJSON(w, http.StatusBadRequest, errors.New("no seed bundle configured"))
		return
	}
	if _, err := os.Stat(path); err != nil {
		errJSON(w, http.StatusBadRequest, err)
		return
	}
	counts, err := importer.ImportBundle(s.st, path)
	if err != nil {
		errJSON(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"reset": true, "source": path, "counts": counts})
}
