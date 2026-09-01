import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"

// Month stepper with a FIXED footprint: the label sits in a reserved,
// centre-aligned box so that "May" and "September" produce the same width and
// the ▶ arrow can never be pushed off the screen edge.
Item {
    id: root
    property string month: ""          // "YYYY-MM"
    property bool longNames: false     // "September" vs "Sep"
    signal stepped(int delta)          // -1 / +1

    // arrow + label + arrow, all fixed
    readonly property real arrowSize: units.gu(4)
    readonly property real labelWidth: longNames ? units.gu(15) : units.gu(10)

    implicitWidth: arrowSize * 2 + labelWidth
    implicitHeight: units.gu(4)
    width: implicitWidth
    height: implicitHeight

    Row {
        anchors.fill: parent

        Rectangle {
            width: root.arrowSize
            height: parent.height
            radius: units.gu(0.8)
            color: prevMouse.pressed ? Theme.divider : "transparent"

            Text {
                anchors.centerIn: parent
                text: "◀"
                font.pixelSize: units.dp(15)
                color: Theme.textSecondary
            }
            MouseArea {
                id: prevMouse
                anchors.fill: parent
                onClicked: root.stepped(-1)
            }
        }

        Item {
            width: root.labelWidth
            height: parent.height

            Text {
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.title()
                font.pixelSize: Theme.fontSub
                font.bold: true
                color: Theme.textPrimary
            }
        }

        Rectangle {
            width: root.arrowSize
            height: parent.height
            radius: units.gu(0.8)
            color: nextMouse.pressed ? Theme.divider : "transparent"

            Text {
                anchors.centerIn: parent
                text: "▶"
                font.pixelSize: units.dp(15)
                color: Theme.textSecondary
            }
            MouseArea {
                id: nextMouse
                anchors.fill: parent
                onClicked: root.stepped(1)
            }
        }
    }

    function title() {
        if (!month) return ""
        var parts = month.split("-")
        if (parts.length < 2) return month
        var shortN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var longN = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        var idx = parseInt(parts[1], 10) - 1
        var names = longNames ? longN : shortN
        var name = (idx >= 0 && idx < 12) ? names[idx] : parts[1]
        return name + " " + parts[0]
    }

    // Shared month arithmetic so callers don't reimplement it.
    function shift(m, delta) {
        var parts = m.split("-")
        var y = parseInt(parts[0], 10)
        var mm = parseInt(parts[1], 10) + delta
        if (mm < 1) { mm = 12; y-- }
        if (mm > 12) { mm = 1; y++ }
        return y + "-" + (mm < 10 ? "0" + mm : "" + mm)
    }
}
