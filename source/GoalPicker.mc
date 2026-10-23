import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// A scroll wheel for the goal. The first value is "No goal", then 1 to
// BeerGoal.MAX. Values are the goal itself, with 0 standing for no goal.
class GoalPicker extends WatchUi.Picker {
    function initialize(goal as BeerGoal) {
        var current = goal.value();
        Picker.initialize({
            :title => new WatchUi.Text({
                :text => WatchUi.loadResource(Rez.Strings.Goal) as String,
                :color => Graphics.COLOR_WHITE,
                :font => Graphics.FONT_SMALL,
                :locX => WatchUi.LAYOUT_HALIGN_CENTER,
                :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
            }),
            :pattern => [new GoalFactory()],
            :defaults => [current == null ? 0 : current]
        });
    }

    // The picker draws on whatever is already on screen, so clear it to black
    // first like the other pages.
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class GoalFactory extends WatchUi.PickerFactory {
    function initialize() {
        PickerFactory.initialize();
    }

    function getSize() as Number {
        return BeerGoal.MAX + 1;
    }

    function getValue(index as Number) as Object? {
        return index;
    }

    function getDrawable(index as Number, isSelected as Boolean) as WatchUi.Drawable? {
        var isNoGoal = index == 0;
        return new WatchUi.Text({
            :text => isNoGoal ? WatchUi.loadResource(Rez.Strings.NoGoal) as String : index.toString(),
            :color => Graphics.COLOR_YELLOW,
            :font => isNoGoal ? Graphics.FONT_MEDIUM : Graphics.FONT_NUMBER_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }
}

class GoalPickerDelegate extends WatchUi.PickerDelegate {
    private var _goal as BeerGoal;

    function initialize(goal as BeerGoal) {
        PickerDelegate.initialize();
        _goal = goal;
    }

    function onAccept(values as Array) as Boolean {
        var value = values[0] as Number;
        _goal.set(value == 0 ? null : value);
        // Close both the picker and the main menu, back to the page it was
        // opened from.
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
