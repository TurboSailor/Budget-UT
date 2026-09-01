pragma Singleton
import QtQuick 2.4
import Ubuntu.Components 1.3

// Theme mirrors the iOS Budget App design language:
// Clean light canvas, white rounded cards with subtle borders,
// yellow primary accent (FEDB5A), distinct per-category colors.
// Uses Ubuntu.Components units.gu / units.dp for proper DPI scaling on phones.
QtObject {
    // Canvas colors
    readonly property color background: "#F5F6FA"
    readonly property color cardBackground: "#FFFFFF"
    readonly property color cardBorder: "#E5E7EB"
    readonly property color divider: "#F0F2F5"

    // Text colors
    readonly property color textPrimary: "#111827"
    readonly property color textSecondary: "#6B7280"
    readonly property color textMuted: "#9CA3AF"
    readonly property color textInverted: "#FFFFFF"

    // Accents
    readonly property color primary: "#FEDB5A"         // App signature yellow
    readonly property color primaryDark: "#E5C23D"
    readonly property color primaryText: "#1A1A1A"
    readonly property color accent: "#5B8DEF"          // Secondary blue
    readonly property color income: "#10B981"          // Green
    readonly property color expense: "#EF4444"         // Red
    readonly property color transfer: "#8B5CF6"        // Purple

    // Category palette fallbacks
    readonly property var categoryPalette: [
        "#FEDB5A", "#5AA6FE", "#FE5A5A", "#20DAB8",
        "#BC92E8", "#FE9F5A", "#94DD64", "#FF8FB2",
        "#4ECDC4", "#FFD166", "#06D6A0", "#118AB2"
    ]

    // Geometry / Rhythm with Grid Units (adapts to device DPI)
    readonly property real xs: units.gu(0.5)
    readonly property real s: units.gu(1)
    readonly property real m: units.gu(1.5)
    readonly property real l: units.gu(2)
    readonly property real xl: units.gu(3)

    readonly property real radiusSmall: units.gu(1)
    readonly property real radiusCard: units.gu(1.8)
    readonly property real radiusPill: units.gu(2.5)

    readonly property real paddingSmall: units.gu(1)
    readonly property real paddingMedium: units.gu(1.5)
    readonly property real paddingLarge: units.gu(2)

    // Typography (using units.dp for crisp legible text on all phone displays)
    readonly property int fontHero: units.dp(34)
    readonly property int fontTitleLarge: units.dp(26)
    readonly property int fontTitle: units.dp(21)
    readonly property int fontHeading: units.dp(16)
    readonly property int fontBody: units.dp(14)
    readonly property int fontSub: units.dp(12)
    readonly property int fontMicro: units.dp(10)
}
