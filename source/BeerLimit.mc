import Toybox.Application;
import Toybox.Lang;

// The most beers the user wants in a session, or null for no limit.
(:glance)
class BeerLimit {
    static const MAX = 30;

    private const STORAGE_KEY = "limit";

    private var _value as Number?;

    function initialize() {
        _value = Application.Storage.getValue(STORAGE_KEY) as Number?;
    }

    function value() as Number? {
        return _value;
    }

    function set(value as Number?) as Void {
        _value = value;
        if (value == null) {
            Application.Storage.deleteValue(STORAGE_KEY);
        } else {
            Application.Storage.setValue(STORAGE_KEY, value);
        }
    }
}
