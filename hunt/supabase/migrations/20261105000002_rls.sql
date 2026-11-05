-- Hunt: visibility rules (row level security).
--
-- Core rule: hunters never read runner positions from `locations` while the
-- game is going on. They get them from `pings` only. Exception: a runner who
-- has been outside the zone for longer than zone_grace_seconds.

-- ---------------------------------------------------------------------------
-- Helpers (security definer, so policies can look at players without
-- recursing into the players policy).
-- ---------------------------------------------------------------------------

-- Great-circle distance in metres.
create function private.distance_m(lat1 double precision, lng1 double precision,
                                   lat2 double precision, lng2 double precision)
returns double precision
language sql immutable strict as $$
  select 2 * 6371008.8 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  ))
$$;

-- The calling user's player row in a game (null if not a member).
create function private.me(p_game uuid) returns public.players
language sql stable security definer set search_path = '' as $$
  select p.* from public.players p where p.game_id = p_game and p.user_id = auth.uid()
$$;

create function private.is_member(p_game uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.players p where p.game_id = p_game and p.user_id = auth.uid())
$$;

create function private.can_see_location(p_game uuid, p_target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.players me
    join public.games g on g.id = me.game_id
    join public.players t on t.game_id = me.game_id and t.id = p_target
    where me.game_id = p_game
      and me.user_id = auth.uid()
      and (
        me.id = t.id
        or g.status = 'ended'
        -- observers with full view
        or (me.status <> 'active' and g.settings ->> 'spectator_view' = 'all')
        -- own team (observers keep seeing their own team as well)
        or (me.team = t.team and g.status in ('headstart', 'running') and me.status = 'active')
        -- hunter-like view: own hunters + runners outside the zone too long
        or (
          (me.team = 'hunter' or (me.status <> 'active' and g.settings ->> 'spectator_view' = 'hunter'))
          and (
            (t.team = 'hunter' and g.status in ('headstart', 'running'))
            or (
              t.team = 'runner' and t.status = 'active' and g.status = 'running'
              and t.out_of_zone_since is not null
              and t.out_of_zone_since <= now()
                  - make_interval(secs => coalesce((g.settings ->> 'zone_grace_seconds')::int, 30))
            )
          )
        )
      )
  )
$$;

create function private.can_see_pings(p_game uuid, p_runner uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.players me
    join public.games g on g.id = me.game_id
    where me.game_id = p_game
      and me.user_id = auth.uid()
      and (
        me.team = 'hunter'
        or me.status <> 'active'       -- observers (both spectator views include pings)
        or me.id = p_runner            -- runners see when they were pinged
        or g.status = 'ended'
      )
  )
$$;

create function private.can_read_team_chat(p_game uuid, p_team public.team) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.players me
    where me.game_id = p_game and me.user_id = auth.uid() and me.team = p_team
  )
$$;

create function private.owns_player(p_player uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.players p where p.id = p_player and p.user_id = auth.uid())
$$;

-- ---------------------------------------------------------------------------
-- Privileges: read-only for clients, everything else through RPCs.
-- ---------------------------------------------------------------------------

grant usage on schema private to authenticated;  -- policies call these helpers
revoke all on all functions in schema private from public, anon;
grant execute on function
  private.is_member(uuid),
  private.can_see_location(uuid, uuid),
  private.can_see_pings(uuid, uuid),
  private.can_read_team_chat(uuid, public.team),
  private.owns_player(uuid)
to authenticated;

do $$
declare t text;
begin
  foreach t in array array['games', 'players', 'push_tokens', 'locations', 'location_track',
                           'pings', 'tags', 'zone_state', 'messages'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Policies (select only).
-- ---------------------------------------------------------------------------

create policy games_select on public.games for select to authenticated
  using (private.is_member(id));

create policy players_select on public.players for select to authenticated
  using (private.is_member(game_id));

create policy push_tokens_select on public.push_tokens for select to authenticated
  using (private.owns_player(player_id));

create policy locations_select on public.locations for select to authenticated
  using (private.can_see_location(game_id, player_id));

create policy location_track_select on public.location_track for select to authenticated
  using (
    private.owns_player(player_id)
    or exists (select 1 from public.games g where g.id = game_id and g.status = 'ended')
       and private.is_member(game_id)
  );

create policy pings_select on public.pings for select to authenticated
  using (private.can_see_pings(game_id, runner_id));

create policy tags_select on public.tags for select to authenticated
  using (private.is_member(game_id));

create policy zone_state_select on public.zone_state for select to authenticated
  using (private.is_member(game_id));

create policy messages_select on public.messages for select to authenticated
  using (private.can_read_team_chat(game_id, team));
