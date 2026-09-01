# Budget-UT

Open-source budget & spending tracker for Ubuntu Touch — clone of the iOS
[Budget App](https://apps.apple.com/us/app/budget-app-spending-tracker/id1525179720)
(Budget planner, spending tracker, finance tracker). All "premium" features are
free, as it should be.

## Architecture

Go backend + QML (Lomiri) frontend, mirroring the proven pattern of other
Go-based UT apps (`garpun-ut`):

```
backend/              Go (module: budgetd)
  cmd/budgetd/        daemon: SQLite storage + JSON API on 127.0.0.1
  cmd/budgetctl/      diagnostic CLI
  internal/           store / api / import / model
qml/                  Ubuntu.Components 1.3 UI
click/                manifest.json, apparmor, desktop, run.sh, icon
scripts/              build.sh (click packed on phone), deploy.sh, logs.sh
tools/realm-export/   Budget.realm -> bundle JSON converter (host-side)
Makefile              backend / qml / pkg / click / deploy / logs
```

The daemon is started by `run.sh` (own session, survives UI restarts); the UI
talks to it over `http://127.0.0.1:21990`.

## Data / backup format

The original iOS app stores data in a Realm database (`Budget.realm`).
Restoring that backup happens in two steps:

1. `tools/realm-export/` converts `Budget.realm` (any backup of it) into a
   portable `budget-bundle.json` (lossless for everything the app uses).
2. The app imports the bundle (Settings → Import) or ships with it preloaded.

Export: full-fidelity `budget-bundle.json` + CSV (same as the iOS app's
export). Binary Realm *writing* is not implementable from Go without shipping
C++ realm-core; the iOS app itself imports only CSV, so JSON-bundle + CSV
cover the real interop surface.

Money is stored in minor units (cents) per currency, like the original.

## Features

- Accounts: cash / debit / credit / custom (funds, stocks, crypto) with
  groups, assets toggle, hidden accounts
- Categories & sub-categories with icons/colors
- Transactions: expense / income / transfer, remarks, soft-delete
- Budgets: per bill, per category, per sub-category; weekly / monthly /
  custom periods; rollover
- Calendar view of day-to-day spending
- Stats & charts (per category / day / month / account)
- Recurring transactions & subscriptions
- Import (bundle JSON, CSV) / export (bundle JSON, CSV)

## Build

```
make click    # cross-compile arm64, assemble build/pkg, pack click on phone
make deploy   # install on device + verify apparmor registration
make logs     # journalctl tail for the app
```

Requires: go, adb, phone connected (`adb devices`).
