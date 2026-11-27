// Lista de ejercicios de hoy: al elegir uno se abre la pantalla de series.
import Toybox.Lang;
import Toybox.WatchUi;

class ExerciseMenuDelegate extends WatchUi.Menu2InputDelegate {

    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number && id >= 0) {
            var view = new SetView(id);
            WatchUi.pushView(view, new SetDelegate(view), WatchUi.SLIDE_LEFT);
        } else {
            // "Actualizar": volver a cargar la rutina desde Serevix.
            var load = new LoadView();
            WatchUi.switchToView(load, new LoadDelegate(load), WatchUi.SLIDE_RIGHT);
        }
    }
}
