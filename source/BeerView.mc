import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

class BeerView extends WatchUi.View {
    private const ARC_WIDTH = 8;

    private var _session as BeerSession;
    private var _goal as BeerGoal;
    // Redraws once a minute so "last one X min ago" stays current.
    private var _timer as Timer.Timer?;

    function initialize(session as BeerSession, goal as BeerGoal) {
        View.initialize();
        _session = session;
        _goal = goal;
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
        var centerX = width / 2;
        var count = _session.count();
        var goal = _goal.value();
        var overGoal = goal != null && count > goal;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (goal != null) {
            drawGoalArc(dc, count, goal);
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var top = goal != null
            ? Lang.format(WatchUi.loadResource(Rez.Strings.GoalOf) as String, [goal])
            : WatchUi.loadResource(Rez.Strings.Hint) as String;
        dc.drawText(centerX, height / 8, Graphics.FONT_XTINY, top, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(overGoal ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 9 / 20, Graphics.FONT_NUMBER_THAI_HOT, count.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var label = count == 1 ? Rez.Strings.Beer : Rez.Strings.Beers;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 13 / 20, Graphics.FONT_MEDIUM, WatchUi.loadResource(label) as String,
            Graphics.TEXT_JUSTIFY_CENTER);

        var lastAt = _session.lastAt();
        if (lastAt != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height * 4 / 5, Graphics.FONT_XTINY, lastBeerText(lastAt),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // A ring around the edge that fills clockwise from the top as the count
    // approaches the goal. It turns red once the count goes over.
    private function drawGoalArc(dc as Graphics.Dc, count as Number, goal as Number) as Void {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var radius = centerX - ARC_WIDTH / 2;
        dc.setPenWidth(ARC_WIDTH);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, centerY, radius);

        if (count >= goal) {
            dc.setColor(count > goal ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(centerX, centerY, radius);
        } else if (count > 0) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, 90, 90 - 360 * count / goal);
        }

        dc.setPenWidth(1);
    }
}
