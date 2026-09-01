import QtQuick 2.4
import Ubuntu.Components 1.3
import "theme"
import "store"
import "components"
import "pages"
import "js/api.js" as Api

MainView {
    id: mainView
    objectName: "mainView"
    applicationName: "budget.turbosailor"
    automaticOrientation: true
    anchorToKeyboard: true

    width: units.gu(45)
    height: units.gu(75)
    backgroundColor: Theme.background

    // Locked until the PIN is verified (when one is configured).
    property bool locked: false

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

    Item {
        anchors.top: errorBanner.visible ? errorBanner.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomNav.top

        OverviewPage {
            anchors.fill: parent
            visible: AppState.activeTab === 0
            onEditTxRequested: editSheet.open(tx)
            onSettingsRequested: mainView.openSettings(0)
            onStatsRequested: AppState.activeTab = 4
            onQuickAddRequested: editSheet.openFor(category)
            onCategoryEditRequested: mainView.openSettings(3)
            onCategoryCreateRequested: mainView.openSettings(3)
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
            id: settingsPage
            anchors.fill: parent
            visible: AppState.activeTab === 5
        }
    }

    BottomNav {
        id: bottomNav
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        currentTab: AppState.activeTab
        onTabSelected: {
            // Leaving Settings resets any open manager sub-screen.
            if (AppState.activeTab === 5 && index !== 5) settingsPage.managerIndex = 0
            AppState.activeTab = index
        }
        onAddClicked: editSheet.open(null)
    }

    EditTxSheet {
        id: editSheet
        anchors.fill: parent
        z: 100
    }

    // PIN gate: covers everything, including the nav bar.
    PinLock {
        id: pinLock
        anchors.fill: parent
        z: 200
        mode: "verify"
        visible: mainView.locked
        onUnlocked: mainView.locked = false
    }

    function openSettings(manager) {
        settingsPage.managerIndex = manager
        AppState.activeTab = 5
    }

    Component.onCompleted: {
        AppState.reload()
        Api.get("/api/security", function(err, res) {
            if (!err && res && res.pinEnabled) mainView.locked = true
        })
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: {
            if (!AppState.connected) AppState.reload()
        }
    }
}
