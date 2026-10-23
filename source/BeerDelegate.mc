import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// The counter page. A double tap adds a beer here too. DOWN and UP move
// through the pages: counter, stats, splits, damage, and around again. Splits
// and damage have nothing to show without a beer, so an empty session loops
// through only the counter and stats.
class BeerDelegate extends PageDelegate {
    // The longest gap between two taps that still counts as a double tap.
    private const DOUBLE_TAP_MS = 400;

    private var _session as BeerSession;
    private var _size as BeerSize;
    // When the last single tap happened, in System.getTimer() milliseconds.
    private var _lastTapAt as Number?;

    function initialize(session as BeerSession, history as BeerHistory, goal as BeerGoal, size as BeerSize) {
        PageDelegate.initialize(new BeerMenu(session, history, goal, size), method(:addBeer));
        _session = session;
        _size = size;
    }

    // A single tap does nothing, so brushing the screen doesn't add a beer.
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

    function addBeer() as Void {
        // The new beer closes a lap on the previous one, unless the session is
        // empty or has gone idle, in which case this beer starts a new session.
        var lastAt = _session.lastAt();
        var lap = null as LapView?;
        if (lastAt != null && !_session.isIdle()) {
            lap = new LapView(_session.count(), Time.now().subtract(lastAt).value(), _session.totalMl());
        }
        _session.add(_size.value());
        // A short buzz confirms the click without looking at the screen.
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 150)]);
        }
        if (lap != null) {
            WatchUi.pushView(lap, new LapDelegate(lap, method(:addBeer)), WatchUi.SLIDE_IMMEDIATE);
        } else {
            WatchUi.requestUpdate();
        }
    }

    function onNextPage() as Boolean {
        WatchUi.pushView(new StatsView(_session), new StatsDelegate(_session, _menu, _addBeer), WatchUi.SLIDE_UP);
        return true;
    }

    // The pages loop, so UP from the counter wraps around to the damage page.
    // Stats and splits go on the stack under it, so UP keeps going backwards
    // through the pages to the counter.
    function onPreviousPage() as Boolean {
        if (_session.count() == 0) {
            WatchUi.pushView(new StatsView(_session), new StatsDelegate(_session, _menu, _addBeer),
                WatchUi.SLIDE_DOWN);
            return true;
        }
        WatchUi.pushView(new StatsView(_session), new StatsDelegate(_session, _menu, _addBeer),
            WatchUi.SLIDE_IMMEDIATE);
        WatchUi.pushView(new SplitsView(_session), new SplitsDelegate(_session, _menu, _addBeer),
            WatchUi.SLIDE_IMMEDIATE);
        WatchUi.pushView(new DamageView(_session), new DamageDelegate(_menu, _addBeer), WatchUi.SLIDE_DOWN);
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

// The menu: undo, finish, history, size, goal and discard. Every page opens
// it, and closing it goes back to that page.
class BeerMenu {
    private var _session as BeerSession;
    private var _history as BeerHistory;
    private var _goal as BeerGoal;
    private var _size as BeerSize;

    function initialize(session as BeerSession, history as BeerHistory, goal as BeerGoal, size as BeerSize) {
        _session = session;
        _history = history;
        _goal = goal;
        _size = size;
    }

    function open() as Void {
        var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.AppName) as String});
        // With no beers there is nothing to undo or save.
        if (_session.count() > 0) {
            menu.addItem(item(Rez.Strings.Undo, null, :undo, Rez.Drawables.MenuUndo));
            menu.addItem(item(Rez.Strings.Finish, null, :end, Rez.Drawables.MenuEnd));
        }
        menu.addItem(item(Rez.Strings.History, null, :history, Rez.Drawables.MenuHistory));
        menu.addItem(item(Rez.Strings.Size, sizeLabel(_size.value()), :size, Rez.Drawables.MenuSize));
        menu.addItem(item(Rez.Strings.Goal, goalLabel(_goal.value()), :goal, Rez.Drawables.MenuGoal));
        menu.addItem(item(Rez.Strings.Discard, null, :discard, Rez.Drawables.MenuDiscard));
        WatchUi.pushView(menu, new BeerMenuDelegate(_session, _history, _goal, _size), WatchUi.SLIDE_UP);
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
    private var _history as BeerHistory;
    private var _goal as BeerGoal;
    private var _size as BeerSize;

    function initialize(session as BeerSession, history as BeerHistory, goal as BeerGoal, size as BeerSize) {
        Menu2InputDelegate.initialize();
        _session = session;
        _history = history;
        _goal = goal;
        _size = size;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :undo) {
            _session.undo();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :end) {
            confirm(Rez.Strings.EndConfirm, Rez.Drawables.MenuEnd, Graphics.COLOR_YELLOW, method(:finish));
        } else if (id == :history) {
            // The history takes the menu's place, so BACK goes to the page the
            // menu was opened from.
            var view = new HistoryView(_history);
            WatchUi.switchToView(view, new HistoryDelegate(view), WatchUi.SLIDE_LEFT);
        } else if (id == :goal) {
            WatchUi.pushView(new GoalPicker(_goal), new GoalPickerDelegate(_goal), WatchUi.SLIDE_LEFT);
        } else if (id == :size) {
            pushSizeMenu();
        } else if (id == :discard) {
            confirm(Rez.Strings.DiscardConfirm, Rez.Drawables.MenuDiscard, Graphics.COLOR_RED,
                _session.method(:discard));
        }
    }

    // An empty session is not saved, so it gets no saved alert.
    function finish() as Void {
        var saved = _session.count() > 0;
        _session.end();
        if (!saved) {
            return;
        }
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_SUCCESS);
        }
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(75, 300)]);
        }
        var view = new SavedView();
        WatchUi.pushView(view, new TimedAlertDelegate(view), WatchUi.SLIDE_IMMEDIATE);
    }

    // The question takes the menu's place, so answering it goes back to the
    // page the menu was opened from.
    private function confirm(question as ResourceId, icon as ResourceId, yesColor as Graphics.ColorType,
        action as Method() as Void) as Void {
        WatchUi.switchToView(new ConfirmView(question, icon, yesColor), new ConfirmDelegate(action),
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
