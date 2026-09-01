import QtQuick 2.4
import Ubuntu.Components 1.3
import "../../theme"
import "../../store"
import "../../js/api.js" as Api

// CategoryManager — CRUD over /api/categories (+/{id}) and
// /api/subcategories (+/{id}). Categories come from AppState.categories, which
// already nests `subcategories`; every mutation re-bootstraps AppState.
Item {
    id: root

    property string statusMsg: ""
    property var expandedIds: ({})

    // category editor state
    property bool catEditorOpen: false
    property string catEditId: ""
    property string catEditName: ""
    property bool catEditIsIncome: false
    property string catEditColor: "#FEDB5A"
    property string catEditIcon: "daily_0"

    // subcategory editor state
    property bool subEditorOpen: false
    property string subEditId: ""
    property string subEditCategoryId: ""
    property string subEditName: ""

    readonly property var iconChoices: [
        "daily_0", "business_9", "House Renew_0", "icon_28", "Cash",
        "food", "transport", "home", "shopping", "fun",
        "health", "salary", "invest", "gift", "subscription"
    ]

    function hexColor(c, fallback) {
        if (!c || c.length === 0) return fallback;
        return c.indexOf("#") === 0 ? c : "#" + c;
    }

    function categoriesFor(isIncome) {
        var src = AppState.categories || [];
        var out = [];
        for (var i = 0; i < src.length; i++) {
            var c = src[i];
            if (c.status === 1) continue;
            if ((c.isIncome === true) !== isIncome) continue;
            out.push(c);
        }
        return out;
    }

    function activeSubs(cat) {
        var src = cat.subcategories || [];
        var out = [];
        for (var i = 0; i < src.length; i++) {
            if (src[i].status === 1) continue;
            out.push(src[i]);
        }
        return out;
    }

    function isExpanded(id) {
        return root.expandedIds[id] === true;
    }

    function toggleExpanded(id) {
        var next = {};
        for (var k in root.expandedIds) next[k] = root.expandedIds[k];
        next[id] = !(next[id] === true);
        root.expandedIds = next;
    }

    function reload() {
        AppState.reload();
    }

    // ---- category actions ----

    function openCreateCategory(isIncome) {
        root.catEditId = "";
        root.catEditName = "";
        root.catEditIsIncome = isIncome;
        root.catEditColor = Theme.categoryPalette[isIncome ? 6 : 0];
        root.catEditIcon = isIncome ? "salary" : "daily_0";
        root.catEditorOpen = true;
    }

    function openEditCategory(c) {
        root.catEditId = c.id;
        root.catEditName = c.name || "";
        root.catEditIsIncome = c.isIncome === true;
        root.catEditColor = root.hexColor(c.color, Theme.categoryPalette[0]);
        root.catEditIcon = c.icon || "daily_0";
        root.catEditorOpen = true;
    }

    function saveCategory() {
        var name = root.catEditName.trim();
        if (name.length === 0) {
            root.statusMsg = "Category name cannot be empty";
            return;
        }
        var body = {
            billId: (AppState.settings && AppState.settings.billId) ? AppState.settings.billId : "",
            name: name,
            isIncome: root.catEditIsIncome,
            icon: root.catEditIcon,
            color: root.catEditColor,
            sorted: 0,
            status: 0
        };
        var done = function(err) {
            if (err) {
                root.statusMsg = "Save failed: " + err;
                return;
            }
            root.catEditorOpen = false;
            root.statusMsg = "Category saved";
            AppState.reload();
        };
        if (root.catEditId.length > 0) {
            body.id = root.catEditId;
            Api.put("/api/categories/" + root.catEditId, body, done);
        } else {
            Api.post("/api/categories", body, done);
        }
    }

    function removeCategory(c) {
        Api.del("/api/categories/" + c.id, function(err) {
            if (err) {
                root.statusMsg = "Delete failed: " + err;
                return;
            }
            root.statusMsg = "Category deleted";
            AppState.reload();
        });
    }

    // ---- subcategory actions ----

    function openCreateSub(categoryId) {
        root.subEditId = "";
        root.subEditCategoryId = categoryId;
        root.subEditName = "";
        root.subEditorOpen = true;
    }

    function openEditSub(s) {
        root.subEditId = s.id;
        root.subEditCategoryId = s.categoryId;
        root.subEditName = s.name || "";
        root.subEditorOpen = true;
    }

    function saveSub() {
        var name = root.subEditName.trim();
        if (name.length === 0) {
            root.statusMsg = "Subcategory name cannot be empty";
            return;
        }
        var body = {
            categoryId: root.subEditCategoryId,
            name: name,
            sorted: 0,
            status: 0
        };
        var done = function(err) {
            if (err) {
                root.statusMsg = "Save failed: " + err;
                return;
            }
            root.subEditorOpen = false;
            root.statusMsg = "Subcategory saved";
            AppState.reload();
        };
        if (root.subEditId.length > 0) {
            body.id = root.subEditId;
            Api.put("/api/subcategories/" + root.subEditId, body, done);
        } else {
            Api.post("/api/subcategories", body, done);
        }
    }

    function removeSub(s) {
        Api.del("/api/subcategories/" + s.id, function(err) {
            if (err) {
                root.statusMsg = "Delete failed: " + err;
                return;
            }
            root.statusMsg = "Subcategory deleted";
            AppState.reload();
        });
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.height + units.gu(6)
        clip: true

        Column {
            id: col
            width: parent.width - units.gu(3)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: units.gu(1.2)

            Item { width: units.gu(1); height: units.gu(0.5) }

            Text {
                text: root.statusMsg
                width: parent.width
                wrapMode: Text.WordWrap
                visible: root.statusMsg.length > 0
                font.pixelSize: Theme.fontSub
                color: Theme.accent
            }

            Repeater {
                model: [false, true]

                delegate: Column {
                    id: group

                    property bool groupIncome: modelData

                    width: col.width
                    spacing: units.gu(1)

                    Item { width: units.gu(1); height: units.gu(0.5) }

                    // Anchored header: the title elides and the button keeps its
                    // place at the right edge on any screen width. The previous
                    // spacer arithmetic (parent.width - 22gu) pushed "+ Add" off
                    // screen as soon as the title was wider than the allowance.
                    Item {
                        width: parent.width
                        height: units.gu(4.5)

                        Text {
                            anchors.left: parent.left
                            anchors.right: groupAddBtn.left
                            anchors.rightMargin: units.gu(1)
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: group.groupIncome ? "Income categories" : "Expense categories"
                            font.pixelSize: Theme.fontHeading
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Rectangle {
                            id: groupAddBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(10)
                            height: units.gu(4)
                            radius: Theme.radiusSmall
                            color: groupAdd.pressed ? Theme.primaryDark : Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: "+ Add"
                                font.pixelSize: Theme.fontSub
                                font.bold: true
                                color: Theme.primaryText
                            }
                            MouseArea {
                                id: groupAdd
                                anchors.fill: parent
                                onClicked: root.openCreateCategory(group.groupIncome)
                            }
                        }
                    }

                    Repeater {
                        model: root.categoriesFor(group.groupIncome)

                        delegate: Rectangle {
                            id: catCard

                            property var cat: modelData
                            property var subs: root.activeSubs(modelData)
                            property bool expanded: root.isExpanded(modelData.id)

                            width: group.width
                            height: header.height + (expanded ? subList.height + units.gu(1.2) : 0)
                            radius: Theme.radiusCard
                            color: Theme.cardBackground
                            border.color: Theme.cardBorder
                            border.width: units.dp(1)
                            clip: true

                            MouseArea {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: units.gu(7)
                                onClicked: root.toggleExpanded(catCard.cat.id)
                            }

                            Row {
                                id: header
                                width: parent.width - units.gu(2.4)
                                height: units.gu(7)
                                x: units.gu(1.2)
                                spacing: units.gu(1.2)

                                Rectangle {
                                    width: units.gu(4.4)
                                    height: units.gu(4.4)
                                    radius: width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: AppState.categoryColor(catCard.cat.id, Theme.primary)

                                    Text {
                                        anchors.centerIn: parent
                                        text: AppState.categoryGlyph(catCard.cat.icon, catCard.cat.name)
                                        font.pixelSize: units.dp(18)
                                        color: Theme.textPrimary
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - units.gu(16.8)
                                    spacing: units.gu(0.3)

                                    Text {
                                        text: catCard.cat.name || "(unnamed)"
                                        width: parent.width
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontHeading
                                        font.bold: true
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: catCard.subs.length === 0
                                            ? "No subcategories — tap to add"
                                            : (catCard.subs.length + " subcategor" + (catCard.subs.length === 1 ? "y" : "ies")
                                               + (catCard.expanded ? " ▾" : " ▸"))
                                        width: parent.width
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontMicro
                                        color: Theme.textMuted
                                    }
                                }

                                Rectangle {
                                    width: units.gu(4.4)
                                    height: units.gu(4.4)
                                    radius: Theme.radiusSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: cEdit.pressed ? Theme.divider : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✎"
                                        font.pixelSize: units.dp(18)
                                        color: Theme.textSecondary
                                    }
                                    MouseArea {
                                        id: cEdit
                                        anchors.fill: parent
                                        onClicked: root.openEditCategory(catCard.cat)
                                    }
                                }

                                Rectangle {
                                    width: units.gu(4.4)
                                    height: units.gu(4.4)
                                    radius: Theme.radiusSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: cDel.pressed ? "#FEE2E2" : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🗑"
                                        font.pixelSize: units.dp(18)
                                        color: Theme.expense
                                    }
                                    MouseArea {
                                        id: cDel
                                        anchors.fill: parent
                                        onClicked: root.removeCategory(catCard.cat)
                                    }
                                }
                            }

                            Column {
                                id: subList
                                width: parent.width - units.gu(4.8)
                                x: units.gu(3.6)
                                y: header.height
                                visible: catCard.expanded
                                spacing: units.gu(0.4)

                                Repeater {
                                    model: catCard.subs

                                    delegate: Row {
                                        width: subList.width
                                        height: units.gu(4.4)
                                        spacing: units.gu(0.8)

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - units.gu(8.4)
                                            elide: Text.ElideRight
                                            text: "• " + (modelData.name || "(unnamed)")
                                            font.pixelSize: Theme.fontBody
                                            color: Theme.textSecondary
                                        }

                                        Rectangle {
                                            width: units.gu(3.6)
                                            height: units.gu(3.6)
                                            radius: Theme.radiusSmall
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: sEdit.pressed ? Theme.divider : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✎"
                                                font.pixelSize: units.dp(14)
                                                color: Theme.textSecondary
                                            }
                                            MouseArea {
                                                id: sEdit
                                                anchors.fill: parent
                                                onClicked: root.openEditSub(modelData)
                                            }
                                        }

                                        Rectangle {
                                            width: units.gu(3.6)
                                            height: units.gu(3.6)
                                            radius: Theme.radiusSmall
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: sDel.pressed ? "#FEE2E2" : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "🗑"
                                                font.pixelSize: units.dp(14)
                                                color: Theme.expense
                                            }
                                            MouseArea {
                                                id: sDel
                                                anchors.fill: parent
                                                onClicked: root.removeSub(modelData)
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: subList.width
                                    height: units.gu(4)
                                    radius: Theme.radiusSmall
                                    color: subAdd.pressed ? Theme.divider : "#F3F4F6"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+ Add subcategory"
                                        font.pixelSize: Theme.fontSub
                                        color: Theme.textSecondary
                                    }
                                    MouseArea {
                                        id: subAdd
                                        anchors.fill: parent
                                        onClicked: root.openCreateSub(catCard.cat.id)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: group.groupIncome ? "No income categories yet" : "No expense categories yet"
                        visible: root.categoriesFor(group.groupIncome).length === 0
                        font.pixelSize: Theme.fontSub
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // ---- category editor overlay ----
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: root.catEditorOpen

        MouseArea {
            anchors.fill: parent
            onClicked: root.catEditorOpen = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - units.gu(3), units.gu(44))
            height: Math.min(catForm.height + units.gu(4), parent.height - units.gu(6))
            radius: Theme.radiusCard
            color: Theme.cardBackground

            MouseArea {
                anchors.fill: parent
                onClicked: { /* keep the dialog open */ }
            }

            Flickable {
                id: catFlick
                anchors.fill: parent
                anchors.margins: units.gu(2)
                contentHeight: catForm.height
                clip: true

                Column {
                    id: catForm
                    width: catFlick.width
                    spacing: units.gu(1.2)

                    Row {
                        width: parent.width
                        height: units.gu(5.5)
                        spacing: units.gu(1.2)

                        Rectangle {
                            width: units.gu(5)
                            height: units.gu(5)
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.catEditColor

                            Text {
                                anchors.centerIn: parent
                                text: AppState.categoryGlyph(root.catEditIcon, root.catEditName)
                                font.pixelSize: units.dp(20)
                                color: Theme.textPrimary
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.catEditId.length > 0 ? "Edit category" : "New category"
                            font.pixelSize: Theme.fontHeading
                            font.bold: true
                            color: Theme.textPrimary
                        }
                    }

                    TextField {
                        width: parent.width
                        placeholderText: "Category name"
                        text: root.catEditName
                        onTextChanged: root.catEditName = text
                    }

                    Row {
                        width: parent.width
                        spacing: units.gu(0.8)

                        Repeater {
                            model: [false, true]

                            delegate: Rectangle {
                                width: (catForm.width - units.gu(0.8)) / 2
                                height: units.gu(4.5)
                                radius: Theme.radiusSmall
                                color: root.catEditIsIncome === modelData
                                    ? (modelData ? Theme.income : Theme.expense)
                                    : "#F3F4F6"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData ? "Income" : "Expense"
                                    font.pixelSize: Theme.fontSub
                                    font.bold: root.catEditIsIncome === modelData
                                    color: root.catEditIsIncome === modelData ? Theme.textInverted : Theme.textSecondary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.catEditIsIncome = modelData
                                }
                            }
                        }
                    }

                    Text {
                        text: "Colour"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    Flow {
                        width: parent.width
                        spacing: units.gu(1)

                        Repeater {
                            model: Theme.categoryPalette

                            delegate: Rectangle {
                                width: units.gu(4)
                                height: units.gu(4)
                                radius: width / 2
                                color: modelData
                                border.color: root.catEditColor === modelData ? Theme.textPrimary : Theme.cardBorder
                                border.width: root.catEditColor === modelData ? units.dp(3) : units.dp(1)

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.catEditColor = modelData
                                }
                            }
                        }
                    }

                    Text {
                        text: "Icon"
                        font.pixelSize: Theme.fontSub
                        color: Theme.textSecondary
                    }

                    TextField {
                        width: parent.width
                        placeholderText: "Icon name (e.g. daily_0, food, salary)"
                        text: root.catEditIcon
                        onTextChanged: root.catEditIcon = text
                    }

                    Flow {
                        width: parent.width
                        spacing: units.gu(0.8)

                        Repeater {
                            model: root.iconChoices

                            delegate: Rectangle {
                                width: units.gu(4.4)
                                height: units.gu(4.4)
                                radius: Theme.radiusSmall
                                color: root.catEditIcon === modelData ? Theme.primary : "#F3F4F6"

                                Text {
                                    anchors.centerIn: parent
                                    text: AppState.categoryGlyph(modelData, "")
                                    font.pixelSize: units.dp(16)
                                    color: Theme.textPrimary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.catEditIcon = modelData
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: units.gu(1.5)

                        Button {
                            text: "Cancel"
                            onClicked: root.catEditorOpen = false
                        }

                        Button {
                            text: "Save"
                            color: Theme.primary
                            onClicked: root.saveCategory()
                        }
                    }

                    Item { width: units.gu(1); height: units.gu(1) }
                }
            }
        }
    }

    // ---- subcategory editor overlay ----
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: root.subEditorOpen

        MouseArea {
            anchors.fill: parent
            onClicked: root.subEditorOpen = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - units.gu(4), units.gu(42))
            height: subForm.height + units.gu(4)
            radius: Theme.radiusCard
            color: Theme.cardBackground

            MouseArea {
                anchors.fill: parent
                onClicked: { /* keep the dialog open */ }
            }

            Column {
                id: subForm
                x: units.gu(2)
                y: units.gu(2)
                width: parent.width - units.gu(4)
                spacing: units.gu(1.4)

                Text {
                    text: root.subEditId.length > 0 ? "Edit subcategory" : "New subcategory"
                    font.pixelSize: Theme.fontHeading
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: "in " + AppState.categoryName(root.subEditCategoryId)
                    font.pixelSize: Theme.fontSub
                    color: Theme.textSecondary
                }

                TextField {
                    width: parent.width
                    placeholderText: "Subcategory name"
                    text: root.subEditName
                    onTextChanged: root.subEditName = text
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1.5)

                    Button {
                        text: "Cancel"
                        onClicked: root.subEditorOpen = false
                    }

                    Button {
                        text: "Save"
                        color: Theme.primary
                        onClicked: root.saveSub()
                    }
                }
            }
        }
    }
}
