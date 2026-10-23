import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// The stats page for the current session, laid out like a running app's data
// screen, with litres standing in for distance: the timer on top, litres and
// beers in the middle, and the pace (time per litre) at the bottom.
class StatsView extends WatchUi.View {
    private var _session as BeerSession;
    // Redraws every second so the timer ticks like a stopwatch.
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
        var none = "--";
        var count = _session.count();
        var ml = _session.totalMl();
        var firstAt = _session.firstAt();
        var elapsed = firstAt != null ? Time.now().subtract(firstAt).value() : 0;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var dividerTop = height * 37 / 100;
        var dividerBottom = height * 65 / 100;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, dividerTop, width, dividerTop);
        dc.drawLine(0, dividerBottom, width, dividerBottom);
        dc.drawLine(centerX, dividerTop, centerX, dividerBottom);

        drawField(dc, centerX, height * 14 / 100, height * 27 / 100, Graphics.FONT_NUMBER_MEDIUM,
            Rez.Strings.StatTimer, firstAt != null ? clockDuration(elapsed) : none);

        drawField(dc, width * 3 / 10, height * 42 / 100, height * 53 / 100, Graphics.FONT_NUMBER_MILD,
            Rez.Strings.StatLitres, ml > 0 ? (ml / 1000.0).format("%.2f") : none);
        drawField(dc, width * 7 / 10, height * 42 / 100, height * 53 / 100, Graphics.FONT_NUMBER_MILD,
            Rez.Strings.StatBeers, count.toString());

        var pace = ml > 0 ? clockDuration((elapsed * 1000.0 / ml).toNumber()) : none;
        drawField(dc, centerX, height * 70 / 100, height * 81 / 100, Graphics.FONT_NUMBER_MEDIUM,
            Rez.Strings.StatPace, pace);
        drawUnit(dc, centerX, height * 81 / 100, Graphics.FONT_NUMBER_MEDIUM, pace, Rez.Strings.PerLitre);
    }

    private function drawField(dc as Graphics.Dc, x as Number, labelY as Number, valueY as Number,
        valueFont as Graphics.FontDefinition, label as ResourceId, value as String) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, labelY, Graphics.FONT_XTINY, WatchUi.loadResource(label) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, valueY, valueFont, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Draws a unit like "/L" just right of a centred value. The number fonts
    // have no letters or slash, so the unit uses a text font.
    private function drawUnit(dc as Graphics.Dc, x as Number, y as Number,
        valueFont as Graphics.FontDefinition, value as String, unit as ResourceId) as Void {
        var unitX = x + dc.getTextWidthInPixels(value, valueFont) / 2 + 4;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(unitX, y, Graphics.FONT_TINY, WatchUi.loadResource(unit) as String,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A duration like a stopwatch shows it: "4:07" under an hour, "1:04:07"
    // from an hour on.
    private function clockDuration(seconds as Number) as String {
        var hours = seconds / 3600;
        var minutes = (seconds / 60) % 60;
        var secs = (seconds % 60).format("%02d");
        if (hours > 0) {
            return hours + ":" + minutes.format("%02d") + ":" + secs;
        }
        return minutes + ":" + secs;
    }
}

// UP goes back to the counter, DOWN on to the history.
class StatsDelegate extends WatchUi.BehaviorDelegate {
    private var _history as BeerHistory;
    private var _menu as BeerMenu;

    function initialize(history as BeerHistory, menu as BeerMenu) {
        BehaviorDelegate.initialize();
        _history = history;
        _menu = menu;
    }

    function onPreviousPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onNextPage() as Boolean {
        var view = new HistoryView(_history);
        WatchUi.pushView(view, new HistoryDelegate(view, _menu), WatchUi.SLIDE_UP);
        return true;
    }

    function onMenu() as Boolean {
        _menu.open();
        return true;
    }
}
