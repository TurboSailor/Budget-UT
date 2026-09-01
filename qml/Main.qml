import QtQuick 2.4
import Ubuntu.Components 1.3
import "theme"
import "store"
import "components"
import "pages"

MainView {
    id: mainView
    objectName: "mainView"
    applicationName: "budget.turbosailor"
    automaticOrientation: true
    anchorToKeyboard: true

    width: units.gu(45)
    height: units.gu(75)
    backgroundColor: Theme.background

    // Connection retry / banner
    Rectangle {
        id: errorBanner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: units.gu(4)
        color: "#FEE2E2"
        visible: !AppState.connected && AppState.lastError.length > 0
        z: 10

        Text {
            anchors.centerIn: parent
            text: "Connecting to budget daemon..."
            font.pixelSize: Theme.fontSub
            color: Theme.expense
        }
    }

    // Main content area
    Item {
        anchors.top: errorBanner.visible ? errorBanner.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomNav.top

        OverviewPage {
            anchors.fill: parent
            visible: AppState.activeTab === 0
            onEditTxRequested: editSheet.open(tx)
            onSettingsRequested: AppState.activeTab = 5
        }

        CalendarPage {
            anchors.fill: parent
            visible: AppState.activeTab === 1
            onEditTxRequested: editSheet.open(tx)
        }

        BudgetPage {
            anchors.fill: parent
            visible: AppState.activeTab === 2
        }

        AccountsPage {
            anchors.fill: parent
            visible: AppState.activeTab === 3
        }

        StatsPage {
            anchors.fill: parent
            visible: AppState.activeTab === 4
        }

        SettingsPage {
            anchors.fill: parent
            visible: AppState.activeTab === 5
        }
    }

    // Bottom Navigation Bar
    BottomNav {
        id: bottomNav
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        currentTab: AppState.activeTab
        onTabSelected: AppState.activeTab = index
        onAddClicked: editSheet.open(null)
    }

    // Modal Edit/Create Transaction Sheet
    EditTxSheet {
        id: editSheet
        anchors.fill: parent
        z: 100
    }

    // Initial load + periodic poll
    Component.onCompleted: {
        AppState.reload();
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: {
            if (!AppState.connected) {
                AppState.reload();
            }
        }
    }
}
