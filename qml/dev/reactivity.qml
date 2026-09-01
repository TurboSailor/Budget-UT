import QtQuick 2.4
import "../store"

// Does a Repeater bound to `model: someFunction()` rebuild when the singleton
// data behind that function changes? Compared against `model: someProperty`.
//
// Two gotchas baked in:
//  - root is a plain Item: with MainView the process dies before any timer fires;
//  - a Repeater without a delegate instantiates nothing and always reports 0.
Item {
    id: probe
    width: 100
    height: 100

    property var explicitModel: []
    property int step: 0

    function derived() {
        // same shape as AccountsPage.buildGroupedSections(): plain JS objects
        var out = []
        var src = AppState.accounts || []
        for (var i = 0; i < src.length; i++) out.push({ name: src[i].name })
        return out
    }

    Repeater { id: implicitRep; model: probe.derived();     delegate: Item { width: 1; height: 1 } }
    Repeater { id: explicitRep; model: probe.explicitModel; delegate: Item { width: 1; height: 1 } }

    function seed(n) {
        var a = []
        for (var i = 0; i < n; i++) a.push({ id: "" + i, name: "acct" + i })
        AppState.accounts = a
        probe.explicitModel = probe.derived()
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            probe.step++
            if (probe.step === 1) {
                seed(2)
            } else if (probe.step === 2) {
                console.log("after seed(2):  implicit=" + implicitRep.count + " explicit=" + explicitRep.count)
            } else if (probe.step === 3) {
                // mutate the store exactly like AppState.reload() does
                seed(5)
            } else if (probe.step === 4) {
                console.log("after seed(5):  implicit=" + implicitRep.count + " explicit=" + explicitRep.count)
                console.log(implicitRep.count === 5
                            ? "VERDICT: function-model DID re-evaluate"
                            : "VERDICT: function-model went STALE (stuck at " + implicitRep.count + ")")
                console.log(explicitRep.count === 5
                            ? "VERDICT: property-model updated correctly"
                            : "VERDICT: property-model FAILED (" + explicitRep.count + ")")
                Qt.quit()
            }
        }
    }
}
