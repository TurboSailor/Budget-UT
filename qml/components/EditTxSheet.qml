import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../store"
import "../js/api.js" as Api

Rectangle {
    id: root
    property var tx: null // null for new, tx object for edit
    property bool visibleSheet: false
    signal closed()
    signal saved()

    // Working state
    property int kind: 0 // 0: expense, 1: transfer, 2: income
    property string amountStr: "0"
    property string selectedCatId: ""
    property string selectedSubId: ""
    property string selectedAccId: ""
    property string selectedToAccId: ""
    property string txDay: AppState.todayDay
    property string labelText: ""
    property string remarkText: ""

    color: "transparent"
    visible: visibleSheet

    // Dim background
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.visibleSheet ? 0.45 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Slide-up panel
    Rectangle {
        id: panel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.min(parent.height * 0.94, units.gu(78))
        radius: Theme.radiusCard
        color: Theme.cardBackground

        // Header: Close / Title / Save
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: units.gu(6)
            color: "transparent"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: units.gu(2)
                anchors.verticalCenter: parent.verticalCenter
                text: "Cancel"
                font.pixelSize: Theme.fontBody
                color: Theme.textSecondary
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -units.gu(1)
                    onClicked: root.close()
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.tx ? "Edit Record" : "New Record"
                font.pixelSize: Theme.fontHeading
                font.bold: true
                color: Theme.textPrimary
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: units.gu(2)
                anchors.verticalCenter: parent.verticalCenter
                text: "Save"
                font.pixelSize: Theme.fontHeading
                font.bold: true
                color: Theme.accent
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -units.gu(1)
                    onClicked: root.save()
                }
            }
        }

        // Kind switcher: Expense | Income | Transfer
        Rectangle {
            id: kindBar
            anchors.top: header.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - units.gu(4)
            height: units.gu(4.5)
            radius: height / 2
            color: "#EEF0F5"

            Row {
                anchors.fill: parent
                Repeater {
                    model: [
                        { idx: 0, text: "Expense" },
                        { idx: 2, text: "Income" },
                        { idx: 1, text: "Transfer" }
                    ]
                    delegate: Rectangle {
                        property bool active: root.kind === modelData.idx
                        width: parent.width / 3
                        height: parent.height
                        radius: height / 2
                        color: active ? Theme.cardBackground : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.text
                            font.pixelSize: Theme.fontSub
                            font.bold: active
                            color: active ? Theme.textPrimary : Theme.textSecondary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.kind = modelData.idx
                                if (modelData.idx !== 1) root.autoPickCat()
                            }
                        }
                    }
                }
            }
        }

        // Amount display
        Rectangle {
            id: amountBox
            anchors.top: kindBar.bottom
            anchors.topMargin: units.gu(1)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: units.gu(2)
            height: units.gu(6)
            color: "transparent"

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: AppState.currencySymbol(root.accountCurrency())
                font.pixelSize: Theme.fontTitleLarge
                font.bold: true
                color: Theme.textSecondary
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.amountStr
                font.pixelSize: Theme.fontHero
                font.bold: true
                color: root.kind === 2 ? Theme.income : (root.kind === 1 ? Theme.transfer : Theme.expense)
            }
        }

        // Scrollable selection body
        Flickable {
            id: scroll
            anchors.top: amountBox.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: numpad.top
            anchors.margins: units.gu(1)
            contentHeight: bodyCol.height + units.gu(2)
            clip: true

            Column {
                id: bodyCol
                width: parent.width
                spacing: units.gu(1.2)

                // Accounts row
                Item { width: 1; height: units.gu(0.2) }
                Row {
                    Item { width: units.gu(1); height: 1 }
                    Text {
                        text: root.kind === 1 ? "From Account:" : "Account:"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }
                }

                Row {
                    Item { width: units.gu(1); height: 1 }
                    Flow {
                        width: bodyCol.width - units.gu(2)
                        spacing: units.gu(0.8)
                        Repeater {
                            model: AppState.accounts
                            delegate: Rectangle {
                                height: units.gu(3.6)
                                width: accLabel.width + units.gu(2.4)
                                radius: height / 2
                                color: root.selectedAccId === modelData.id ? Theme.primary : "#F3F4F6"
                                border.color: root.selectedAccId === modelData.id ? Theme.primaryDark : "transparent"
                                Text {
                                    id: accLabel
                                    anchors.centerIn: parent
                                    text: modelData.name + " (" + modelData.currency + ")"
                                    font.pixelSize: Theme.fontSub
                                    font.bold: root.selectedAccId === modelData.id
                                    color: Theme.textPrimary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.selectedAccId = modelData.id
                                }
                            }
                        }
                    }
                }

                // For transfer: To Account
                Item {
                    width: parent.width
                    height: toCol.height
                    visible: root.kind === 1
                    Column {
                        id: toCol
                        width: parent.width
                        spacing: units.gu(0.6)
                        Row {
                            Item { width: units.gu(1); height: 1 }
                            Text {
                                text: "To Account:"
                                font.pixelSize: Theme.fontSub
                                color: Theme.textSecondary
                            }
                        }
                        Row {
                            Item { width: units.gu(1); height: 1 }
                            Flow {
                                width: bodyCol.width - units.gu(2)
                                spacing: units.gu(0.8)
                                Repeater {
                                    model: AppState.accounts
                                    delegate: Rectangle {
                                        height: units.gu(3.6)
                                        width: toAccLabel.width + units.gu(2.4)
                                        radius: height / 2
                                        color: root.selectedToAccId === modelData.id ? Theme.accent : "#F3F4F6"
                                        Text {
                                            id: toAccLabel
                                            anchors.centerIn: parent
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSub
                                            font.bold: root.selectedToAccId === modelData.id
                                            color: root.selectedToAccId === modelData.id ? "#FFFFFF" : Theme.textPrimary
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.selectedToAccId = modelData.id
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Categories (for expense / income)
                Item {
                    width: parent.width
                    height: catCol.height
                    visible: root.kind !== 1
                    Column {
                        id: catCol
                        width: parent.width
                        spacing: units.gu(0.8)
                        Row {
                            Item { width: units.gu(1); height: 1 }
                            Text {
                                text: "Category:"
                                font.pixelSize: Theme.fontSub
                                color: Theme.textSecondary
                            }
                        }
                        Row {
                            Item { width: units.gu(1); height: 1 }
                            Grid {
                                width: bodyCol.width - units.gu(2)
                                columns: 4
                                spacing: units.gu(1)
                                Repeater {
                                    model: root.filteredCategories()
                                    delegate: Column {
                                        width: (bodyCol.width - units.gu(5)) / 4
                                        spacing: units.gu(0.4)
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: units.gu(5.6)
                                            height: units.gu(5.6)
                                            radius: width / 2
                                            color: root.selectedCatId === modelData.id ? (modelData.color ? (modelData.color.indexOf("#") === 0 ? modelData.color : "#" + modelData.color) : Theme.primary) : "#F3F4F6"
                                            border.color: root.selectedCatId === modelData.id ? Theme.textPrimary : "transparent"
                                            border.width: root.selectedCatId === modelData.id ? 2 : 0

                                            Text {
                                                anchors.centerIn: parent
                                                text: AppState.categoryGlyph(modelData.icon, modelData.name)
                                                font.pixelSize: units.dp(22)
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    root.selectedCatId = modelData.id
                                                    root.selectedSubId = ""
                                                }
                                            }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.name
                                            font.pixelSize: Theme.fontMicro
                                            elide: Text.ElideRight
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            color: root.selectedCatId === modelData.id ? Theme.textPrimary : Theme.textSecondary
                                            font.bold: root.selectedCatId === modelData.id
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Subcategories (chips)
                Item {
                    width: parent.width
                    height: subCol.height
                    visible: root.kind !== 1 && root.currentSubcategories().length > 0
                    Column {
                        id: subCol
                        width: parent.width
                        spacing: units.gu(0.6)
                        Row {
                            Item { width: units.gu(1); height: 1 }
                            Text {
                                text: "Subcategory:"
                                font.pixelSize: Theme.fontSub
                                color: Theme.textSecondary
                            }
                        }
                        Row {
                            Item { width: units.gu(1); height: 1 }
                            Flow {
                                width: bodyCol.width - units.gu(2)
                                spacing: units.gu(0.8)
                                Repeater {
                                    model: root.currentSubcategories()
                                    delegate: Rectangle {
                                        height: units.gu(3.2)
                                        width: subLabel.width + units.gu(2)
                                        radius: height / 2
                                        color: root.selectedSubId === modelData.id ? Theme.primary : "#F3F4F6"
                                        Text {
                                            id: subLabel
                                            anchors.centerIn: parent
                                            text: modelData.name
                                            font.pixelSize: Theme.fontMicro
                                            font.bold: root.selectedSubId === modelData.id
                                            color: Theme.textPrimary
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.selectedSubId = (root.selectedSubId === modelData.id ? "" : modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Note / Remark row
                Row {
                    width: parent.width - units.gu(2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    TextField {
                        id: noteInput
                        width: parent.width - units.gu(12)
                        placeholderText: "Note / Merchant..."
                        text: root.labelText
                        onTextChanged: root.labelText = text
                    }

                    Rectangle {
                        width: units.gu(11)
                        height: noteInput.height
                        radius: Theme.radiusSmall
                        color: "#F3F4F6"
                        Text {
                            anchors.centerIn: parent
                            text: root.txDay === AppState.todayDay ? "Today" : root.txDay.substring(5)
                            font.pixelSize: Theme.fontSub
                            color: Theme.textPrimary
                        }
                    }
                }

                // Delete button for editing
                Rectangle {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: units.gu(4.5)
                    radius: Theme.radiusSmall
                    color: "#FEE2E2"
                    visible: root.tx !== null

                    Text {
                        anchors.centerIn: parent
                        text: "Delete Transaction"
                        color: Theme.expense
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.deleteTx()
                    }
                }
            }
        }

        // Custom Numpad at bottom
        Rectangle {
            id: numpad
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: units.gu(23)
            color: "#F8F9FB"
            border.color: Theme.cardBorder
            border.width: 1

            Grid {
                anchors.fill: parent
                anchors.margins: units.gu(0.6)
                columns: 4
                spacing: units.gu(0.6)

                Repeater {
                    model: [
                        { t: "1", c: "#FFFFFF", act: "" },
                        { t: "2", c: "#FFFFFF", act: "" },
                        { t: "3", c: "#FFFFFF", act: "" },
                        { t: "⌫", c: "#E5E7EB", act: "bk" },
                        { t: "4", c: "#FFFFFF", act: "" },
                        { t: "5", c: "#FFFFFF", act: "" },
                        { t: "6", c: "#FFFFFF", act: "" },
                        { t: "C", c: "#E5E7EB", act: "c" },
                        { t: "7", c: "#FFFFFF", act: "" },
                        { t: "8", c: "#FFFFFF", act: "" },
                        { t: "9", c: "#FFFFFF", act: "" },
                        { t: "✓", c: Theme.primary, act: "save" },
                        { t: "", c: "#F8F9FB", act: "" },
                        { t: "0", c: "#FFFFFF", act: "" },
                        { t: ".", c: "#FFFFFF", act: "" },
                        { t: "00", c: "#FFFFFF", act: "00" }
                    ]
                    delegate: Rectangle {
                        width: (parent.width - units.gu(1.8)) / 4
                        height: (parent.height - units.gu(1.8)) / 4
                        radius: units.gu(0.8)
                        color: keyMouse.pressed ? "#D1D5DB" : modelData.c
                        border.color: "#E5E7EB"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.t
                            font.pixelSize: units.dp(22)
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        MouseArea {
                            id: keyMouse
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.act === "bk") root.backspace()
                                else if (modelData.act === "c") root.amountStr = "0"
                                else if (modelData.act === "save") root.save()
                                else if (modelData.act === "00") { root.appendDigit("0"); root.appendDigit("0") }
                                else if (modelData.t) root.appendDigit(modelData.t)
                            }
                        }
                    }
                }
            }
        }
    }

    function appendDigit(d) {
        if (amountStr === "0" && d !== ".") {
            amountStr = d
            return
        }
        if (d === "." && amountStr.indexOf(".") >= 0) return
        var dot = amountStr.indexOf(".")
        if (dot >= 0 && amountStr.length - dot > 2) return
        if (amountStr.length > 9) return
        amountStr += d
    }

    function backspace() {
        if (amountStr.length <= 1) {
            amountStr = "0"
            return
        }
        amountStr = amountStr.substring(0, amountStr.length - 1)
    }

    function filteredCategories() {
        var out = []
        var wantIncome = (kind === 2)
        for (var i = 0; i < AppState.categories.length; i++) {
            var c = AppState.categories[i]
            if (c.status === 0 && Boolean(c.isIncome) === wantIncome) {
                out.push(c)
            }
        }
        return out
    }

    function currentSubcategories() {
        var c = AppState.categoryById(selectedCatId)
        return (c && c.subcategories) ? c.subcategories : []
    }

    function accountCurrency() {
        var a = AppState.accountById(selectedAccId)
        return a ? a.currency : (AppState.wallets.system || "USD")
    }

    function autoPickCat() {
        var list = filteredCategories()
        if (list.length > 0) {
            selectedCatId = list[0].id
        }
    }

    function open(existing) {
        tx = existing || null
        if (tx) {
            kind = tx.kind
            amountStr = ((tx.originalCost || tx.amount) / 100).toFixed(2)
            selectedCatId = tx.categoryId || ""
            selectedSubId = tx.subcategoryId || ""
            selectedAccId = tx.accountId || ""
            selectedToAccId = tx.toAccountId || ""
            txDay = tx.day || AppState.todayDay
            labelText = tx.label || ""
            remarkText = tx.remark || ""
        } else {
            kind = 0
            amountStr = "0"
            selectedSubId = ""
            selectedToAccId = ""
            txDay = AppState.selectedDay || AppState.todayDay
            labelText = ""
            remarkText = ""
            if (AppState.accounts.length > 0) {
                selectedAccId = AppState.accounts[0].id
            }
            autoPickCat()
        }
        visibleSheet = true
    }

    function close() {
        visibleSheet = false
        root.closed()
    }

    function save() {
        var val = parseFloat(amountStr) || 0
        if (val <= 0) {
            close()
            return
        }
        var minor = Math.round(val * 100)
        var cur = accountCurrency()
        var sysCur = AppState.wallets.system || "USD"

        var rate = 1.0
        for (var i = 0; i < AppState.currencies.length; i++) {
            if (AppState.currencies[i].code === cur) {
                rate = AppState.currencies[i].rate || 1.0
                break
            }
        }
        var sysMinor = Math.round(minor / rate)

        var payload = {
            kind: kind,
            isIncome: (kind === 2),
            amount: sysMinor,
            currency: sysCur,
            originalCost: minor,
            originalCurrency: cur,
            accountId: selectedAccId || null,
            toAccountId: (kind === 1 ? selectedToAccId : null) || null,
            categoryId: (kind !== 1 ? selectedCatId : null) || null,
            subcategoryId: (kind !== 1 && selectedSubId ? selectedSubId : null),
            label: labelText,
            remark: remarkText,
            day: txDay
        }

        if (tx && tx.id) {
            Api.put("/api/tx/" + tx.id, payload, function(err, res) {
                if (!err) {
                    AppState.reload()
                    AppState.txChanged()
                    root.saved()
                }
                close()
            })
        } else {
            Api.post("/api/tx", payload, function(err, res) {
                if (!err) {
                    AppState.reload()
                    AppState.txChanged()
                    root.saved()
                }
                close()
            })
        }
    }

    function deleteTx() {
        if (!tx || !tx.id) return
        Api.del("/api/tx/" + tx.id, function(err, res) {
            if (!err) {
                AppState.reload()
                AppState.txChanged()
                root.saved()
            }
            close()
        })
    }
}
