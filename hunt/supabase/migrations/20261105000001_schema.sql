-- Hunt: core schema.
-- All writes go through security-definer RPCs (see later migrations);
-- clients only get SELECT, filtered by row level security.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public;

create type public.game_status as enum ('lobby', 'headstart', 'running', 'ended');
create type public.team as enum ('hunter', 'runner');
create type public.player_status as enum ('active', 'tagged', 'spectator');
create type public.tag_status as enum ('pending', 'confirmed', 'rejected', 'cancelled');

-- Default settings of a new game. Keys are validated by private.validate_settings().
create function private.default_settings() returns jsonb
language sql immutable as $$
  select jsonb_build_object(
    'round_minutes', 30,
    'headstart_minutes', 5,
    'pings_enabled', true,
    'ping_interval_minutes', 3,
    'zone_enabled', true,
    'zone_center', null,            -- {"lat": .., "lng": ..}, set by host on the map
    'zone_radius_m', 1000,
    'zone_shrink_interval_minutes', 5,
    'zone_shrink_percent', 15,
    'zone_min_radius_m', 100,
    'zone_grace_seconds', 30,       -- outside the zone longer than this => visible to hunters
    'tag_confirm_seconds', 30,      -- runner must answer a tag within this time, then host decides
    'spectator_view', 'all'         -- 'all' | 'hunter': what tagged players see
  )
$$;

create table public.games (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9]{6}$'),
  host_id uuid not null references auth.users (id) on delete cascade,
  status public.game_status not null default 'lobby',
  settings jsonb not null default private.default_settings(),
  winner public.team,                 -- null while running or when aborted
  created_at timestamptz not null default now(),
  started_at timestamptz,             -- headstart begins
  headstart_ends_at timestamptz,      -- round begins
  ends_at timestamptz,                -- round time is over
  ended_at timestamptz,
  next_ping_at timestamptz
);

create table public.players (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 24),
  team public.team not null default 'runner',
  status public.player_status not null default 'active',
  joined_at timestamptz not null default now(),
  tagged_at timestamptz,
  out_of_zone_since timestamptz,
  distance_m double precision not null default 0,
  unique (game_id, user_id)
);
create index players_game_idx on public.players (game_id);
create index players_user_idx on public.players (user_id);

-- Push tokens live apart from players so other players can never read them.
create table public.push_tokens (
  player_id uuid primary key references public.players (id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

-- Latest position per player only.
create table public.locations (
  player_id uuid primary key references public.players (id) on delete cascade,
  game_id uuid not null references public.games (id) on delete cascade,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  accuracy double precision,
  updated_at timestamptz not null default now()
);
create index locations_game_idx on public.locations (game_id);

-- Full path, used for distance statistics and a later replay.
create table public.location_track (
  id bigint generated always as identity primary key,
  player_id uuid not null references public.players (id) on delete cascade,
  game_id uuid not null references public.games (id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  ts timestamptz not null default now()
);
create index location_track_player_idx on public.location_track (player_id, ts);

create table public.pings (
  id bigint generated always as identity primary key,
  game_id uuid not null references public.games (id) on delete cascade,
  runner_id uuid not null references public.players (id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  captured_at timestamptz not null,   -- when the runner's phone measured the position
  created_at timestamptz not null default now()  -- when the ping went out
);
create index pings_game_idx on public.pings (game_id, created_at desc);

create table public.tags (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  hunter_id uuid not null references public.players (id) on delete cascade,
  runner_id uuid not null references public.players (id) on delete cascade,
  status public.tag_status not null default 'pending',
  ts timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by_host boolean not null default false
);
create index tags_game_idx on public.tags (game_id);
-- At most one open tag per runner.
create unique index tags_one_pending_per_runner on public.tags (runner_id) where status = 'pending';

create table public.zone_state (
  game_id uuid primary key references public.games (id) on delete cascade,
  center_lat double precision not null,
  center_lng double precision not null,
  radius_m double precision not null check (radius_m > 0),
  next_shrink_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.messages (
  id bigint generated always as identity primary key,
  game_id uuid not null references public.games (id) on delete cascade,
  team public.team not null,
  player_id uuid not null references public.players (id) on delete cascade,
  text text not null check (char_length(text) between 1 and 500),
  ts timestamptz not null default now()
);
create index messages_game_team_idx on public.messages (game_id, team, ts);
