import Toybox.Application;
import Toybox.Lang;

// How many beers the user aims for in a session, or null for no goal.
(:glance)
class BeerGoal {
    static const MAX = 30;

    // The goal used to be called the limit, and is still saved under that name.
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
