import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Shown for a few seconds after a session is finished and saved to history.
class SavedView extends TimedAlertView {
    private const SHOW_MS = 3000;

    function initialize() {
        TimedAlertView.initialize(SHOW_MS);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawCountdown(dc);

        // A black check on a yellow disc.
        var badgeY = height * 40 / 100;
        var badgeRadius = width * 15 / 100;
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, badgeY, badgeRadius);
        var mark = badgeRadius / 2;
        dc.setPenWidth(badgeRadius / 4);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX - mark, badgeY, centerX - mark / 3, badgeY + mark * 2 / 3);
        dc.drawLine(centerX - mark / 3, badgeY + mark * 2 / 3, centerX + mark, badgeY - mark * 2 / 3);
        dc.setPenWidth(1);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height * 68 / 100, Graphics.FONT_MEDIUM,
            WatchUi.loadResource(Rez.Strings.SessionSaved) as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
