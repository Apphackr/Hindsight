-- Hindsight — shared trips schema
-- Run this once in your Supabase project's SQL editor (Project → SQL Editor → New query → paste → Run).
-- Creates all tables first, then all policies — so nothing references a table that doesn't exist yet.
-- Safe to re-run: tables are "if not exists"; policies are dropped and recreated each time.

-- ============ TABLES (create these all first) ============

-- ---------- profiles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  created_at timestamptz default now()
);
alter table public.profiles enable row level security;

-- ---------- trips ----------
-- id is text, not uuid — it matches the id Hindsight already generates locally for every trip.
create table if not exists public.trips (
  id text primary key,
  owner uuid references auth.users(id) not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);
alter table public.trips enable row level security;

-- ---------- trip_members ----------
create table if not exists public.trip_members (
  trip_id text references public.trips(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  role text default 'member',
  joined_at timestamptz default now(),
  primary key (trip_id, user_id)
);
alter table public.trip_members enable row level security;

-- ---------- trip_invites ----------
create table if not exists public.trip_invites (
  id uuid primary key default gen_random_uuid(),
  trip_id text references public.trips(id) on delete cascade,
  email text not null,
  invited_by uuid references auth.users(id),
  created_at timestamptz default now()
);
alter table public.trip_invites enable row level security;

-- ============ POLICIES (all tables now exist, so these can reference each other) ============

-- ---------- profiles ----------
drop policy if exists "profiles self" on public.profiles;
create policy "profiles self" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "profiles co-members" on public.profiles;
create policy "profiles co-members" on public.profiles
  for select using (
    id in (
      select tm2.user_id from public.trip_members tm1
      join public.trip_members tm2 on tm1.trip_id = tm2.trip_id
      where tm1.user_id = auth.uid()
    )
  );

-- ---------- trips ----------
drop policy if exists "trips member read" on public.trips;
create policy "trips member read" on public.trips
  for select using (
    id in (select trip_id from public.trip_members where user_id = auth.uid())
    or id in (select trip_id from public.trip_invites where email = auth.jwt()->>'email')
  );

drop policy if exists "trips member write" on public.trips;
create policy "trips member write" on public.trips
  for update using (
    id in (select trip_id from public.trip_members where user_id = auth.uid())
  ) with check (
    id in (select trip_id from public.trip_members where user_id = auth.uid())
  );

drop policy if exists "trips owner insert" on public.trips;
create policy "trips owner insert" on public.trips
  for insert with check (owner = auth.uid());

drop policy if exists "trips owner delete" on public.trips;
create policy "trips owner delete" on public.trips
  for delete using (owner = auth.uid());

-- ---------- trip_members ----------
drop policy if exists "trip_members read" on public.trip_members;
create policy "trip_members read" on public.trip_members
  for select using (
    trip_id in (select trip_id from public.trip_members where user_id = auth.uid())
  );

drop policy if exists "trip_members self insert" on public.trip_members;
create policy "trip_members self insert" on public.trip_members
  for insert with check (
    user_id = auth.uid() and (
      role = 'owner'
      or trip_id in (select trip_id from public.trip_invites where email = auth.jwt()->>'email')
    )
  );

drop policy if exists "trip_members leave" on public.trip_members;
create policy "trip_members leave" on public.trip_members
  for delete using (user_id = auth.uid());

-- ---------- trip_invites ----------
drop policy if exists "trip_invites visible" on public.trip_invites;
create policy "trip_invites visible" on public.trip_invites
  for select using (
    email = auth.jwt()->>'email'
    or trip_id in (select trip_id from public.trip_members where user_id = auth.uid())
  );

drop policy if exists "trip_invites create" on public.trip_invites;
create policy "trip_invites create" on public.trip_invites
  for insert with check (
    trip_id in (select trip_id from public.trip_members where user_id = auth.uid())
  );

drop policy if exists "trip_invites accept-delete" on public.trip_invites;
create policy "trip_invites accept-delete" on public.trip_invites
  for delete using (
    email = auth.jwt()->>'email'
    or trip_id in (select trip_id from public.trip_members where user_id = auth.uid())
  );

-- ============ REALTIME ============
-- lets the app get live updates when someone else changes a shared trip
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'trips'
  ) then
    alter publication supabase_realtime add table public.trips;
  end if;
end $$;
