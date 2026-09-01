package importer

import (
	"encoding/base64"
	"encoding/json"
	"os"
	"strings"
	"time"

	"budgetd/internal/model"
	"budgetd/internal/store"
)

// ExportBundle writes the DB back into the source-backup shape (Realm class
// names and field names), so a re-import round-trips and the file stays
// familiar to anyone who has seen the original Budget.realm dump.
func ExportBundle(st *store.Store, path string) error {
	b := map[string]any{
		"format":      "budget-ut/bundle1",
		"exportedAt":  time.Now().UTC().Format(time.RFC3339),
		"source":      "budget-ut",
		"objects":     map[string][]map[string]any{},
	}
	objs := b["objects"].(map[string][]map[string]any)

	bills, _ := st.Bills()
	cats, _ := st.Categories()
	accts, _ := st.Accounts()
	groups, _ := st.Groups()
	budgets, _ := st.Budgets()
	curs, _ := st.Currencies()
	_, txs, _ := st.ListTx(store.TxFilter{Limit: 500, Offset: 0})

	owner := "__defaultOwner__"
	ck := func(prefix, id string) string { return prefix + id + "___" + owner }

	for _, bill := range bills {
		objs["Bill"] = append(objs["Bill"], map[string]any{
			"compoundKey": ck("", bill.ID), "id": bill.ID, "owner": owner,
			"name": bill.Name, "createDate": nowISO(), "modifyDate": nowISO(),
			"isDefault": false, "sorted": bill.Sorted, "status": bill.Status,
		})
		objs["DisplayInfo"] = append(objs["DisplayInfo"], map[string]any{
			"compoundKey": ck("info:", bill.ID), "id": "info:" + bill.ID, "owner": owner,
			"iconName": bill.Icon, "colorHex": bill.Color,
			"createDate": nowISO(), "modifyDate": nowISO(), "isDefault": false,
			"bill": ck("", bill.ID), "classify": nil, "syncInfo": nil,
		})
	}

	for _, c := range cats {
		objs["BillClassify"] = append(objs["BillClassify"], map[string]any{
			"compoundKey": ck("", c.ID), "id": c.ID, "owner": owner,
			"budget": nil, "name": c.Name, "isIncome": c.IsIncome,
			"createDate": nowISO(), "modifyDate": nowISO(), "isDefault": false,
			"sorted": c.Sorted, "labels": []string{}, "bill": ck("", c.BillID),
			"info": ck("info:", c.ID), "syncInfo": nil, "status": c.Status,
		})
		objs["DisplayInfo"] = append(objs["DisplayInfo"], map[string]any{
			"compoundKey": ck("info:", c.ID), "id": "info:" + c.ID, "owner": owner,
			"iconName": c.Icon, "colorHex": c.Color,
			"createDate": nowISO(), "modifyDate": nowISO(), "isDefault": false,
			"bill": nil, "classify": ck("", c.ID), "syncInfo": nil,
		})
		for _, sc := range c.Subcategories {
			objs["Subcategory"] = append(objs["Subcategory"], map[string]any{
				"compoundKey": ck("", sc.ID), "id": sc.ID, "owner": owner,
				"name": sc.Name, "classify": ck("", c.ID),
				"createDate": nowISO(), "modifyDate": nowISO(),
				"sorted": sc.Sorted, "isDefault": false, "budget": nil, "syncInfo": nil,
			})
		}
	}

	for _, a := range accts {
		if a.Kind == model.AcctCustom {
			objs["Account3"] = append(objs["Account3"], map[string]any{
				"compoundKey": ck("", a.ID), "id": a.ID, "owner": owner,
				"createDate": nowISO(), "modifyDate": nowISO(),
				"sorted": a.Sorted, "isDefault": false, "syncInfo": nil,
				"currencyCode": a.Currency, "data": nil, "financesType": a.FinancesType,
				"nickname": a.Name, "iconName": a.Icon, "colorHex": a.Color,
				"code": a.Code, "inAssets": a.InAssets, "status": a.Status,
				"cacheTotalValue": float64(a.Balance) / 100,
			})
			continue
		}
		objs["Account2"] = append(objs["Account2"], map[string]any{
			"compoundKey": ck("", a.ID), "id": a.ID, "owner": owner,
			"createDate": nowISO(), "modifyDate": nowISO(),
			"sorted": a.Sorted, "isDefault": false, "syncInfo": nil,
			"bankName": a.Name, "nickName": a.Name, "iconName": a.Icon,
			"bankType": 2, "colorHex": a.Color,
			"isDebit": map[bool]int{true: 1, false: 0}[a.Kind == model.AcctDebit],
			"creditLimit":     float64(a.CreditLimit) / 100,
			"liability":       float64(a.Liability) / 100,
			"startDate":       nowISO(), "resetDate": nowISO(),
			"cardID": nil, "currencyID": a.Currency, "zeroMode": false,
			"cacheAmount": float64(a.Balance) / 100, "cacheIncome": 0, "cacheExpend": 0,
			"inAssets": a.InAssets, "status": a.Status, "hiddenAssets": a.Hidden,
		})
	}

	for _, g := range groups {
		objs["AccountGroup"] = append(objs["AccountGroup"], map[string]any{
			"compoundKey": ck("", g.Name), "id": g.Name, "owner": owner,
			"createDate": nowISO(), "modifyDate": nowISO(), "syncInfo": nil,
			"name": g.Name, "groups": g.AccountIDs, "sorted": g.Sorted,
		})
	}

	for _, bud := range budgets {
		row := map[string]any{
			"compoundKey": ck("", bud.ID), "id": bud.ID, "owner": owner,
			"value": float64(bud.Value) / 100,
			"classify": nil, "bill": nil, "subcategory": nil,
			"createDate": nowISO(), "modifyDate": nowISO(), "isDefault": false,
			"s_date": bud.StartDate + "T00:00:00.000Z",
			"t_data": base64.StdEncoding.EncodeToString(mustJSON(map[string]int{"rawValue": bud.Period})),
			"shouldSummary": bud.ShouldSummary,
			"originalCurrency": bud.Currency, "syncInfo": nil,
			"fixedPeriodAmount": bud.FixedAmount,
			"categoryMode": bud.CategoryMode, "rolloverMode": bud.RolloverMode,
			"status": bud.Status,
		}
		switch bud.Scope {
		case model.ScopeCategory:
			row["classify"] = ck("", bud.RefID)
		case model.ScopeSubcategory:
			row["subcategory"] = ck("", bud.RefID)
		default:
			row["bill"] = ck("", bud.RefID)
		}
		objs["Budget"] = append(objs["Budget"], row)
	}

	for _, c := range curs {
		objs["Country"] = append(objs["Country"], map[string]any{
			"currencyAbbreviated": c.Code, "countryName": c.Country,
			"zhHans": c.Name, "zhHant": c.Name,
			"encountryAbbreviated": c.Code, "en": c.Name,
			"currencySymbol": c.Symbol, "regularMarketPrice": c.Rate,
			"create": nowISO(), "inUse": c.InUse, "modify": nowISO(),
			"isSymbolManuallySet": false, "isRateManuallySet": false,
		})
	}

	for _, t := range txs {
		objs["Expend"] = append(objs["Expend"], expendRow(st, t, owner, ck))
	}

	// paginate the rest of the transactions (ListTx caps at 500)
	for offset := 500; offset < 1<<30; offset += 500 {
		_, more, _ := st.ListTx(store.TxFilter{Limit: 500, Offset: offset})
		if len(more) == 0 {
			break
		}
		for _, t := range more {
			objs["Expend"] = append(objs["Expend"], expendRow(st, t, owner, ck))
		}
	}

	// Account history. The synthetic "open:<id>" opening-balance rows are left
	// out: the importer regenerates them from the account balance, so emitting
	// them would only fight with its own row. Realm has no notion of *why* a
	// balance moved, hence a re-import lands everything as kind=2 (snapshot).
	logs, _ := st.AllAccountLogs()
	for acct, items := range logs {
		for _, l := range items {
			if strings.HasPrefix(l.ID, "open:") {
				continue
			}
			iso := time.UnixMilli(l.TsMs).UTC().Format(time.RFC3339Nano)
			amount, ttype := float64(l.Delta)/100, 1
			if l.Delta < 0 {
				amount, ttype = -amount, -1
			}
			objs["AccountBalanceChangeLog"] = append(objs["AccountBalanceChangeLog"], map[string]any{
				"compoundKey": ck("", l.ID), "id": l.ID, "owner": owner,
				"createDate": iso, "modifyDate": iso, "syncInfo": nil,
				"relatedAccountId": acct, "transactionId": l.TxID,
				"transactionType": ttype, "amount": amount,
				"currencyCode": l.Currency,
				"balanceAfterChange": float64(l.BalanceAfter) / 100,
				"transactionDate":    iso, "hasBoundRecordId": l.TxID != "",
			})
		}
	}

	f, err := os.Create(path)
	if err != nil {
		return err
	}
	enc := json.NewEncoder(f)
	enc.SetIndent("", " ")
	if err := enc.Encode(b); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}

func expendRow(st *store.Store, t model.Tx, owner string, ck func(string, string) string) map[string]any {
	row := map[string]any{
		"compoundKey": ck("", t.ID), "id": t.ID, "owner": owner,
		"date": time.UnixMilli(t.TsMs).UTC().Format(time.RFC3339Nano),
		"label": nilOr(t.Label), "classify": nil, "isIncome": t.IsIncome,
		"createDate": t.CreatedAt, "modifyDate": t.ModifiedAt, "isDefault": false,
		"remark": nilOr(t.Remark),
		"originalCurrency": t.OriginalCurrency,
		"originalCost":     float64(t.OriginalCost) / 100,
		"oSystemCurrency": t.Currency, "amount": float64(t.Amount) / 100,
		"booking": nil, "syncInfo": nil, "accountInfo": nil,
		"transferType": t.Kind,
		"ignore": t.Ignored, "ignoreFromBudget": t.IgnoreBudget,
		"ignoreFromExpend": t.IgnoreExpend,
		"hasBeenDebited": false, "createdByMethod": "",
		"labels": []string{}, "userID": nil, "status": t.Status,
		"hasImage": 0,
	}
	if t.CategoryID != nil {
		row["classify"] = ck("", *t.CategoryID)
	}
	if t.SubcategoryID != nil {
		row["subcategory"] = ck("", *t.SubcategoryID)
	}
	if t.AccountID != nil {
		row["accountInfo"] = *t.AccountID
	}
	if t.ToAccountID != nil {
		row["transferAccountID"] = *t.ToAccountID
		row["transferSnapshotAmount"] = float64(t.ToAmount) / 100
	}
	return row
}

func nilOr(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func nowISO() string { return time.Now().UTC().Format(time.RFC3339Nano) }

func mustJSON(v any) []byte {
	b, _ := json.Marshal(v)
	return b
}
