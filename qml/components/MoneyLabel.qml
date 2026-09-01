import QtQuick 2.4
import "../theme"
import "../store"

Text {
    id: root
    property int minor: 0
    property string currency: ""
    property bool colored: true
    property bool showSign: false
    property bool isIncome: false

    text: AppState.formatMoney(minor, currency, showSign)
    font.pixelSize: Theme.fontBody
    font.bold: true
    color: {
        if (!colored) return Theme.textPrimary;
        if (isIncome || (minor > 0 && showSign)) return Theme.income;
        if (minor < 0 || (!isIncome && minor > 0)) return Theme.expense;
        return Theme.textPrimary;
    }
}
