package importer

import (
	"encoding/csv"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"budgetd/internal/model"
	"budgetd/internal/store"
)

var csvHeader = []string{"date", "type", "category", "subcategory", "account", "toAccount",
	"label", "amount", "currency", "originalCost", "originalCurrency", "remark"}

// ExportCSV writes all active transactions as CSV (major units, dot decimal).
func ExportCSV(st *store.Store, path string) (int, error) {
	f, err := os.Create(path)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	w := csv.NewWriter(f)
	if err := w.Write(csvHeader); err != nil {
		return 0, err
	}

	cats, _ := st.Categories()
	catName := map[string]model.Category{}
	for _, c := range cats {
		catName[c.ID] = c
	}
	accts, _ := st.Accounts()
	acctName := map[string]string{}
	for _, a := range accts {
		acctName[a.ID] = a.Name
	}

	n := 0
	for offset := 0; offset < 1<<30; offset += 500 {
		_, txs, err := st.ListTx(store.TxFilter{Limit: 500, Offset: offset})
		if err != nil {
			return n, err
		}
		if len(txs) == 0 {
			break
		}
		for _, t := range txs {
			typ := "expense"
			switch t.Kind {
			case model.KindIncome:
				typ = "income"
			case model.KindTransfer:
				typ = "transfer"
			}
			cat, sub, acc, toAcc := "", "", "", ""
			if t.CategoryID != nil {
				if c, ok := catName[*t.CategoryID]; ok {
					cat = c.Name
				}
			}
			if t.SubcategoryID != nil {
				for _, c := range cats {
					for _, sc := range c.Subcategories {
						if sc.ID == *t.SubcategoryID {
							sub = sc.Name
						}
					}
				}
			}
			if t.AccountID != nil {
				acc = acctName[*t.AccountID]
			}
			if t.ToAccountID != nil {
				toAcc = acctName[*t.ToAccountID]
			}
			rec := []string{
				t.Day, typ, cat, sub, acc, toAcc, t.Label,
				major(t.Amount), t.Currency,
				major(t.OriginalCost), t.OriginalCurrency, t.Remark,
			}
			if err := w.Write(rec); err != nil {
				return n, err
			}
			n++
		}
		if len(txs) < 500 {
			break
		}
	}
	w.Flush()
	return n, w.Error()
}

func major(minor int64) string {
	return fmt.Sprintf("%.2f", float64(minor)/100)
}

// ImportCSV appends transactions from a CSV in the export format. Unknown
// categories/accounts are created on the fly. Returns the row count.
func ImportCSV(st *store.Store, path string) (int, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	r := csv.NewReader(f)
	r.FieldsPerRecord = -1
	recs, err := r.ReadAll()
	if err != nil {
		return 0, err
	}
	if len(recs) == 0 {
		return 0, fmt.Errorf("empty csv")
	}
	if strings.EqualFold(strings.TrimSpace(recs[0][0]), "date") {
		recs = recs[1:]
	}

	cats, _ := st.Categories()
	catByName := map[string]model.Category{}
	for _, c := range cats {
		catByName[strings.ToLower(c.Name)] = c
	}
	subByName := map[string]model.Subcategory{}
	for _, c := range cats {
		for _, sc := range c.Subcategories {
			subByName[strings.ToLower(sc.Name)] = sc
		}
	}
	accts, _ := st.Accounts()
	acctByName := map[string]model.Account{}
	for _, a := range accts {
		acctByName[strings.ToLower(a.Name)] = *a
	}
	sysCur := st.SystemCurrency()
	zone := st.Zone()

	n := 0
	for _, rec := range recs {
		if len(rec) < 8 {
			continue
		}
		get := func(i int) string {
			if i < len(rec) {
				return strings.TrimSpace(rec[i])
			}
			return ""
		}
		day := get(0)
		if _, err := time.ParseInLocation("2006-01-02", day, zone); err != nil {
			if t, err2 := time.Parse("2006-01-02 15:04", day); err2 == nil {
				day = t.Format("2006-01-02")
			} else {
				continue
			}
		}
		typ := strings.ToLower(get(1))
		t := model.Tx{
			Day:  day,
			Kind: model.KindExpense,
		}
		switch typ {
		case "income":
			t.Kind, t.IsIncome = model.KindIncome, true
		case "transfer":
			t.Kind = model.KindTransfer
		}
		if name := get(2); name != "" {
			if c, ok := catByName[strings.ToLower(name)]; ok {
				id := c.ID
				t.CategoryID = &id
				t.IsIncome = c.IsIncome && t.Kind != model.KindTransfer
			} else {
				c := model.Category{
					ID: store.NewID(), BillID: st.Setting("billId", ""), Name: name,
					IsIncome: t.IsIncome, Icon: "daily_0", Color: pickColor(name),
					Sorted: float64(time.Now().Unix()), Subcategories: []model.Subcategory{},
				}
				if err := st.SaveCategory(&c); err != nil {
					return n, err
				}
				catByName[strings.ToLower(name)] = c
				id := c.ID
				t.CategoryID = &id
			}
		}
		if name := get(3); name != "" {
			if sc, ok := subByName[strings.ToLower(name)]; ok {
				id := sc.ID
				t.SubcategoryID = &id
			}
		}
		mkAcct := func(name, cur string) (string, error) {
			if a, ok := acctByName[strings.ToLower(name)]; ok {
				return a.ID, nil
			}
			a := model.Account{
				ID: store.NewID(), Kind: model.AcctDebit, Name: name,
				Icon: "Cash", Color: pickColor(name), Currency: orDefault(cur, sysCur),
				InAssets: true, Sorted: float64(time.Now().Unix()),
			}
			if err := st.SaveAccount(&a); err != nil {
				return "", err
			}
			acctByName[strings.ToLower(name)] = a
			return a.ID, nil
		}
		if name := get(4); name != "" {
			id, err := mkAcct(name, get(10))
			if err != nil {
				return n, err
			}
			t.AccountID = &id
		}
		if name := get(5); name != "" && t.Kind == model.KindTransfer {
			id, err := mkAcct(name, get(10))
			if err != nil {
				return n, err
			}
			t.ToAccountID = &id
		}
		t.Label = get(6)
		amt, _ := strconv.ParseFloat(strings.ReplaceAll(get(7), ",", "."), 64)
		t.Amount = int64(amt * 100) // system currency column
		t.Currency = orDefault(get(8), sysCur)
		oc, _ := strconv.ParseFloat(strings.ReplaceAll(get(9), ",", "."), 64)
		if oc == 0 {
			oc = amt
		}
		t.OriginalCost = int64(oc * 100)
		t.OriginalCurrency = orDefault(get(10), t.Currency)
		t.Remark = get(11)
		if t.ToAccountID != nil {
			t.ToAmount = t.OriginalCost
		}
		ts, _ := time.ParseInLocation("2006-01-02", t.Day, zone)
		t.TsMs = ts.Add(12 * time.Hour).UnixMilli()
		if err := st.InsertTx(&t); err != nil {
			return n, err
		}
		n++
	}
	return n, nil
}

func orDefault(v, def string) string {
	if v == "" {
		return def
	}
	return v
}

func pickColor(name string) string {
	palette := []string{"FEDB5A", "5AA6FE", "FE5A5A", "20DAB8", "BC92E8", "FE9F5A", "94DD64", "FF8FB2"}
	h := 0
	for _, c := range strings.ToLower(name) {
		h = h*31 + int(c)
	}
	if h < 0 {
		h = -h
	}
	return palette[h%len(palette)]
}
