import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The row in the glance list: the count, the goal if one is set, and how
// long ago the last beer was. With a goal, a bar along the bottom fills up
// like the ring on the main screen.
(:glance)
class BeerGlanceView extends WatchUi.GlanceView {
    private const BAR_HEIGHT = 4;

    private var _session as BeerSession;
    private var _goal as BeerGoal;

    function initialize(session as BeerSession, goal as BeerGoal) {
        GlanceView.initialize();
        _session = session;
        _goal = goal;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var count = _session.count();
        var goal = _goal.value();
        var overGoal = goal != null && count > goal;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, height / 4, Graphics.FONT_GLANCE,
            (WatchUi.loadResource(Rez.Strings.AppName) as String).toUpper(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var countText = goal != null ? count + "/" + goal : count.toString();
        var lastAt = _session.lastAt();
        var detail = lastAt != null
            ? lastBeerText(lastAt)
            : WatchUi.loadResource(count == 1 ? Rez.Strings.Beer : Rez.Strings.Beers) as String;
        dc.setColor(overGoal ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, height * 5 / 8, Graphics.FONT_GLANCE_NUMBER, countText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var countWidth = dc.getTextWidthInPixels(countText + " ", Graphics.FONT_GLANCE_NUMBER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(countWidth, height * 5 / 8, Graphics.FONT_GLANCE, detail,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (goal != null) {
            var barY = height - BAR_HEIGHT;
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, barY, width, BAR_HEIGHT);
            var filled = count >= goal ? width : width * count / goal;
            dc.setColor(overGoal ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, barY, filled, BAR_HEIGHT);
        }
    }
}
