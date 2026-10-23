import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// The lap alert shown for a few seconds after a beer is added, like a running
// app shows one when you press LAP. Adding a beer means the previous one is
// finished, so the lap is that previous beer: how long it took, and the litres
// drunk up to and including it. A ring around the edge runs down until the
// alert closes itself. START still adds a beer; any other button or a tap
// closes it early.
class LapView extends WatchUi.View {
    private const SHOW_MS = 5000;
    private const FRAME_MS = 100;
    private const ARC_WIDTH = 8;

    private var _lap as Number;
    private var _lapSeconds as Number;
    private var _totalMl as Number;
    private var _timer as Timer.Timer?;
    // When the alert appeared, in System.getTimer() milliseconds.
    private var _shownAt as Number = 0;

    function initialize(lap as Number, lapSeconds as Number, totalMl as Number) {
        View.initialize();
        _lap = lap;
        _lapSeconds = lapSeconds;
        _totalMl = totalMl;
    }

    function onShow() as Void {
        _shownAt = System.getTimer();
        var timer = new Timer.Timer();
        timer.start(method(:onFrame), FRAME_MS, true);
        _timer = timer;
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onFrame() as Void {
        if (System.getTimer() - _shownAt >= SHOW_MS) {
            onHide();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else {
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawCountdown(dc);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 20 / 100, Graphics.FONT_SMALL,
            Lang.format(WatchUi.loadResource(Rez.Strings.Lap) as String, [_lap]),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawField(dc, centerX, height * 34 / 100, height * 46 / 100, Rez.Strings.LapTime,
            clockDuration(_lapSeconds));
        drawField(dc, centerX, height * 61 / 100, height * 73 / 100, Rez.Strings.StatLitres,
            (_totalMl / 1000.0).format("%.2f"));
    }

    private function drawField(dc as Graphics.Dc, x as Number, labelY as Number, valueY as Number,
        label as ResourceId, value as String) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, labelY, Graphics.FONT_XTINY, WatchUi.loadResource(label) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, valueY, Graphics.FONT_NUMBER_MEDIUM, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A ring around the edge that starts full at the top and empties
    // clockwise as the alert runs out.
    private function drawCountdown(dc as Graphics.Dc) as Void {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var radius = centerX - ARC_WIDTH / 2;
        var left = 1.0 - (System.getTimer() - _shownAt).toFloat() / SHOW_MS;
        if (left <= 0) {
            return;
        }
        dc.setPenWidth(ARC_WIDTH);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        if (left >= 1) {
            dc.drawCircle(centerX, centerY, radius);
        } else {
            var start = 90 - (360 * (1 - left)).toNumber();
            dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, start, 90);
        }
        dc.setPenWidth(1);
    }
}

// START closes the lap alert and adds another beer, so pressing it twice in a
// row adds two. Any other button or a tap only closes it.
class LapDelegate extends WatchUi.BehaviorDelegate {
    private var _view as LapView;
    private var _addBeer as Method() as Void;

    function initialize(view as LapView, addBeer as Method() as Void) {
        BehaviorDelegate.initialize();
        _view = view;
        _addBeer = addBeer;
    }

    function onKey(event as WatchUi.KeyEvent) as Boolean {
        close();
        if (event.getKey() == WatchUi.KEY_ENTER) {
            _addBeer.invoke();
        }
        return true;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        close();
        return true;
    }

    private function close() as Void {
        _view.onHide();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
