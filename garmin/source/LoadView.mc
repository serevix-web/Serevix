// Pantalla de inicio: vincula el reloj con tu cuenta y carga la rutina de hoy.
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

const LILA = 0xB79BFF;
const GRIS = 0x8C8A99;

class LoadView extends WatchUi.View {

    private var _msg as String = "Conectando…";
    private var _code as String? = null;
    private var _timer as Timer.Timer? = null;
    private var _busy as Boolean = false;

    public function initialize() {
        View.initialize();
    }

    public function onShow() as Void {
        start();
    }

    public function onHide() as Void {
        stopTimer();
    }

    //! Empieza (o reintenta) la conexión.
    public function start() as Void {
        if (_busy) {
            return;
        }
        _busy = true;
        var tok = Application.Storage.getValue("token");
        if (tok == null) {
            _code = null;
            _msg = "Pidiendo código…";
            Api.post({ "action" => "pair-start", "name" => "Forerunner 170" }, method(:onPair));
        } else {
            _msg = "Conectando con Serevix…";
            Api.post({ "action" => "status" }, method(:onStatus));
        }
        WatchUi.requestUpdate();
    }

    public function onPair(code as Number, data as Dictionary or String or Null) as Void {
        _busy = false;
        if (code == 200 && data instanceof Dictionary && data["token"] instanceof String) {
            Application.Storage.setValue("token", data["token"] as String);
            Application.Storage.setValue("code", data["code"] as String);
            _code = data["code"] as String;
            _msg = "En Serevix: Ajustes › Reloj Garmin. Escribe este código";
            poll();
        } else {
            _msg = Api.errorText(code);
        }
        WatchUi.requestUpdate();
    }

    public function onStatus(code as Number, data as Dictionary or String or Null) as Void {
        _busy = false;
        if (code == 200 && data instanceof Dictionary && data["linked"] == true) {
            _code = null;
            _msg = "Cargando tu rutina…";
            WatchUi.requestUpdate();
            loadToday();
            return;
        }
        if (code == 401 || (code == 200 && data instanceof Dictionary && data["expired"] == true)) {
            // El código caducó o el reloj se desvinculó: pedimos uno nuevo.
            Application.Storage.deleteValue("token");
            Application.Storage.deleteValue("code");
            start();
            return;
        }
        if (code == 200) {
            var c = Application.Storage.getValue("code");
            _code = (c instanceof String) ? c : null;
            _msg = "En Serevix: Ajustes › Reloj Garmin. Escribe este código";
            poll();
        } else {
            _msg = Api.errorText(code);
        }
        WatchUi.requestUpdate();
    }

    public function loadToday() as Void {
        _busy = true;
        var b = Api.today();
        b.put("action", "today");
        Api.post(b, method(:onToday));
    }

    public function onToday(code as Number, data as Dictionary or String or Null) as Void {
        _busy = false;
        if (code == 200 && data instanceof Dictionary) {
            var st = getStore();
            st.load(data);
            if (st.exs.size() == 0) {
                _msg = "Hoy no tienes ejercicios de gym en tu rutina. START para actualizar.";
                WatchUi.requestUpdate();
                return;
            }
            var menu = st.buildMenu();
            WatchUi.switchToView(menu, new ExerciseMenuDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        _msg = Api.errorText(code);
        WatchUi.requestUpdate();
    }

    private function poll() as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        (_timer as Timer.Timer).start(method(:onPoll), 4000, false);
    }

    public function onPoll() as Void {
        start();
    }

    private function stopTimer() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
        }
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(LILA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.14, Graphics.FONT_SMALL, "SEREVIX", Graphics.TEXT_JUSTIFY_CENTER);
        var y = h * 0.30;
        if (_code != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Graphics.FONT_NUMBER_MEDIUM, _code as String, Graphics.TEXT_JUSTIFY_CENTER);
            y = h * 0.55;
        }
        dc.setColor(_code != null ? GRIS : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var txt = Graphics.fitTextToArea(_msg, Graphics.FONT_XTINY, w * 0.72, h * 0.34, true);
        dc.drawText(w / 2, y, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class LoadDelegate extends WatchUi.BehaviorDelegate {

    private var _view as LoadView;

    public function initialize(view as LoadView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    public function onSelect() as Boolean {
        if (Application.Storage.getValue("token") != null && Application.Storage.getValue("code") == null) {
            _view.loadToday();
        } else {
            _view.start();
        }
        return true;
    }
}
