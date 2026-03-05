-- Phase 2 migration for TallyCart
-- Safe to run on existing schema; uses if not exists guards and safe alter

create extension if not exists "pgcrypto";

-- Profiles
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    display_name text null
);

-- Stores (Phase 2 shape)
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

-- Add Phase 2 columns to existing stores if present
alter table public.stores add column if not exists location_text text;
alter table public.stores add column if not exists notes text;
alter table public.stores add column if not exists is_default boolean default false;
alter table public.stores add column if not exists updated_at timestamptz default now();

-- Unique store name per user (case-insensitive)
create unique index if not exists stores_user_name_unique
on public.stores (user_id, lower(name));

-- Only one default store per user
create unique index if not exists stores_user_default_unique
on public.stores (user_id)
where is_default = true;

-- Trips (Phase 2 shape)
create table if not exists public.trips (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    store_id uuid references public.stores(id) on delete set null,
    title text not null default 'Grocery Trip',
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

-- Add Phase 2 columns to existing trips if present
alter table public.trips add column if not exists title text;
alter table public.trips add column if not exists trip_date date;
alter table public.trips add column if not exists status text;
alter table public.trips add column if not exists planned_budget_cents int;
alter table public.trips add column if not exists actual_spend_cents int;
alter table public.trips add column if not exists currency text default 'USD';
alter table public.trips add column if not exists started_at timestamptz;
alter table public.trips add column if not exists completed_at timestamptz;
alter table public.trips add column if not exists updated_at timestamptz default now();

-- Trip items (Phase 2 shape)
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

-- Add Phase 2 columns to existing trip_items if present
alter table public.trip_items add column if not exists quantity text;
alter table public.trip_items add column if not exists category text;
alter table public.trip_items add column if not exists is_purchased boolean default false;
alter table public.trip_items add column if not exists sort_order int default 0;
alter table public.trip_items add column if not exists source text default 'manual';
alter table public.trip_items add column if not exists updated_at timestamptz default now();

create index if not exists trip_items_trip_sort_idx on public.trip_items (trip_id, sort_order);

-- Preferences
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

-- Suggestions
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

create table if not exists public.suggestion_actions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    trip_id uuid references public.trips(id) on delete cascade not null,
    suggestion_run_id uuid references public.suggestion_runs(id) on delete cascade not null,
    item_name text not null,
    action text not null check (action in ('accepted','dismissed')),
    created_at timestamptz default now()
);

-- Indexes
create index if not exists trips_user_date_idx on public.trips (user_id, trip_date desc);
create index if not exists trips_user_status_idx on public.trips (user_id, status);

-- RLS
alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.trips enable row level security;
alter table public.trip_items enable row level security;
alter table public.user_preferences enable row level security;
alter table public.suggestion_runs enable row level security;
alter table public.suggestion_actions enable row level security;

-- Policies
create policy "profiles_private" on public.profiles
for all using (id = auth.uid()) with check (id = auth.uid());

create policy "stores_private" on public.stores
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "trips_private" on public.trips
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "trip_items_private" on public.trip_items
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "preferences_private" on public.user_preferences
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "suggestion_runs_private" on public.suggestion_runs
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "suggestion_actions_private" on public.suggestion_actions
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- updated_at triggers
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;$$;

create trigger profiles_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

create trigger stores_updated_at
before update on public.stores
for each row execute procedure public.set_updated_at();

create trigger trips_updated_at
before update on public.trips
for each row execute procedure public.set_updated_at();

create trigger trip_items_updated_at
before update on public.trip_items
for each row execute procedure public.set_updated_at();

create trigger user_preferences_updated_at
before update on public.user_preferences
for each row execute procedure public.set_updated_at();
