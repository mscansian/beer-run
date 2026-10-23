import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// The playful line under the beer debt. The debt falls into a band by race
// distance, and each band has a few lines. The line is picked at random when
// the debt moves into another band, and is saved, so it stays the same while
// the debt stays in its band.
module DebtLine {
    const STORAGE_KEY = "debtLine";
    // Where each band starts, in km. The first band starts at 0.
    const BAND_STARTS_KM = [3, 7, 15, 30, 50] as Array<Number>;

    // `marathon` fills in the lines that mention it, e.g. "26.2" or "42.2".
    function text(km as Float, marathon as String) as String {
        var band = bandOf(km);
        var stored = Application.Storage.getValue(STORAGE_KEY) as [Number, Number]?;
        var lines = linesOf(band);
        var index = 0;
        if (stored != null && stored[0] == band) {
            index = stored[1];
        } else {
            index = Math.rand().abs() % lines.size();
            Application.Storage.setValue(STORAGE_KEY, [band, index] as Array<Application.Storage.ValueType>);
        }
        return Lang.format(WatchUi.loadResource(lines[index]) as String, [marathon]);
    }

    function bandOf(km as Float) as Number {
        var band = 0;
        while (band < BAND_STARTS_KM.size() && km >= BAND_STARTS_KM[band]) {
            band++;
        }
        return band;
    }

    function linesOf(band as Number) as Array<ResourceId> {
        switch (band) {
            case 0:
                return [Rez.Strings.DebtBlock1, Rez.Strings.DebtBlock2, Rez.Strings.DebtBlock3,
                    Rez.Strings.DebtBlock4, Rez.Strings.DebtBlock5];
            case 1:
                return [Rez.Strings.Debt5k1, Rez.Strings.Debt5k2, Rez.Strings.Debt5k3,
                    Rez.Strings.Debt5k4, Rez.Strings.Debt5k5];
            case 2:
                return [Rez.Strings.Debt10k1, Rez.Strings.Debt10k2, Rez.Strings.Debt10k3,
                    Rez.Strings.Debt10k4, Rez.Strings.Debt10k5];
            case 3:
                return [Rez.Strings.DebtHalf1, Rez.Strings.DebtHalf2, Rez.Strings.DebtHalf3,
                    Rez.Strings.DebtHalf4, Rez.Strings.DebtHalf5];
            case 4:
                return [Rez.Strings.DebtMarathon1, Rez.Strings.DebtMarathon2, Rez.Strings.DebtMarathon3,
                    Rez.Strings.DebtMarathon4, Rez.Strings.DebtMarathon5];
        }
        return [Rez.Strings.DebtUltra1, Rez.Strings.DebtUltra2, Rez.Strings.DebtUltra3,
            Rez.Strings.DebtUltra4, Rez.Strings.DebtUltra5];
    }
}
