// Package store owns the SQLite schema and all persistence.
package store

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	_ "modernc.org/sqlite"

	"budgetd/internal/model"
)

const schema = `
CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE IF NOT EXISTS bills(
  id TEXT PRIMARY KEY, name TEXT NOT NULL, icon TEXT DEFAULT '', color TEXT DEFAULT '',
  sorted REAL DEFAULT 0, status INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS categories(
  id TEXT PRIMARY KEY, bill_id TEXT NOT NULL, name TEXT NOT NULL, is_income INTEGER DEFAULT 0,
  icon TEXT DEFAULT '', color TEXT DEFAULT '', sorted REAL DEFAULT 0, status INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS subcategories(
  id TEXT PRIMARY KEY, category_id TEXT NOT NULL, name TEXT NOT NULL,
  sorted REAL DEFAULT 0, status INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS accounts(
  id TEXT PRIMARY KEY, kind INTEGER DEFAULT 0, name TEXT NOT NULL,
  icon TEXT DEFAULT '', color TEXT DEFAULT '', currency TEXT DEFAULT 'USD',
  credit_limit INTEGER DEFAULT 0, liability INTEGER DEFAULT 0, balance INTEGER DEFAULT 0,
  finances_type INTEGER DEFAULT 0, code TEXT DEFAULT '',
  in_assets INTEGER DEFAULT 1, hidden INTEGER DEFAULT 0, sorted REAL DEFAULT 0,
  status INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS account_groups(
  name TEXT PRIMARY KEY, account_ids TEXT DEFAULT '[]', sorted REAL DEFAULT 0);
CREATE TABLE IF NOT EXISTS transactions(
  id TEXT PRIMARY KEY, bill_id TEXT DEFAULT '', ts_ms INTEGER NOT NULL, day TEXT NOT NULL,
  category_id TEXT, subcategory_id TEXT,
  kind INTEGER DEFAULT 0, is_income INTEGER DEFAULT 0,
  amount INTEGER DEFAULT 0, currency TEXT DEFAULT 'USD',
  original_cost INTEGER DEFAULT 0, original_currency TEXT DEFAULT 'USD',
  account_id TEXT, to_account_id TEXT, to_amount INTEGER DEFAULT 0,
  label TEXT DEFAULT '', remark TEXT DEFAULT '',
  ignored INTEGER DEFAULT 0, ignore_budget INTEGER DEFAULT 0, ignore_expend INTEGER DEFAULT 0,
  has_image INTEGER DEFAULT 0, status INTEGER DEFAULT 0,
  created_at TEXT DEFAULT '', modified_at TEXT DEFAULT '');
CREATE INDEX IF NOT EXISTS idx_tx_day ON transactions(day);
CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_tx_cat ON transactions(category_id);
CREATE TABLE IF NOT EXISTS budgets(
  id TEXT PRIMARY KEY, scope TEXT DEFAULT 'bill', ref_id TEXT DEFAULT '',
  period INTEGER DEFAULT 3, period_days INTEGER DEFAULT 0,
  value INTEGER DEFAULT 0, currency TEXT DEFAULT 'USD',
  category_mode INTEGER DEFAULT 1, rollover_mode INTEGER DEFAULT 0,
  fixed_amount INTEGER DEFAULT 1, should_summary INTEGER DEFAULT 1,
  start_date TEXT DEFAULT '', status INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS recurring(
  id TEXT PRIMARY KEY, name TEXT NOT NULL, kind INTEGER DEFAULT 0,
  amount INTEGER DEFAULT 0, currency TEXT DEFAULT 'USD',
  category_id TEXT, subcategory_id TEXT, account_id TEXT, remark TEXT DEFAULT '',
  period INTEGER DEFAULT 3, period_days INTEGER DEFAULT 0,
  next_date TEXT DEFAULT '', end_date TEXT DEFAULT '', status INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS currencies(
  code TEXT PRIMARY KEY, symbol TEXT DEFAULT '', name TEXT DEFAULT '',
  country TEXT DEFAULT '', rate REAL DEFAULT 1, in_use INTEGER DEFAULT 0);
`

// Store wraps the DB; all handlers run under one mutex — SQLite for a single
// user phone app does not need more.
type Store struct {
	db *sql.DB
	mu sync.Mutex
}

func Open(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path+"?_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)&_pragma=foreign_keys(ON)")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1) // modernc sqlite + WAL: serialize writers, avoids SQLITE_BUSY
	if _, err := db.Exec(schema); err != nil {
		return nil, fmt.Errorf("migrate: %w", err)
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() error { return s.db.Close() }

// ---- settings ----

func (s *Store) Setting(key, def string) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	var v string
	err := s.db.QueryRow(`SELECT value FROM settings WHERE key=?`, key).Scan(&v)
	if err != nil {
		return def
	}
	return v
}

func (s *Store) SetSetting(key, value string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO settings(key,value) VALUES(?,?)
		ON CONFLICT(key) DO UPDATE SET value=excluded.value`, key, value)
	return err
}

func (s *Store) AllSettings() (map[string]string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT key, value FROM settings`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	m := map[string]string{}
	for rows.Next() {
		var k, v string
		if err := rows.Scan(&k, &v); err != nil {
			return nil, err
		}
		m[k] = v
	}
	return m, rows.Err()
}

// Zone returns the user timezone from settings (default +03:00 like the
// source data).
func (s *Store) Zone() *time.Location {
	spec := s.Setting("tz", "+03:00")
	if loc, err := time.LoadLocation(spec); err == nil {
		return loc
	}
	if off, err := strconv.Atoi(spec); err == nil {
		return time.FixedZone(spec, off*3600)
	}
	if strings.HasPrefix(spec, "+") || strings.HasPrefix(spec, "-") {
		h, err1 := strconv.Atoi(spec[1:3])
		m, err2 := strconv.Atoi(spec[3:5])
		if err1 == nil && err2 == nil {
			sign := 1
			if spec[0] == '-' {
				sign = -1
			}
			return time.FixedZone(spec, sign*(h*3600+m*60))
		}
	}
	return time.FixedZone("+03:00", 3*3600)
}

func (s *Store) SystemCurrency() string { return s.Setting("systemCurrency", "USD") }

// ---- accounts ----

const acctCols = `id, kind, name, icon, color, currency, credit_limit, liability, balance,
  finances_type, code, in_assets, hidden, sorted, status`

func scanAccount(sc interface{ Scan(...any) error }) (*model.Account, error) {
	a := &model.Account{}
	var ia, ih int
	err := sc.Scan(&a.ID, &a.Kind, &a.Name, &a.Icon, &a.Color, &a.Currency, &a.CreditLimit,
		&a.Liability, &a.Balance, &a.FinancesType, &a.Code, &ia, &ih, &a.Sorted, &a.Status)
	if err != nil {
		return nil, err
	}
	a.InAssets, a.Hidden = ia != 0, ih != 0
	return a, nil
}

func (s *Store) Accounts() ([]*model.Account, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT ` + acctCols + ` FROM accounts ORDER BY sorted, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*model.Account
	for rows.Next() {
		a, err := scanAccount(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (s *Store) Account(id string) (*model.Account, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	row := s.db.QueryRow(`SELECT `+acctCols+` FROM accounts WHERE id=?`, id)
	a, err := scanAccount(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("account %s not found", id)
	}
	return a, err
}

func (s *Store) SaveAccount(a *model.Account) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO accounts(`+acctCols+`)
		VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		ON CONFLICT(id) DO UPDATE SET kind=excluded.kind, name=excluded.name,
		  icon=excluded.icon, color=excluded.color, currency=excluded.currency,
		  credit_limit=excluded.credit_limit, liability=excluded.liability,
		  balance=excluded.balance, finances_type=excluded.finances_type,
		  code=excluded.code, in_assets=excluded.in_assets, hidden=excluded.hidden,
		  sorted=excluded.sorted, status=excluded.status`,
		a.ID, a.Kind, a.Name, a.Icon, a.Color, a.Currency, a.CreditLimit, a.Liability,
		a.Balance, a.FinancesType, a.Code, b2i(a.InAssets), b2i(a.Hidden), a.Sorted, a.Status)
	return err
}

func (s *Store) DeleteAccount(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, err := s.db.Exec(`UPDATE accounts SET status=1 WHERE id=?`, id); err != nil {
		return err
	}
	_, err := s.db.Exec(`UPDATE transactions SET status=1 WHERE account_id=? OR to_account_id=?`, id, id)
	return err
}

func (s *Store) Groups() ([]model.Group, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT name, account_ids, sorted FROM account_groups ORDER BY sorted, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []model.Group
	for rows.Next() {
		var g model.Group
		var ids string
		if err := rows.Scan(&g.Name, &ids, &g.Sorted); err != nil {
			return nil, err
		}
		_ = json.Unmarshal([]byte(ids), &g.AccountIDs)
		out = append(out, g)
	}
	return out, rows.Err()
}

func (s *Store) SaveGroup(g model.Group) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	ids, _ := json.Marshal(g.AccountIDs)
	_, err := s.db.Exec(`INSERT INTO account_groups(name, account_ids, sorted) VALUES(?,?,?)
		ON CONFLICT(name) DO UPDATE SET account_ids=excluded.account_ids, sorted=excluded.sorted`,
		g.Name, string(ids), g.Sorted)
	return err
}

// ---- bills / categories / subcategories ----

func (s *Store) Bills() ([]model.Bill, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT id, name, icon, color, sorted, status FROM bills ORDER BY sorted`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []model.Bill
	for rows.Next() {
		var b model.Bill
		if err := rows.Scan(&b.ID, &b.Name, &b.Icon, &b.Color, &b.Sorted, &b.Status); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (s *Store) SaveBill(b model.Bill) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO bills(id,name,icon,color,sorted,status) VALUES(?,?,?,?,?,?)
		ON CONFLICT(id) DO UPDATE SET name=excluded.name, icon=excluded.icon,
		  color=excluded.color, sorted=excluded.sorted, status=excluded.status`,
		b.ID, b.Name, b.Icon, b.Color, b.Sorted, b.Status)
	return err
}

const catCols = `id, bill_id, name, is_income, icon, color, sorted, status`

func (s *Store) Categories() ([]model.Category, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT ` + catCols + ` FROM categories WHERE status=0 ORDER BY sorted, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []model.Category
	for rows.Next() {
		c := model.Category{Subcategories: []model.Subcategory{}}
		var ii int
		if err := rows.Scan(&c.ID, &c.BillID, &c.Name, &ii, &c.Icon, &c.Color, &c.Sorted, &c.Status); err != nil {
			return nil, err
		}
		c.IsIncome = ii != 0
		out = append(out, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	rows.Close()

	subs, err := s.subcategoriesLocked()
	if err != nil {
		return nil, err
	}
	for i := range out {
		for _, sc := range subs {
			if sc.CategoryID == out[i].ID && sc.Status == model.StatusActive {
				out[i].Subcategories = append(out[i].Subcategories, sc)
			}
		}
	}
	return out, nil
}

func (s *Store) subcategoriesLocked() ([]model.Subcategory, error) {
	rows, err := s.db.Query(`SELECT id, category_id, name, sorted, status FROM subcategories ORDER BY sorted, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []model.Subcategory
	for rows.Next() {
		var sc model.Subcategory
		if err := rows.Scan(&sc.ID, &sc.CategoryID, &sc.Name, &sc.Sorted, &sc.Status); err != nil {
			return nil, err
		}
		out = append(out, sc)
	}
	return out, rows.Err()
}

func (s *Store) Subcategories() ([]model.Subcategory, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.subcategoriesLocked()
}

func (s *Store) SaveCategory(c *model.Category) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO categories(`+catCols+`) VALUES(?,?,?,?,?,?,?,?)
		ON CONFLICT(id) DO UPDATE SET bill_id=excluded.bill_id, name=excluded.name,
		  is_income=excluded.is_income, icon=excluded.icon, color=excluded.color,
		  sorted=excluded.sorted, status=excluded.status`,
		c.ID, c.BillID, c.Name, b2i(c.IsIncome), c.Icon, c.Color, c.Sorted, c.Status)
	return err
}

func (s *Store) SaveSubcategory(sc *model.Subcategory) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO subcategories(id, category_id, name, sorted, status)
		VALUES(?,?,?,?,?)
		ON CONFLICT(id) DO UPDATE SET category_id=excluded.category_id, name=excluded.name,
		  sorted=excluded.sorted, status=excluded.status`,
		sc.ID, sc.CategoryID, sc.Name, sc.Sorted, sc.Status)
	return err
}

func (s *Store) DeleteCategory(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, err := s.db.Exec(`UPDATE categories SET status=1 WHERE id=?`, id); err != nil {
		return err
	}
	_, err := s.db.Exec(`UPDATE subcategories SET status=1 WHERE category_id=?`, id)
	return err
}

func (s *Store) DeleteSubcategory(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`UPDATE subcategories SET status=1 WHERE id=?`, id)
	return err
}

// ---- budgets ----

const budCols = `id, scope, ref_id, period, period_days, value, currency,
  category_mode, rollover_mode, fixed_amount, should_summary, start_date, status`

func (s *Store) Budgets() ([]model.Budget, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT ` + budCols + ` FROM budgets WHERE status=0 ORDER BY scope, ref_id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []model.Budget
	for rows.Next() {
		b := model.Budget{}
		var fa, ss int
		if err := rows.Scan(&b.ID, &b.Scope, &b.RefID, &b.Period, &b.PeriodDays, &b.Value,
			&b.Currency, &b.CategoryMode, &b.RolloverMode, &fa, &ss, &b.StartDate, &b.Status); err != nil {
			return nil, err
		}
		b.FixedAmount, b.ShouldSummary = fa != 0, ss != 0
		out = append(out, b)
	}
	return out, rows.Err()
}

func (s *Store) SaveBudget(b *model.Budget) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO budgets(`+budCols+`) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
		ON CONFLICT(id) DO UPDATE SET scope=excluded.scope, ref_id=excluded.ref_id,
		  period=excluded.period, period_days=excluded.period_days, value=excluded.value,
		  currency=excluded.currency, category_mode=excluded.category_mode,
		  rollover_mode=excluded.rollover_mode, fixed_amount=excluded.fixed_amount,
		  should_summary=excluded.should_summary, start_date=excluded.start_date,
		  status=excluded.status`,
		b.ID, b.Scope, b.RefID, b.Period, b.PeriodDays, b.Value, b.Currency, b.CategoryMode,
		b.RolloverMode, b2i(b.FixedAmount), b2i(b.ShouldSummary), b.StartDate, b.Status)
	return err
}

// ---- currencies ----

func (s *Store) Currencies() ([]model.Currency, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT code, symbol, name, country, rate, in_use FROM currencies ORDER BY code`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []model.Currency
	for rows.Next() {
		var c model.Currency
		var iu int
		if err := rows.Scan(&c.Code, &c.Symbol, &c.Name, &c.Country, &c.Rate, &iu); err != nil {
			return nil, err
		}
		c.InUse = iu != 0
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) SaveCurrency(c model.Currency) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO currencies(code,symbol,name,country,rate,in_use)
		VALUES(?,?,?,?,?,?)
		ON CONFLICT(code) DO UPDATE SET symbol=excluded.symbol, name=excluded.name,
		  country=excluded.country, rate=excluded.rate, in_use=excluded.in_use`,
		c.Code, c.Symbol, c.Name, c.Country, c.Rate, b2i(c.InUse))
	return err
}

// Rate returns units-per-USD for a code (1.0 if unknown).
func (s *Store) Rate(code string) float64 {
	s.mu.Lock()
	defer s.mu.Unlock()
	var r float64
	if err := s.db.QueryRow(`SELECT rate FROM currencies WHERE code=?`, code).Scan(&r); err != nil || r <= 0 {
		return 1
	}
	return r
}

// ---- recurring ----

const recCols = `id, name, kind, amount, currency, category_id, subcategory_id, account_id,
  remark, period, period_days, next_date, end_date, status`

func (s *Store) Recurring() ([]model.Recurring, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT ` + recCols + ` FROM recurring WHERE status=0 ORDER BY next_date`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []model.Recurring
	for rows.Next() {
		r := model.Recurring{}
		var cat, sub, acc sql.NullString
		if err := rows.Scan(&r.ID, &r.Name, &r.Kind, &r.Amount, &r.Currency, &cat, &sub, &acc,
			&r.Remark, &r.Period, &r.PeriodDays, &r.NextDate, &r.EndDate, &r.Status); err != nil {
			return nil, err
		}
		r.CategoryID, r.SubcategoryID, r.AccountID = np(cat), np(sub), np(acc)
		out = append(out, r)
	}
	return out, rows.Err()
}

func (s *Store) SaveRecurring(r *model.Recurring) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO recurring(`+recCols+`)
		VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		ON CONFLICT(id) DO UPDATE SET name=excluded.name, kind=excluded.kind,
		  amount=excluded.amount, currency=excluded.currency, category_id=excluded.category_id,
		  subcategory_id=excluded.subcategory_id, account_id=excluded.account_id,
		  remark=excluded.remark, period=excluded.period, period_days=excluded.period_days,
		  next_date=excluded.next_date, end_date=excluded.end_date, status=excluded.status`,
		r.ID, r.Name, r.Kind, r.Amount, r.Currency, pn(r.CategoryID), pn(r.SubcategoryID),
		pn(r.AccountID), r.Remark, r.Period, r.PeriodDays, r.NextDate, r.EndDate, r.Status)
	return err
}

func (s *Store) DeleteRecurring(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`UPDATE recurring SET status=1 WHERE id=?`, id)
	return err
}

// ---- helpers ----

func b2i(b bool) int {
	if b {
		return 1
	}
	return 0
}

func pn(p *string) any {
	if p == nil {
		return nil
	}
	return *p
}

func np(v sql.NullString) *string {
	if !v.Valid {
		return nil
	}
	s := v.String
	return &s
}

// NewID makes a snowflake-ish unique id compatible in shape with the imported ones.
func NewID() string {
	now := time.Now().UnixMilli()
	return fmt.Sprintf("%d%d", now, now%9973%1000)
}

// Wipe deletes every row of a table (importer only).
func (s *Store) Wipe(table string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, _ = s.db.Exec(`DELETE FROM ` + table)
}
