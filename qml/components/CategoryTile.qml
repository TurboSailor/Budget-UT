import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"

// A tappable category tile for the Home grid.
// Tap  -> record a transaction in that category.
// Hold -> edit the category itself.
// `isAdd` turns the tile into the dashed "new category" placeholder.
Item {
    id: root
    property var category: null
    property bool isAdd: false
    signal picked()
    signal edit()

    width: units.gu(9)
    height: units.gu(11)

    Column {
        anchors.centerIn: parent
        spacing: units.gu(0.6)

        Rectangle {
            id: bubble
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(6.4)
            height: units.gu(6.4)
            radius: width / 2
            scale: tileMouse.pressed ? 0.93 : 1.0
            Behavior on scale { NumberAnimation { duration: 90 } }

            color: {
                if (root.isAdd) return "transparent"
                if (!root.category) return Theme.divider
                var h = root.category.color || ""
                if (h === "") return Theme.primary
                return h.indexOf("#") === 0 ? h : "#" + h
            }
            border.color: root.isAdd ? Theme.textMuted : "transparent"
            border.width: root.isAdd ? 1 : 0

            Text {
                anchors.centerIn: parent
                text: root.isAdd ? "+"
                                 : AppState.categoryGlyph(root.category ? root.category.icon : "",
                                                          root.category ? root.category.name : "")
                font.pixelSize: root.isAdd ? units.dp(26) : units.dp(24)
                color: root.isAdd ? Theme.textMuted : "#1A1A1A"
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width - units.gu(0.8)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            text: root.isAdd ? "New" : (root.category ? root.category.name : "")
            font.pixelSize: Theme.fontMicro
            color: Theme.textSecondary
        }
    }

    MouseArea {
        id: tileMouse
        anchors.fill: parent
        onClicked: root.picked()
        onPressAndHold: {
            if (!root.isAdd) root.edit()
        }
    }
}
