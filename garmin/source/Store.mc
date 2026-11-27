// Los datos de hoy en el reloj y la cola de series pendientes de enviar.
import Toybox.Lang;
import Toybox.WatchUi;

class Store {

    public var title as String = "";
    public var exs as Array<Dictionary> = [];
    public var menu as WatchUi.Menu2? = null;
    private var _queue as Array<Dictionary> = [];
    private var _sending as Boolean = false;
    public var lastError as String? = null;

    public function initialize() {
    }

    //! Guarda la rutina de hoy que manda Serevix.
    public function load(data as Dictionary) as Void {
        var t = data["title"];
        title = (t instanceof String) ? t : "";
        exs = [];
        var arr = data["ex"];
        if (arr instanceof Array) {
            for (var i = 0; i < arr.size(); i++) {
                var e = arr[i];
                if (e instanceof Dictionary) {
                    exs.add(e);
                }
            }
        }
    }

    public function done(e as Dictionary) as Array {
        var d = e["done"];
        if (d instanceof Array) {
            return d;
        }
        d = [false, false, false];
        e["done"] = d;
        return d;
    }

    public function doneCount(e as Dictionary) as Number {
        var d = done(e);
        var n = 0;
        for (var i = 0; i < d.size(); i++) {
            if (d[i] == true) {
                n++;
            }
        }
        return n;
    }

    //! Primera serie sin hacer, o -1 si el ejercicio está completo.
    public function nextSet(e as Dictionary) as Number {
        var d = done(e);
        for (var i = 0; i < d.size(); i++) {
            if (d[i] != true) {
                return i;
            }
        }
        return -1;
    }

    public function num(v as Object?, def as Float) as Float {
        if (v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double) {
            return (v as Number or Float or Long or Double).toFloat();
        }
        return def;
    }

    public function kgText(e as Dictionary, kg as Float) as String {
        var s = (kg == kg.toNumber()) ? kg.toNumber().toString() : kg.format("%.1f");
        return s + " kg";
    }

    public function subLabel(e as Dictionary) as String {
        var d = done(e);
        var s = doneCount(e).toString() + "/" + d.size().toString() + " series";
        var kg = num(e["kg"] as Object?, 0.0);
        if (kg > 0) {
            s += " · " + kgText(e, kg);
        }
        return s;
    }

    public function name(e as Dictionary) as String {
        var n = e["n"];
        return (n instanceof String) ? n : "Ejercicio";
    }

    //! Menú con los ejercicios de hoy.
    public function buildMenu() as WatchUi.Menu2 {
        var m = new WatchUi.Menu2({ :title => (title.length() > 0 ? title : "Hoy") });
        for (var i = 0; i < exs.size(); i++) {
            m.addItem(new WatchUi.MenuItem(name(exs[i]), subLabel(exs[i]), i, null));
        }
        m.addItem(new WatchUi.MenuItem("Actualizar", "Volver a cargar la rutina", -1, null));
        menu = m;
        return m;
    }

    public function refreshMenu() as Void {
        var m = menu;
        if (m == null) {
            return;
        }
        for (var i = 0; i < exs.size(); i++) {
            var it = m.getItem(i);
            if (it != null) {
                it.setSubLabel(subLabel(exs[i]));
            }
        }
        WatchUi.requestUpdate();
    }

    //! Apunta una serie: se marca en el reloj al momento y se manda a Serevix.
    //! Si no hay conexión, se queda en la cola y se reintenta en el siguiente envío.
    public function sendSet(idx as Number, setIndex as Number, reps as Number, kg as Float) as Void {
        var e = exs[idx];
        var d = done(e);
        if (setIndex < d.size()) {
            d[setIndex] = true;
        }
        e["kg"] = kg;
        var b = Api.today();
        b.put("action", "set");
        b.put("ex", e["id"] as Object);
        b.put("i", setIndex);
        b.put("reps", reps);
        b.put("kg", kg);
        _queue.add(b);
        flush();
    }

    public function pending() as Number {
        return _queue.size();
    }

    public function flush() as Void {
        if (_sending || _queue.size() == 0) {
            return;
        }
        _sending = true;
        Api.post(_queue[0], method(:onSent));
    }

    public function onSent(code as Number, data as Dictionary or String or Null) as Void {
        _sending = false;
        if (code == 200 || code == 400) {
            // 400 = serie no válida: se descarta para no bloquear la cola.
            _queue = _queue.slice(1, null);
            lastError = null;
            flush();
        } else {
            lastError = Api.errorText(code);
        }
        WatchUi.requestUpdate();
    }
}
