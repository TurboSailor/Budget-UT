import QtQuick 2.4
import "../theme"
import "../store"

Item {
    id: root
    property var days: [] // array of {day, expenseMinor, incomeMinor}
    property string selectedDay: AppState.selectedDay
    signal barClicked(string day)

    implicitHeight: 140
    implicitWidth: 320

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: 6

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            if (!root.days || root.days.length === 0) {
                ctx.fillStyle = Theme.textMuted;
                ctx.font = "12px sans-serif";
                ctx.textAlign = "center";
                ctx.fillText("No transactions in this period", width / 2, height / 2);
                return;
            }

            var n = Math.min(root.days.length, 31);
            var maxVal = 1;
            for (var i = 0; i < n; i++) {
                var v = (root.days[i].expenseMinor || 0) + (root.days[i].incomeMinor || 0);
                if (v > maxVal) maxVal = v;
            }

            var labelH = 22;
            var chartH = height - labelH - 10;
            var colW = width / n;
            var barW = Math.max(3, Math.min(18, colW * 0.65));

            for (var i = 0; i < n; i++) {
                var d = root.days[i];
                var exp = d.expenseMinor || 0;
                var x = i * colW + (colW - barW) / 2;
                var h = (exp / maxVal) * (chartH - 8);
                if (h < 3 && exp > 0) h = 3;
                var y = chartH - h;

                var isSelected = (d.day === root.selectedDay);

                // Background track
                ctx.fillStyle = isSelected ? "#F3E8FF" : "#F3F4F6";
                drawRoundedRect(ctx, x, 4, barW, chartH - 4, barW / 2);

                // Bar fill
                if (exp > 0) {
                    ctx.fillStyle = isSelected ? Theme.accent : Theme.primary;
                    drawRoundedRect(ctx, x, y, barW, h, barW / 2);
                }

                // Label (day number or weekday)
                var dayNum = d.day ? d.day.substring(d.day.length - 2) : "";
                ctx.fillStyle = isSelected ? Theme.accent : Theme.textSecondary;
                ctx.font = isSelected ? "bold 10px sans-serif" : "10px sans-serif";
                ctx.textAlign = "center";
                ctx.fillText(dayNum, x + barW / 2, height - 4);
            }
        }

        function drawRoundedRect(ctx, x, y, w, h, r) {
            if (h < 2 * r) r = h / 2;
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.lineTo(x + w - r, y);
            ctx.quadraticCurveTo(x + w, y, x + w, y + r);
            ctx.lineTo(x + w, y + h - r);
            ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
            ctx.lineTo(x + r, y + h);
            ctx.quadraticCurveTo(x, y + h, x, y + h - r);
            ctx.lineTo(x, y + r);
            ctx.quadraticCurveTo(x, y, x + r, y);
            ctx.closePath();
            ctx.fill();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!root.days || root.days.length === 0) return;
            var colW = width / Math.min(root.days.length, 31);
            var idx = Math.floor(mouse.x / colW);
            if (idx >= 0 && idx < root.days.length) {
                root.barClicked(root.days[idx].day);
            }
        }
    }

    onDaysChanged: canvas.requestPaint()
    onSelectedDayChanged: canvas.requestPaint()
}
