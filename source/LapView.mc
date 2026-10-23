import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The lap alert shown for a few seconds after a beer is added, like a running
// app shows one when you press LAP. Adding a beer means the previous one is
// finished, so the lap is that previous beer: how long it took, and the litres
// drunk up to and including it. START still adds a beer; any other button or
// a tap closes it early.
class LapView extends TimedAlertView {
    private const SHOW_MS = 5000;

    private var _lap as Number;
    private var _lapSeconds as Number;
    private var _totalMl as Number;

    function initialize(lap as Number, lapSeconds as Number, totalMl as Number) {
        TimedAlertView.initialize(SHOW_MS);
        _lap = lap;
        _lapSeconds = lapSeconds;
        _totalMl = totalMl;
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
}

// START closes the lap alert and adds another beer, so pressing it twice in a
// row adds two. Any other button or a tap only closes it.
class LapDelegate extends TimedAlertDelegate {
    private var _addBeer as Method() as Void;

    function initialize(view as LapView, addBeer as Method() as Void) {
        TimedAlertDelegate.initialize(view);
        _addBeer = addBeer;
    }

    function onKey(event as WatchUi.KeyEvent) as Boolean {
        close();
        if (event.getKey() == WatchUi.KEY_ENTER) {
            _addBeer.invoke();
        }
        return true;
    }
}
