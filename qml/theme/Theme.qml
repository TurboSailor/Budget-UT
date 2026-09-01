pragma Singleton
import QtQuick 2.4

// Theme mirrors the iOS Budget App design language:
// Clean light canvas, white rounded cards with subtle borders,
// yellow primary accent (FEDB5A), distinct per-category colors.
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

    // Typography
    readonly property int fontTitleLarge: 28
    readonly property int fontTitle: 22
    readonly property int fontHeading: 17
    readonly property int fontBody: 14
    readonly property int fontSub: 12
    readonly property int fontMicro: 10

    // Geometry
    readonly property int radiusSmall: 8
    readonly property int radiusCard: 14
    readonly property int radiusPill: 20
    readonly property int paddingSmall: 8
    readonly property int paddingMedium: 14
    readonly property int paddingLarge: 20
}
