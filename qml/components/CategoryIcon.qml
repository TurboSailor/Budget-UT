import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"

Item {
    id: root
    property string categoryId: ""
    property string iconName: ""
    property string label: ""
    property color customColor: "transparent"
    property real size: units.gu(5)

    width: size
    height: size

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: size / 2
        color: {
            if (customColor !== "transparent" && customColor !== "#00000000") return customColor;
            return AppState.categoryColor(categoryId, Theme.primary);
        }

        Text {
            anchors.centerIn: parent
            text: {
                var c = AppState.categoryById(categoryId);
                return AppState.categoryGlyph(iconName || (c ? c.icon : ""), label || (c ? c.name : ""));
            }
            font.pixelSize: Math.max(units.dp(16), root.size * 0.45)
            color: "#1A1A1A"
        }
    }
}
