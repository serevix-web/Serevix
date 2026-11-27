-- Serevix: base de datos y reglas de seguridad.
-- Pégalo entero en Supabase › SQL Editor › New query y pulsa "Run".

-- 1) Una tabla para los datos de cada usuario: su plan y registro ("app"),
--    su comida ("food") y sus fotos ("ph-...").
create table if not exists public.docs (
  user_id    uuid        not null references auth.users(id) on delete cascade,
  id         text        not null check (char_length(id) between 1 and 64),
  data       jsonb       not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  constraint docs_size check (octet_length(data::text) < 2000000)
);

-- 2) Seguridad: cada persona solo puede leer y escribir SUS filas.
alter table public.docs enable row level security;

drop policy if exists "docs_select_own" on public.docs;
drop policy if exists "docs_insert_own" on public.docs;
drop policy if exists "docs_update_own" on public.docs;
drop policy if exists "docs_delete_own" on public.docs;

create policy "docs_select_own" on public.docs for select to authenticated using (auth.uid() = user_id);
create policy "docs_insert_own" on public.docs for insert to authenticated with check (auth.uid() = user_id);
create policy "docs_update_own" on public.docs for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "docs_delete_own" on public.docs for delete to authenticated using (auth.uid() = user_id);

-- 3) Borrar la propia cuenta desde la app (lo exigen App Store y Google Play).
--    Al borrar el usuario se borran también todas sus filas (on delete cascade).
create or replace function public.delete_my_account()
returns void
language sql
security definer
set search_path = public
as $$
  delete from auth.users where id = auth.uid();
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- =====================================================================
-- 4) Amigos y seguidores
-- =====================================================================
-- Perfil público: el nombre de usuario con el que te encuentran.
create table if not exists public.profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  username   text unique not null check (username ~ '^[a-z0-9_.]{3,20}$'),
  name       text not null default '' check (char_length(name) <= 30),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
drop policy if exists "profiles_read" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_read" on public.profiles for select to authenticated using (true);
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check (auth.uid() = user_id);
create policy "profiles_update_own" on public.profiles for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Seguir: pides seguir a alguien y esa persona acepta (o rechaza).
create table if not exists public.follows (
  follower   uuid not null references auth.users(id) on delete cascade,
  followee   uuid not null references auth.users(id) on delete cascade,
  status     text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  primary key (follower, followee),
  check (follower <> followee)
);
alter table public.follows enable row level security;
drop policy if exists "follows_read_mine" on public.follows;
drop policy if exists "follows_request" on public.follows;
drop policy if exists "follows_accept" on public.follows;
drop policy if exists "follows_remove" on public.follows;
create policy "follows_read_mine" on public.follows for select to authenticated using (auth.uid() = follower or auth.uid() = followee);
create policy "follows_request" on public.follows for insert to authenticated with check (auth.uid() = follower and status = 'pending');
create policy "follows_accept" on public.follows for update to authenticated using (auth.uid() = followee) with check (auth.uid() = followee);
create policy "follows_remove" on public.follows for delete to authenticated using (auth.uid() = follower or auth.uid() = followee);

-- Lo que compartes: tu resumen, tus actividades y sus fotos.
-- Solo lo ven las personas a las que has aceptado como seguidores.
create table if not exists public.shares (
  user_id    uuid not null references auth.users(id) on delete cascade,
  id         text not null check (char_length(id) between 1 and 64),
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  constraint shares_size check (octet_length(data::text) < 400000)
);
alter table public.shares enable row level security;
drop policy if exists "shares_read" on public.shares;
drop policy if exists "shares_insert_own" on public.shares;
drop policy if exists "shares_update_own" on public.shares;
drop policy if exists "shares_delete_own" on public.shares;
create policy "shares_read" on public.shares for select to authenticated using (
  auth.uid() = user_id
  or exists (select 1 from public.follows f
             where f.followee = shares.user_id and f.follower = auth.uid() and f.status = 'accepted')
);
create policy "shares_insert_own" on public.shares for insert to authenticated with check (auth.uid() = user_id);
create policy "shares_update_own" on public.shares for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "shares_delete_own" on public.shares for delete to authenticated using (auth.uid() = user_id);

-- =====================================================================
-- 5) Strava (solo las usa la función del servidor; la app no puede leerlas)
-- =====================================================================
create table if not exists public.strava_tokens (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  athlete_id    bigint,
  athlete_name  text,
  access_token  text not null,
  refresh_token text not null,
  expires_at    bigint not null,
  updated_at    timestamptz not null default now()
);
alter table public.strava_tokens enable row level security;

create table if not exists public.strava_states (
  state      text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.strava_states enable row level security;

-- =====================================================================
-- 6) Permisos explícitos (los proyectos nuevos de Supabase ya no los dan solos)
-- =====================================================================
grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on public.docs, public.profiles, public.follows, public.shares to authenticated;
revoke all on public.docs, public.profiles, public.follows, public.shares from anon;
revoke all on public.strava_tokens, public.strava_states from anon, authenticated;
grant select, insert, update, delete on public.strava_tokens, public.strava_states to service_role;
