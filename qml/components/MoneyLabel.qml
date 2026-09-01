import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"

// Renders a money amount. The source data keeps every transaction amount
// positive, so the sign and the colour come from `kind`, never from the number:
//   kind 0 = expense (-, red), 1 = transfer (no sign, purple), 2 = income (+, green)
//   kind -1 = plain balance: only a genuinely negative value shows a minus.
Text {
    id: root
    property int minor: 0
    property string currency: ""
    property int kind: -1
    property bool colored: true

    text: kind === -1 ? AppState.formatMoney(minor, currency)
                      : AppState.formatSigned(minor, currency, kind)
    font.pixelSize: Theme.fontBody
    font.bold: true
    color: {
        if (!colored) return minor < 0 && kind === -1 ? Theme.expense : Theme.textPrimary;
        if (kind === -1) return minor < 0 ? Theme.expense : Theme.textPrimary;
        return AppState.colorForKind(kind);
    }
}
