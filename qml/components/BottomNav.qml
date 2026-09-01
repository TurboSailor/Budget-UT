import QtQuick 2.4
import "../theme"
import "../store"

Item {
    id: root
    property int currentTab: AppState.activeTab
    signal tabSelected(int index)
    signal addClicked()

    height: 60
    implicitWidth: 360

    // White background card with top shadow/border
    Rectangle {
        anchors.fill: parent
        color: Theme.cardBackground
        border.color: Theme.cardBorder
        border.width: 1

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.cardBorder
        }
    }

    Row {
        anchors.fill: parent

        // 0: Home
        NavItem {
            width: parent.width / 5
            iconText: "🏠"
            label: "Home"
            active: root.currentTab === 0
            onClicked: root.tabSelected(0)
        }

        // 1: Calendar
        NavItem {
            width: parent.width / 5
            iconText: "📅"
            label: "Calendar"
            active: root.currentTab === 1
            onClicked: root.tabSelected(1)
        }

        // Center space for FAB
        Item {
            width: parent.width / 5
            height: parent.height
        }

        // 2: Budget
        NavItem {
            width: parent.width / 5
            iconText: "🎯"
            label: "Budget"
            active: root.currentTab === 2
            onClicked: root.tabSelected(2)
        }

        // 3: Accounts
        NavItem {
            width: parent.width / 5
            iconText: "💳"
            label: "Cards"
            active: root.currentTab === 3
            onClicked: root.tabSelected(3)
        }
    }

    // Center floating FAB [+]
    Rectangle {
        id: fab
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        width: 52
        height: 52
        radius: 26
        color: Theme.primary
        border.color: Theme.primaryDark
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: 28
            font.bold: true
            color: Theme.primaryText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.addClicked()
        }
    }

    component NavItem: Rectangle {
        property string iconText: ""
        property string label: ""
        property bool active: false
        signal clicked()

        height: parent.height
        color: "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: iconText
                font.pixelSize: 18
                opacity: active ? 1.0 : 0.4
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: label
                font.pixelSize: 10
                font.bold: active
                color: active ? Theme.textPrimary : Theme.textSecondary
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }
}
