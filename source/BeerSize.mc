import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// The size in ml that each new beer is counted as. It starts as a pint.
(:glance)
class BeerSize {
    static const OPTIONS = [330, 350, 473, 500, 600, 1000] as Array<Number>;
    static const PINT = 473;

    private const STORAGE_KEY = "size";

    private var _ml as Number;

    function initialize() {
        var stored = Application.Storage.getValue(STORAGE_KEY) as Number?;
        _ml = stored != null ? stored : PINT;
    }

    function value() as Number {
        return _ml;
    }

    function set(ml as Number) as Void {
        _ml = ml;
        Application.Storage.setValue(STORAGE_KEY, ml);
    }
}

// The short name of a size, e.g. "Pint".
function sizeName(ml as Number) as String {
    switch (ml) {
        case 330:
            return WatchUi.loadResource(Rez.Strings.SizeSmall) as String;
        case 350:
            return WatchUi.loadResource(Rez.Strings.SizeCan) as String;
        case 473:
            return WatchUi.loadResource(Rez.Strings.SizePint) as String;
        case 500:
            return WatchUi.loadResource(Rez.Strings.SizeHalf) as String;
        case 600:
            return WatchUi.loadResource(Rez.Strings.SizeBottle) as String;
        case 1000:
            return WatchUi.loadResource(Rez.Strings.SizeMass) as String;
    }
    return ml + " ml";
}

// The menu label of a size, e.g. "Pint 473 ml".
function sizeLabel(ml as Number) as String {
    return sizeName(ml) + " " + ml + " ml";
}

// A volume in litres with one decimal, e.g. "1.9 L".
function litresText(ml as Number) as String {
    return (ml / 1000.0).format("%.1f") + " L";
}
