// Pantalla de una serie: kilos y repeticiones. UP/DOWN cambian el valor marcado,
// MENU (o tocar la pantalla) cambia entre kilos y repeticiones, START = serie hecha.
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class SetView extends WatchUi.View {

    public var idx as Number;
    public var setIndex as Number = 0;
    public var reps as Number = 8;
    public var kg as Float = 0.0;
    public var step as Float = 2.5;
    public var editKg as Boolean = false;   // false = repeticiones, true = kilos

    public function initialize(index as Number) {
        View.initialize();
        idx = index;
        var st = getStore();
        var e = st.exs[idx];
        setIndex = st.nextSet(e);
        reps = st.num(e["reps"] as Object?, 8.0).toNumber();
        kg = st.num(e["kg"] as Object?, 0.0);
        step = st.num(e["step"] as Object?, 2.5);
    }

    public function exercise() as Dictionary {
        return getStore().exs[idx];
    }

    public function finished() as Boolean {
        return setIndex < 0;
    }

    public function change(dir as Number) as Void {
        if (finished()) {
            return;
        }
        if (editKg && step > 0) {
            kg = kg + dir * step;
            if (kg < 0) {
                kg = 0.0;
            }
            if (kg > 1000) {
                kg = 1000.0;
            }
        } else {
            reps = reps + dir;
            if (reps < 1) {
                reps = 1;
            }
            if (reps > 100) {
                reps = 100;
            }
        }
        WatchUi.requestUpdate();
    }

    public function toggle() as Void {
        if (step > 0) {
            editKg = !editKg;
            WatchUi.requestUpdate();
        }
    }

    //! START: apunta la serie y arranca el descanso.
    public function doneSet() as Void {
        if (finished()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }
        var st = getStore();
        var e = exercise();
        st.sendSet(idx, setIndex, reps, kg);
        st.refreshMenu();
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(60, 150)]);
        }
        var next = st.nextSet(e);
        var rest = st.num(e["rest"] as Object?, 90.0).toNumber();
        if (next < 0) {
            // Ejercicio terminado: volvemos a la lista.
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }
        if (rest > 0) {
            var rv = new RestView(idx, rest);
            WatchUi.switchToView(rv, new RestDelegate(rv), WatchUi.SLIDE_LEFT);
        } else {
            setIndex = next;
            WatchUi.requestUpdate();
        }
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        var st = getStore();
        var e = exercise();
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var name = Graphics.fitTextToArea(st.name(e), Graphics.FONT_SMALL, w * 0.70, h * 0.13, true);
        dc.drawText(w / 2, h * 0.10, Graphics.FONT_SMALL, name, Graphics.TEXT_JUSTIFY_CENTER);

        var total = st.done(e).size();
        dc.setColor(finished() ? LILA : GRIS, Graphics.COLOR_TRANSPARENT);
        var head = finished() ? "Ejercicio completado" : "Serie " + (setIndex + 1).toString() + " de " + total.toString();
        dc.drawText(w / 2, h * 0.24, Graphics.FONT_XTINY, head, Graphics.TEXT_JUSTIFY_CENTER);

        if (!finished()) {
            if (step > 0) {
                drawValue(dc, w / 2, h * 0.36, st.kgText(e, kg), editKg);
                var unit = e["unit"];
                if (unit instanceof String && unit.length() > 0) {
                    dc.setColor(GRIS, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(w / 2, h * 0.50, Graphics.FONT_XTINY, unit, Graphics.TEXT_JUSTIFY_CENTER);
                }
            }
            drawValue(dc, w / 2, h * 0.58, reps.toString() + " reps", !editKg || step <= 0);
            dc.setColor(GRIS, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.76, Graphics.FONT_XTINY, "START  Serie hecha", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(GRIS, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.50, Graphics.FONT_XTINY, "START para volver", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var err = st.lastError;
        if (err != null && st.pending() > 0) {
            dc.setColor(0xFF8FA3, Graphics.COLOR_TRANSPARENT);
            var t = Graphics.fitTextToArea("Sin enviar (" + st.pending().toString() + "): " + err, Graphics.FONT_XTINY, w * 0.62, h * 0.12, true);
            dc.drawText(w / 2, h * 0.84, Graphics.FONT_XTINY, t, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Un valor grande; el que se está editando va en lila con flechas.
    private function drawValue(dc as Graphics.Dc, x as Number, y as Float, txt as String, active as Boolean) as Void {
        dc.setColor(active ? LILA : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_MEDIUM, txt, Graphics.TEXT_JUSTIFY_CENTER);
        if (active) {
            var tw = dc.getTextWidthInPixels(txt, Graphics.FONT_MEDIUM);
            var fh = dc.getFontHeight(Graphics.FONT_MEDIUM);
            var ax = x + tw / 2 + 18;
            var ay = y + fh / 2;
            dc.fillPolygon([[ax - 8, ay - 6], [ax + 8, ay - 6], [ax, ay - 16]]);
            dc.fillPolygon([[ax - 8, ay + 6], [ax + 8, ay + 6], [ax, ay + 16]]);
        }
    }
}

class SetDelegate extends WatchUi.BehaviorDelegate {

    private var _view as SetView;

    public function initialize(view as SetView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    public function onPreviousPage() as Boolean {
        _view.change(1);
        return true;
    }

    public function onNextPage() as Boolean {
        _view.change(-1);
        return true;
    }

    public function onMenu() as Boolean {
        _view.toggle();
        return true;
    }

    public function onSelect() as Boolean {
        _view.doneSet();
        return true;
    }

    //! Tocar arriba = kilos, tocar abajo = repeticiones (no marca la serie: eso solo con START).
    public function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var xy = evt.getCoordinates();
        var h = System.getDeviceSettings().screenHeight;
        if (_view.step > 0) {
            _view.editKg = xy[1] < h * 0.53;
            WatchUi.requestUpdate();
        }
        return true;
    }

    public function onBack() as Boolean {
        getStore().refreshMenu();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
