#!/usr/bin/env bash
# Host-side smoke test: builds budgetd, starts it against a clean temporary DB,
# seeds it from tools/realm-export/budget-bundle.json, probes REST endpoints.
set -euo pipefail

PORT=21991
TMPDIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMPDIR"
    pkill -f "budgetd.*$PORT" 2>/dev/null || true
}
trap cleanup EXIT

echo ">> building budgetd"
(cd backend && go build -o "$TMPDIR/budgetd" ./cmd/budgetd)

echo ">> starting daemon on :$PORT"
"$TMPDIR/budgetd" -db "$TMPDIR/test.db" -addr "127.0.0.1:$PORT" -seed tools/realm-export/budget-bundle.json >"$TMPDIR/budgetd.log" 2>&1 &

for _ in $(seq 1 30); do
    if curl -s "http://127.0.0.1:$PORT/api/health" 2>/dev/null | grep -q '"ok":true'; then
        break
    fi
    sleep 0.1
done

echo "== /api/health =="
curl -s "http://127.0.0.1:$PORT/api/health"
echo

echo "== /api/bootstrap (summary) =="
python3 -c '
import urllib.request, json
d = json.loads(urllib.request.urlopen("http://127.0.0.1:'"$PORT"'/api/bootstrap").read())
print("accounts:", len(d["accounts"]))
print("categories:", len(d["categories"]))
print("budgets:", len(d["budgets"]))
print("wallets:", d["wallets"])
'

echo "== /api/overview (2026-09-01) =="
python3 -c '
import urllib.request, json
d = json.loads(urllib.request.urlopen("http://127.0.0.1:'"$PORT"'/api/overview?date=2026-09-01").read())
print("date:", d["date"], "exp:", d["expenseMinor"], "inc:", d["incomeMinor"], "items:", len(d["items"]))
'

echo "== /api/stats (by category, full year) =="
python3 -c '
import urllib.request, json
rows = json.loads(urllib.request.urlopen("http://127.0.0.1:'"$PORT"'/api/stats?from=2025-06-01&to=2026-09-01&group=category").read())
for r in rows[:5]:
    print("%-20s exp=$%.2f inc=$%.2f (%d tx)" % (r["label"], r["expenseMinor"]/100, r["incomeMinor"]/100, r["count"]))
'

echo "== /api/budgets/status =="
python3 -c '
import urllib.request, json
rows = json.loads(urllib.request.urlopen("http://127.0.0.1:'"$PORT"'/api/budgets/status?at=2026-08-01").read())
for s in rows[:5]:
    b = s["budget"]
    print("scope=%s val=$%.2f spent=$%.2f left=$%.2f [%s..%s]" % (b["scope"], b["value"]/100, s["spentMinor"]/100, s["leftMinor"]/100, s["windowStart"], s["windowEnd"]))
'

echo "== POST /api/tx (create expense) =="
python3 -c '
import urllib.request, json
req = urllib.request.Request("http://127.0.0.1:'"$PORT"'/api/tx",
    data=b"{\"kind\":0,\"isIncome\":false,\"amount\":550,\"currency\":\"USD\",\"originalCost\":550,\"originalCurrency\":\"USD\",\"label\":\"Test Coffee\"}",
    headers={"Content-Type": "application/json"})
d = json.loads(urllib.request.urlopen(req).read())
print("created tx id:", d.get("id"), "day:", d.get("day"))
'

echo "== host-test OK =="
