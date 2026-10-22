import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// A scroll wheel for the limit. The first value is "No limit", then 1 to
// BeerLimit.MAX. Values are the limit itself, with 0 standing for no limit.
class LimitPicker extends WatchUi.Picker {
    function initialize(limit as BeerLimit) {
        var current = limit.value();
        Picker.initialize({
            :title => new WatchUi.Text({
                :text => WatchUi.loadResource(Rez.Strings.Limit) as String,
                :color => Graphics.COLOR_WHITE,
                :font => Graphics.FONT_SMALL,
                :locX => WatchUi.LAYOUT_HALIGN_CENTER,
                :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
            }),
            :pattern => [new LimitFactory()],
            :defaults => [current == null ? 0 : current]
        });
    }
}

class LimitFactory extends WatchUi.PickerFactory {
    function initialize() {
        PickerFactory.initialize();
    }

    function getSize() as Number {
        return BeerLimit.MAX + 1;
    }

    function getValue(index as Number) as Object? {
        return index;
    }

    function getDrawable(index as Number, isSelected as Boolean) as WatchUi.Drawable? {
        var isNoLimit = index == 0;
        return new WatchUi.Text({
            :text => isNoLimit ? WatchUi.loadResource(Rez.Strings.NoLimit) as String : index.toString(),
            :color => Graphics.COLOR_YELLOW,
            :font => isNoLimit ? Graphics.FONT_MEDIUM : Graphics.FONT_NUMBER_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }
}

class LimitPickerDelegate extends WatchUi.PickerDelegate {
    private var _limit as BeerLimit;

    function initialize(limit as BeerLimit) {
        PickerDelegate.initialize();
        _limit = limit;
    }

    function onAccept(values as Array) as Boolean {
        var value = values[0] as Number;
        _limit.set(value == 0 ? null : value);
        // Close both the picker and the main menu, back to the counter.
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
