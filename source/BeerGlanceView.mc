import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The row in the glance list: the count, the limit if one is set, and how
// long ago the last beer was. With a limit, a bar along the bottom fills up
// like the ring on the main screen.
(:glance)
class BeerGlanceView extends WatchUi.GlanceView {
    private const BAR_HEIGHT = 4;

    private var _session as BeerSession;
    private var _limit as BeerLimit;

    function initialize(session as BeerSession, limit as BeerLimit) {
        GlanceView.initialize();
        _session = session;
        _limit = limit;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var count = _session.count();
        var limit = _limit.value();
        var overLimit = limit != null && count > limit;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, height / 4, Graphics.FONT_GLANCE,
            (WatchUi.loadResource(Rez.Strings.AppName) as String).toUpper(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var countText = limit != null ? count + "/" + limit : count.toString();
        var lastAt = _session.lastAt();
        var detail = lastAt != null
            ? lastBeerText(lastAt)
            : WatchUi.loadResource(count == 1 ? Rez.Strings.Beer : Rez.Strings.Beers) as String;
        dc.setColor(overLimit ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, height * 5 / 8, Graphics.FONT_GLANCE_NUMBER, countText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var countWidth = dc.getTextWidthInPixels(countText + " ", Graphics.FONT_GLANCE_NUMBER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(countWidth, height * 5 / 8, Graphics.FONT_GLANCE, detail,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (limit != null) {
            var barY = height - BAR_HEIGHT;
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, barY, width, BAR_HEIGHT);
            var filled = count >= limit ? width : width * count / limit;
            dc.setColor(overLimit ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, barY, filled, BAR_HEIGHT);
        }
    }
}
