import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"
import "../pages"
import "../pages/managers"

// Reusable layout auditor: builds ONE screen at a given width and reports every
// visible item that leaves the viewport or ends up with a negative width.
//
// Method notes (each learned from a wrong result):
//  1) One screen per process — instantiating them all at once crashes qmlscene
//     under the offscreen platform.
//  2) Positioners (Row/Column) lay out during polish, so the screen gets settle
//     ticks before being measured; measuring in the creating frame reports
//     garbage negative positions.
//  3) A blocking bootstrap fetch fills AppState so lists hold real data.
//
// Usage: a generated wrapper sets `target` and `screenWidthGu`, e.g.
//   LayoutAudit { target: "category-new"; screenWidthGu: 32 }
MainView {
    id: audit
    applicationName: "budget.turbosailor"

    property bool fetchData: true
    property real screenWidthGu: 45
    property real screenHeightGu: 100
    property int problems: 0
    property int step: 0

    width: units.gu(screenWidthGu)
    height: units.gu(screenHeightGu)
    backgroundColor: Theme.background

    Loader { id: host; anchors.fill: parent }

    Component { id: cHome;      OverviewPage    { } }
    Component { id: cBudget;    BudgetPage      { } }
    Component { id: cCards;     AccountsPage    { } }
    Component { id: cStats;     StatsPage       { } }
    Component { id: cCalendar;  CalendarPage    { } }
    Component { id: cSettings;  SettingsPage    { } }
    Component { id: cCategory;  CategoryManager { } }
    Component { id: cLedger;    LedgerManager   { } }
    Component { id: cAccount;   AccountManager  { } }
    Component { id: cCurrency;  CurrencyManager { } }
    Component { id: cTx;        EditTxSheet     { } }
    Component { id: cAcctSheet; AccountSheet    { } }
    Component { id: cDate;      DatePickerSheet { } }
    Component { id: cPin;       PinLock         { } }

    function componentFor(t) {
        if (t === "home") return cHome
        if (t === "budget") return cBudget
        if (t === "cards") return cCards
        if (t === "stats") return cStats
        if (t === "calendar") return cCalendar
        if (t === "settings") return cSettings
        if (t === "category" || t === "category-new" || t === "category-sub") return cCategory
        if (t === "ledger") return cLedger
        if (t === "account") return cAccount
        if (t === "currency") return cCurrency
        if (t === "tx") return cTx
        if (t === "acctsheet" || t === "acctsheet-balance" || t === "acctsheet-edit") return cAcctSheet
        if (t === "date") return cDate
        if (t === "pin") return cPin
        return cHome
    }

    function activate() {
        var s = host.item
        if (!s) return
        var t = audit.target
        if (t === "category-new") s.openCreateCategory(false)
        else if (t === "category-sub") s.openCreateSub(AppState.categories.length > 0 ? AppState.categories[0].id : "x")
        else if (t === "tx") s.open(null)
        else if (t === "date") s.open(AppState.todayDay)
        else if (t.indexOf("acctsheet") === 0 && AppState.accounts.length > 0) {
            s.open(AppState.accounts[0])
            if (t === "acctsheet-balance") s.startBalanceEdit()
            if (t === "acctsheet-edit") s.startDetailsEdit()
        }
    }

    function syncBootstrap() {
        var x = new XMLHttpRequest()
        x.open("GET", "http://127.0.0.1:21990/api/bootstrap", false) // blocking on purpose
        x.send()
        if (x.status !== 200) { console.log("(bootstrap unavailable: " + x.status + ")"); return }
        var d = JSON.parse(x.responseText)
        AppState.settings = d.settings || {}
        AppState.currencies = d.currencies || []
        AppState.groups = d.groups || []
        AppState.accounts = d.accounts || []
        AppState.bills = d.bills || []
        AppState.categories = d.categories || []
        AppState.subcategories = d.subcategories || []
        AppState.budgets = d.budgets || []
        AppState.wallets = d.wallets || AppState.wallets
        AppState.connected = true
        AppState.ready = true
    }

    function describe(it) {
        var t = it.toString().split("(")[0].split("_QMLTYPE")[0].split("_QML_")[0]
        var extra = ""
        if (it.text !== undefined && ("" + it.text).length > 0)
            extra = " text=\"" + ("" + it.text).substring(0, 24) + "\""
        else if (it.placeholderText !== undefined && ("" + it.placeholderText).length > 0)
            extra = " ph=\"" + ("" + it.placeholderText).substring(0, 24) + "\""
        return t + extra
    }

    function walk(item, depth) {
        if (depth > 15) return
        for (var i = 0; i < item.children.length; i++) {
            var c = item.children[i]
            if (c.visible === false) continue
            if (c.width !== undefined) {
                if (c.width < -0.5) {
                    audit.problems++
                    console.log("  NEGATIVE-WIDTH " + describe(c) + " w=" + c.width.toFixed(1))
                } else if (c.width > 0) {
                    var p = c.mapToItem(audit, 0, 0)
                    var right = p.x + c.width
                    if (p.x < -0.5 || right > audit.width + 0.5) {
                        audit.problems++
                        console.log("  OVERFLOW " + describe(c)
                                    + " x=" + p.x.toFixed(1) + " w=" + c.width.toFixed(1)
                                    + " right=" + right.toFixed(1) + " screen=" + audit.width)
                    }
                }
            }
            walk(c, depth + 1)
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            audit.step++
            if (audit.step === 1) {
                host.sourceComponent = audit.componentFor(audit.target)
            } else if (audit.step === 2) {
                audit.activate()
            } else if (audit.step === 4) {
                console.log("--- " + audit.target + " @" + audit.screenWidthGu + "gu"
                            + " (" + audit.width + "x" + audit.height + "px)"
                            + " itemW=" + (host.item ? host.item.width : -1) + " ---")
                walk(host, 0)
                console.log("RESULT " + audit.target + " @" + audit.screenWidthGu + "gu: "
                            + audit.problems + " problem(s)")
                Qt.quit()
            }
        }
    }

    Component.onCompleted: {
        if (audit.fetchData) syncBootstrap()
    }
}
