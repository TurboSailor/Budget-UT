pragma Singleton
import QtQuick 2.4
import "../js/api.js" as Api
import "../theme"

QtObject {
    id: root

    property bool ready: false
    property bool connected: false
    property string lastError: ""

    // Loaded datasets
    property var settings: ({})
    property var currencies: []
    property var groups: []
    property var accounts: []
    property var bills: []
    property var categories: []
    property var subcategories: []
    property var budgets: []
    property var wallets: ({ system: "USD", totalMinor: 0, incomeMinor: 0, expenseMinor: 0, byCurrency: {} })

    // Active navigation / date selections
    property int activeTab: 0 // 0: Home, 1: Calendar, 2: Budget, 3: Accounts, 4: Stats, 5: Settings
    property string todayDay: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property string selectedDay: todayDay
    property string selectedMonth: Qt.formatDate(new Date(), "yyyy-MM")

    // Signals for sub-views to refresh their local lists
    signal txChanged()
    signal dataRefreshed()

    function reload(cb) {
        Api.get("/api/bootstrap", function(err, data) {
            if (err) {
                root.connected = false;
                root.lastError = err;
                if (cb) cb(err);
                return;
            }
            root.connected = true;
            root.ready = true;
            root.lastError = "";
            if (data) {
                root.settings = data.settings || {};
                root.currencies = data.currencies || [];
                root.groups = data.groups || [];
                root.accounts = data.accounts || [];
                root.bills = data.bills || [];
                root.categories = data.categories || [];
                root.subcategories = data.subcategories || [];
                root.budgets = data.budgets || [];
                root.wallets = data.wallets || root.wallets;
            }
            root.dataRefreshed();
            if (cb) cb(null);
        });
    }

    // Lookup helpers
    function categoryById(id) {
        if (!id) return null;
        for (var i = 0; i < categories.length; i++) {
            if (categories[i].id === id) return categories[i];
        }
        return null;
    }

    function subcategoryById(id) {
        if (!id) return null;
        for (var i = 0; i < subcategories.length; i++) {
            if (subcategories[i].id === id) return subcategories[i];
        }
        return null;
    }

    function accountById(id) {
        if (!id) return null;
        for (var i = 0; i < accounts.length; i++) {
            if (accounts[i].id === id) return accounts[i];
        }
        return null;
    }

    function currencySymbol(code) {
        if (!code) code = wallets.system || "USD";
        for (var i = 0; i < currencies.length; i++) {
            if (currencies[i].code === code && currencies[i].symbol) {
                return currencies[i].symbol;
            }
        }
        switch (code) {
        case "USD": return "$";
        case "EUR": return "€";
        case "RUB": return "₽";
        case "GBP": return "£";
        case "CNY": case "JPY": return "¥";
        default: return code;
        }
    }

    // formatMoney returns formatted string e.g. "$1,234.56" or "-$15.00"
    function formatMoney(minor, cur, showSign) {
        if (minor === undefined || minor === null) minor = 0;
        var sym = currencySymbol(cur);
        var isNeg = minor < 0;
        var abs = Math.abs(minor);
        var major = (abs / 100).toFixed(2);
        // add thousand separators
        var parts = major.split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        var formatted = parts.join(".");
        var sign = "";
        if (isNeg) sign = "-";
        else if (showSign && minor > 0) sign = "+";
        // symbol placement: before for $, €, £, after for ₽
        if (sym === "₽") return sign + formatted + " ₽";
        return sign + sym + formatted;
    }

    // categoryColor resolves hex string to valid QML color
    function categoryColor(catId, fallback) {
        var c = categoryById(catId);
        if (c && c.color) {
            var h = c.color;
            if (h.indexOf("#") !== 0) h = "#" + h;
            return h;
        }
        return fallback || Theme.primary;
    }

    // categoryName returns label or fallback
    function categoryName(catId) {
        var c = categoryById(catId);
        return c ? c.name : "Uncategorized";
    }

    // categoryIconGlyph returns single-char / emoji / short text representation
    // since Ubuntu Touch has no SF Symbols.
    function categoryGlyph(iconName, name) {
        if (!iconName && !name) return "•";
        var s = (iconName || name || "").toLowerCase();
        if (s.indexOf("food") >= 0 || s.indexOf("drink") >= 0 || s.indexOf("restaurant") >= 0 || s.indexOf("coffee") >= 0) return "🍽";
        if (s.indexOf("transport") >= 0 || s.indexOf("car") >= 0 || s.indexOf("gas") >= 0) return "🚗";
        if (s.indexOf("home") >= 0 || s.indexOf("rent") >= 0 || s.indexOf("house") >= 0) return "🏠";
        if (s.indexOf("shopping") >= 0 || s.indexOf("clothing") >= 0) return "🛍";
        if (s.indexOf("fun") >= 0 || s.indexOf("entertainment") >= 0) return "🎉";
        if (s.indexOf("health") >= 0 || s.indexOf("fitness") >= 0 || s.indexOf("gym") >= 0) return "💊";
        if (s.indexOf("salary") >= 0 || s.indexOf("wage") >= 0) return "💰";
        if (s.indexOf("freelance") >= 0 || s.indexOf("work") >= 0 || s.indexOf("business") >= 0) return "💼";
        if (s.indexOf("invest") >= 0 || s.indexOf("stock") >= 0) return "📈";
        if (s.indexOf("subscri") >= 0 || s.indexOf("netflix") >= 0 || s.indexOf("apple") >= 0) return "📱";
        if (s.indexOf("cash") >= 0) return "💵";
        if (s.indexOf("smoke") >= 0 || s.indexOf("smoking") >= 0) return "🚬";
        if (s.indexOf("gift") >= 0) return "🎁";
        if (name && name.length > 0) return name.charAt(0).toUpperCase();
        return "•";
    }
}
