// Función "strava" de Serevix (Supabase Edge Function).
// Conecta la cuenta de Strava de cada usuario y le devuelve sus carreras.
// Necesita dos secretos en Supabase › Edge Functions › Secrets:
//   STRAVA_CLIENT_ID y STRAVA_CLIENT_SECRET (de https://www.strava.com/settings/api)
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const CLIENT_ID = Deno.env.get('STRAVA_CLIENT_ID') ?? '';
const CLIENT_SECRET = Deno.env.get('STRAVA_CLIENT_SECRET') ?? '';
const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

async function currentUser(req: Request) {
  const auth = req.headers.get('Authorization') ?? '';
  const client = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false },
  });
  const { data } = await client.auth.getUser();
  return data.user;
}

async function stravaToken(body: Record<string, string>) {
  const res = await fetch('https://www.strava.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ client_id: CLIENT_ID, client_secret: CLIENT_SECRET, ...body }),
  });
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, data };
}

async function tokenFor(userId: string) {
  const { data } = await admin.from('strava_tokens').select('*').eq('user_id', userId).maybeSingle();
  if (!data) return null;
  if (data.expires_at * 1000 > Date.now() + 60_000) return data;
  const r = await stravaToken({ grant_type: 'refresh_token', refresh_token: data.refresh_token });
  if (!r.ok) return null;
  const row = {
    ...data,
    access_token: r.data.access_token,
    refresh_token: r.data.refresh_token,
    expires_at: r.data.expires_at,
    updated_at: new Date().toISOString(),
  };
  await admin.from('strava_tokens').upsert(row);
  return row;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  if (!CLIENT_ID || !CLIENT_SECRET) return json({ error: 'not_configured' }, 500);
  // deno-lint-ignore no-explicit-any
  let body: any = {};
  try { body = await req.json(); } catch { /* cuerpo vacío */ }
  const action = String(body.action ?? '');

  try {
    // Vuelta desde Strava: canjea el código por los tokens del usuario que empezó la conexión.
    if (action === 'exchange') {
      const state = String(body.state ?? ''), code = String(body.code ?? '');
      if (!state || !code) return json({ error: 'missing' }, 400);
      const { data: st } = await admin.from('strava_states').select('*').eq('state', state).maybeSingle();
      if (!st || Date.now() - new Date(st.created_at).getTime() > 15 * 60_000) return json({ error: 'state' }, 400);
      const r = await stravaToken({ code, grant_type: 'authorization_code' });
      if (!r.ok) return json({ error: 'strava' }, 400);
      const a = r.data.athlete ?? {};
      await admin.from('strava_tokens').upsert({
        user_id: st.user_id,
        athlete_id: a.id ?? null,
        athlete_name: [a.firstname, a.lastname].filter(Boolean).join(' '),
        access_token: r.data.access_token,
        refresh_token: r.data.refresh_token,
        expires_at: r.data.expires_at,
        updated_at: new Date().toISOString(),
      });
      await admin.from('strava_states').delete().eq('state', state);
      return json({ ok: true });
    }

    const user = await currentUser(req);
    if (!user) return json({ error: 'auth' }, 401);

    if (action === 'start') {
      const redirect = String(body.redirect ?? '');
      if (!/^https:\/\/[^\s]+$/.test(redirect)) return json({ error: 'redirect' }, 400);
      const state = crypto.randomUUID().replace(/-/g, '');
      await admin.from('strava_states').delete().eq('user_id', user.id);
      await admin.from('strava_states').insert({ state, user_id: user.id });
      const url = 'https://www.strava.com/oauth/authorize?' + new URLSearchParams({
        client_id: CLIENT_ID, redirect_uri: redirect, response_type: 'code',
        approval_prompt: 'auto', scope: 'read,activity:read_all', state,
      });
      return json({ url });
    }

    if (action === 'status') {
      const { data } = await admin.from('strava_tokens').select('athlete_name').eq('user_id', user.id).maybeSingle();
      return json({ connected: !!data, athlete: data?.athlete_name ?? '' });
    }

    if (action === 'disconnect') {
      const tk = await tokenFor(user.id);
      if (tk) {
        await fetch('https://www.strava.com/oauth/deauthorize', {
          method: 'POST', headers: { Authorization: 'Bearer ' + tk.access_token },
        }).catch(() => {});
      }
      await admin.from('strava_tokens').delete().eq('user_id', user.id);
      return json({ ok: true });
    }

    if (action === 'sync') {
      const tk = await tokenFor(user.id);
      if (!tk) return json({ error: 'not_connected' }, 400);
      const params = new URLSearchParams({ per_page: '60' });
      const after = Math.max(0, Math.floor(Number(body.after) || 0));
      if (after) params.set('after', String(after));
      const res = await fetch('https://www.strava.com/api/v3/athlete/activities?' + params, {
        headers: { Authorization: 'Bearer ' + tk.access_token },
      });
      if (res.status === 429) return json({ error: 'rate' }, 429);
      if (!res.ok) return json({ error: 'strava' }, 502);
      const list = await res.json();
      // deno-lint-ignore no-explicit-any
      const runs = (Array.isArray(list) ? list : []).filter((a: any) => /run/i.test(a.sport_type ?? a.type ?? '')).map((a: any) => ({
        id: String(a.id),
        date: String(a.start_date_local ?? '').slice(0, 10),
        name: String(a.name ?? '').slice(0, 80),
        km: Math.round((a.distance ?? 0) / 10) / 100,
        min: Math.round((a.moving_time ?? 0) / 6) / 10,
        hr: Math.round(a.average_heartrate ?? 0),
        hrMax: Math.round(a.max_heartrate ?? 0),
        elev: Math.round(a.total_elevation_gain ?? 0),
        cad: Math.round((a.average_cadence ?? 0) * 2),
        poly: String(a.map?.summary_polyline ?? ''),
      }));
      return json({ runs });
    }

    return json({ error: 'action' }, 400);
  } catch (_e) {
    return json({ error: 'server' }, 500);
  }
});
