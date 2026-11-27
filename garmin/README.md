# Serevix para Garmin (Forerunner 170)

App para el reloj: ves los ejercicios de hoy de tu rutina, marcas cada serie desde la muñeca y Serevix (en el móvil) se actualiza sola. Tus amigos lo ven en directo en el Muro.

## Cómo funciona

- El reloj envía cada serie por Bluetooth a la app **Garmin Connect** del iPhone, y de ahí a tu cuenta de Serevix.
- Durante el entreno, el iPhone tiene que estar cerca y con Garmin Connect funcionando en segundo plano.

**Botones durante el entreno**

| Pantalla | Botón | Qué hace |
|---|---|---|
| Lista de ejercicios | — | Elige el ejercicio que vas a hacer. «Actualizar» vuelve a cargar la rutina. |
| Serie | **UP / DOWN** | Sube o baja el valor marcado en lila. |
| Serie | **MENU** (mantén UP) o toca la pantalla | Cambia entre kilos (arriba) y repeticiones (abajo). |
| Serie | **START** | Serie hecha. |
| Descanso | — | Empieza la cuenta atrás y el reloj vibra al acabar. |
| Descanso | **UP** / **DOWN** | +15 s / −15 s. |
| Descanso | **START** | Empezar ya. |

Si en ese momento no hay conexión, la serie se guarda en el reloj y se envía en cuanto vuelve.

## Prepararla en el ordenador (una sola vez)

1. Instala **Visual Studio Code**: https://code.visualstudio.com
2. Descarga el **Connect IQ SDK Manager** de Garmin: https://developer.garmin.com/connect-iq/sdk/
   - Ábrelo e inicia sesión con tu cuenta de Garmin.
   - Descarga el SDK más reciente.
   - En la pestaña **Devices**, descarga **Forerunner 170**.
3. En Visual Studio Code, ve a **Extensiones** e instala **Monkey C** (de Garmin).
4. Pulsa `Ctrl+Mayús+P` (en Mac `Cmd+Mayús+P`) y ejecuta **«Monkey C: Generate a Developer Key»**.
   - Guarda la clave en una carpeta tuya.
   - No la subas a GitHub.
   - No la pierdas: hace falta para actualizar la app.
5. Descarga el proyecto desde GitHub (**Code › Download ZIP**) y descomprímelo.
6. En Visual Studio Code: **File › Open Folder** y elige la carpeta **garmin**.

## Probarla en el simulador (opcional)

1. Ejecuta **«Monkey C: Run»** y elige **Forerunner 170**.
2. Se abre un reloj en pantalla que se conecta de verdad a Serevix.
3. En el móvil, ve a **Perfil › Ajustes › Reloj Garmin** y escribe el código que sale en el simulador.

## Instalarla en el reloj (por cable)

1. Ejecuta **«Monkey C: Build for Device»**, elige **Forerunner 170** y una carpeta de salida. Se crea un archivo `.prg`.
2. Conecta el reloj al ordenador con su cable.
   - En Windows aparece como una unidad.
   - En Mac necesitas la app gratuita **OpenMTP**.
3. Copia el archivo `.prg` en la carpeta **GARMIN/APPS** del reloj.
4. Desconecta el reloj. **Serevix** aparece en la lista de actividades y apps (pulsa START en la esfera).

## Vincular el reloj con tu cuenta

1. Abre Serevix en el reloj. Te muestra un código de 6 letras y números, que caduca a los 15 minutos.
2. En el móvil, ve a **Serevix › Perfil › Ajustes › Reloj Garmin**, escribe el código y pulsa **Vincular**.
3. El reloj carga la rutina de hoy.

## Para tus amigos (más adelante)

Con **«Monkey C: Export Project»** se crea un archivo `.iq` que se sube a la tienda de Garmin: https://apps.garmin.com/developer/upload

- Primero se sube como **beta**: solo la ves tú.
- Cuando funcione bien, se publica para todos.

## Para quien toque el código

- El reloj habla con la función `watch` de Supabase (`supabase/functions/watch`).
- Esa función guarda las series en la tabla `watch_events`.
- La app del móvil las aplica al momento mediante Supabase Realtime.
