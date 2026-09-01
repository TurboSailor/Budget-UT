package store

import (
	"database/sql"
	"fmt"
	"time"

	"budgetd/internal/model"
)

// Overview returns day totals + items for the day view.
func (s *Store) Overview(day string) (expense, income int64, items []model.Tx, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err = s.db.QueryRow(`SELECT
		COALESCE(SUM(CASE WHEN kind=0 AND ignored=0 THEN amount ELSE 0 END),0),
		COALESCE(SUM(CASE WHEN kind=2 AND ignored=0 THEN amount ELSE 0 END),0)
		FROM transactions WHERE status=0 AND day=?`, day).Scan(&expense, &income); err != nil {
		return
	}
	rows, err := s.db.Query(`SELECT `+txCols+` FROM transactions
		WHERE status=0 AND day=? ORDER BY ts_ms DESC, id`, day)
	if err != nil {
		return
	}
	defer rows.Close()
	items = []model.Tx{}
	for rows.Next() {
		var t *model.Tx
		t, err = scanTx(rows)
		if err != nil {
			return
		}
		items = append(items, *t)
	}
	err = rows.Err()
	return
}

// Calendar aggregates a month (YYYY-MM) per day.
func (s *Store) Calendar(month string) ([]model.DayStat, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	rows, err := s.db.Query(`SELECT day,
		COALESCE(SUM(CASE WHEN kind=0 AND ignored=0 THEN amount ELSE 0 END),0),
		COALESCE(SUM(CASE WHEN kind=2 AND ignored=0 THEN amount ELSE 0 END),0),
		COUNT(*)
		FROM transactions WHERE status=0 AND day LIKE ? || '-%'
		GROUP BY day ORDER BY day`, month)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []model.DayStat{}
	for rows.Next() {
		var d model.DayStat
		if err := rows.Scan(&d.Day, &d.Expense, &d.Income, &d.Count); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// Stats groups expenses/incomes over a day range (inclusive).
func (s *Store) Stats(from, to, group string) ([]model.StatRow, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	var rows *sql.Rows
	var err error
	switch group {
	case "subcategory":
		rows, err = s.db.Query(`SELECT 'sub:'||t.subcategory_id, COALESCE(sc.name,'?'), '', '',
				COALESCE(SUM(CASE WHEN t.kind=0 AND t.ignored=0 THEN t.amount ELSE 0 END),0),
				COALESCE(SUM(CASE WHEN t.kind=2 AND t.ignored=0 THEN t.amount ELSE 0 END),0),
				COUNT(*)
			FROM transactions t LEFT JOIN subcategories sc ON sc.id=t.subcategory_id
			WHERE t.status=0 AND t.day>=? AND t.day<=? AND t.subcategory_id IS NOT NULL
			GROUP BY t.subcategory_id ORDER BY 5 DESC`, from, to)
	case "day":
		rows, err = s.db.Query(`SELECT t.day, t.day, '', '',
				COALESCE(SUM(CASE WHEN t.kind=0 AND t.ignored=0 THEN t.amount ELSE 0 END),0),
				COALESCE(SUM(CASE WHEN t.kind=2 AND t.ignored=0 THEN t.amount ELSE 0 END),0),
				COUNT(*)
			FROM transactions t
			WHERE t.status=0 AND t.day>=? AND t.day<=?
			GROUP BY t.day ORDER BY t.day`, from, to)
	case "month":
		rows, err = s.db.Query(`SELECT substr(t.day,1,7), substr(t.day,1,7), '', '',
				COALESCE(SUM(CASE WHEN t.kind=0 AND t.ignored=0 THEN t.amount ELSE 0 END),0),
				COALESCE(SUM(CASE WHEN t.kind=2 AND t.ignored=0 THEN t.amount ELSE 0 END),0),
				COUNT(*)
			FROM transactions t
			WHERE t.status=0 AND t.day>=? AND t.day<=?
			GROUP BY 1 ORDER BY 1`, from, to)
	case "account":
		rows, err = s.db.Query(`SELECT 'acc:'||t.account_id, COALESCE(a.name,'?'), COALESCE(a.color,''), COALESCE(a.icon,''),
				COALESCE(SUM(CASE WHEN t.kind=0 AND t.ignored=0 THEN t.amount ELSE 0 END),0),
				COALESCE(SUM(CASE WHEN t.kind=2 AND t.ignored=0 THEN t.amount ELSE 0 END),0),
				COUNT(*)
			FROM transactions t LEFT JOIN accounts a ON a.id=t.account_id
			WHERE t.status=0 AND t.day>=? AND t.day<=?
			GROUP BY t.account_id ORDER BY 5 DESC`, from, to)
	default: // category
		rows, err = s.db.Query(`SELECT 'cat:'||t.category_id, COALESCE(c.name,'?'), COALESCE(c.color,''), COALESCE(c.icon,''),
				COALESCE(SUM(CASE WHEN t.kind=0 AND t.ignored=0 THEN t.amount ELSE 0 END),0),
				COALESCE(SUM(CASE WHEN t.kind=2 AND t.ignored=0 THEN t.amount ELSE 0 END),0),
				COUNT(*)
			FROM transactions t LEFT JOIN categories c ON c.id=t.category_id
			WHERE t.status=0 AND t.day>=? AND t.day<=? AND t.category_id IS NOT NULL
			GROUP BY t.category_id ORDER BY 5 DESC`, from, to)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []model.StatRow{}
	for rows.Next() {
		var r model.StatRow
		if err := rows.Scan(&r.Key, &r.Label, &r.Color, &r.Icon, &r.Expense, &r.Income, &r.Count); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// BudgetStatuses computes spent/left per budget for the period containing at (YYYY-MM-DD).
func (s *Store) BudgetStatuses(at string) ([]model.BudgetStatus, error) {
	budgets, err := s.Budgets()
	if err != nil {
		return nil, err
	}
	zone := s.Zone()
	ref, err := time.ParseInLocation("2006-01-02", at, zone)
	if err != nil {
		return nil, fmt.Errorf("bad date %q: %w", at, err)
	}
	// Rates must be read before spentIn takes the store lock (Rate() locks too).
	sysCur := s.SystemCurrency()
	rateSys := s.Rate(sysCur)
	out := []model.BudgetStatus{}
	for _, b := range budgets {
		if b.Value <= 0 {
			continue // unbudgeted
		}
		if b.Currency == "" {
			b.Currency = sysCur
		}
		ws, we := budgetWindow(b, ref)
		spent, err := s.spentIn(b, ws.Format("2006-01-02"), we.AddDate(0, 0, -1).Format("2006-01-02"),
			rateSys, s.Rate(b.Currency))
		if err != nil {
			return nil, err
		}
		out = append(out, model.BudgetStatus{
			Budget:  b,
			Spent:   spent,
			Left:    b.Value - spent,
			WindowS: ws.Format("2006-01-02"),
			WindowE: we.AddDate(0, 0, -1).Format("2006-01-02"),
		})
	}
	return out, nil
}

// budgetWindow returns [start, end) in the local zone for the period containing ref.
func budgetWindow(b model.Budget, ref time.Time) (time.Time, time.Time) {
	y, m, d := ref.Date()
	switch b.Period {
	case model.PeriodDaily:
		st := time.Date(y, m, d, 0, 0, 0, 0, ref.Location())
		return st, st.AddDate(0, 0, 1)
	case model.PeriodWeekly:
		st := weekStart(ref)
		return st, st.AddDate(0, 0, 7)
	case model.PeriodBiweekly:
		anchor := weekStart(ref)
		if b.StartDate != "" {
			if a, err := time.ParseInLocation("2006-01-02", b.StartDate[:min(10, len(b.StartDate))], ref.Location()); err == nil {
				anchor = weekStart(a)
			}
		}
		days := int(ref.Sub(anchor).Hours() / 24)
		if days < 0 {
			days = 0
		}
		st := anchor.AddDate(0, 0, (days/14)*14)
		return st, st.AddDate(0, 0, 14)
	case model.PeriodQuarterly:
		q := int((m - 1) / 3) * 3
		st := time.Date(y, time.Month(q)+1, 1, 0, 0, 0, 0, ref.Location())
		return st, st.AddDate(0, 3, 0)
	case model.PeriodYearly:
		st := time.Date(y, 1, 1, 0, 0, 0, 0, ref.Location())
		return st, st.AddDate(1, 0, 0)
	case model.PeriodCustom:
		anchor := time.Date(y, m, d, 0, 0, 0, 0, ref.Location())
		if b.StartDate != "" {
			if a, err := time.ParseInLocation("2006-01-02", b.StartDate[:min(10, len(b.StartDate))], ref.Location()); err == nil {
				anchor = a
			}
		}
		n := b.PeriodDays
		if n <= 0 {
			n = 30
		}
		days := int(ref.Sub(anchor).Hours() / 24)
		if days < 0 {
			days = 0
		}
		st := anchor.AddDate(0, 0, (days/n)*n)
		return st, st.AddDate(0, 0, n)
	default: // monthly (calendar month, like the source app)
		st := time.Date(y, m, 1, 0, 0, 0, 0, ref.Location())
		return st, st.AddDate(0, 1, 0)
	}
}

func weekStart(t time.Time) time.Time {
	wd := (int(t.Weekday()) + 6) % 7
	y, m, d := t.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, t.Location()).AddDate(0, 0, -wd)
}

// spentIn totals the expenses of a budget's window **in the budget's own
// currency**. Rows already booked in that currency are summed verbatim from
// original_cost; anything else is converted from the system-currency `amount`
// through the USD pivot (rates are "units per USD" and are passed in because
// Rate() takes the same lock).
func (s *Store) spentIn(b model.Budget, from, to string, rateSys, rateBudget float64) (int64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	where := `status=0 AND ignored=0 AND ignore_budget=0 AND kind=0 AND day>=? AND day<=?`
	args := []any{from, to}
	switch b.Scope {
	case model.ScopeCategory:
		where += ` AND category_id=?`
		args = append(args, b.RefID)
	case model.ScopeSubcategory:
		where += ` AND subcategory_id=?`
		args = append(args, b.RefID)
	default:
		// Ledger-wide budget. Rows imported before bill_id was populated carry
		// NULL, so treat those as belonging to the active ledger.
		if b.RefID != "" {
			where += ` AND (bill_id=? OR bill_id IS NULL OR bill_id='')`
			args = append(args, b.RefID)
		}
	}

	cur := b.Currency
	if cur == "" {
		cur = "USD" // BudgetStatuses resolves the real fallback before locking
	}
	if rateBudget <= 0 {
		rateBudget = 1
	}
	if rateSys <= 0 {
		rateSys = 1
	}

	var same, otherSys int64
	err := s.db.QueryRow(`SELECT
		COALESCE(SUM(CASE WHEN original_currency=? THEN original_cost ELSE 0 END),0),
		COALESCE(SUM(CASE WHEN original_currency=? THEN 0 ELSE amount END),0)
		FROM transactions WHERE `+where,
		append([]any{cur, cur}, args...)...).Scan(&same, &otherSys)
	if err != nil {
		return 0, err
	}
	converted := int64(float64(otherSys) / rateSys * rateBudget)
	return same + converted, nil
}

// Wallets summarizes visible asset accounts + current-month income/expense in system currency.
type Wallets struct {
	System       string           `json:"system"`
	TotalMinor   int64            `json:"totalMinor"`
	IncomeMinor  int64            `json:"incomeMinor"`
	ExpenseMinor int64            `json:"expenseMinor"`
	ByCurrency   map[string]int64 `json:"byCurrency"`
}

func (s *Store) Wallets() (*Wallets, error) {
	accounts, err := s.Accounts()
	if err != nil {
		return nil, err
	}
	w := &Wallets{System: s.SystemCurrency(), ByCurrency: map[string]int64{}}
	for _, a := range accounts {
		if a.Status != model.StatusActive || a.Hidden || !a.InAssets {
			continue
		}
		w.ByCurrency[a.Currency] += a.Balance
		// minor(account) -> minor(system) via the USD pivot: rate = units per USD
		w.TotalMinor += int64(float64(a.Balance) / s.Rate(a.Currency) * s.Rate(w.System))
	}
	month := time.Now().In(s.Zone()).Format("2006-01")
	s.mu.Lock()
	err = s.db.QueryRow(`SELECT
		COALESCE(SUM(CASE WHEN kind=2 AND ignored=0 THEN amount ELSE 0 END),0),
		COALESCE(SUM(CASE WHEN kind=0 AND ignored=0 THEN amount ELSE 0 END),0)
		FROM transactions WHERE status=0 AND day LIKE ? || '-%'`, month).
		Scan(&w.IncomeMinor, &w.ExpenseMinor)
	s.mu.Unlock()
	if err != nil {
		return nil, err
	}
	return w, nil
}

// SummaryStats is the whole-database overview shown on the settings/statistics
// screen: how much history exists, not what it sums to.
type SummaryStats struct {
	Transactions         int64  `json:"transactions"`
	DaysWithTransactions int64  `json:"daysWithTransactions"`
	FirstDay             string `json:"firstDay"`
	LastDay              string `json:"lastDay"`
	ExpenseCount         int64  `json:"expenseCount"`
	IncomeCount          int64  `json:"incomeCount"`
	TransferCount        int64  `json:"transferCount"`
	Accounts             int64  `json:"accounts"`
	Categories           int64  `json:"categories"`
	Budgets              int64  `json:"budgets"`
}

// SummaryStats counts active rows across the whole database in one query.
func (s *Store) SummaryStats() (*SummaryStats, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := &SummaryStats{}
	err := s.db.QueryRow(`SELECT
		COUNT(*),
		COUNT(DISTINCT day),
		COALESCE(MIN(day),''),
		COALESCE(MAX(day),''),
		COALESCE(SUM(CASE WHEN kind=0 THEN 1 ELSE 0 END),0),
		COALESCE(SUM(CASE WHEN kind=2 THEN 1 ELSE 0 END),0),
		COALESCE(SUM(CASE WHEN kind=1 THEN 1 ELSE 0 END),0),
		(SELECT COUNT(*) FROM accounts   WHERE status=0),
		(SELECT COUNT(*) FROM categories WHERE status=0),
		(SELECT COUNT(*) FROM budgets    WHERE status=0)
		FROM transactions WHERE status=0`).Scan(
		&out.Transactions, &out.DaysWithTransactions, &out.FirstDay, &out.LastDay,
		&out.ExpenseCount, &out.IncomeCount, &out.TransferCount,
		&out.Accounts, &out.Categories, &out.Budgets)
	if err != nil {
		return nil, err
	}
	return out, nil
}
