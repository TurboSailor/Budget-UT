#!/usr/bin/env bash
# Tail the daemon log (own file) + the user journal for the app.
set -euo pipefail
ADB=(adb)
[ -n "${ADB_SERIAL:-}" ] && ADB=(adb -s "$ADB_SERIAL")
echo "== budgetd.log =="
"${ADB[@]}" shell "tail -n 100 \${XDG_CACHE_HOME:-\$HOME/.cache}/budget-ut/budgetd.log 2>/dev/null || echo '(no log)'" | tr -d '\r'
echo
echo "== journalctl --user (budget) =="
"${ADB[@]}" shell "journalctl --user -n 50 --no-pager 2>/dev/null | grep -i -E 'budget|qml' || true" | tr -d '\r'
