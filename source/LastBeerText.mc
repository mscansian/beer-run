import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// How long ago the last beer was, e.g. "last one 25 min ago".
(:glance)
function lastBeerText(lastAt as Time.Moment) as String {
    var minutes = Time.now().subtract(lastAt).value() / 60;
    if (minutes < 1) {
        return WatchUi.loadResource(Rez.Strings.LastJustNow) as String;
    }
    if (minutes < 60) {
        return Lang.format(WatchUi.loadResource(Rez.Strings.LastMinutes) as String, [minutes]);
    }
    return Lang.format(WatchUi.loadResource(Rez.Strings.LastHours) as String,
        [minutes / 60, (minutes % 60).format("%02d")]);
}
