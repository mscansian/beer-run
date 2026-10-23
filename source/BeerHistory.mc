import Toybox.Application;
import Toybox.Lang;

// Past drinking sessions, newest first. Only the latest MAX_ENTRIES are kept.
(:glance)
class BeerHistory {
    static const MAX_ENTRIES = 50;

    private const STORAGE_KEY = "history";

    // Each entry is [start, end, count, ml]: the times of the first and last
    // beer in seconds since the Unix epoch, the number of beers, and the total
    // volume in ml.
    private var _entries as Array<[Number, Number, Number, Number]>;

    function initialize() {
        var stored = Application.Storage.getValue(STORAGE_KEY);
        _entries = stored != null
            ? stored as Array<[Number, Number, Number, Number]>
            : [] as Array<[Number, Number, Number, Number]>;
        // Earlier versions saved sessions without sizes as 0 ml. Their beers
        // count as pints.
        for (var i = 0; i < _entries.size(); i++) {
            if (_entries[i][3] == 0) {
                _entries[i][3] = _entries[i][2] * BeerSize.PINT;
            }
        }
    }

    function entries() as Array<[Number, Number, Number, Number]> {
        return _entries;
    }

    function add(start as Number, end as Number, count as Number, ml as Number) as Void {
        var entries = [[start, end, count, ml]] as Array<[Number, Number, Number, Number]>;
        entries.addAll(_entries);
        _entries = entries.size() > MAX_ENTRIES ? entries.slice(0, MAX_ENTRIES) : entries;
        Application.Storage.setValue(STORAGE_KEY, _entries as Array<Application.Storage.ValueType>);
    }
}
