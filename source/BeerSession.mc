import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// The beers in the current drinking session, as the time each one was added.
// Every change is written to storage right away, so the session survives
// closing the app or a reboot.
(:glance)
class BeerSession {
    private const STORAGE_KEY = "beers";

    // Seconds since the Unix epoch, oldest first.
    private var _times as Array<Number>;

    function initialize() {
        var stored = Application.Storage.getValue(STORAGE_KEY);
        _times = stored != null ? stored as Array<Number> : [] as Array<Number>;
    }

    function count() as Number {
        return _times.size();
    }

    // The time of the most recent beer, or null when the session is empty.
    function lastAt() as Time.Moment? {
        if (_times.size() == 0) {
            return null;
        }
        return new Time.Moment(_times[_times.size() - 1]);
    }

    function add() as Void {
        _times.add(Time.now().value());
        save();
    }

    function undo() as Void {
        if (_times.size() > 0) {
            _times = _times.slice(0, -1);
            save();
        }
    }

    function reset() as Void {
        _times = [] as Array<Number>;
        save();
    }

    private function save() as Void {
        Application.Storage.setValue(STORAGE_KEY, _times as Array<Application.Storage.ValueType>);
    }
}
