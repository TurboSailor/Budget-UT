import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"
import "../pages"

// Dev harness: instantiates the screens without Main.qml so a single page can
// be type-checked in isolation.
//   qmlscene qml/dev/check.qml            -> all
//   qmlscene qml/dev/check.qml -- home    -> one screen (env CHECK_ONLY also works)
MainView {
    id: harness
    applicationName: "budget.turbosailor"
    width: units.gu(45)
    height: units.gu(75)
    backgroundColor: Theme.background

    property string only: ""

    OverviewPage {
        anchors.fill: parent
        visible: harness.only === "" || harness.only === "home"
        onQuickAddRequested: console.log("harness: quickAdd", category ? category.name : "?")
        onCategoryEditRequested: console.log("harness: categoryEdit")
        onCategoryCreateRequested: console.log("harness: categoryCreate", income)
        onStatsRequested: console.log("harness: stats")
        onSettingsRequested: console.log("harness: settings")
        onEditTxRequested: sheet.open(tx)
    }

    CalendarPage {
        anchors.fill: parent
        visible: harness.only === "calendar"
        onEditTxRequested: sheet.open(tx)
    }

    BudgetPage {
        anchors.fill: parent
        visible: harness.only === "budget"
    }

    AccountsPage {
        anchors.fill: parent
        visible: harness.only === "accounts"
    }

    StatsPage {
        anchors.fill: parent
        visible: harness.only === "stats"
    }

    EditTxSheet {
        id: sheet
        anchors.fill: parent
        z: 100
    }

    MonthNavigator {
        id: navProbe
        visible: false
        month: "2026-09"
    }

    Component.onCompleted: {
        AppState.reload()
        // Exercise the pieces that only run on interaction.
        console.log("harness: month short =", navProbe.title())
        navProbe.longNames = true
        console.log("harness: month long  =", navProbe.title())
        console.log("harness: next month  =", navProbe.shift("2026-12", 1))
        console.log("harness: prev month  =", navProbe.shift("2026-01", -1))
        console.log("harness: money       =", AppState.formatMoney(335000000, "RUB"),
                    "|", AppState.formatSigned(37000, "RUB", 0),
                    "|", AppState.formatSigned(100000, "USD", 2))
        console.log("harness: OK")
    }
}
