// Conexión con tu cuenta de Serevix (función "watch" de Supabase).
import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

module Api {

    const URL = "https://iwjeefkkomyrvlvmqrse.supabase.co/functions/v1/watch";

    //! Envía una petición a Serevix con el token del reloj.
    function post(body as Dictionary, cb as Method(responseCode as Number, data as Dictionary or String or Null) as Void) as Void {
        var tok = Application.Storage.getValue("token");
        if (tok instanceof String) {
            body.put("token", tok);
        }
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(URL, body as Dictionary<Object, Object>, options, cb);
    }

    //! La fecha de hoy del reloj ("2026-11-27") y el día de la semana (0 = domingo).
    function today() as Dictionary {
        var i = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var d = (i.year as Number).format("%04d") + "-" + (i.month as Number).format("%02d") + "-" + (i.day as Number).format("%02d");
        return { "date" => d, "dow" => (i.day_of_week as Number) - 1 };
    }

    //! Mensaje claro para cada error de conexión.
    function errorText(code as Number) as String {
        if (code == Communications.BLE_CONNECTION_UNAVAILABLE) {
            return "Sin conexión con el móvil. Abre Garmin Connect en el iPhone.";
        }
        if (code == Communications.NETWORK_REQUEST_TIMED_OUT || code == Communications.BLE_HOST_TIMEOUT || code == Communications.BLE_SERVER_TIMEOUT) {
            return "El móvil no responde. Comprueba que tiene internet.";
        }
        if (code == 401) {
            return "Hay que volver a vincular el reloj.";
        }
        if (code == 403) {
            return "Vincula el reloj en Serevix: Ajustes › Reloj Garmin.";
        }
        return "No se pudo conectar (" + code.toString() + "). Pulsa START para reintentar.";
    }
}
