import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// One beer: [time, ml, abv]. The time is in seconds since the Unix epoch,
// and abv is in tenths of a percent (50 is 5%).
typedef Beer as [Number, Number, Number];

// The beers in the current drinking session. Every change is written to
// storage right away, so the session survives closing the app or a reboot.
// A session ends when the user ends it, or once IDLE_SECONDS pass without a
// beer; either way it moves to the history. The goal belongs to one session,
// so ending a session with beers in it clears the goal. The beers of the
// last finished session are also saved on their own, since the history keeps
// only totals.
(:glance)
class BeerSession {
    static const IDLE_SECONDS = 8 * 60 * 60;
    // Every beer counts as 5% ABV. It is saved with each beer so it can become
    // a setting later.
    static const ABV = 50;

    private const STORAGE_KEY = "session";
    private const FINISHED_KEY = "finished";
    // Earlier versions stored only the time of each beer under this key.
    private const TIMES_ONLY_KEY = "beers";

    private var _history as BeerHistory;
    private var _goal as BeerGoal;
    // Oldest first.
    private var _beers as Array<Beer>;

    function initialize(history as BeerHistory, goal as BeerGoal) {
        _history = history;
        _goal = goal;
        var stored = Application.Storage.getValue(STORAGE_KEY) as Array<Array<Number?>>?;
        _beers = stored != null ? upgrade(stored) : loadTimesOnly();
    }

    // Earlier versions saved each beer as [time, ml], and before that with a
    // size of 0 ml. Those beers count as 5% pints.
    private function upgrade(stored as Array<Array<Number?>>) as Array<Beer> {
        var beers = [] as Array<Beer>;
        for (var i = 0; i < stored.size(); i++) {
            var beer = stored[i];
            if (beer.size() == 3) {
                beers.add(beer as Beer);
            } else {
                var ml = beer[1] as Number;
                beers.add([beer[0] as Number, ml == 0 ? BeerSize.PINT : ml, ABV]);
            }
        }
        return beers;
    }

    // Oldest first.
    function beers() as Array<Beer> {
        return _beers;
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

    // Nothing records when the user stopped drinking, so an idle session ends
    // at its last beer.
    function endIfIdle() as Void {
        if (isIdle()) {
            endAt(_beers[_beers.size() - 1][0]);
        }
    }

    function add(ml as Number) as Void {
        endIfIdle();
        _beers.add([Time.now().value(), ml, ABV]);
        save();
    }

    function undo() as Void {
        if (_beers.size() > 0) {
            _beers = _beers.slice(0, -1);
            save();
        }
    }

    // Finishes the session now: moves it to the history and starts an empty one.
    function end() as Void {
        endAt(Time.now().value());
    }

    // `end` is in seconds since the Unix epoch.
    private function endAt(end as Number) as Void {
        if (_beers.size() > 0) {
            _history.add(_beers[0][0], end, _beers.size(), totalMl());
            Application.Storage.setValue(FINISHED_KEY, _beers as Array<Application.Storage.ValueType>);
        }
        discard();
    }

    // Throws the session away without saving it to the history.
    function discard() as Void {
        if (_beers.size() > 0) {
            _goal.set(null);
        }
        _beers = [] as Array<Beer>;
        save();
    }

    private function loadTimesOnly() as Array<Beer> {
        var times = Application.Storage.getValue(TIMES_ONLY_KEY) as Array<Number>?;
        var beers = [] as Array<Beer>;
        if (times != null) {
            for (var i = 0; i < times.size(); i++) {
                beers.add([times[i], BeerSize.PINT, ABV]);
            }
        }
        return beers;
    }

    private function save() as Void {
        Application.Storage.setValue(STORAGE_KEY, _beers as Array<Application.Storage.ValueType>);
        Application.Storage.deleteValue(TIMES_ONLY_KEY);
    }
}
