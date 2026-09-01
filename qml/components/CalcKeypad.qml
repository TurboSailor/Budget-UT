import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"

// Four-function calculator keypad with its own amount display.
// Shared by the transaction sheet and the account balance editor so both
// accept "1200+340" style input.
Item {
    id: root

    property string currencySymbol: "$"
    property color valueColor: Theme.textPrimary
    property bool showDisplay: true
    property string saveGlyph: "✓"
    signal saveRequested()

    // calculator state
    property string entry: "0"
    property real acc: 0
    property string pendingOp: ""
    property bool entryDirty: false

    implicitHeight: (showDisplay ? display.height : 0) + pad.height

    Item {
        id: display
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.showDisplay ? units.gu(7) : 0
        visible: root.showDisplay

        Text {
            anchors.left: parent.left
            anchors.leftMargin: units.gu(2)
            anchors.bottom: amountText.bottom
            text: root.currencySymbol
            font.pixelSize: Theme.fontTitle
            font.bold: true
            color: Theme.textSecondary
        }

        // pending expression, e.g. "1200 +"
        Text {
            anchors.right: parent.right
            anchors.rightMargin: units.gu(2)
            anchors.top: parent.top
            text: root.pendingOp !== "" ? (root.trimNum(root.acc) + " " + root.opGlyph(root.pendingOp)) : ""
            font.pixelSize: Theme.fontSub
            color: Theme.textMuted
        }

        Text {
            id: amountText
            anchors.right: parent.right
            anchors.rightMargin: units.gu(2)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: units.gu(0.5)
            text: root.entry
            font.pixelSize: Theme.fontHero
            font.bold: true
            color: root.valueColor
        }
    }

    Rectangle {
        id: pad
        anchors.top: display.bottom
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
                    { t: "1",  a: "d" }, { t: "2", a: "d" }, { t: "3", a: "d" },  { t: "÷", a: "op", op: "/" }, { t: "⌫", a: "bk" },
                    { t: "4",  a: "d" }, { t: "5", a: "d" }, { t: "6", a: "d" },  { t: "×", a: "op", op: "*" }, { t: "C",  a: "clr" },
                    { t: "7",  a: "d" }, { t: "8", a: "d" }, { t: "9", a: "d" },  { t: "−", a: "op", op: "-" }, { t: "=",  a: "eq" },
                    { t: ".",  a: "d" }, { t: "0", a: "d" }, { t: "00", a: "d00" }, { t: "+", a: "op", op: "+" }, { t: "save", a: "save" }
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
                        text: modelData.a === "save" ? root.saveGlyph : modelData.t
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
                            else if (a === "save") root.saveRequested()
                        }
                    }
                }
            }
        }
    }

    // ---- calculator ----

    function appendDigit(d) {
        if (d === "." && entry.indexOf(".") >= 0) return
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

    // Chained input evaluates left to right, like a phone calculator.
    function applyOperator(op) {
        var cur = parseFloat(entry) || 0
        if (pendingOp !== "" && entryDirty) acc = compute(acc, pendingOp, cur)
        else if (pendingOp === "") acc = cur
        pendingOp = op
        entry = "0"
        entryDirty = false
    }

    function equals() {
        if (pendingOp === "") return
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

    // value() folds any pending operation so callers always read a number.
    function value() {
        var cur = parseFloat(entry) || 0
        if (pendingOp !== "" && entryDirty) return compute(acc, pendingOp, cur)
        if (pendingOp !== "") return acc
        return cur
    }

    function valueMinor() {
        return Math.round(value() * 100)
    }

    // Seed the display, e.g. when editing an existing amount.
    function setValue(v) {
        acc = 0
        pendingOp = ""
        entry = trimNum(v)
        entryDirty = true
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
}
