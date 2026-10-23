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
        var history = new BeerHistory();
        var session = new BeerSession(history);
        // Opening the app the day after shows an empty session, with the
        // previous one already in the history.
        session.endIfIdle();
        var goal = new BeerGoal();
        var size = new BeerSize();
        return [new BeerView(session, goal), new BeerDelegate(session, history, goal, size)];
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new BeerGlanceView(new BeerSession(new BeerHistory()), new BeerGoal())];
    }
}
