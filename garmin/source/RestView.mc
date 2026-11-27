// Descanso entre series: cuenta atrás, vibra al terminar y pasa a la siguiente serie.
// START = empezar ya, UP = +15 s, DOWN = -15 s.
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class RestView extends WatchUi.View {

    private var _idx as Number;
    private var _end as Number;
    private var _timer as Timer.Timer;
    private var _gone as Boolean = false;

    public function initialize(index as Number, seconds as Number) {
        View.initialize();
        _idx = index;
        _end = Time.now().value() + seconds;
        _timer = new Timer.Timer();
    }

    public function onShow() as Void {
        _timer.start(method(:tick), 1000, true);
    }

    public function onHide() as Void {
        _timer.stop();
    }

    public function left() as Number {
        var l = _end - Time.now().value();
        return l > 0 ? l : 0;
    }

    public function add(seconds as Number) as Void {
        _end += seconds;
        WatchUi.requestUpdate();
    }

    public function tick() as Void {
        if (left() <= 0) {
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(100, 400), new Attention.VibeProfile(0, 200), new Attention.VibeProfile(100, 400)]);
            }
            if (Attention has :playTone) {
                Attention.playTone(Attention.TONE_ALERT_HI);
            }
            next();
            return;
        }
        WatchUi.requestUpdate();
    }

    //! A la siguiente serie.
    public function next() as Void {
        if (_gone) {
            return;
        }
        _gone = true;
        _timer.stop();
        getStore().flush();
        var v = new SetView(_idx);
        WatchUi.switchToView(v, new SetDelegate(v), WatchUi.SLIDE_LEFT);
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        var st = getStore();
        var e = st.exs[_idx];
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(GRIS, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.16, Graphics.FONT_XTINY, "DESCANSO", Graphics.TEXT_JUSTIFY_CENTER);
        var l = left();
        var txt = (l / 60).toString() + ":" + (l % 60).format("%02d");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.27, Graphics.FONT_NUMBER_HOT, txt, Graphics.TEXT_JUSTIFY_CENTER);
        var n = st.nextSet(e);
        if (n >= 0) {
            dc.setColor(LILA, Graphics.COLOR_TRANSPARENT);
            var info = "Siguiente: serie " + (n + 1).toString();
            var kg = st.num(e["kg"] as Object?, 0.0);
            if (kg > 0) {
                info += " · " + st.kgText(e, kg);
            }
            dc.drawText(w / 2, h * 0.62, Graphics.FONT_XTINY, info, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(GRIS, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.74, Graphics.FONT_XTINY, "START  Empezar ya", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class RestDelegate extends WatchUi.BehaviorDelegate {

    private var _view as RestView;

    public function initialize(view as RestView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    public function onSelect() as Boolean {
        _view.next();
        return true;
    }

    public function onPreviousPage() as Boolean {
        _view.add(15);
        return true;
    }

    public function onNextPage() as Boolean {
        _view.add(-15);
        return true;
    }

    public function onBack() as Boolean {
        _view.next();
        return true;
    }
}
