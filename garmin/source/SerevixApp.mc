// Serevix para relojes Garmin.
// Marca tus series desde la muñeca: el reloj las manda a tu cuenta de Serevix
// (a través de la app Garmin Connect del móvil) y la app del móvil se actualiza sola.
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SerevixApp extends Application.AppBase {

    public var store as Store;

    public function initialize() {
        AppBase.initialize();
        store = new Store();
    }

    public function onStart(state as Dictionary?) as Void {
    }

    public function onStop(state as Dictionary?) as Void {
    }

    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new LoadView();
        return [view, new LoadDelegate(view)];
    }
}

//! Acceso rápido a los datos de la app desde cualquier pantalla.
function getStore() as Store {
    return (Application.getApp() as SerevixApp).store;
}
