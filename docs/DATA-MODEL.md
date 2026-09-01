# Budget-UT data model & API contract

Single source of truth for backend (Go) and UI (QML). Anything both sides
touch is defined here; do not diverge.

## Money & time

- All amounts are **minor units** (cents), JSON numbers (int64).
- Every transaction carries `amount` (converted to the **system currency**,
  default `USD` — mirrors the original app's `oSystemCurrency`/`amount` pair)
  and `originalCost`/`originalCurrency` (what was actually paid, normally the
  account currency). Stats/budgets/overview always sum `amount`.
- Timestamps: `tsMs` (epoch millis, UTC) + `day` (`YYYY-MM-DD` in the user's
  timezone, taken from settings `tz`, default `+03:00`). **Day grouping is by
  `day`, never by UTC.**

## Enums

- `tx.kind` (Realm `transferType`): `0` expense, `1` transfer, `2` income.
- `account.kind`: `0` debit, `1` credit, `2` custom (funds/stock/crypto).
  `financesType` (custom only, Realm): `0` fund, `2` crypto/stock, `3` other.
- `accountLog.kind`: `0` manual adjustment (user corrected the balance),
  `1` transaction effect (create/edit/delete of a `Tx`), `2` initial/imported
  snapshot (opening balance and the Realm `AccountBalanceChangeLog` rows).
- `budget.period` (Realm `t_data.rawValue`): `0` daily, `1` weekly
  (Mon start), `2` biweekly, `3` monthly (calendar month), `4` quarterly,
  `5` yearly, `6` custom (`periodDays`).
- `budget.scope`: `bill` (whole ledger), `category`, `subcategory`; `refId`
  points at the corresponding id.
- `budget.categoryMode` (Realm): `0` off, `1` category budget, `2` bill-level
  total. `rolloverMode`: `0` none, `1` accumulate leftovers.
- `status`: `0` active, `1` soft-deleted (kept for fidelity, filtered out of
  default views and all sums).
- Period windows are computed in the user timezone; monthly = calendar month.

## SQLite tables (backend internal)

    settings(key TEXT PK, value TEXT)
    bills(id TEXT PK, name, icon, color, sorted REAL, status INT)
    categories(id TEXT PK, bill_id, name, is_income INT, icon, color, sorted REAL, status INT)
    subcategories(id TEXT PK, category_id, name, sorted REAL, status INT)
    accounts(id TEXT PK, kind INT, name, icon, color, currency,
             credit_limit INT, liability INT, balance INT,
             finances_type INT, code TEXT,
             in_assets INT, hidden INT, sorted REAL, status INT)
    account_groups(name TEXT PK, account_ids TEXT /*json array*/, sorted REAL)
    account_logs(id TEXT PK, account_id TEXT, ts_ms INT, day TEXT,
                 kind INT, delta INT, balance_after INT,
                 currency TEXT, note TEXT, tx_id TEXT)   -- index (account_id, ts_ms)
    transactions(id TEXT PK, bill_id, ts_ms INT, day TEXT,
                 category_id TEXT, subcategory_id TEXT,
                 kind INT, is_income INT,
                 amount INT, currency TEXT,
                 original_cost INT, original_currency TEXT,
                 account_id TEXT, to_account_id TEXT, to_amount INT,
                 label TEXT, remark TEXT,
                 ignored INT, ignore_budget INT, ignore_expend INT,
                 has_image INT, status INT, created_at TEXT, modified_at TEXT)
    budgets(id TEXT PK, scope TEXT, ref_id TEXT, period INT, period_days INT,
            value INT, currency TEXT, category_mode INT, rollover_mode INT,
            fixed_amount INT, should_summary INT, start_date TEXT, status INT)
    recurring(id TEXT PK, name, kind INT, amount INT, currency TEXT,
              category_id TEXT, subcategory_id TEXT, account_id TEXT,
              remark TEXT, period INT, period_days INT,
              next_date TEXT, end_date TEXT, status INT)
    currencies(code TEXT PK, symbol, name, country, rate REAL /*units per USD*/, in_use INT)

Settings keys: `systemCurrency` (USD), `tz` (+03:00), `nickname`, `billId`
(active ledger), `firstRunDone`.

Account balance maintenance: on create/patch/delete the daemon adjusts the
account(s) `balance` by `±original_cost` (income/expense) and
`-original_cost`/`+to_amount` (transfer). Import sets balances from Realm
`cacheAmount`/`cacheTotalValue` snapshots and then **replays** the same rule is
NOT applied (balances are snapshots, like the original app).

Account change log (`account_logs`, shown on the account card): every balance
move leaves exactly one row per affected account, written inside the same lock
as the balance write, so `balance_after` of the newest row always equals
`accounts.balance`.

- `delta` is **signed** minor units (negative = money left the account);
  `balance_after` is the balance right after the change.
- `kind=1` for transaction effects. Creating a Tx logs its delta, deleting or
  editing one logs the compensating delta first (note prefixed `Reverted · `)
  and then the new effect. `tx_id` carries the transaction id; the note reads
  e.g. `Expense · Food & Drink`, `Income · Salary`, `Transfer out · <account>`,
  `Transfer in · <account>`.
- `kind=0` for manual corrections: `POST /api/accounts/{id}/adjust`, and also a
  `PUT /api/accounts/{id}` that carries a different `balance`.
- `kind=2` for snapshots: one `open:<accountId>` "Opening balance" row per
  account (written by the importer and on account creation, so a fresh card is
  never empty) plus the imported Realm `AccountBalanceChangeLog` rows. Realm
  keeps the magnitude in `amount` and the direction in `transactionType`
  (`-1` out, `+1` in), so the importer signs `delta` from `transactionType`.
  Those imported rows carry `balance_after` verbatim from
  `balanceAfterChange` — in the original backup that field is `0`, so do not
  render it for imported rows.
- The bundle exporter emits `account_logs` back as `AccountBalanceChangeLog`
  (major units, ISO dates, `transactionType` from the sign of `delta`), minus
  the synthetic `open:` rows which the importer regenerates from the balance.
  Realm has no field for *why* a balance moved, so a round-trip lands every
  row as `kind=2`.
- The importer wipes `account_logs` together with the rest, so re-import and
  `POST /api/reset` never duplicate history.

## REST API (127.0.0.1:21990, JSON everywhere)

Envelope: objects directly; errors `{"error":"..."}` with 4xx/5xx.

    GET  /api/health                    -> {"ok":true,"version":"...","imported":bool}
    GET  /api/bootstrap                 -> {settings, currencies[], groups[], accounts[],
                                            bills[], categories[], subcategories[],
                                            wallets:{system,totalMinor,incomeMinor,expenseMinor,
                                                     byCurrency{code:minor}}}
    GET  /api/overview?date=YYYY-MM-DD  -> {date, expenseMinor, incomeMinor,
                                            items:[Tx]}
    GET  /api/calendar?month=YYYY-MM    -> {month, days:[{day,expenseMinor,incomeMinor,count}]}
    GET  /api/tx?from=YYYY-MM-DD&to=&account=&category=&kind=&q=&limit=&offset=
                                        -> {total, items:[Tx]}
    POST /api/tx                        body Tx (no id)      -> Tx
    PUT  /api/tx/{id}                   body Tx (partial ok) -> Tx
    DELETE /api/tx/{id}                 soft delete
    GET  /api/accounts / POST /api/accounts
    PUT/DELETE /api/accounts/{id}
    GET  /api/accounts/{id}              -> Account
    GET  /api/accounts/{id}/logs?limit=N -> {accountId, currency, items:[AccountLog]}
                                           newest first, limit default 100, max 500
    POST /api/accounts/{id}/adjust       body {newBalance|delta, note}
                                        -> {account: Account, log: AccountLog}
    GET  /api/categories                -> [{..category, subcategories:[..]}]
    POST /api/categories, PUT/DELETE /api/categories/{id}
    POST /api/subcategories, PUT/DELETE /api/subcategories/{id}
    GET  /api/budgets                   -> [Budget]
    GET  /api/budgets/status?at=YYYY-MM-DD -> [{budget, spentMinor, leftMinor, windowStart, windowEnd}]
    PUT  /api/budgets/{id}              body partial Budget
    POST /api/budgets
    GET  /api/stats?from=&to=&group=category|subcategory|day|month|account
                                        -> [{key,label,color,icon,expenseMinor,incomeMinor,count}]
    GET  /api/recurring / POST/PUT/DELETE
    POST /api/recurring/run             materialize due (up to today)
    GET  /api/export/bundle             -> budget-bundle.json (download, same format as import)
    GET  /api/export/csv                -> CSV
    POST /api/import/bundle  {path}     -> {counts}
    POST /api/import/csv     {path,mode}

`Tx` JSON: `{id, tsMs, day, kind, isIncome, amount, currency, originalCost,
originalCurrency, accountId, toAccountId, toAmount, categoryId, subcategoryId,
label, remark, ignored, ignoreBudget, ignoreExpend, status, createdAt,
modifiedAt}` — `amount*` fields are minor units.

`AccountLog` JSON: `{id, tsMs, day, kind, delta, balanceAfter, currency, note,
txId}` — `delta`/`balanceAfter` are minor units, `delta` signed. `txId` is `""`
for manual and opening rows.

## Bundle format (`budget-ut/bundle1`)

`tools/realm-export/export.js` output: `{format, exportedAt, source, objects:{ClassName:[row]}}`
with original Realm field names (snake_case as in Realm), object links as
compound-key strings, `data` blobs base64. The importer also accepts a
re-exported bundle (round-trip identical). CSV columns:

    date,type,category,subcategory,account,toAccount,label,amount,currency,originalCost,originalCurrency,remark

`type` ∈ expense|income|transfer. Amounts in **major** units (human readable).

## Icon mapping (Realm `iconName` -> QML)

DisplayInfo icons are iOS SF-Symbol-ish names (`daily_0`, `business_9`,
`House Renew_0`, `icon_28`, `Cash`, `USDT`…). The UI maps unknown names to a
stable hash color+glyph; known families map by prefix:
`daily_N`/`icon_N`/`business_N` -> glyph set N mod len. Accounts: `Cash` ->
cash glyph, `icon_add_account_N` -> bank glyph tinted by account color.
