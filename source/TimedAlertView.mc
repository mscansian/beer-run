import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// An alert that closes itself after a few seconds, like the ones a running app
// shows. Subclasses draw the content and call drawCountdown for the ring that
// runs down around the edge until the alert closes.
class TimedAlertView extends WatchUi.View {
    private const FRAME_MS = 100;
    private const ARC_WIDTH = 8;

    private var _showMs as Number;
    private var _timer as Timer.Timer?;
    // When the alert appeared, in System.getTimer() milliseconds.
    private var _shownAt as Number = 0;

    function initialize(showMs as Number) {
        View.initialize();
        _showMs = showMs;
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
        if (System.getTimer() - _shownAt >= _showMs) {
            onHide();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else {
            WatchUi.requestUpdate();
        }
    }

    // A ring around the edge that starts full at the top and empties
    // clockwise as the alert runs out.
    protected function drawCountdown(dc as Graphics.Dc) as Void {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var radius = centerX - ARC_WIDTH / 2;
        var left = 1.0 - (System.getTimer() - _shownAt).toFloat() / _showMs;
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

// Any button or a tap closes the alert early.
class TimedAlertDelegate extends WatchUi.BehaviorDelegate {
    private var _view as TimedAlertView;

    function initialize(view as TimedAlertView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(event as WatchUi.KeyEvent) as Boolean {
        close();
        return true;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        close();
        return true;
    }

    protected function close() as Void {
        _view.onHide();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
