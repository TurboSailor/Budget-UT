package store

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"budgetd/internal/model"
)

const txCols = `id, bill_id, ts_ms, day, category_id, subcategory_id, kind, is_income,
  amount, currency, original_cost, original_currency, account_id, to_account_id, to_amount,
  label, remark, ignored, ignore_budget, ignore_expend, has_image, status, created_at, modified_at`

func scanTx(sc interface{ Scan(...any) error }) (*model.Tx, error) {
	t := &model.Tx{}
	var cat, sub, acc, toAcc, billID, cur, origCur, label, remark, cr, md sql.NullString
	var ii, ig, igb, ige, hasImage int
	err := sc.Scan(&t.ID, &billID, &t.TsMs, &t.Day, &cat, &sub, &t.Kind, &ii,
		&t.Amount, &cur, &t.OriginalCost, &origCur, &acc, &toAcc, &t.ToAmount,
		&label, &remark, &ig, &igb, &ige, &hasImage, &t.Status, &cr, &md)
	if err != nil {
		return nil, err
	}
	t.BillID = billID.String
	t.Currency = cur.String
	t.OriginalCurrency = origCur.String
	t.Label = label.String
	t.Remark = remark.String
	t.CreatedAt = cr.String
	t.ModifiedAt = md.String
	t.CategoryID, t.SubcategoryID, t.AccountID, t.ToAccountID = np(cat), np(sub), np(acc), np(toAcc)
	t.IsIncome, t.Ignored, t.IgnoreBudget, t.IgnoreExpend = ii != 0, ig != 0, igb != 0, ige != 0
	return t, nil
}

// InsertTx stores a transaction and adjusts account balances.
func (s *Store) InsertTx(t *model.Tx) error {
	if t.ID == "" {
		t.ID = NewID()
	}
	now := time.Now().UTC().Format(time.RFC3339)
	if t.CreatedAt == "" {
		t.CreatedAt = now
	}
	t.ModifiedAt = now
	if t.TsMs == 0 {
		t.TsMs = time.Now().UnixMilli()
	}
	if t.Day == "" {
		t.Day = time.UnixMilli(t.TsMs).In(s.Zone()).Format("2006-01-02")
	}
	if t.Currency == "" {
		t.Currency = s.SystemCurrency()
	}
	if t.BillID == "" {
		t.BillID = s.Setting("billId", "")
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	if _, err := s.db.Exec(`INSERT INTO transactions(`+txCols+`)
		VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
		t.ID, pn0(t.BillID), t.TsMs, t.Day, pn(t.CategoryID), pn(t.SubcategoryID), t.Kind,
		b2i(t.IsIncome), t.Amount, pn0(t.Currency), t.OriginalCost, pn0(t.OriginalCurrency),
		pn(t.AccountID), pn(t.ToAccountID), t.ToAmount, pn0(t.Label), pn0(t.Remark),
		b2i(t.Ignored), b2i(t.IgnoreBudget), b2i(t.IgnoreExpend), 0, t.Status,
		t.CreatedAt, t.ModifiedAt); err != nil {
		return err
	}
	s.applyBalancesLocked(t, 1, true)
	return nil
}

// InsertTxRaw inserts with precomputed fields and NO balance adjustments —
// used by the bundle importer, whose balances are authoritative snapshots.
func (s *Store) InsertTxRaw(t *model.Tx) error {
	if t.ID == "" {
		t.ID = NewID()
	}
	if t.CreatedAt == "" {
		t.CreatedAt = time.Now().UTC().Format(time.RFC3339)
	}
	if t.ModifiedAt == "" {
		t.ModifiedAt = t.CreatedAt
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	_, err := s.db.Exec(`INSERT INTO transactions(`+txCols+`)
		VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
		t.ID, pn0(t.BillID), t.TsMs, t.Day, pn(t.CategoryID), pn(t.SubcategoryID), t.Kind,
		b2i(t.IsIncome), t.Amount, pn0(t.Currency), t.OriginalCost, pn0(t.OriginalCurrency),
		pn(t.AccountID), pn(t.ToAccountID), t.ToAmount, pn0(t.Label), pn0(t.Remark),
		b2i(t.Ignored), b2i(t.IgnoreBudget), b2i(t.IgnoreExpend), 0, t.Status,
		t.CreatedAt, t.ModifiedAt)
	return err
}

// UpdateTx patches a transaction: old balance effects are reverted, new applied.
func (s *Store) UpdateTx(id string, patch map[string]any) (*model.Tx, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	row := s.db.QueryRow(`SELECT `+txCols+` FROM transactions WHERE id=?`, id)
	old, err := scanTx(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("transaction %s not found", id)
	}
	if err != nil {
		return nil, err
	}

	b, err := json.Marshal(patch)
	if err != nil {
		return nil, err
	}
	fresh := *old
	if err := json.Unmarshal(b, &fresh); err != nil {
		return nil, err
	}
	fresh.ID = old.ID
	fresh.CreatedAt = old.CreatedAt
	fresh.ModifiedAt = time.Now().UTC().Format(time.RFC3339)
	// zoneLocked, never Zone(): s.mu is held here and the mutex is not reentrant.
	fresh.Day = time.UnixMilli(fresh.TsMs).In(s.zoneLocked()).Format("2006-01-02")
	if fresh.BillID == "" {
		fresh.BillID = old.BillID
	}

	if _, err := s.db.Exec(`UPDATE transactions SET
		ts_ms=?, day=?, category_id=?, subcategory_id=?, kind=?, is_income=?,
		amount=?, currency=?, original_cost=?, original_currency=?,
		account_id=?, to_account_id=?, to_amount=?, label=?, remark=?,
		ignored=?, ignore_budget=?, ignore_expend=?, status=?, modified_at=?
		WHERE id=?`,
		fresh.TsMs, fresh.Day, pn(fresh.CategoryID), pn(fresh.SubcategoryID), fresh.Kind,
		b2i(fresh.IsIncome), fresh.Amount, fresh.Currency, fresh.OriginalCost, pn0(fresh.OriginalCurrency),
		pn(fresh.AccountID), pn(fresh.ToAccountID), fresh.ToAmount, fresh.Label, fresh.Remark,
		b2i(fresh.Ignored), b2i(fresh.IgnoreBudget), b2i(fresh.IgnoreExpend), fresh.Status,
		fresh.ModifiedAt, id); err != nil {
		return nil, err
	}
	// Balances and history move only once the row itself is stored, so a failed
	// UPDATE can neither shift a balance nor leave a phantom log entry.
	s.applyBalancesLocked(old, -1, true)
	s.applyBalancesLocked(&fresh, 1, true)
	return &fresh, nil
}

// DeleteTx soft-deletes and reverts balances.
func (s *Store) DeleteTx(id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	row := s.db.QueryRow(`SELECT `+txCols+` FROM transactions WHERE id=?`, id)
	t, err := scanTx(row)
	if errors.Is(err, sql.ErrNoRows) {
		return fmt.Errorf("transaction %s not found", id)
	}
	if err != nil {
		return err
	}
	if t.Status == model.StatusDeleted {
		return nil
	}
	if _, err := s.db.Exec(`UPDATE transactions SET status=1, modified_at=? WHERE id=?`,
		time.Now().UTC().Format(time.RFC3339), id); err != nil {
		return err
	}
	s.applyBalancesLocked(t, -1, true)
	return nil
}

// applyBalancesLocked moves the affected account balances by ±dir and, when
// history is asked for, appends a kind=1 log row per touched account. dir=-1
// is the compensating direction (edit-old / delete), so its rows carry the
// reverted note. history=false is for the internal rollback path, which must
// not leave a trace of a change that never happened.
func (s *Store) applyBalancesLocked(t *model.Tx, dir int, history bool) {
	switch t.Kind {
	case model.KindExpense:
		if t.AccountID != nil {
			s.bumpBalanceLocked(*t.AccountID, int64(-dir)*t.OriginalCost, s.txNoteLocked(t, dir, false, history), t.ID)
		}
	case model.KindIncome:
		if t.AccountID != nil {
			s.bumpBalanceLocked(*t.AccountID, int64(dir)*t.OriginalCost, s.txNoteLocked(t, dir, false, history), t.ID)
		}
	case model.KindTransfer:
		if t.AccountID != nil {
			s.bumpBalanceLocked(*t.AccountID, int64(-dir)*t.OriginalCost, s.txNoteLocked(t, dir, false, history), t.ID)
		}
		if t.ToAccountID != nil {
			s.bumpBalanceLocked(*t.ToAccountID, int64(dir)*t.ToAmount, s.txNoteLocked(t, dir, true, history), t.ID)
		}
	}
}

// bumpBalanceLocked shifts one account balance. A non-empty note also records
// the change in account_logs, right next to the balance write so the logged
// balanceAfter can never drift.
func (s *Store) bumpBalanceLocked(id string, delta int64, note, txID string) {
	if delta == 0 {
		return
	}
	if _, err := s.db.Exec(`UPDATE accounts SET balance = balance + ? WHERE id=?`, delta, id); err != nil {
		return
	}
	if note == "" {
		return
	}
	_, _ = s.appendAccountLogLocked(id, model.LogTransaction, delta, note, txID)
}

// txNoteLocked builds the human note for a transaction-driven balance change.
// `incoming` marks the receiving side of a transfer. Returns "" when no history
// is wanted, which is what switches logging off in bumpBalanceLocked.
func (s *Store) txNoteLocked(t *model.Tx, dir int, incoming, history bool) string {
	if !history {
		return ""
	}
	var note string
	switch t.Kind {
	case model.KindExpense:
		note = joinNote("Expense", s.categoryNameLocked(t.CategoryID))
	case model.KindIncome:
		note = joinNote("Income", s.categoryNameLocked(t.CategoryID))
	case model.KindTransfer:
		if incoming {
			note = joinNote("Transfer in", s.accountNameLocked(t.AccountID))
		} else {
			note = joinNote("Transfer out", s.accountNameLocked(t.ToAccountID))
		}
	default:
		note = "Transaction"
	}
	if dir < 0 {
		return "Reverted · " + note
	}
	return note
}

func joinNote(head, tail string) string {
	if tail == "" {
		return head
	}
	return head + " · " + tail
}

func (s *Store) categoryNameLocked(id *string) string {
	if id == nil || *id == "" {
		return ""
	}
	var name string
	if err := s.db.QueryRow(`SELECT name FROM categories WHERE id=?`, *id).Scan(&name); err != nil {
		return ""
	}
	return name
}

func (s *Store) accountNameLocked(id *string) string {
	if id == nil || *id == "" {
		return ""
	}
	var name string
	if err := s.db.QueryRow(`SELECT name FROM accounts WHERE id=?`, *id).Scan(&name); err != nil {
		return ""
	}
	return name
}

type TxFilter struct {
	From, To    string
	Account     string
	Category    string
	Subcategory string
	Kind        *int
	Q           string
	Limit       int
	Offset      int
}

func (s *Store) ListTx(f TxFilter) (int, []model.Tx, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	where := `status=0`
	args := []any{}
	if f.From != "" {
		where += ` AND day>=?`
		args = append(args, f.From)
	}
	if f.To != "" {
		where += ` AND day<=?`
		args = append(args, f.To)
	}
	if f.Account != "" {
		where += ` AND (account_id=? OR to_account_id=?)`
		args = append(args, f.Account, f.Account)
	}
	if f.Category != "" {
		where += ` AND category_id=?`
		args = append(args, f.Category)
	}
	if f.Subcategory != "" {
		where += ` AND subcategory_id=?`
		args = append(args, f.Subcategory)
	}
	if f.Kind != nil {
		where += ` AND kind=?`
		args = append(args, *f.Kind)
	}
	if f.Q != "" {
		where += ` AND (label LIKE ? OR remark LIKE ?)`
		args = append(args, "%"+f.Q+"%", "%"+f.Q+"%")
	}

	var total int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM transactions WHERE `+where, args...).Scan(&total); err != nil {
		return 0, nil, err
	}
	if f.Limit <= 0 || f.Limit > 500 {
		f.Limit = 100
	}
	q := `SELECT ` + txCols + ` FROM transactions WHERE ` + where + `
		ORDER BY ts_ms DESC, id LIMIT ? OFFSET ?`
	args = append(args, f.Limit, f.Offset)
	rows, err := s.db.Query(q, args...)
	if err != nil {
		return 0, nil, err
	}
	defer rows.Close()
	items := []model.Tx{}
	for rows.Next() {
		t, err := scanTx(rows)
		if err != nil {
			return 0, nil, err
		}
		items = append(items, *t)
	}
	return total, items, rows.Err()
}

func (s *Store) TxByID(id string) (*model.Tx, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	row := s.db.QueryRow(`SELECT `+txCols+` FROM transactions WHERE id=?`, id)
	return scanTx(row)
}

func pn0(v string) any {
	if v == "" {
		return nil
	}
	return v
}
