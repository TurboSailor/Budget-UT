// Package model defines the JSON-facing types shared by the API and the store.
package model

// Enums (see docs/DATA-MODEL.md).
const (
	KindExpense  = 0 // tx.kind / Realm transferType
	KindTransfer = 1
	KindIncome   = 2
)

const (
	AcctDebit  = 0
	AcctCredit = 1
	AcctCustom = 2
)

const (
	PeriodDaily     = 0
	PeriodWeekly    = 1
	PeriodBiweekly  = 2
	PeriodMonthly   = 3
	PeriodQuarterly = 4
	PeriodYearly    = 5
	PeriodCustom    = 6
)

const (
	ScopeBill        = "bill"
	ScopeCategory    = "category"
	ScopeSubcategory = "subcategory"
)

const (
	StatusActive   = 0
	StatusDeleted  = 1
)

type Tx struct {
	ID               string  `json:"id"`
	TsMs             int64   `json:"tsMs"`
	Day              string  `json:"day"`
	Kind             int     `json:"kind"`
	BillID          string  `json:"billId,omitempty"`
	IsIncome         bool    `json:"isIncome"`
	Amount           int64   `json:"amount"`           // minor, system currency
	Currency         string  `json:"currency"`          // system currency
	OriginalCost     int64   `json:"originalCost"`      // minor, original currency
	OriginalCurrency string  `json:"originalCurrency"`
	AccountID        *string `json:"accountId"`
	ToAccountID      *string `json:"toAccountId"`
	ToAmount         int64   `json:"toAmount"`
	CategoryID       *string `json:"categoryId"`
	SubcategoryID    *string `json:"subcategoryId"`
	Label            string  `json:"label"`
	Remark           string  `json:"remark"`
	Ignored          bool    `json:"ignored"`
	IgnoreBudget     bool    `json:"ignoreBudget"`
	IgnoreExpend     bool    `json:"ignoreExpend"`
	Status           int     `json:"status"`
	CreatedAt        string  `json:"createdAt"`
	ModifiedAt       string  `json:"modifiedAt"`
}

type Account struct {
	ID           string `json:"id"`
	Kind         int    `json:"kind"`
	Name         string `json:"name"`
	Icon         string `json:"icon"`
	Color        string `json:"color"`
	Currency     string `json:"currency"`
	CreditLimit  int64  `json:"creditLimit"`
	Liability    int64  `json:"liability"`
	Balance      int64  `json:"balance"`
	FinancesType int    `json:"financesType"`
	Code         string `json:"code"`
	InAssets     bool   `json:"inAssets"`
	Hidden       bool   `json:"hidden"`
	Sorted       float64 `json:"sorted"`
	Status       int    `json:"status"`
}

type Group struct {
	Name       string   `json:"name"`
	AccountIDs []string `json:"accountIds"`
	Sorted     float64  `json:"sorted"`
}

type Bill struct {
	ID     string  `json:"id"`
	Name   string  `json:"name"`
	Icon   string  `json:"icon"`
	Color  string  `json:"color"`
	Sorted float64 `json:"sorted"`
	Status int     `json:"status"`
}

type Category struct {
	ID            string        `json:"id"`
	BillID        string        `json:"billId"`
	Name          string        `json:"name"`
	IsIncome      bool          `json:"isIncome"`
	Icon          string        `json:"icon"`
	Color         string        `json:"color"`
	Sorted        float64       `json:"sorted"`
	Status        int           `json:"status"`
	Subcategories []Subcategory `json:"subcategories,omitempty"`
}

type Subcategory struct {
	ID         string  `json:"id"`
	CategoryID string  `json:"categoryId"`
	Name       string  `json:"name"`
	Sorted     float64 `json:"sorted"`
	Status     int     `json:"status"`
}

type Budget struct {
	ID            string  `json:"id"`
	Scope         string  `json:"scope"`
	RefID         string  `json:"refId"`
	Period        int     `json:"period"`
	PeriodDays    int     `json:"periodDays"`
	Value         int64   `json:"value"`
	Currency      string  `json:"currency"`
	CategoryMode  int     `json:"categoryMode"`
	RolloverMode  int     `json:"rolloverMode"`
	FixedAmount   bool    `json:"fixedAmount"`
	ShouldSummary bool    `json:"shouldSummary"`
	StartDate     string  `json:"startDate"`
	Status        int     `json:"status"`
}

type BudgetStatus struct {
	Budget    Budget `json:"budget"`
	Spent     int64  `json:"spentMinor"`
	Left      int64  `json:"leftMinor"`
	WindowS   string `json:"windowStart"`
	WindowE   string `json:"windowEnd"`
}

type Currency struct {
	Code    string  `json:"code"`
	Symbol  string  `json:"symbol"`
	Name    string  `json:"name"`
	Country string  `json:"country"`
	Rate    float64 `json:"rate"` // units per USD
	InUse   bool    `json:"inUse"`
}

type Recurring struct {
	ID            string  `json:"id"`
	Name          string  `json:"name"`
	Kind          int     `json:"kind"`
	Amount        int64   `json:"amount"`
	Currency      string  `json:"currency"`
	CategoryID    *string `json:"categoryId"`
	SubcategoryID *string `json:"subcategoryId"`
	AccountID     *string `json:"accountId"`
	Remark        string  `json:"remark"`
	Period        int     `json:"period"`
	PeriodDays    int     `json:"periodDays"`
	NextDate      string  `json:"nextDate"`
	EndDate       string  `json:"endDate"`
	Status        int     `json:"status"`
}

type StatRow struct {
	Key         string `json:"key"`
	Label       string `json:"label"`
	Color       string `json:"color"`
	Icon        string `json:"icon"`
	Expense     int64  `json:"expenseMinor"`
	Income      int64  `json:"incomeMinor"`
	Count       int64  `json:"count"`
}

type DayStat struct {
	Day     string `json:"day"`
	Expense int64  `json:"expenseMinor"`
	Income  int64  `json:"incomeMinor"`
	Count   int64  `json:"count"`
}
