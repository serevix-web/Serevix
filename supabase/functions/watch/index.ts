// Función "watch" de Serevix (Supabase Edge Function).
// La usa la app de Serevix para relojes Garmin (carpeta garmin/ del repositorio):
//   pair-start  → el reloj pide un código de 6 letras y un token secreto.
//   status      → el reloj pregunta si ya lo has vinculado en Serevix (Ajustes › Reloj Garmin).
//   today       → el reloj recibe la rutina de hoy con lo que ya llevas hecho.
//   set         → el reloj apunta una serie (repeticiones y kilos). La app del móvil la aplica
//                 al momento y tus amigos la ven en directo en el Muro.
// Se despliega con verify_jwt = false: el reloj no tiene sesión de Supabase y se identifica
// con su token (en la base de datos solo se guarda su hash).
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

const ALPH = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 32 símbolos, sin 0/O ni 1/I
const COMPOUND = ['bench', 'ohp', 'row', 'pullup', 'dips', 'squat', 'deadlift', 'lunge'];
const DAY = /^\d{4}-\d\d-\d\d$/;
const PAIR_MIN = 15;

const bytes = (n: number) => crypto.getRandomValues(new Uint8Array(n));
const hex = (n: number) => [...bytes(n)].map((b) => b.toString(16).padStart(2, '0')).join('');
const code6 = () => [...bytes(6)].map((b) => ALPH[b % 32]).join('');
async function sha(t: string) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(t));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
const norm = (s: unknown) => String(s ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

// deno-lint-ignore no-explicit-any
type Any = any;

async function deviceFor(token: unknown) {
  if (typeof token !== 'string' || token.length < 32 || token.length > 128) return null;
  const { data } = await admin.from('watch_devices').select('id,user_id,created_at').eq('token_hash', await sha(token)).maybeSingle();
  return data ?? null;
}
async function appDoc(uid: string): Promise<Any | null> {
  const { data } = await admin.from('docs').select('data').eq('user_id', uid).eq('id', 'app').maybeSingle();
  return data?.data ?? null;
}
async function pendingFor(uid: string, day: string) {
  const { data } = await admin.from('watch_events').select('ex_id,set_i,reps,kg').eq('user_id', uid).eq('day', day).eq('applied', false);
  const out: Record<string, Any[]> = {};
  (data ?? []).forEach((e: Any) => { (out[e.ex_id] = out[e.ex_id] ?? []).push(e); });
  return out;
}
function restFor(S: Any, x: Any) {
  if (x && +x.rest > 0) return Math.round(+x.rest);
  const r = +(S?.settings?.rest);
  if (r > 0) return Math.round(r);
  if (r === 0) return 0;
  return x && COMPOUND.includes(x.mv) ? 150 : 90;
}
// La rutina de un día, como la calcula la app (planFor), con lo hecho y lo que llegó del reloj.
function plan(S: Any, day: string, dow: number, pending: Record<string, Any[]>) {
  const X = S?.exercises ?? {};
  const L = S?.log?.days?.[day] ?? {};
  const dw = L.from != null && S?.days?.[L.from] ? +L.from : dow;
  const d = S?.days?.[dw] ?? { ex: [] };
  const base = (d.ex ?? []).filter((id: string) => X[id]);
  const extra = (L.extra ?? []).filter((id: string) => X[id] && !base.includes(id));
  const ex = base.concat(extra).slice(0, 20).map((id: string) => {
    const x = X[id], e = L.ex?.[id];
    const done: boolean[] = e && Array.isArray(e.done) ? e.done.map(Boolean) : new Array(Math.max(1, Math.min(20, +x.sets || 3))).fill(false);
    const reps = Math.round(+(e ? e.reps : x.reps) || 8);
    let kg = +(e ? e.w : x.w) || 0;
    for (const ev of (pending[id] ?? []).sort((a, b) => a.set_i - b.set_i)) {
      while (done.length <= ev.set_i) done.push(false);
      done[ev.set_i] = true;
      kg = +ev.kg;
    }
    const side = x.wm === 'lado';
    return {
      id,
      n: String(x.name ?? 'Ejercicio').slice(0, 40),
      done,
      reps,
      kg: Math.round(kg * 100) / 100,
      unit: side ? (/mancuern/.test(norm(x.name)) ? 'por mancuerna' : 'por lado') : '',
      step: x.prog === 'reps' ? 0 : (side ? 1 : 2.5),
      rest: restFor(S, x),
    };
  });
  return { title: String(d.title ?? '').slice(0, 40), ex };
}
// Tarjeta "en directo" en el Muro de tus amigos aunque el móvil esté bloqueado.
// Cuando abres Serevix en el móvil, la app la rehace con todos los detalles.
async function liveShare(uid: string, day: string, dow: number, exId: string) {
  try {
    const S = await appDoc(uid);
    if (!S || S.social?.share === false) return;
    const { data: prof } = await admin.from('profiles').select('user_id').eq('user_id', uid).maybeSingle();
    if (!prof) return;
    const P = plan(S, day, dow, await pendingFor(uid, day));
    const sets = P.ex.reduce((a, x) => a + x.done.filter(Boolean).length, 0);
    const tot = P.ex.reduce((a, x) => a + x.done.length, 0);
    const cur = P.ex.find((x) => x.id === exId)?.n ?? '';
    const id = 'act-' + day, now = Date.now();
    const { data: row } = await admin.from('shares').select('data').eq('user_id', uid).eq('id', id).maybeSingle();
    const old: Any = row?.data && !row.data.gone ? row.data : {};
    if (old.end) return;
    const data = {
      title: P.title || 'Entreno', end: null, dur: 0, vol: 0, run: null, rpe: 0, P: [], S: [], ex: [], note: '', photo: null,
      ...old,
      k: day,
      sets: Math.max(sets, +old.sets || 0),
      live: { ...(old.live ?? {}), start: old.live?.start ?? now, at: now, tot: Math.max(tot, sets), cur },
    };
    await admin.from('shares').upsert({ user_id: uid, id, data, updated_at: new Date().toISOString() });
  } catch (_e) { /* el directo es opcional */ }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  let b: Any = {};
  try { b = await req.json(); } catch { /* cuerpo vacío */ }
  const action = String(b?.action ?? '');

  try {
    if (action === 'pair-start') {
      await admin.from('watch_devices').delete().is('user_id', null).lt('created_at', new Date(Date.now() - 86400e3).toISOString());
      const token = hex(32), hash = await sha(token);
      for (let i = 0; i < 5; i++) {
        const code = code6();
        const { error } = await admin.from('watch_devices').insert({ token_hash: hash, code, name: String(b.name ?? 'Garmin').slice(0, 40) });
        if (!error) return json({ token, code, minutes: PAIR_MIN });
      }
      return json({ error: 'server' }, 500);
    }

    const dev = await deviceFor(b?.token);
    if (!dev) return json({ error: 'token' }, 401);

    if (action === 'status') {
      if (!dev.user_id) {
        const expired = Date.now() - Date.parse(dev.created_at) > PAIR_MIN * 60e3;
        return json({ linked: false, expired });
      }
      await admin.from('watch_devices').update({ last_seen: new Date().toISOString() }).eq('id', dev.id);
      const { data: p } = await admin.from('profiles').select('name,username').eq('user_id', dev.user_id).maybeSingle();
      return json({ linked: true, name: p?.name || p?.username || '' });
    }

    if (!dev.user_id) return json({ error: 'not_linked' }, 403);
    const day = String(b.date ?? ''), dow = Math.floor(Number(b.dow));
    if (!DAY.test(day) || !(dow >= 0 && dow <= 6)) return json({ error: 'date' }, 400);

    if (action === 'today') {
      await admin.from('watch_devices').update({ last_seen: new Date().toISOString() }).eq('id', dev.id);
      const S = await appDoc(dev.user_id);
      if (!S) return json({ title: '', ex: [] });
      return json(plan(S, day, dow, await pendingFor(dev.user_id, day)));
    }

    if (action === 'set') {
      const ex = String(b.ex ?? ''), i = Math.floor(Number(b.i)), reps = Math.floor(Number(b.reps));
      const kg = Math.round(Number(b.kg) * 100) / 100;
      if (!ex || ex.length > 64 || !(i >= 0 && i < 50) || !(reps >= 1 && reps <= 100) || !(kg >= 0 && kg <= 1000)) return json({ error: 'data' }, 400);
      const { error } = await admin.from('watch_events').upsert(
        { user_id: dev.user_id, device_id: dev.id, day, ex_id: ex, set_i: i, reps, kg, applied: false, created_at: new Date().toISOString() },
        { onConflict: 'user_id,day,ex_id,set_i' },
      );
      if (error) return json({ error: 'server' }, 500);
      await liveShare(dev.user_id, day, dow, ex);
      return json({ ok: true });
    }

    return json({ error: 'action' }, 400);
  } catch (_e) {
    return json({ error: 'server' }, 500);
  }
});
