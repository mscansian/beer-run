import Toybox.Lang;
import Toybox.WatchUi;

// The input every page shares: START adds a beer and MENU (hold UP) opens the
// menu. Each page adds its own UP and DOWN.
class PageDelegate extends WatchUi.BehaviorDelegate {
    protected var _menu as BeerMenu;
    protected var _addBeer as Method() as Void;

    function initialize(menu as BeerMenu, addBeer as Method() as Void) {
        BehaviorDelegate.initialize();
        _menu = menu;
        _addBeer = addBeer;
    }

    // The select behavior runs before onKey and onTap and fires for both START
    // and a tap, so it can't tell them apart. With no onSelect here, START
    // arrives as KEY_ENTER.
    function onKey(event as WatchUi.KeyEvent) as Boolean {
        if (event.getKey() == WatchUi.KEY_ENTER) {
            _addBeer.invoke();
            return true;
        }
        return false;
    }

    function onMenu() as Boolean {
        _menu.open();
        return true;
    }
}
