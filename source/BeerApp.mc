import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class BeerApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    // The system calls this only for the full app, never in glance mode.
    (:typecheck(disableGlanceCheck))
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var session = new BeerSession();
        var limit = new BeerLimit();
        return [new BeerView(session, limit), new BeerDelegate(session, limit)];
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new BeerGlanceView(new BeerSession(), new BeerLimit())];
    }
}
