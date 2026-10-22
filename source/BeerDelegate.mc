import Toybox.Attention;
import Toybox.Lang;
import Toybox.WatchUi;

// START (or a tap) adds a beer. MENU (hold UP) opens undo, limit and reset.
class BeerDelegate extends WatchUi.BehaviorDelegate {
    private var _session as BeerSession;
    private var _limit as BeerLimit;

    function initialize(session as BeerSession, limit as BeerLimit) {
        BehaviorDelegate.initialize();
        _session = session;
        _limit = limit;
    }

    function onSelect() as Boolean {
        _session.add();
        // A short buzz confirms the click without looking at the screen.
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 150)]);
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() as Boolean {
        var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.AppName) as String});
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Undo) as String, null, :undo, null));
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Limit) as String,
            limitLabel(_limit.value()), :limit, null));
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Reset) as String, null, :reset, null));
        WatchUi.pushView(menu, new BeerMenuDelegate(_session, _limit), WatchUi.SLIDE_UP);
        return true;
    }
}

function limitLabel(limit as Number?) as String {
    return limit == null ? WatchUi.loadResource(Rez.Strings.NoLimit) as String : limit.toString();
}

class BeerMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _session as BeerSession;
    private var _limit as BeerLimit;

    function initialize(session as BeerSession, limit as BeerLimit) {
        Menu2InputDelegate.initialize();
        _session = session;
        _limit = limit;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :undo) {
            _session.undo();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :limit) {
            WatchUi.pushView(new LimitPicker(_limit), new LimitPickerDelegate(_limit), WatchUi.SLIDE_LEFT);
        } else if (id == :reset) {
            WatchUi.switchToView(
                new WatchUi.Confirmation(WatchUi.loadResource(Rez.Strings.ResetConfirm) as String),
                new ResetConfirmationDelegate(_session),
                WatchUi.SLIDE_IMMEDIATE);
        }
    }

}

class ResetConfirmationDelegate extends WatchUi.ConfirmationDelegate {
    private var _session as BeerSession;

    function initialize(session as BeerSession) {
        ConfirmationDelegate.initialize();
        _session = session;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _session.reset();
        }
        return true;
    }
}
