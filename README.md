# Serevix

App de gym y running: series guiadas con descanso automático, NPC en 3D que hace cada ejercicio, mapa de músculos, retos, racha, actividades con foto, calendario, estadística de kilómetros y control de comida con capricho semanal.

Es una app web instalable (PWA): se abre desde el navegador y se instala en el móvil con su propio icono, a pantalla completa y sin barra del navegador. Cada persona tiene su cuenta (correo y contraseña) y sus datos, guardados en una base de datos propia (Supabase).

## Qué hay en esta carpeta

| Archivo | Para qué sirve |
|---|---|
| `index.html` | La app entera |
| `config.js` | La dirección y la clave pública de tu base de datos |
| `manifest.webmanifest`, `sw.js`, `icons/` | Lo que permite instalarla en el móvil y abrirla sin conexión |
| `vendor/` | Librerías incluidas (3D y base de datos) |
| `supabase/schema.sql` | Las tablas y las reglas de seguridad de la base de datos (datos, amigos y Strava) |
| `supabase/functions/strava/` | La función del servidor que conecta con Strava |
| `vercel.json` | Ajustes para publicarla en Vercel |

Si `config.js` está vacío, la app funciona en **modo sin cuenta**: pide solo un nombre y guarda todo en el móvil.

## Cómo ponerla en marcha

### 1. GitHub (guardar el código)
1. Crea una cuenta en [github.com](https://github.com).
2. Crea un repositorio vacío llamado `serevix` (sin README).
3. Pásale a Claude el nombre (`tu-usuario/serevix`) para que suba el código.

### 2. Supabase (cuentas y base de datos)
1. Entra en [supabase.com](https://supabase.com) con tu cuenta de GitHub y crea un proyecto llamado `serevix`. Elige una región de Europa. Guarda la contraseña de la base de datos y no se la des a nadie.
2. **SQL Editor › New query**: pega el contenido de `supabase/schema.sql` y pulsa **Run**.
3. **Authentication › Sign In / Providers › Email**: desactiva **Confirm email** y guarda. Así nadie necesita confirmar el correo para entrar.
4. **Project Settings › API**: copia la **Project URL** y la clave **anon public**. Esas dos van en `config.js`. Son públicas por diseño. La clave **service_role** o **secret** no la compartas nunca.

### 3. Vercel (publicar la app)
1. Entra en [vercel.com](https://vercel.com) con GitHub.
2. **Add New › Project** › importa `serevix` › en *Framework Preset* elige **Other** › **Deploy**.
3. Te dará una dirección como `serevix.vercel.app`. Esa es tu app.

### 4. Instalarla en el móvil
- **Android (Chrome)**: abre la dirección y pulsa **Instalar** en el aviso de la app, o en el menú ⋮ › **Instalar aplicación**.
- **iPhone (Safari)**: botón **Compartir** › **Añadir a pantalla de inicio**.

### 5. Pasar tus datos de la versión de Claude
Crea tu cuenta en la app y ve a **Perfil › Ajustes › Importar copia**. Elige el archivo `serevix-mis-datos.json`.

### 6. Amigos y seguidores
Funciona en cuanto ejecutes `supabase/schema.sql`, que ya incluye las tablas de amigos. Si ya lo habías ejecutado, vuelve a pegarlo entero y pulsa **Run**: no borra nada.

- En **Perfil › Amigos** cada persona elige su nombre de usuario, busca a sus amigos y les manda una solicitud.
- Cuando la otra persona acepta, ves sus entrenos, su racha, su nivel y sus kilómetros.
- Cada uno decide si comparte (interruptor en Amigos). Solo lo ven los seguidores aceptados.

### 7. Strava (y Garmin a través de Strava)
1. En [strava.com/settings/api](https://www.strava.com/settings/api) crea una app:
   - Nombre: **Serevix**.
   - Sitio web: tu dirección de Vercel.
   - **Authorization Callback Domain**: solo el dominio, por ejemplo `serevix.vercel.app`.
2. Copia el **Client ID** (es público) en `config.js`, en `stravaClientId`.
3. En Supabase › **Edge Functions › Secrets** añade:
   - `STRAVA_CLIENT_ID` con el Client ID.
   - `STRAVA_CLIENT_SECRET` con el Client Secret. El secreto no lo pongas nunca en `config.js` ni se lo pases a nadie.
4. En Supabase › **Edge Functions › Deploy a new function › Via Editor**: llámala `strava`, pega el contenido de `supabase/functions/strava/index.ts` y pulsa **Deploy**.
5. En la app: **Perfil › Strava › Conectar con Strava**.

**Garmin:** en la app Garmin Connect activa **Apps conectadas › Strava**. Tus actividades del reloj subirán a Strava y de ahí llegarán a Serevix. La conexión directa con Garmin exige que Garmin apruebe la app en su programa para desarrolladores. Mientras tanto también puedes importar archivos GPX o TCX.

**Límites de Strava:**
- Una app nueva solo la puede conectar 1 persona, que eres tú. Para que la conecten más usuarios hay que pedir a Strava que la revise y amplíe el límite.
- Strava no permite mostrar sus datos a otras personas, así que las carreras importadas de Strava no salen en el muro de tus amigos.

## Siguientes pasos
- **Google Play** (pago único de 25 $) y **App Store** (99 $ al año; necesita un Mac o un servicio que compile en la nube): se empaqueta la misma app con Capacitor.
- **Recuperar contraseña por correo**: hace falta configurar un servicio de envío de correos (SMTP) en Supabase.
- **Calcular macros con IA**: una función de Supabase con una clave de la API de Claude, que se paga por uso. Mientras no esté, se usa la lista de alimentos o se añaden a mano.

## Notas
- En el plan gratuito, Supabase pausa los proyectos que pasan una semana sin uso. Se reactivan desde su panel.
- Desde **Perfil › Ajustes** cada persona puede exportar sus datos o borrar su cuenta. Las tiendas de apps exigen poder borrar la cuenta.
