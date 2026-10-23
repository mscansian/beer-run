import Toybox.Lang;

// A duration like a stopwatch shows it: "4:07" under an hour, "1:04:07" from
// an hour on.
function clockDuration(seconds as Number) as String {
    var hours = seconds / 3600;
    var minutes = (seconds / 60) % 60;
    var secs = (seconds % 60).format("%02d");
    if (hours > 0) {
        return hours + ":" + minutes.format("%02d") + ":" + secs;
    }
    return minutes + ":" + secs;
}

// A duration spelled out in units, e.g. "40s", "12m5s" or "3h5m10s".
function durationText(seconds as Number) as String {
    var hours = seconds / 3600;
    var minutes = (seconds / 60) % 60;
    var secs = seconds % 60;
    if (hours > 0) {
        return hours + "h" + minutes + "m" + secs + "s";
    }
    if (minutes > 0) {
        return minutes + "m" + secs + "s";
    }
    return secs + "s";
}
