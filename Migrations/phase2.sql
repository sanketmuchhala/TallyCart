-- Phase 2 migration for TallyCart
-- Enables uuid generation, core tables, RLS policies, and updated_at triggers.

create extension if not exists pgcrypto;

-- Helper function for updated_at timestamps
create or replace function public.set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

-- PROFILES
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    display_name text null
);

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- STORES
create table if not exists public.stores (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    name text not null,
    location_text text null,
    notes text null,
    is_default boolean default false,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

alter table public.stores add column if not exists location_text text;
alter table public.stores add column if not exists notes text;
alter table public.stores add column if not exists is_default boolean default false;
alter table public.stores add column if not exists updated_at timestamptz default now();

create unique index if not exists stores_unique_name_per_user
on public.stores (user_id, lower(name));

create unique index if not exists stores_one_default_per_user
on public.stores (user_id)
where is_default is true;

drop trigger if exists set_stores_updated_at on public.stores;
create trigger set_stores_updated_at
before update on public.stores
for each row execute function public.set_updated_at();

-- TRIPS
create table if not exists public.trips (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    store_id uuid references public.stores(id) null,
    title text not null,
    trip_date date not null,
    status text not null check (status in ('planned','active','done')),
    planned_budget_cents int null,
    actual_spend_cents int null,
    currency text default 'USD',
    started_at timestamptz null,
    completed_at timestamptz null,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

alter table public.trips add column if not exists title text;
alter table public.trips add column if not exists trip_date date;
alter table public.trips add column if not exists status text;
alter table public.trips add column if not exists planned_budget_cents int;
alter table public.trips add column if not exists actual_spend_cents int;
alter table public.trips add column if not exists currency text default 'USD';
alter table public.trips add column if not exists started_at timestamptz;
alter table public.trips add column if not exists completed_at timestamptz;
alter table public.trips add column if not exists updated_at timestamptz default now();

create index if not exists trips_user_date_idx
on public.trips (user_id, trip_date desc);

create index if not exists trips_user_status_idx
on public.trips (user_id, status);

drop trigger if exists set_trips_updated_at on public.trips;
create trigger set_trips_updated_at
before update on public.trips
for each row execute function public.set_updated_at();

-- TRIP ITEMS
create table if not exists public.trip_items (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    trip_id uuid references public.trips(id) on delete cascade not null,
    name text not null,
    quantity text null,
    category text null,
    is_purchased boolean default false,
    sort_order int default 0,
    source text not null default 'manual' check (source in ('manual','suggestion','template','repeat')),
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

alter table public.trip_items add column if not exists quantity text;
alter table public.trip_items add column if not exists category text;
alter table public.trip_items add column if not exists is_purchased boolean default false;
alter table public.trip_items add column if not exists sort_order int default 0;
alter table public.trip_items add column if not exists source text default 'manual';
alter table public.trip_items add column if not exists updated_at timestamptz default now();

create index if not exists trip_items_trip_sort_idx
on public.trip_items (trip_id, sort_order);

drop trigger if exists set_trip_items_updated_at on public.trip_items;
create trigger set_trip_items_updated_at
before update on public.trip_items
for each row execute function public.set_updated_at();

-- USER PREFERENCES
create table if not exists public.user_preferences (
    user_id uuid primary key references auth.users(id) on delete cascade,
    monthly_budget_cents int null,
    household_size int default 1,
    premium_sensitivity int default 50 check (premium_sensitivity between 0 and 100),
    always_suggest_staples boolean default true,
    diet_flags jsonb default '{}'::jsonb,
    avoid_items text[] default '{}'::text[],
    preferred_brands jsonb default '{}'::jsonb,
    staples_items text[] default '{}'::text[],
    updated_at timestamptz default now()
);

alter table public.user_preferences add column if not exists staples_items text[] default '{}'::text[];

-- SUGGESTION RUNS
create table if not exists public.suggestion_runs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    trip_id uuid references public.trips(id) on delete cascade not null,
    created_at timestamptz default now(),
    engine_version text not null,
    inputs jsonb not null,
    outputs jsonb not null,
    stats jsonb default '{}'::jsonb
);

-- SUGGESTION ACTIONS
create table if not exists public.suggestion_actions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    trip_id uuid references public.trips(id) on delete cascade not null,
    suggestion_run_id uuid references public.suggestion_runs(id) on delete cascade not null,
    item_name text not null,
    action text not null check (action in ('accepted','dismissed')),
    created_at timestamptz default now()
);

-- RLS
alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.trips enable row level security;
alter table public.trip_items enable row level security;
alter table public.user_preferences enable row level security;
alter table public.suggestion_runs enable row level security;
alter table public.suggestion_actions enable row level security;

-- PROFILES POLICIES
drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_insert on public.profiles;
drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_delete on public.profiles;

create policy profiles_select on public.profiles
for select using (id = auth.uid());

create policy profiles_insert on public.profiles
for insert with check (id = auth.uid());

create policy profiles_update on public.profiles
for update using (id = auth.uid());

create policy profiles_delete on public.profiles
for delete using (id = auth.uid());

-- STORES POLICIES
drop policy if exists stores_select on public.stores;
drop policy if exists stores_insert on public.stores;
drop policy if exists stores_update on public.stores;
drop policy if exists stores_delete on public.stores;

create policy stores_select on public.stores
for select using (user_id = auth.uid());

create policy stores_insert on public.stores
for insert with check (user_id = auth.uid());

create policy stores_update on public.stores
for update using (user_id = auth.uid());

create policy stores_delete on public.stores
for delete using (user_id = auth.uid());

-- TRIPS POLICIES
drop policy if exists trips_select on public.trips;
drop policy if exists trips_insert on public.trips;
drop policy if exists trips_update on public.trips;
drop policy if exists trips_delete on public.trips;

create policy trips_select on public.trips
for select using (user_id = auth.uid());

create policy trips_insert on public.trips
for insert with check (user_id = auth.uid());

create policy trips_update on public.trips
for update using (user_id = auth.uid());

create policy trips_delete on public.trips
for delete using (user_id = auth.uid());

-- TRIP ITEMS POLICIES
drop policy if exists trip_items_select on public.trip_items;
drop policy if exists trip_items_insert on public.trip_items;
drop policy if exists trip_items_update on public.trip_items;
drop policy if exists trip_items_delete on public.trip_items;

create policy trip_items_select on public.trip_items
for select using (user_id = auth.uid());

create policy trip_items_insert on public.trip_items
for insert with check (user_id = auth.uid());

create policy trip_items_update on public.trip_items
for update using (user_id = auth.uid());

create policy trip_items_delete on public.trip_items
for delete using (user_id = auth.uid());

-- USER PREFERENCES POLICIES
drop policy if exists prefs_select on public.user_preferences;
drop policy if exists prefs_insert on public.user_preferences;
drop policy if exists prefs_update on public.user_preferences;
drop policy if exists prefs_delete on public.user_preferences;

create policy prefs_select on public.user_preferences
for select using (user_id = auth.uid());

create policy prefs_insert on public.user_preferences
for insert with check (user_id = auth.uid());

create policy prefs_update on public.user_preferences
for update using (user_id = auth.uid());

create policy prefs_delete on public.user_preferences
for delete using (user_id = auth.uid());

-- SUGGESTION RUNS POLICIES
drop policy if exists suggestion_runs_select on public.suggestion_runs;
drop policy if exists suggestion_runs_insert on public.suggestion_runs;
drop policy if exists suggestion_runs_update on public.suggestion_runs;
drop policy if exists suggestion_runs_delete on public.suggestion_runs;

create policy suggestion_runs_select on public.suggestion_runs
for select using (user_id = auth.uid());

create policy suggestion_runs_insert on public.suggestion_runs
for insert with check (user_id = auth.uid());

create policy suggestion_runs_update on public.suggestion_runs
for update using (user_id = auth.uid());

create policy suggestion_runs_delete on public.suggestion_runs
for delete using (user_id = auth.uid());

-- SUGGESTION ACTIONS POLICIES
drop policy if exists suggestion_actions_select on public.suggestion_actions;
drop policy if exists suggestion_actions_insert on public.suggestion_actions;
drop policy if exists suggestion_actions_update on public.suggestion_actions;
drop policy if exists suggestion_actions_delete on public.suggestion_actions;

create policy suggestion_actions_select on public.suggestion_actions
for select using (user_id = auth.uid());

create policy suggestion_actions_insert on public.suggestion_actions
for insert with check (user_id = auth.uid());

create policy suggestion_actions_update on public.suggestion_actions
for update using (user_id = auth.uid());

create policy suggestion_actions_delete on public.suggestion_actions
for delete using (user_id = auth.uid());
