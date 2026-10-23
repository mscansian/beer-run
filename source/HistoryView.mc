import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// The history page: past sessions, newest first, PER_PAGE at a time. Each
// session shows as "Fri 18 Oct · 6 beers" over "21:10-01:40 · 2.8 L".
class HistoryView extends WatchUi.View {
    static const PER_PAGE = 3;

    private var _history as BeerHistory;
    private var _page as Number = 0;

    function initialize(history as BeerHistory) {
        View.initialize();
        _history = history;
    }

    function showLastPage() as Void {
        _page = pageCount() - 1;
    }

    function pageCount() as Number {
        var size = _history.entries().size();
        return size == 0 ? 1 : (size + PER_PAGE - 1) / PER_PAGE;
    }

    function page() as Number {
        return _page;
    }

    function setPage(page as Number) as Void {
        _page = page;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var entries = _history.entries();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, height / 8, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.History) as String, Graphics.TEXT_JUSTIFY_CENTER);

        if (entries.size() == 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height / 2, Graphics.FONT_SMALL,
                WatchUi.loadResource(Rez.Strings.HistoryEmpty) as String,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var rowHeight = height / 5;
        var first = _page * PER_PAGE;
        for (var i = 0; i < PER_PAGE && first + i < entries.size(); i++) {
            var entry = entries[first + i];
            var y = height * 3 / 10 + i * rowHeight;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_TINY, sessionLabel(entry[0], entry[2]),
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y + dc.getFontHeight(Graphics.FONT_TINY), Graphics.FONT_XTINY,
                sessionDetail(entry[0], entry[1], entry[3]), Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (pageCount() > 1) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height * 7 / 8, Graphics.FONT_XTINY, (_page + 1) + "/" + pageCount(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function sessionLabel(start as Number, count as Number) as String {
        var date = Gregorian.info(new Time.Moment(start), Time.FORMAT_MEDIUM);
        var beers = WatchUi.loadResource(count == 1 ? Rez.Strings.Beer : Rez.Strings.Beers) as String;
        return Lang.format("$1$ $2$ $3$ · $4$ $5$", [date.day_of_week, date.day, date.month, count, beers]);
    }

    private function sessionDetail(start as Number, end as Number, ml as Number) as String {
        return clockTime(start) + "-" + clockTime(end) + " · " + litresText(ml);
    }

    private function clockTime(time as Number) as String {
        var info = Gregorian.info(new Time.Moment(time), Time.FORMAT_SHORT);
        return info.hour.format("%02d") + ":" + info.min.format("%02d");
    }
}

// DOWN shows older sessions, UP newer ones. UP on the first page goes back to
// the stats page. DOWN on the last page wraps around to the counter, which
// sits under the stats page on the view stack.
class HistoryDelegate extends WatchUi.BehaviorDelegate {
    private var _view as HistoryView;
    private var _menu as BeerMenu;

    function initialize(view as HistoryView, menu as BeerMenu) {
        BehaviorDelegate.initialize();
        _view = view;
        _menu = menu;
    }

    function onMenu() as Boolean {
        _menu.open();
        return true;
    }

    function onNextPage() as Boolean {
        if (_view.page() < _view.pageCount() - 1) {
            _view.setPage(_view.page() + 1);
        } else {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_UP);
        }
        return true;
    }

    function onPreviousPage() as Boolean {
        if (_view.page() > 0) {
            _view.setPage(_view.page() - 1);
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
        return true;
    }
}
