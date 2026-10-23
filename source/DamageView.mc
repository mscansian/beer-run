import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// The damage page: when you will probably be sober, and how many km you would
// have to run to burn off the beer. It shows the current session, or after
// Finish the finished one until its sober time passes. The sober time counts
// the beers of both, since the alcohol of the finished session can still be
// there.
class DamageView extends WatchUi.View {
    private const KM_PER_MILE = 1.609344;

    private var _session as BeerSession;
    // Redraws so the time left stays current.
    private var _timer as Timer.Timer?;

    function initialize(session as BeerSession) {
        View.initialize();
        _session = session;
    }

    function onShow() as Void {
        var timer = new Timer.Timer();
        timer.start(method(:onTick), 30 * 1000, true);
        _timer = timer;
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var body = BodyProfile.fromWatch();
        if (body == null) {
            drawMessage(dc, Rez.Strings.DamageNoProfile);
            return;
        }

        var now = Time.now().value();
        var current = _session.beers();
        var finished = _session.finishedBeers();
        var allBeers = [] as Array<Beer>;
        allBeers.addAll(finished);
        allBeers.addAll(current);
        var soberAt = BloodAlcohol.soberAt(body, allBeers);

        // The session the beer debt is about.
        var beers = null as Array<Beer>?;
        if (current.size() > 0) {
            beers = current;
        } else if (finished.size() > 0 && soberAt != null && soberAt > now) {
            beers = finished;
        }
        if (beers == null || soberAt == null) {
            drawMessage(dc, Rez.Strings.DamageEmpty);
            return;
        }

        var divider = height * 49 / 100;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, divider, width, divider);

        drawLabel(dc, centerX, height * 14 / 100, Rez.Strings.DamageSober);
        var clock = clockTime(soberAt);
        drawValue(dc, centerX, height * 27 / 100, clock[0], clock[1]);
        if (soberAt > now) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height * 40 / 100, Graphics.FONT_XTINY, timeLeftText(soberAt - now),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var km = BeerDebt.km(body, beers);
        var inMiles = System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE;
        drawLabel(dc, centerX, height * 56 / 100, Rez.Strings.DamageDebt);
        drawValue(dc, centerX, height * 68 / 100, (inMiles ? km / KM_PER_MILE : km).format("%.1f"),
            inMiles ? "mi" : "km");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 81 / 100, Graphics.FONT_XTINY,
            DebtLine.text(km, inMiles ? "26.2" : "42.2"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A time of day as the watch shows it: the digits, and "am" or "pm" when
    // the watch uses a 12-hour clock.
    private function clockTime(at as Number) as [String, String?] {
        var info = Gregorian.info(new Time.Moment(at), Time.FORMAT_SHORT);
        var hour = info.hour as Number;
        var minutes = (info.min as Number).format("%02d");
        if (System.getDeviceSettings().is24Hour) {
            return [hour.format("%02d") + ":" + minutes, null];
        }
        var hour12 = hour % 12 == 0 ? 12 : hour % 12;
        return [hour12 + ":" + minutes, hour < 12 ? "am" : "pm"];
    }

    // E.g. "in 2h40" or "in 25 min".
    private function timeLeftText(seconds as Number) as String {
        var minutes = (seconds + 59) / 60;
        if (minutes < 60) {
            return Lang.format(WatchUi.loadResource(Rez.Strings.DamageInMinutes) as String, [minutes]);
        }
        return Lang.format(WatchUi.loadResource(Rez.Strings.DamageInHours) as String,
            [minutes / 60, (minutes % 60).format("%02d")]);
    }

    private function drawMessage(dc as Graphics.Dc, message as ResourceId) as Void {
        var text = Graphics.fitTextToArea(WatchUi.loadResource(message) as String, Graphics.FONT_SMALL,
            dc.getWidth() * 7 / 10, dc.getHeight() / 2, true);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawLabel(dc as Graphics.Dc, x as Number, y as Number, label as ResourceId) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, WatchUi.loadResource(label) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A centred number with an optional unit just right of it. The number
    // fonts have no letters, so the unit uses a text font.
    private function drawValue(dc as Graphics.Dc, x as Number, y as Number, value as String,
        unit as String?) as Void {
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_NUMBER_MEDIUM, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (unit != null) {
            var unitX = x + dc.getTextWidthInPixels(value, Graphics.FONT_NUMBER_MEDIUM) / 2 + 4;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(unitX, y, Graphics.FONT_TINY, unit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

// UP goes back to the splits. DOWN wraps around to the counter, which sits
// under the stats and splits pages on the view stack.
class DamageDelegate extends PageDelegate {
    function initialize(menu as BeerMenu, addBeer as Method() as Void) {
        PageDelegate.initialize(menu, addBeer);
    }

    function onPreviousPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onNextPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_UP);
        return true;
    }
}
