import Toybox.Lang;

// Estimates when the alcohol from a list of beers will be gone, with the
// Widmark model and the Watson body water formula. Each beer enters the blood
// evenly over ABSORB_SECONDS, and the body clears a fixed amount per hour.
// People vary a lot, so this is a rough guess, never a reason to drive.
module BloodAlcohol {
    const ETHANOL_GRAMS_PER_ML = 0.789;
    // Blood is about 80% water.
    const BLOOD_WATER = 0.8;
    const ABSORB_SECONDS = 45 * 60;
    // In g/L per second. Most people clear 0.10 to 0.20 g/L per hour. A rate
    // near the slow end makes most people sober by the time shown.
    const CLEARED_PER_SECOND = 0.11 / 3600;
    // In g/L. Below this nobody feels it.
    const SOBER_LEVEL = 0.1;

    // When the level drops below SOBER_LEVEL, in seconds since the Unix epoch,
    // or null with no beers. The answer is never before the last beer is fully
    // absorbed.
    function soberAt(body as BodyProfile, beers as Array<Beer>) as Number? {
        if (beers.size() == 0) {
            return null;
        }
        var levelPerGram = BLOOD_WATER / body.bodyWaterLitres();
        // How fast each beer raises the level while it is being absorbed.
        var rates = [] as Array<Float>;
        // The level changes at a steady rate between these moments.
        var moments = [] as Array<Number>;
        for (var i = 0; i < beers.size(); i++) {
            var beer = beers[i];
            var grams = beer[1] * beer[2] / 1000.0 * ETHANOL_GRAMS_PER_ML;
            rates.add(grams * levelPerGram / ABSORB_SECONDS);
            moments.add(beer[0]);
            moments.add(beer[0] + ABSORB_SECONDS);
        }
        sort(moments);

        var level = 0.0;
        for (var i = 0; i + 1 < moments.size(); i++) {
            var from = moments[i];
            var rate = -CLEARED_PER_SECOND;
            for (var j = 0; j < beers.size(); j++) {
                if (beers[j][0] <= from && from < beers[j][0] + ABSORB_SECONDS) {
                    rate += rates[j];
                }
            }
            level += rate * (moments[i + 1] - from);
            if (level < 0) {
                level = 0.0;
            }
        }

        var absorbedAt = moments[moments.size() - 1];
        if (level <= SOBER_LEVEL) {
            return absorbedAt;
        }
        return absorbedAt + ((level - SOBER_LEVEL) / CLEARED_PER_SECOND).toNumber();
    }

    // Insertion sort. A night has a few dozen beers at most.
    function sort(values as Array<Number>) as Void {
        for (var i = 1; i < values.size(); i++) {
            var value = values[i];
            var j = i - 1;
            while (j >= 0 && values[j] > value) {
                values[j + 1] = values[j];
                j--;
            }
            values[j + 1] = value;
        }
    }
}
