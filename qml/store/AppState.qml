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

    // ---- lookups ----

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

    function rateOf(code) {
        for (var i = 0; i < currencies.length; i++) {
            if (currencies[i].code === code && currencies[i].rate > 0) return currencies[i].rate;
        }
        return 1.0;
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

    // Symbols that read naturally before the number; everything else is suffixed.
    function symbolIsPrefix(sym) {
        return sym === "$" || sym === "€" || sym === "£" || sym === "¥"
            || sym === "₹" || sym === "₩" || sym === "₪" || sym === "₫";
    }

    // ---- money formatting ----
    // Manual digit grouping: the V4 engine mangles the regex lookahead trick,
    // which is what produced the doubled separators.
    function groupDigits(intStr) {
        var out = "";
        var n = 0;
        for (var i = intStr.length - 1; i >= 0; i--) {
            out = intStr.charAt(i) + out;
            n++;
            if (n % 3 === 0 && i > 0) out = "," + out;
        }
        return out;
    }

    // formatMoney renders an absolute-value-agnostic amount: a stored negative
    // (an overdrawn balance) keeps its minus, nothing else gains a sign.
    function formatMoney(minor, cur) {
        if (minor === undefined || minor === null || isNaN(minor)) minor = 0;
        var sym = currencySymbol(cur);
        var neg = minor < 0;
        var abs = Math.abs(minor);
        var major = Math.floor(abs / 100);
        var cents = abs % 100;
        var body = groupDigits("" + major) + "." + (cents < 10 ? "0" + cents : "" + cents);
        var sign = neg ? "-" : "";
        return symbolIsPrefix(sym) ? (sign + sym + body) : (sign + body + " " + sym);
    }

    // formatSigned applies the transaction sign from `kind`, never from the
    // stored number: the source data keeps every amount positive
    // (kind 0 = expense, 1 = transfer, 2 = income).
    function formatSigned(minor, cur, kind) {
        var base = formatMoney(Math.abs(minor === undefined || minor === null ? 0 : minor), cur);
        if (kind === 0) return "-" + base;
        if (kind === 2) return "+" + base;
        return base;
    }

    function colorForKind(kind) {
        if (kind === 0) return Theme.expense;
        if (kind === 2) return Theme.income;
        if (kind === 1) return Theme.transfer;
        return Theme.textPrimary;
    }

    // ---- category presentation ----

    function categoryColor(catId, fallback) {
        var c = categoryById(catId);
        if (c && c.color) {
            var h = c.color;
            if (h.indexOf("#") !== 0) h = "#" + h;
            return h;
        }
        return fallback || Theme.primary;
    }

    function categoryName(catId) {
        var c = categoryById(catId);
        return c ? c.name : "Uncategorized";
    }

    function categoryGlyph(iconName, name) {
        if (!iconName && !name) return "•";
        var s = ((iconName || "") + " " + (name || "")).toLowerCase();
        if (s.indexOf("food") >= 0 || s.indexOf("drink") >= 0 || s.indexOf("restaurant") >= 0 || s.indexOf("coffee") >= 0) return "🍽";
        if (s.indexOf("transport") >= 0 || s.indexOf("car") >= 0 || s.indexOf("gas") >= 0) return "🚗";
        if (s.indexOf("home") >= 0 || s.indexOf("rent") >= 0 || s.indexOf("house") >= 0 || s.indexOf("bills") >= 0) return "🏠";
        if (s.indexOf("shopping") >= 0 || s.indexOf("clothing") >= 0) return "🛍";
        if (s.indexOf("fun") >= 0 || s.indexOf("entertainment") >= 0) return "🎉";
        if (s.indexOf("health") >= 0 || s.indexOf("fitness") >= 0 || s.indexOf("gym") >= 0) return "💊";
        if (s.indexOf("salary") >= 0 || s.indexOf("wage") >= 0) return "💰";
        if (s.indexOf("freelance") >= 0 || s.indexOf("work") >= 0 || s.indexOf("business") >= 0 || s.indexOf("office") >= 0) return "💼";
        if (s.indexOf("invest") >= 0 || s.indexOf("stock") >= 0) return "📈";
        if (s.indexOf("subscri") >= 0) return "📱";
        if (s.indexOf("cash") >= 0) return "💵";
        if (s.indexOf("smok") >= 0) return "🚬";
        if (s.indexOf("gift") >= 0) return "🎁";
        if (s.indexOf("girl") >= 0 || s.indexOf("love") >= 0) return "💝";
        if (name && name.length > 0) return name.charAt(0).toUpperCase();
        return "•";
    }
}
