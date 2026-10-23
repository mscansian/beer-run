import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// START (or a double tap) adds a beer. DOWN and UP move through the pages: counter,
// stats, history, and around again. MENU (hold UP) opens the menu from any
// page.
class BeerDelegate extends WatchUi.BehaviorDelegate {
    // The longest gap between two taps that still counts as a double tap.
    private const DOUBLE_TAP_MS = 400;

    private var _session as BeerSession;
    private var _history as BeerHistory;
    private var _size as BeerSize;
    private var _menu as BeerMenu;
    // When the last single tap happened, in System.getTimer() milliseconds.
    private var _lastTapAt as Number?;

    function initialize(session as BeerSession, history as BeerHistory, goal as BeerGoal, size as BeerSize) {
        BehaviorDelegate.initialize();
        _session = session;
        _history = history;
        _size = size;
        _menu = new BeerMenu(session, goal, size);
    }

    function onSelect() as Boolean {
        addBeer();
        return true;
    }

    // A single tap does nothing, so brushing the screen doesn't add a beer.
    // Handling the tap here keeps it from also triggering onSelect.
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var now = System.getTimer();
        if (_lastTapAt != null && now - _lastTapAt <= DOUBLE_TAP_MS) {
            _lastTapAt = null;
            addBeer();
        } else {
            _lastTapAt = now;
        }
        return true;
    }

    private function addBeer() as Void {
        _session.add(_size.value());
        // A short buzz confirms the click without looking at the screen.
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 150)]);
        }
        WatchUi.requestUpdate();
    }

    function onNextPage() as Boolean {
        WatchUi.pushView(new StatsView(_session), new StatsDelegate(_history, _menu), WatchUi.SLIDE_UP);
        return true;
    }

    // The pages loop, so UP from the counter wraps around to the end of the
    // history. Stats goes on the stack under it, so UP keeps going backwards
    // through the pages to the counter.
    function onPreviousPage() as Boolean {
        WatchUi.pushView(new StatsView(_session), new StatsDelegate(_history, _menu), WatchUi.SLIDE_IMMEDIATE);
        var history = new HistoryView(_history);
        history.showLastPage();
        WatchUi.pushView(history, new HistoryDelegate(history, _menu), WatchUi.SLIDE_DOWN);
        return true;
    }

    function onMenu() as Boolean {
        _menu.open();
        return true;
    }
}

// The menu label of a goal, e.g. "9 beers", or "No goal".
function goalLabel(goal as Number?) as String {
    if (goal == null) {
        return WatchUi.loadResource(Rez.Strings.NoGoal) as String;
    }
    return goal + " " + WatchUi.loadResource(goal == 1 ? Rez.Strings.Beer : Rez.Strings.Beers) as String;
}

// The menu: undo, end session, size, goal and discard. Every page opens it,
// and closing it goes back to that page.
class BeerMenu {
    private var _session as BeerSession;
    private var _goal as BeerGoal;
    private var _size as BeerSize;

    function initialize(session as BeerSession, goal as BeerGoal, size as BeerSize) {
        _session = session;
        _goal = goal;
        _size = size;
    }

    function open() as Void {
        var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.AppName) as String});
        menu.addItem(item(Rez.Strings.Undo, null, :undo, Rez.Drawables.MenuUndo));
        menu.addItem(item(Rez.Strings.Finish, null, :end, Rez.Drawables.MenuEnd));
        menu.addItem(item(Rez.Strings.Size, sizeLabel(_size.value()), :size, Rez.Drawables.MenuSize));
        menu.addItem(item(Rez.Strings.Goal, goalLabel(_goal.value()), :goal, Rez.Drawables.MenuGoal));
        menu.addItem(item(Rez.Strings.Discard, null, :discard, Rez.Drawables.MenuDiscard));
        WatchUi.pushView(menu, new BeerMenuDelegate(_session, _goal, _size), WatchUi.SLIDE_UP);
    }

    private function item(label as ResourceId, subLabel as String?, id as Symbol, icon as ResourceId)
        as WatchUi.IconMenuItem {
        return new WatchUi.IconMenuItem(WatchUi.loadResource(label) as String, subLabel, id,
            new MenuIcon(icon), {:alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_LEFT});
    }
}

// A menu icon drawn in the middle of the space the menu gives it.
class MenuIcon extends WatchUi.Drawable {
    private var _bitmap as WatchUi.BitmapResource;

    function initialize(rezId as ResourceId) {
        Drawable.initialize({});
        _bitmap = WatchUi.loadResource(rezId) as WatchUi.BitmapResource;
    }

    function draw(dc as Graphics.Dc) as Void {
        dc.drawBitmap((dc.getWidth() - _bitmap.getWidth()) / 2, (dc.getHeight() - _bitmap.getHeight()) / 2,
            _bitmap);
    }
}

class BeerMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _session as BeerSession;
    private var _goal as BeerGoal;
    private var _size as BeerSize;

    function initialize(session as BeerSession, goal as BeerGoal, size as BeerSize) {
        Menu2InputDelegate.initialize();
        _session = session;
        _goal = goal;
        _size = size;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :undo) {
            _session.undo();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :end) {
            confirm(Rez.Strings.EndConfirm, _session.method(:end));
        } else if (id == :goal) {
            WatchUi.pushView(new GoalPicker(_goal), new GoalPickerDelegate(_goal), WatchUi.SLIDE_LEFT);
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
        // Item ids are the size in ml.
        var current = _size.value();
        for (var i = 0; i < BeerSize.OPTIONS.size(); i++) {
            var ml = BeerSize.OPTIONS[i];
            menu.addItem(new WatchUi.MenuItem(sizeLabel(ml), null, ml, null));
            if (ml == current) {
                menu.setFocus(i);
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
        _size.set(item.getId() as Number);
        // Close both the size list and the main menu, back to the page it was
        // opened from.
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
