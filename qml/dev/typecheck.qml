import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../components"

// Type-resolution probe: if a component in ../components were not visible,
// qmlscene fails at load with "Type <X> unavailable" instead of printing OK.
MainView {
    applicationName: "budget.turbosailor"
    width: units.gu(45)
    height: units.gu(75)

    AccountSheet    { id: acctSheet;  anchors.fill: parent }
    DatePickerSheet { id: datePick;   anchors.fill: parent }
    CalcKeypad      { id: pad;        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right }
    CategoryTile    { id: tile;       visible: false }
    MonthNavigator  { id: nav;        visible: false; month: "2026-09" }

    Component.onCompleted: {
        console.log("typecheck: AccountSheet    ->", acctSheet.toString().split("(")[0], "mode=" + acctSheet.mode)
        console.log("typecheck: DatePickerSheet ->", datePick.toString().split("(")[0], "day=" + datePick.day)
        console.log("typecheck: CalcKeypad      ->", pad.toString().split("(")[0])
        console.log("typecheck: CategoryTile    ->", tile.toString().split("(")[0])
        console.log("typecheck: MonthNavigator  ->", nav.toString().split("(")[0], nav.title())

        // exercise the shared keypad: 1200 + 340 =
        pad.appendDigit("1"); pad.appendDigit("2"); pad.appendDigit("0"); pad.appendDigit("0")
        pad.applyOperator("+")
        pad.appendDigit("3"); pad.appendDigit("4"); pad.appendDigit("0")
        console.log("typecheck: 1200+340 value =", pad.value(), "minor =", pad.valueMinor())

        // date picker helpers
        console.log("typecheck: yesterday      =", datePick.dayWithOffset(-1))
        console.log("typecheck: cells in month =", datePick.buildCells().length)
        console.log("typecheck: OK")
    }
}
