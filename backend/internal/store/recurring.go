package store

import (
	"fmt"
	"time"

	"budgetd/internal/model"
)

// RunRecurring materializes due recurring items up to `today` (YYYY-MM-DD local).
// Advances their nextDate. Returns count of created transactions.
func (s *Store) RunRecurring(today string) (int, error) {
	recs, err := s.Recurring()
	if err != nil {
		return 0, err
	}
	zone := s.Zone()
	if today == "" {
		today = time.Now().In(zone).Format("2006-01-02")
	}
	tToday, err := time.ParseInLocation("2006-01-02", today, zone)
	if err != nil {
		return 0, fmt.Errorf("bad date %q: %w", today, err)
	}

	created := 0
	for _, r := range recs {
		if r.Status != model.StatusActive || r.NextDate == "" {
			continue
		}
		curDate := r.NextDate
		for {
			tCur, err := time.ParseInLocation("2006-01-02", curDate, zone)
			if err != nil || tCur.After(tToday) {
				break
			}
			if r.EndDate != "" {
				if tEnd, err := time.ParseInLocation("2006-01-02", r.EndDate, zone); err == nil && tCur.After(tEnd) {
					break
				}
			}
			isIncome := false
			if r.CategoryID != nil {
				var ii int
				s.mu.Lock()
				_ = s.db.QueryRow(`SELECT is_income FROM categories WHERE id=?`, *r.CategoryID).Scan(&ii)
				s.mu.Unlock()
				isIncome = ii != 0
			}
			kind := r.Kind
			if isIncome && kind == model.KindExpense {
				kind = model.KindIncome
			}
			sysCur := s.SystemCurrency()
			amt := r.Amount
			if r.Currency != sysCur {
				amt = int64(float64(r.Amount) / s.Rate(r.Currency) * s.Rate(sysCur))
			}
			tx := model.Tx{
				ID:               fmt.Sprintf("rec:%s:%s", r.ID, curDate),
				TsMs:             tCur.Add(12 * time.Hour).UnixMilli(),
				Day:              curDate,
				Kind:             kind,
				IsIncome:         isIncome,
				Amount:           amt,
				Currency:         sysCur,
				OriginalCost:     r.Amount,
				OriginalCurrency: r.Currency,
				AccountID:        r.AccountID,
				CategoryID:       r.CategoryID,
				SubcategoryID:    r.SubcategoryID,
				Label:            r.Name,
				Remark:           r.Remark,
			}
			if err := s.InsertTx(&tx); err == nil {
				created++
			}
			curDate = advanceDate(curDate, r.Period, r.PeriodDays, zone)
		}
		if curDate != r.NextDate {
			r.NextDate = curDate
			_ = s.SaveRecurring(&r)
		}
	}
	return created, nil
}

func advanceDate(d string, period, periodDays int, zone *time.Location) string {
	t, err := time.ParseInLocation("2006-01-02", d, zone)
	if err != nil {
		return d
	}
	switch period {
	case model.PeriodDaily:
		return t.AddDate(0, 0, 1).Format("2006-01-02")
	case model.PeriodWeekly:
		return t.AddDate(0, 0, 7).Format("2006-01-02")
	case model.PeriodBiweekly:
		return t.AddDate(0, 0, 14).Format("2006-01-02")
	case model.PeriodQuarterly:
		return t.AddDate(0, 3, 0).Format("2006-01-02")
	case model.PeriodYearly:
		return t.AddDate(1, 0, 0).Format("2006-01-02")
	case model.PeriodCustom:
		n := periodDays
		if n <= 0 {
			n = 30
		}
		return t.AddDate(0, 0, n).Format("2006-01-02")
	default: // monthly
		return t.AddDate(0, 1, 0).Format("2006-01-02")
	}
}
