// Package importer converts the Realm backup bundle (and CSV) into the app DB
// and back. Bundle format: docs/DATA-MODEL.md.
package importer

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"strings"
	"time"

	"budgetd/internal/model"
	"budgetd/internal/store"
)

type bundleRow map[string]any

type bundle struct {
	Format   string               `json:"format"`
	Objects  map[string][]bundleRow `json:"objects"`
}

func rows(b *bundle, class string) []bundleRow { return b.Objects[class] }

func str(r bundleRow, k string) string {
	if v, ok := r[k]; ok && v != nil {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

func num(r bundleRow, k string) float64 {
	if v, ok := r[k]; ok && v != nil {
		switch x := v.(type) {
		case float64:
			return x
		case int:
			return float64(x)
		}
	}
	return 0
}

func integer(r bundleRow, k string) int { return int(num(r, k)) }

func boolean(r bundleRow, k string) bool {
	if v, ok := r[k]; ok && v != nil {
		switch x := v.(type) {
		case bool:
			return x
		case float64:
			return x != 0
		}
	}
	return false
}

func minor(v float64) int64 { return int64(math.Round(v * 100)) }

func ms(r bundleRow, k string) int64 {
	s := str(r, k)
	if s == "" {
		return time.Now().UnixMilli()
	}
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t.UnixMilli()
	}
	return time.Now().UnixMilli()
}

func dayStr(r bundleRow, k string) string {
	s := str(r, k)
	if len(s) >= 10 {
		return s[:10]
	}
	return ""
}

// tdataPeriod decodes Realm t_data {"rawValue":N} (base64).
func tdataPeriod(r bundleRow) int {
	s := str(r, "t_data")
	if s == "" {
		return model.PeriodMonthly
	}
	if raw, err := base64.StdEncoding.DecodeString(s); err == nil {
		var p struct {
			RawValue int `json:"rawValue"`
		}
		if json.Unmarshal(raw, &p) == nil {
			return p.RawValue
		}
	}
	return model.PeriodMonthly
}

// ImportBundle replaces the DB content with the bundle. Destructive by design
// (a backup restore), matches the original app semantics.
func ImportBundle(st *store.Store, path string) (map[string]int, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var b bundle
	if err := json.Unmarshal(raw, &b); err != nil {
		return nil, fmt.Errorf("bad bundle: %w", err)
	}
	if len(b.Objects) == 0 {
		return nil, fmt.Errorf("bundle has no objects")
	}
	counts := map[string]int{}

	// pass 1: key maps
	catKey := map[string]string{}   // BillClassify.compoundKey -> id
	subKey := map[string]string{}   // Subcategory.compoundKey -> id
	acctID := map[string]bool{}     // Account2.id
	display := map[string][2]string{} // DisplayInfo.classify/bill key -> {icon,color}
	for _, r := range rows(&b, "BillClassify") {
		catKey[str(r, "compoundKey")] = str(r, "id")
	}
	for _, r := range rows(&b, "Subcategory") {
		subKey[str(r, "compoundKey")] = str(r, "id")
	}
	for _, r := range rows(&b, "Account2") {
		acctID[str(r, "id")] = true
	}
	for _, r := range rows(&b, "DisplayInfo") {
		k := str(r, "classify")
		if k == "" {
			k = str(r, "bill")
		}
		display[k] = [2]string{str(r, "iconName"), str(r, "colorHex")}
	}

	// system currency: dominant oSystemCurrency in Expend
	sysCur := "USD"
	{
		seen := map[string]int{}
		for _, r := range rows(&b, "Expend") {
			if c := str(r, "oSystemCurrency"); c != "" {
				seen[c]++
			}
		}
		best, n := "", 0
		for c, v := range seen {
			if v > n {
				best, n = c, v
			}
		}
		if best != "" {
			sysCur = best
		}
	}

	wipeAll(st)

	// bills
	for _, r := range rows(&b, "Bill") {
		inf := display[str(r, "compoundKey")]
		if err := st.SaveBill(model.Bill{
			ID: str(r, "id"), Name: str(r, "name"),
			Icon: inf[0], Color: normHex(inf[1]),
			Sorted: num(r, "sorted"), Status: integer(r, "status"),
		}); err != nil {
			return counts, err
		}
		counts["bills"]++
	}

	// categories
	for _, r := range rows(&b, "BillClassify") {
		inf := display[str(r, "compoundKey")]
		bill := str(r, "bill")
		billID := ""
		if i := strings.Index(bill, "___"); i > 0 {
			billID = bill[:i]
		}
		if err := st.SaveCategory(&model.Category{
			ID: str(r, "id"), BillID: billID, Name: str(r, "name"),
			IsIncome: boolean(r, "isIncome"),
			Icon:     inf[0], Color: normHex(inf[1]),
			Sorted: num(r, "sorted"), Status: integer(r, "status"),
			Subcategories: []model.Subcategory{},
		}); err != nil {
			return counts, err
		}
		counts["categories"]++
	}

	// subcategories
	for _, r := range rows(&b, "Subcategory") {
		ck := str(r, "classify")
		catID := catKey[ck]
		if catID == "" {
			if i := strings.Index(ck, "___"); i > 0 {
				catID = ck[:i]
			}
		}
		if err := st.SaveSubcategory(&model.Subcategory{
			ID: str(r, "id"), CategoryID: catID, Name: str(r, "name"),
			Sorted: num(r, "sorted"), Status: integer(r, "status"),
		}); err != nil {
			return counts, err
		}
		counts["subcategories"]++
	}

	// accounts: Account2 (bank/cash/credit) + Account3 (custom)
	for _, r := range rows(&b, "Account2") {
		kind := model.AcctDebit
		if integer(r, "isDebit") == 0 {
			kind = model.AcctCredit
		}
		if err := st.SaveAccount(&model.Account{
			ID: str(r, "id"), Kind: kind,
			Name: firstNonEmpty(str(r, "nickName"), str(r, "bankName")),
			Icon: str(r, "iconName"), Color: normHex(str(r, "colorHex")),
			Currency:    firstNonEmpty(str(r, "currencyID"), "USD"),
			CreditLimit: minor(num(r, "creditLimit")),
			Liability:   minor(num(r, "liability")),
			Balance:     minor(num(r, "cacheAmount")),
			InAssets:    boolean(r, "inAssets"),
			Hidden:      boolean(r, "hiddenAssets"),
			Sorted:      num(r, "sorted"),
			Status:      integer(r, "status"),
		}); err != nil {
			return counts, err
		}
		counts["accounts"]++
	}
	for _, r := range rows(&b, "Account3") {
		if err := st.SaveAccount(&model.Account{
			ID: str(r, "id"), Kind: model.AcctCustom,
			Name: str(r, "nickname"), Icon: str(r, "iconName"),
			Color: normHex(str(r, "colorHex")),
			Currency: firstNonEmpty(str(r, "currencyCode"), "USD"),
			Balance:      minor(num(r, "cacheTotalValue")),
			FinancesType: integer(r, "financesType"),
			Code:         str(r, "code"),
			InAssets:     boolean(r, "inAssets"),
			Hidden:       boolean(r, "hiddenAssets"),
			Sorted:       num(r, "sorted"),
			Status:       integer(r, "status"),
		}); err != nil {
			return counts, err
		}
		counts["accounts"]++
	}

	// groups
	for _, r := range rows(&b, "AccountGroup") {
		ids := []string{}
		if v, ok := r["groups"].([]any); ok {
			for _, x := range v {
				if s, ok := x.(string); ok {
					ids = append(ids, s)
				}
			}
		}
		if err := st.SaveGroup(model.Group{Name: str(r, "name"), AccountIDs: ids, Sorted: num(r, "sorted")}); err != nil {
			return counts, err
		}
		counts["groups"]++
	}

	// budgets
	for _, r := range rows(&b, "Budget") {
		bud := model.Budget{
			ID: str(r, "id"), Period: tdataPeriod(r),
			Value: minor(num(r, "value")),
			Currency: firstNonEmpty(str(r, "originalCurrency"), sysCur),
			CategoryMode:  integer(r, "categoryMode"),
			RolloverMode:  integer(r, "rolloverMode"),
			FixedAmount:   boolean(r, "fixedPeriodAmount"),
			ShouldSummary: boolean(r, "shouldSummary"),
			StartDate:     dayStr(r, "s_date"),
			Status:        integer(r, "status"),
		}
		switch {
		case str(r, "subcategory") != "":
			bud.Scope, bud.RefID = model.ScopeSubcategory, subKey[str(r, "subcategory")]
		case str(r, "classify") != "":
			bud.Scope, bud.RefID = model.ScopeCategory, catKey[str(r, "classify")]
		default:
			bud.Scope, bud.RefID = model.ScopeBill, billPlainId(str(r, "bill"))
		}
		if err := st.SaveBudget(&bud); err != nil {
			return counts, err
		}
		counts["budgets"]++
	}

	// transactions
	zone := st.Zone()
	for _, r := range rows(&b, "Expend") {
		ts := ms(r, "date")
		t := model.Tx{
			ID: str(r, "id"), TsMs: ts,
			Day: time.UnixMilli(ts).In(zone).Format("2006-01-02"),
			Kind:     integer(r, "transferType"),
			IsIncome: boolean(r, "isIncome"),
			Amount:   minor(num(r, "amount")),
			Currency: firstNonEmpty(str(r, "oSystemCurrency"), sysCur),
			OriginalCost:     minor(num(r, "originalCost")),
			OriginalCurrency: firstNonEmpty(str(r, "originalCurrency"), sysCur),
			Label:            str(r, "label"),
			Remark:           str(r, "remark"),
			Ignored:          boolean(r, "ignore"),
			IgnoreBudget:     boolean(r, "ignoreFromBudget"),
			IgnoreExpend:     boolean(r, "ignoreFromExpend"),
			Status:           integer(r, "status"),
			CreatedAt:        str(r, "createDate"),
			ModifiedAt:       str(r, "modifyDate"),
		}
		if c := catKey[str(r, "classify")]; c != "" {
			t.CategoryID = &c
		}
		if s := subKey[str(r, "subcategory")]; s != "" {
			t.SubcategoryID = &s
		}
		if a := str(r, "accountInfo"); a != "" && acctID[a] {
			t.AccountID = &a
		}
		if a := str(r, "transferAccountID"); a != "" && acctID[a] {
			t.ToAccountID = &a
			t.ToAmount = minor(num(r, "transferSnapshotAmount"))
		}
		if t.Kind != model.KindTransfer && t.ToAccountID != nil {
			t.Kind = model.KindTransfer
		}
		if err := st.InsertTxRaw(&t); err != nil {
			return counts, err
		}
		counts["transactions"]++
	}

	// currencies
	for _, r := range rows(&b, "Country") {
		if err := st.SaveCurrency(model.Currency{
			Code: str(r, "currencyAbbreviated"), Symbol: str(r, "currencySymbol"),
			Name: str(r, "en"), Country: str(r, "countryName"),
			Rate: num(r, "regularMarketPrice"), InUse: boolean(r, "inUse"),
		}); err != nil {
			return counts, err
		}
		counts["currencies"]++
	}

	// recurring from AutoBooking + SubscribeModel (both empty in the source backup)
	for _, r := range rows(&b, "AutoBooking") {
		rec := model.Recurring{
			ID: str(r, "id"), Name: firstNonEmpty(str(r, "remark"), "Recurring"),
			Kind: model.KindExpense, Amount: minor(num(r, "amount")),
			Currency: firstNonEmpty(str(r, "originalCurrency"), sysCur),
			Remark: str(r, "remark"), Period: model.PeriodMonthly,
			NextDate: dayStr(r, "spendDate"), Status: integer(r, "status"),
		}
		if c := catKey[str(r, "classify")]; c != "" {
			rec.CategoryID = &c
		}
		if a := str(r, "account"); a != "" && acctID[a] {
			rec.AccountID = &a
		}
		if err := st.SaveRecurring(&rec); err != nil {
			return counts, err
		}
		counts["recurring"]++
	}
	for _, r := range rows(&b, "SubscribeModel") {
		rec := model.Recurring{
			ID: str(r, "id"), Name: str(r, "name"),
			Kind: model.KindExpense, Amount: minor(num(r, "amount")),
			Currency: firstNonEmpty(str(r, "currencyCode"), sysCur),
			Remark: str(r, "remark"), Period: integer(r, "period"),
			NextDate: dayStr(r, "paymentDate"), EndDate: dayStr(r, "endDate"),
			Status: integer(r, "status"),
		}
		if a := str(r, "accountID"); a != "" && acctID[a] {
			rec.AccountID = &a
		}
		if err := st.SaveRecurring(&rec); err != nil {
			return counts, err
		}
		counts["recurring"]++
	}

	// settings
	st.SetSetting("systemCurrency", sysCur)
	if bill := rows(&b, "Bill"); len(bill) > 0 {
		st.SetSetting("billId", str(bill[0], "id"))
	}
	st.SetSetting("firstRunDone", "1")
	return counts, nil
}

func billPlainId(ck string) string {
	if i := strings.Index(ck, "___"); i > 0 {
		return ck[:i]
	}
	return ck
}

func firstNonEmpty(vs ...string) string {
	for _, v := range vs {
		if v != "" {
			return v
		}
	}
	return ""
}

func normHex(h string) string {
	if h == "" {
		return "FEDB5A"
	}
	return strings.TrimPrefix(h, "#")
}

func wipeAll(st *store.Store) {
	for _, t := range []string{"transactions", "budgets", "subcategories", "categories",
		"account_groups", "accounts", "bills", "currencies", "recurring", "settings"} {
		st.Wipe(t)
	}
}
