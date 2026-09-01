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

    // Record state
    property int kind: 0 // 0: expense, 1: transfer, 2: income
    property string selectedCatId: ""
    property string selectedSubId: ""
    property string selectedAccId: ""
    property string selectedToAccId: ""
    property string txDay: AppState.todayDay
    property string labelText: ""
    property string remarkText: ""

    // Calculator state: the source app lets you type "1200+340" straight into
    // the amount field, so the pad is a real four-function calculator.
    property string entry: "0"      // number currently being typed
    property real acc: 0            // accumulated left-hand value
    property string pendingOp: ""   // "+", "-", "*", "/"
    property bool entryDirty: false // has a digit been typed into `entry` yet

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
        height: Math.min(parent.height * 0.94, units.gu(80))
        radius: Theme.radiusCard
        color: Theme.cardBackground

        // Header: Cancel / Title / Save
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
                            color: active ? AppState.colorForKind(modelData.idx) : Theme.textSecondary
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

        // Amount display + live expression
        Rectangle {
            id: amountBox
            anchors.top: kindBar.bottom
            anchors.topMargin: units.gu(1)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: units.gu(2)
            height: units.gu(8)
            color: "transparent"

            Text {
                id: curSym
                anchors.left: parent.left
                anchors.bottom: mainAmount.bottom
                text: AppState.currencySymbol(root.accountCurrency())
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.textSecondary
            }

            // Pending expression, e.g. "1200 +"
            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                text: root.pendingOp !== "" ? (root.trimNum(root.acc) + " " + root.opGlyph(root.pendingOp)) : ""
                font.pixelSize: Theme.fontSub
                color: Theme.textMuted
            }

            Text {
                id: mainAmount
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: units.gu(0.5)
                text: root.entry
                font.pixelSize: Theme.fontHero
                font.bold: true
                color: AppState.colorForKind(root.kind)
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

                Item { width: 1; height: units.gu(0.2) }

                // From account
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

                // Transfer target
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
                                        color: root.selectedToAccId === modelData.id ? Theme.transfer : "#F3F4F6"
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

                // Categories
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

                // Subcategories
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

                // Note + date
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

                // Delete (edit mode only)
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

        // Calculator numpad
        Rectangle {
            id: numpad
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: units.gu(26)
            color: "#F8F9FB"
            border.color: Theme.cardBorder
            border.width: 1

            Grid {
                anchors.fill: parent
                anchors.margins: units.gu(0.6)
                columns: 5
                spacing: units.gu(0.6)

                Repeater {
                    model: [
                        { t: "1",  a: "d" }, { t: "2", a: "d" }, { t: "3", a: "d" }, { t: "÷", a: "op", op: "/" }, { t: "⌫", a: "bk" },
                        { t: "4",  a: "d" }, { t: "5", a: "d" }, { t: "6", a: "d" }, { t: "×", a: "op", op: "*" }, { t: "C",  a: "clr" },
                        { t: "7",  a: "d" }, { t: "8", a: "d" }, { t: "9", a: "d" }, { t: "−", a: "op", op: "-" }, { t: "=",  a: "eq" },
                        { t: ".",  a: "d" }, { t: "0", a: "d" }, { t: "00", a: "d00" }, { t: "+", a: "op", op: "+" }, { t: "✓", a: "save" }
                    ]
                    delegate: Rectangle {
                        property bool isOp: modelData.a === "op" || modelData.a === "eq"
                        property bool isSave: modelData.a === "save"
                        width: (parent.width - units.gu(2.4)) / 5
                        height: (parent.height - units.gu(1.8)) / 4
                        radius: units.gu(0.8)
                        color: {
                            if (keyMouse.pressed) return "#D1D5DB"
                            if (isSave) return Theme.primary
                            if (isOp) return "#EEF0F5"
                            if (modelData.a === "bk" || modelData.a === "clr") return "#E5E7EB"
                            return "#FFFFFF"
                        }
                        border.color: "#E5E7EB"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.t
                            font.pixelSize: modelData.t === "00" ? units.dp(17) : units.dp(21)
                            font.bold: true
                            color: isOp ? Theme.accent : Theme.textPrimary
                        }

                        MouseArea {
                            id: keyMouse
                            anchors.fill: parent
                            onClicked: {
                                var a = modelData.a
                                if (a === "d") root.appendDigit(modelData.t)
                                else if (a === "d00") { root.appendDigit("0"); root.appendDigit("0") }
                                else if (a === "op") root.applyOperator(modelData.op)
                                else if (a === "eq") root.equals()
                                else if (a === "bk") root.backspace()
                                else if (a === "clr") root.clearAll()
                                else if (a === "save") root.save()
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- calculator ----

    function appendDigit(d) {
        if (d === "." && entry.indexOf(".") >= 0) return
        // A fresh operand (start, or right after an operator) replaces the "0".
        if (!entryDirty && d !== ".") {
            entry = d
            entryDirty = true
            return
        }
        if (entry === "0" && d !== ".") {
            entry = d
            entryDirty = true
            return
        }
        var dot = entry.indexOf(".")
        if (dot >= 0 && entry.length - dot > 2) return // max 2 decimals
        if (entry.replace(".", "").length >= 12) return
        entry += d
        entryDirty = true
    }

    function backspace() {
        if (entry.length <= 1) {
            entry = "0"
            entryDirty = false
            return
        }
        entry = entry.substring(0, entry.length - 1)
    }

    function clearAll() {
        entry = "0"
        acc = 0
        pendingOp = ""
        entryDirty = false
    }

    function compute(a, op, b) {
        switch (op) {
        case "+": return a + b
        case "-": return a - b
        case "*": return a * b
        case "/": return b === 0 ? a : a / b
        }
        return b
    }

    // Chained input evaluates left to right, like a phone calculator:
    // 100 + 50 × 2 = 300.
    function applyOperator(op) {
        var cur = parseFloat(entry) || 0
        if (pendingOp !== "" && entryDirty) {
            acc = compute(acc, pendingOp, cur)
        } else if (pendingOp === "") {
            acc = cur
        }
        pendingOp = op
        entry = "0"
        entryDirty = false
    }

    function equals() {
        if (pendingOp === "") return
        // Operator pressed but no second operand typed: keep the left side.
        if (!entryDirty) {
            pendingOp = ""
            entry = trimNum(acc)
            return
        }
        acc = compute(acc, pendingOp, parseFloat(entry) || 0)
        pendingOp = ""
        entry = trimNum(acc)
        entryDirty = false
    }

    // resolve() folds any pending operation so Save always stores a number.
    function resolve() {
        var cur = parseFloat(entry) || 0
        if (pendingOp !== "" && entryDirty) return compute(acc, pendingOp, cur)
        if (pendingOp !== "") return acc
        return cur
    }

    function trimNum(v) {
        var r = Math.round(v * 100) / 100
        return (r % 1 === 0) ? ("" + r) : r.toFixed(2)
    }

    function opGlyph(op) {
        if (op === "*") return "×"
        if (op === "/") return "÷"
        if (op === "-") return "−"
        return "+"
    }

    // ---- data helpers ----

    function filteredCategories() {
        var out = []
        var wantIncome = (kind === 2)
        for (var i = 0; i < AppState.categories.length; i++) {
            var c = AppState.categories[i]
            if (c.status === 0 && Boolean(c.isIncome) === wantIncome) out.push(c)
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
        selectedCatId = list.length > 0 ? list[0].id : ""
    }

    function open(existing) {
        tx = existing || null
        clearAll()
        if (tx) {
            kind = tx.kind
            entry = trimNum((tx.originalCost || tx.amount) / 100)
            entryDirty = true
            selectedCatId = tx.categoryId || ""
            selectedSubId = tx.subcategoryId || ""
            selectedAccId = tx.accountId || ""
            selectedToAccId = tx.toAccountId || ""
            txDay = tx.day || AppState.todayDay
            labelText = tx.label || ""
            remarkText = tx.remark || ""
        } else {
            kind = 0
            selectedSubId = ""
            selectedToAccId = ""
            txDay = AppState.selectedDay || AppState.todayDay
            labelText = ""
            remarkText = ""
            if (AppState.accounts.length > 0) selectedAccId = AppState.accounts[0].id
            autoPickCat()
        }
        visibleSheet = true
    }

    function close() {
        visibleSheet = false
        root.closed()
    }

    function save() {
        var val = resolve()
        if (!(val > 0)) {
            close()
            return
        }
        var minor = Math.round(val * 100)
        var cur = accountCurrency()
        var sysCur = AppState.wallets.system || "USD"
        // rates are "units per USD": account -> USD -> system currency
        var sysMinor = Math.round(minor / AppState.rateOf(cur) * AppState.rateOf(sysCur))

        var payload = {
            kind: kind,
            isIncome: (kind === 2),
            amount: sysMinor,
            currency: sysCur,
            originalCost: minor,
            originalCurrency: cur,
            accountId: selectedAccId || null,
            toAccountId: (kind === 1 ? selectedToAccId : null) || null,
            toAmount: (kind === 1 ? minor : 0),
            categoryId: (kind !== 1 ? selectedCatId : null) || null,
            subcategoryId: (kind !== 1 && selectedSubId ? selectedSubId : null),
            label: labelText,
            remark: remarkText,
            day: txDay
        }

        var done = function(err, res) {
            if (!err) {
                AppState.reload()
                AppState.txChanged()
                root.saved()
            }
            close()
        }

        if (tx && tx.id) Api.put("/api/tx/" + tx.id, payload, done)
        else Api.post("/api/tx", payload, done)
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
