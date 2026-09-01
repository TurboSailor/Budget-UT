import QtQuick 2.4
import Ubuntu.Components 1.3
import "../theme"
import "../js/api.js" as Api

// PinLock — full-bleed PIN overlay.
//
// mode "verify": asks for the stored PIN and checks it against
//                POST /api/security/verify, emitting unlocked() on success.
// mode "set":    asks twice for a fresh PIN and emits pinSet(pin) once both
//                entries agree. Persisting it is the caller's job
//                (POST /api/security/pin).
//
// The component paints an opaque background, so it can be dropped on top of
// the whole window (z above everything) and nothing leaks through.
Item {
    id: root

    property string mode: "verify"          // "verify" | "set"
    property bool cancellable: true
    property string subtitle: ""

    signal unlocked()
    signal pinSet(string pin)
    signal cancelled()

    // --- internal state ---
    property string entry: ""
    property string firstPin: ""
    property bool confirming: false
    property string errorText: ""
    property bool busy: false
    property real shakeOffset: 0

    readonly property int pinLength: 4

    readonly property string headline: mode === "set"
        ? (confirming ? "Repeat the new PIN" : "Choose a 4-digit PIN")
        : "Enter your PIN"

    function reset() {
        entry = "";
        firstPin = "";
        confirming = false;
        errorText = "";
        busy = false;
    }

    onVisibleChanged: {
        if (visible) {
            reset();
        }
    }

    function pressDigit(d) {
        if (busy) return;
        if (entry.length >= pinLength) return;
        errorText = "";
        entry = entry + d;
        if (entry.length === pinLength) {
            submitTimer.restart();
        }
    }

    function pressBackspace() {
        if (busy) return;
        errorText = "";
        if (entry.length > 0) {
            entry = entry.substring(0, entry.length - 1);
        }
    }

    function fail(msg) {
        errorText = msg;
        entry = "";
        busy = false;
        shakeAnim.restart();
    }

    function submit() {
        if (entry.length !== pinLength) return;
        if (mode === "set") {
            if (!confirming) {
                firstPin = entry;
                entry = "";
                confirming = true;
                return;
            }
            if (entry !== firstPin) {
                firstPin = "";
                confirming = false;
                fail("PINs did not match — start again");
                return;
            }
            var chosen = entry;
            entry = "";
            confirming = false;
            firstPin = "";
            root.pinSet(chosen);
            return;
        }
        busy = true;
        var candidate = entry;
        Api.post("/api/security/verify", { pin: candidate }, function(err, res) {
            root.busy = false;
            if (err) {
                root.fail(err);
                return;
            }
            if (res && res.ok) {
                root.entry = "";
                root.unlocked();
            } else {
                root.fail("Wrong PIN");
            }
        });
    }

    Timer {
        id: submitTimer
        interval: 120
        repeat: false
        onTriggered: root.submit()
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeOffset"; to: units.gu(1.4); duration: 45 }
        NumberAnimation { target: root; property: "shakeOffset"; to: -units.gu(1.4); duration: 90 }
        NumberAnimation { target: root; property: "shakeOffset"; to: units.gu(0.8); duration: 90 }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 60 }
    }

    // Opaque backdrop; also swallows every stray touch.
    Rectangle {
        anchors.fill: parent
        color: Theme.background

        MouseArea {
            anchors.fill: parent
            onClicked: { /* swallow */ }
        }
    }

    Column {
        id: body
        anchors.centerIn: parent
        width: parent.width - units.gu(6)
        spacing: units.gu(1.2)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "🔒"
            font.pixelSize: units.dp(34)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.headline
            font.pixelSize: Theme.fontHeading
            font.bold: true
            color: Theme.textPrimary
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.subtitle
            visible: root.subtitle.length > 0
            font.pixelSize: Theme.fontSub
            color: Theme.textSecondary
        }

        Item { width: units.gu(1); height: units.gu(1) }

        // Dots indicator
        Row {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.shakeOffset
            spacing: units.gu(2)

            Repeater {
                model: root.pinLength
                delegate: Rectangle {
                    width: units.gu(2)
                    height: units.gu(2)
                    radius: width / 2
                    color: index < root.entry.length ? Theme.textPrimary : "transparent"
                    border.color: root.errorText.length > 0 ? Theme.expense : Theme.textMuted
                    border.width: units.dp(1)
                }
            }
        }

        Item { width: units.gu(1); height: units.gu(0.5) }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.busy ? "Checking…" : root.errorText
            visible: root.busy || root.errorText.length > 0
            font.pixelSize: Theme.fontSub
            color: root.busy ? Theme.textSecondary : Theme.expense
        }

        Item { width: units.gu(1); height: units.gu(1.5) }

        // Keypad
        Grid {
            id: pad
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 3
            spacing: units.gu(1.5)

            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "cancel", "0", "back"]

                delegate: Item {
                    id: keyCell

                    property string keyId: modelData
                    property bool isDigit: keyId !== "cancel" && keyId !== "back"
                    property bool isEnabled: isDigit || keyId === "back" || root.cancellable

                    width: units.gu(9)
                    height: units.gu(8)

                    Rectangle {
                        anchors.centerIn: parent
                        width: units.gu(7.5)
                        height: units.gu(7.5)
                        radius: width / 2
                        opacity: keyCell.isEnabled ? 1.0 : 0.3
                        color: !keyCell.isDigit
                            ? "transparent"
                            : (keyArea.pressed ? Theme.divider : Theme.cardBackground)
                        border.color: keyCell.isDigit ? Theme.cardBorder : "transparent"
                        border.width: units.dp(1)

                        Text {
                            anchors.centerIn: parent
                            text: keyCell.keyId === "back"
                                ? "⌫"
                                : (keyCell.keyId === "cancel" ? "Cancel" : keyCell.keyId)
                            font.pixelSize: keyCell.isDigit ? units.dp(24) : Theme.fontBody
                            font.bold: keyCell.isDigit
                            color: keyCell.isDigit ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            id: keyArea
                            anchors.fill: parent
                            enabled: keyCell.isEnabled
                            onClicked: {
                                if (keyCell.isDigit) {
                                    root.pressDigit(keyCell.keyId);
                                } else if (keyCell.keyId === "back") {
                                    root.pressBackspace();
                                } else {
                                    root.reset();
                                    root.cancelled();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
