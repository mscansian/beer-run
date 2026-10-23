import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// The beers in the current drinking session. Every change is written to
// storage right away, so the session survives closing the app or a reboot.
// A session ends when the user ends it, or once IDLE_SECONDS pass without a
// beer; either way it moves to the history.
(:glance)
class BeerSession {
    static const IDLE_SECONDS = 8 * 60 * 60;

    private const STORAGE_KEY = "session";
    // Earlier versions stored only the time of each beer under this key.
    private const TIMES_ONLY_KEY = "beers";

    private var _history as BeerHistory;
    // Oldest first. Each beer is [time, ml]: seconds since the Unix epoch, and
    // its size in ml.
    private var _beers as Array<[Number, Number]>;

    function initialize(history as BeerHistory) {
        _history = history;
        var stored = Application.Storage.getValue(STORAGE_KEY);
        _beers = stored != null ? stored as Array<[Number, Number]> : loadTimesOnly();
        // Earlier versions saved beers without a size as 0 ml. They count as
        // pints.
        for (var i = 0; i < _beers.size(); i++) {
            if (_beers[i][1] == 0) {
                _beers[i][1] = BeerSize.PINT;
            }
        }
    }

    function count() as Number {
        return _beers.size();
    }

    // The time of the first beer, or null when the session is empty.
    function firstAt() as Time.Moment? {
        if (_beers.size() == 0) {
            return null;
        }
        return new Time.Moment(_beers[0][0]);
    }

    // The time of the most recent beer, or null when the session is empty.
    function lastAt() as Time.Moment? {
        if (_beers.size() == 0) {
            return null;
        }
        return new Time.Moment(_beers[_beers.size() - 1][0]);
    }

    // How long each finished beer took, oldest first: the time from one beer
    // to the next. The newest beer is still in progress, so it has no lap yet.
    function lapSeconds() as Array<Number> {
        var laps = [] as Array<Number>;
        for (var i = 1; i < _beers.size(); i++) {
            laps.add(_beers[i][0] - _beers[i - 1][0]);
        }
        return laps;
    }

    function totalMl() as Number {
        var total = 0;
        for (var i = 0; i < _beers.size(); i++) {
            total += _beers[i][1];
        }
        return total;
    }

    // True when the last beer was long enough ago that the next one starts a
    // new session.
    function isIdle() as Boolean {
        var lastAt = lastAt();
        return lastAt != null && Time.now().subtract(lastAt).value() >= IDLE_SECONDS;
    }

    function endIfIdle() as Void {
        if (isIdle()) {
            end();
        }
    }

    function add(ml as Number) as Void {
        endIfIdle();
        _beers.add([Time.now().value(), ml]);
        save();
    }

    function undo() as Void {
        if (_beers.size() > 0) {
            _beers = _beers.slice(0, -1);
            save();
        }
    }

    // Moves the session to the history and starts an empty one.
    function end() as Void {
        if (_beers.size() > 0) {
            _history.add(_beers[0][0], _beers[_beers.size() - 1][0], _beers.size(), totalMl());
        }
        discard();
    }

    // Throws the session away without saving it to the history.
    function discard() as Void {
        _beers = [] as Array<[Number, Number]>;
        save();
    }

    private function loadTimesOnly() as Array<[Number, Number]> {
        var times = Application.Storage.getValue(TIMES_ONLY_KEY) as Array<Number>?;
        var beers = [] as Array<[Number, Number]>;
        if (times != null) {
            for (var i = 0; i < times.size(); i++) {
                beers.add([times[i], BeerSize.PINT]);
            }
        }
        return beers;
    }

    private function save() as Void {
        Application.Storage.setValue(STORAGE_KEY, _beers as Array<Application.Storage.ValueType>);
        Application.Storage.deleteValue(TIMES_ONLY_KEY);
    }
}
