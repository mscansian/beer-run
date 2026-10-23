import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// The splits page: the last few beers of the current session, newest first,
// each with how long it took, like the lap list of a run. The beer in
// progress is the top row, in grey, and its time keeps running. The average
// of the finished beers is at the bottom.
class SplitsView extends WatchUi.View {
    // Rows, counting the beer in progress.
    private const ROWS = 4;

    private var _session as BeerSession;
    // Redraws every second so the time of the beer in progress keeps running.
    private var _timer as Timer.Timer?;

    function initialize(session as BeerSession) {
        View.initialize();
        _session = session;
    }

    function onShow() as Void {
        var timer = new Timer.Timer();
        timer.start(method(:onSecond), 1000, true);
        _timer = timer;
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onSecond() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height / 8, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.Splits) as String, Graphics.TEXT_JUSTIFY_CENTER);

        var lastAt = _session.lastAt();
        if (lastAt == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height / 2, Graphics.FONT_SMALL,
                WatchUi.loadResource(Rez.Strings.SplitsEmpty) as String,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var laps = _session.lapSeconds();
        var rowHeight = height / 8;
        var top = height * 30 / 100;
        var left = width / 4;
        var right = width - width / 4;

        drawRow(dc, left, right, top, laps.size() + 1, Time.now().subtract(lastAt).value(),
            Graphics.COLOR_LT_GRAY);
        for (var row = 1; row < ROWS && row <= laps.size(); row++) {
            var lap = laps.size() - row;
            drawRow(dc, left, right, top + row * rowHeight, lap + 1, laps[lap], Graphics.COLOR_YELLOW);
        }

        if (laps.size() > 0) {
            var total = 0;
            for (var i = 0; i < laps.size(); i++) {
                total += laps[i];
            }
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height * 82 / 100, Graphics.FONT_XTINY,
                Lang.format(WatchUi.loadResource(Rez.Strings.SplitsAverage) as String,
                    [clockDuration(total / laps.size())]),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // One row: the beer's number on the left, its time on the right.
    private function drawRow(dc as Graphics.Dc, left as Number, right as Number, y as Number,
        number as Number, seconds as Number, color as Graphics.ColorType) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, y, Graphics.FONT_TINY, number.toString(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(right, y, Graphics.FONT_TINY, clockDuration(seconds),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// UP goes back to the stats, DOWN on to the damage page.
class SplitsDelegate extends PageDelegate {
    private var _session as BeerSession;

    function initialize(session as BeerSession, menu as BeerMenu, addBeer as Method() as Void) {
        PageDelegate.initialize(menu, addBeer);
        _session = session;
    }

    function onPreviousPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    // With no beers, DOWN wraps around to the counter, under the stats page on
    // the view stack.
    function onNextPage() as Boolean {
        if (_session.count() == 0) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_UP);
            return true;
        }
        WatchUi.pushView(new DamageView(_session), new DamageDelegate(_menu, _addBeer), WatchUi.SLIDE_UP);
        return true;
    }
}
