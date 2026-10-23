import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// A yes/no question shown like the watch's own activity prompts: the menu
// item's icon on top, the question in the middle, and a mark by each button.
// The check sits by START (yes) and the cross by BACK (no). On the supported
// Forerunners START is at 2 o'clock and BACK at 4 o'clock.
class ConfirmView extends WatchUi.View {
    private const START_ANGLE = 30;
    private const BACK_ANGLE = -30;
    // Half the angle each button's arc covers.
    private const ARC_SPAN = 12;
    private const ARC_WIDTH = 8;
    // How far in from the edge the check and cross are drawn.
    private const MARK_INSET = 30;
    private const MARK_SIZE = 9;

    private var _question as String;
    private var _icon as WatchUi.BitmapResource;
    private var _yesColor as Graphics.ColorType;

    function initialize(question as ResourceId, icon as ResourceId, yesColor as Graphics.ColorType) {
        View.initialize();
        _question = WatchUi.loadResource(question) as String;
        _icon = WatchUi.loadResource(icon) as WatchUi.BitmapResource;
        _yesColor = yesColor;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.drawBitmap(centerX - _icon.getWidth() / 2, height * 24 / 100 - _icon.getHeight() / 2, _icon);

        // The text box stays clear of the marks on the right, and is centered
        // so the left side keeps the same margin.
        var textWidth = width * 62 / 100;
        var textHeight = height * 36 / 100;
        var text = Graphics.fitTextToArea(_question, Graphics.FONT_SMALL, textWidth, textHeight, true);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 54 / 100, Graphics.FONT_SMALL, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawButtonArc(dc, START_ANGLE, _yesColor);
        drawButtonArc(dc, BACK_ANGLE, Graphics.COLOR_DK_GRAY);
        drawCheck(dc, markCenter(dc, START_ANGLE), _yesColor);
        drawCross(dc, markCenter(dc, BACK_ANGLE), Graphics.COLOR_LT_GRAY);
        dc.setPenWidth(1);
    }

    private function drawButtonArc(dc as Graphics.Dc, angle as Number, color as Graphics.ColorType) as Void {
        var centerX = dc.getWidth() / 2;
        dc.setPenWidth(ARC_WIDTH);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, dc.getHeight() / 2, centerX - ARC_WIDTH / 2, Graphics.ARC_COUNTER_CLOCKWISE,
            angle - ARC_SPAN, angle + ARC_SPAN);
    }

    // The point MARK_INSET in from the edge at the given angle, where 0 is
    // 3 o'clock and angles grow counterclockwise.
    private function markCenter(dc as Graphics.Dc, angle as Number) as [Number, Number] {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var radius = centerX - MARK_INSET;
        var radians = Math.toRadians(angle);
        return [
            (centerX + radius * Math.cos(radians)).toNumber(),
            (centerY - radius * Math.sin(radians)).toNumber()
        ];
    }

    private function drawCheck(dc as Graphics.Dc, center as [Number, Number], color as Graphics.ColorType) as Void {
        var x = center[0];
        var y = center[1];
        dc.setPenWidth(4);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x - MARK_SIZE, y, x - MARK_SIZE / 3, y + MARK_SIZE * 2 / 3);
        dc.drawLine(x - MARK_SIZE / 3, y + MARK_SIZE * 2 / 3, x + MARK_SIZE, y - MARK_SIZE * 2 / 3);
    }

    private function drawCross(dc as Graphics.Dc, center as [Number, Number], color as Graphics.ColorType) as Void {
        var x = center[0];
        var y = center[1];
        var half = MARK_SIZE * 3 / 4;
        dc.setPenWidth(4);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x - half, y - half, x + half, y + half);
        dc.drawLine(x - half, y + half, x + half, y - half);
    }
}

// START runs the action, BACK cancels. Either way the question closes, back
// to the page the menu was opened from. Taps are ignored so brushing the
// screen can't end or discard a session.
class ConfirmDelegate extends WatchUi.BehaviorDelegate {
    private var _action as Method() as Void;

    function initialize(action as Method() as Void) {
        BehaviorDelegate.initialize();
        _action = action;
    }

    // There is no onSelect: the select behavior also fires for a tap, so START
    // is handled here as KEY_ENTER instead.
    function onKey(event as WatchUi.KeyEvent) as Boolean {
        if (event.getKey() == WatchUi.KEY_ENTER) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _action.invoke();
            return true;
        }
        return false;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        return true;
    }
}
