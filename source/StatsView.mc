import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// The stats page for the current session: how long it has run, the average
// time between beers, the pace, and the volume when sizes are tracked.
class StatsView extends WatchUi.View {
    // Pace needs some elapsed time to mean anything; one beer five minutes in
    // is not 12 per hour.
    private const MIN_PACE_SECONDS = 15 * 60;

    private var _session as BeerSession;
    // Redraws once a minute so the times stay current.
    private var _timer as Timer.Timer?;

    function initialize(session as BeerSession) {
        View.initialize();
        _session = session;
    }

    function onShow() as Void {
        var timer = new Timer.Timer();
        timer.start(method(:onMinute), 60000, true);
        _timer = timer;
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onMinute() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 8, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.Stats) as String, Graphics.TEXT_JUSTIFY_CENTER);

        var rows = statRows();
        var rowHeight = height / 8;
        var top = height / 2 - rows.size() * rowHeight / 2;
        var left = width / 6;
        var right = width - width / 6;
        for (var i = 0; i < rows.size(); i++) {
            var y = top + i * rowHeight + rowHeight / 2;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left, y, Graphics.FONT_TINY, rows[i][0],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(right, y, Graphics.FONT_TINY, rows[i][1],
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // [label, value] pairs. A value is "-" when there is not enough data yet.
    private function statRows() as Array<[String, String]> {
        var none = "-";
        var count = _session.count();
        var firstAt = _session.firstAt();
        var lastAt = _session.lastAt();
        var elapsed = firstAt != null ? Time.now().subtract(firstAt).value() : 0;

        var gap = none;
        if (count >= 2 && firstAt != null && lastAt != null) {
            gap = durationText(lastAt.subtract(firstAt).value() / (count - 1));
        }

        var hasPace = elapsed >= MIN_PACE_SECONDS;
        var pace = hasPace ? (count * 3600.0 / elapsed).format("%.1f") + " /h" : none;

        var rows = [
            [WatchUi.loadResource(Rez.Strings.StatSession) as String, firstAt != null ? durationText(elapsed) : none],
            [WatchUi.loadResource(Rez.Strings.StatGap) as String, gap],
            [WatchUi.loadResource(Rez.Strings.StatPace) as String, pace]
        ] as Array<[String, String]>;

        var ml = _session.totalMl();
        if (ml > 0) {
            rows.add([WatchUi.loadResource(Rez.Strings.StatVolume) as String, litresText(ml)]);
            rows.add([WatchUi.loadResource(Rez.Strings.StatPerHour) as String,
                hasPace ? (ml * 3600 / elapsed) + " ml" : none]);
        }
        return rows;
    }

    // A duration like "34 min" or "2h15".
    private function durationText(seconds as Number) as String {
        var minutes = seconds / 60;
        if (minutes < 60) {
            return minutes + " min";
        }
        return (minutes / 60) + "h" + (minutes % 60).format("%02d");
    }
}

// UP goes back to the counter, DOWN on to the history.
class StatsDelegate extends WatchUi.BehaviorDelegate {
    private var _history as BeerHistory;

    function initialize(history as BeerHistory) {
        BehaviorDelegate.initialize();
        _history = history;
    }

    function onPreviousPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onNextPage() as Boolean {
        var view = new HistoryView(_history);
        WatchUi.pushView(view, new HistoryDelegate(view), WatchUi.SLIDE_UP);
        return true;
    }
}
