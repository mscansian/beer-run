import Toybox.Attention;
import Toybox.Lang;
import Toybox.WatchUi;

// START (or a tap) adds a beer. DOWN and UP move through the pages: counter,
// stats, history, and around again. MENU (hold UP) opens undo, end session,
// limit, size and discard.
class BeerDelegate extends WatchUi.BehaviorDelegate {
    private var _session as BeerSession;
    private var _history as BeerHistory;
    private var _limit as BeerLimit;
    private var _size as BeerSize;

    function initialize(session as BeerSession, history as BeerHistory, limit as BeerLimit, size as BeerSize) {
        BehaviorDelegate.initialize();
        _session = session;
        _history = history;
        _limit = limit;
        _size = size;
    }

    function onSelect() as Boolean {
        var ml = _size.value();
        _session.add(ml == null ? 0 : ml);
        // A short buzz confirms the click without looking at the screen.
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 150)]);
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() as Boolean {
        WatchUi.pushView(new StatsView(_session), new StatsDelegate(_history), WatchUi.SLIDE_UP);
        return true;
    }

    // The pages loop, so UP from the counter wraps around to the end of the
    // history. Stats goes on the stack under it, so UP keeps going backwards
    // through the pages to the counter.
    function onPreviousPage() as Boolean {
        WatchUi.pushView(new StatsView(_session), new StatsDelegate(_history), WatchUi.SLIDE_IMMEDIATE);
        var history = new HistoryView(_history);
        history.showLastPage();
        WatchUi.pushView(history, new HistoryDelegate(history), WatchUi.SLIDE_DOWN);
        return true;
    }

    function onMenu() as Boolean {
        var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.AppName) as String});
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Undo) as String, null, :undo, null));
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.EndSession) as String, null, :end, null));
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Limit) as String,
            limitLabel(_limit.value()), :limit, null));
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Size) as String,
            sizeLabel(_size.value()), :size, null));
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Discard) as String, null, :discard, null));
        WatchUi.pushView(menu, new BeerMenuDelegate(_session, _limit, _size), WatchUi.SLIDE_UP);
        return true;
    }
}

function limitLabel(limit as Number?) as String {
    return limit == null ? WatchUi.loadResource(Rez.Strings.NoLimit) as String : limit.toString();
}

class BeerMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _session as BeerSession;
    private var _limit as BeerLimit;
    private var _size as BeerSize;

    function initialize(session as BeerSession, limit as BeerLimit, size as BeerSize) {
        Menu2InputDelegate.initialize();
        _session = session;
        _limit = limit;
        _size = size;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :undo) {
            _session.undo();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :end) {
            confirm(Rez.Strings.EndConfirm, _session.method(:end));
        } else if (id == :limit) {
            WatchUi.pushView(new LimitPicker(_limit), new LimitPickerDelegate(_limit), WatchUi.SLIDE_LEFT);
        } else if (id == :size) {
            pushSizeMenu();
        } else if (id == :discard) {
            confirm(Rez.Strings.DiscardConfirm, _session.method(:discard));
        }
    }

    private function confirm(question as ResourceId, action as Method() as Void) as Void {
        WatchUi.switchToView(
            new WatchUi.Confirmation(WatchUi.loadResource(question) as String),
            new ConfirmActionDelegate(action),
            WatchUi.SLIDE_IMMEDIATE);
    }

    private function pushSizeMenu() as Void {
        var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.Size) as String});
        // Item ids are the size in ml, with 0 standing for off.
        menu.addItem(new WatchUi.MenuItem(sizeLabel(null), null, 0, null));
        var current = _size.value();
        for (var i = 0; i < BeerSize.OPTIONS.size(); i++) {
            var ml = BeerSize.OPTIONS[i];
            menu.addItem(new WatchUi.MenuItem(sizeLabel(ml), null, ml, null));
            if (ml == current) {
                menu.setFocus(i + 1);
            }
        }
        WatchUi.pushView(menu, new SizeMenuDelegate(_size), WatchUi.SLIDE_LEFT);
    }
}

class SizeMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _size as BeerSize;

    function initialize(size as BeerSize) {
        Menu2InputDelegate.initialize();
        _size = size;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var ml = item.getId() as Number;
        _size.set(ml == 0 ? null : ml);
        // Close both the size list and the main menu, back to the counter.
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

// Runs the action only when the user answers Yes.
class ConfirmActionDelegate extends WatchUi.ConfirmationDelegate {
    private var _action as Method() as Void;

    function initialize(action as Method() as Void) {
        ConfirmationDelegate.initialize();
        _action = action;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _action.invoke();
        }
        return true;
    }
}
