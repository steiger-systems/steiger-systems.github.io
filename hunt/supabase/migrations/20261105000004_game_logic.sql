-- Hunt: server-side game logic.
-- The server decides: phases, pings, zone and the end of the round are driven
-- by private.game_tick() (pg_cron, see next migration), never by the app.

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

create function private.setting_int(p_game public.games, p_key text) returns int
language sql immutable as $$ select (p_game.settings ->> p_key)::int $$;

-- Recomputes out_of_zone_since for all active runners of a game.
create function private.refresh_zone_flags(p_game uuid, p_now timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare z public.zone_state;
begin
  select * into z from public.zone_state where game_id = p_game;
  if not found then
    update public.players set out_of_zone_since = null
     where game_id = p_game and out_of_zone_since is not null;
    return;
  end if;

  update public.players p
     set out_of_zone_since = case
           when outside then coalesce(p.out_of_zone_since, p_now)
           else null
         end
    from (
      select pl.id,
             (l.player_id is not null
              and private.distance_m(z.center_lat, z.center_lng, l.lat, l.lng) > z.radius_m) as outside
        from public.players pl
        left join public.locations l on l.player_id = pl.id
       where pl.game_id = p_game and pl.team = 'runner' and pl.status = 'active'
    ) x
   where p.id = x.id
     and (p.out_of_zone_since is null) = x.outside;  -- only rows whose state changes
end $$;

create function private.finish_game(p_game uuid, p_winner public.team, p_now timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.games
     set status = 'ended', winner = p_winner, ended_at = p_now, next_ping_at = null
   where id = p_game and status <> 'ended';
  update public.tags set status = 'cancelled', resolved_at = p_now
   where game_id = p_game and status = 'pending';
  update public.players set out_of_zone_since = null where game_id = p_game;
  update public.zone_state set next_shrink_at = null where game_id = p_game;
end $$;

create function private.apply_tag(p_tag public.tags, p_now timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.players
     set status = 'tagged', tagged_at = p_now, out_of_zone_since = null
   where id = p_tag.runner_id and status = 'active';

  if not exists (select 1 from public.players
                  where game_id = p_tag.game_id and team = 'runner' and status = 'active') then
    perform private.finish_game(p_tag.game_id, 'hunter', p_now);
  end if;
end $$;

create function private.send_pings(p_game uuid, p_now timestamptz) returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  insert into public.pings (game_id, runner_id, lat, lng, captured_at, created_at)
  select p_game, p.id, l.lat, l.lng, l.updated_at, p_now
    from public.players p
    join public.locations l on l.player_id = p.id
   where p.game_id = p_game and p.team = 'runner' and p.status = 'active';
  get diagnostics n = row_count;
  return n;
end $$;

-- One step of the game clock for a single game.
create function private.tick_game(p_game_id uuid, p_now timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
  g public.games;
  z public.zone_state;
  interval_ping interval;
  interval_shrink interval;
begin
  select * into g from public.games where id = p_game_id for update;
  if not found or g.status not in ('headstart', 'running') then return; end if;

  -- headstart -> running
  if g.status = 'headstart' then
    if p_now < g.headstart_ends_at then return; end if;
    update public.games set status = 'running' where id = g.id returning * into g;
    perform private.refresh_zone_flags(g.id, p_now);
  end if;

  -- round over: remaining runners win
  if p_now >= g.ends_at then
    perform private.finish_game(g.id, 'runner', p_now);
    return;
  end if;

  -- pings
  if (g.settings ->> 'pings_enabled')::boolean and g.next_ping_at is not null and p_now >= g.next_ping_at then
    perform private.send_pings(g.id, p_now);
    interval_ping := make_interval(mins => private.setting_int(g, 'ping_interval_minutes'));
    update public.games
       set next_ping_at = greatest(g.next_ping_at + interval_ping, p_now + interval '1 second')
     where id = g.id;
  end if;

  -- zone shrinking
  select * into z from public.zone_state where game_id = g.id for update;
  if found and z.next_shrink_at is not null and p_now >= z.next_shrink_at then
    interval_shrink := make_interval(mins => private.setting_int(g, 'zone_shrink_interval_minutes'));
    update public.zone_state
       set radius_m = greatest(
             (g.settings ->> 'zone_min_radius_m')::double precision,
             radius_m * (1 - (g.settings ->> 'zone_shrink_percent')::double precision / 100)),
           next_shrink_at = greatest(z.next_shrink_at + interval_shrink, p_now + interval '1 second'),
           updated_at = p_now
     where game_id = g.id;
    perform private.refresh_zone_flags(g.id, p_now);
  end if;
end $$;

-- Called by pg_cron every few seconds. p_now is a parameter for tests.
create function private.game_tick(p_now timestamptz default now()) returns void
language plpgsql security definer set search_path = '' as $$
declare gid uuid;
begin
  for gid in select id from public.games where status in ('headstart', 'running') loop
    perform private.tick_game(gid, p_now);
  end loop;
end $$;

-- Deletes games (and with them all positions, tracks, chats) after 7 days.
create function private.cleanup_old_games() returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  delete from public.games where created_at < now() - interval '7 days';
  get diagnostics n = row_count;
  return n;
end $$;

-- ---------------------------------------------------------------------------
-- Public RPCs
-- ---------------------------------------------------------------------------

create function public.start_game(p_game uuid)
returns public.games
language plpgsql security definer set search_path = '' as $$
declare
  g public.games := private.require_host(p_game);
  now_ts timestamptz := now();
  hs_end timestamptz;
  center jsonb;
begin
  if g.status <> 'lobby' then raise exception 'not_in_lobby'; end if;
  if not exists (select 1 from public.players where game_id = p_game and team = 'hunter' and status = 'active')
     or not exists (select 1 from public.players where game_id = p_game and team = 'runner' and status = 'active') then
    raise exception 'need_both_teams';
  end if;

  center := g.settings -> 'zone_center';
  if (g.settings ->> 'zone_enabled')::boolean and jsonb_typeof(center) <> 'object' then
    raise exception 'zone_center_missing';
  end if;

  hs_end := now_ts + make_interval(mins => private.setting_int(g, 'headstart_minutes'));

  update public.games
     set status = 'headstart',
         started_at = now_ts,
         headstart_ends_at = hs_end,
         ends_at = hs_end + make_interval(mins => private.setting_int(g, 'round_minutes')),
         next_ping_at = case when (settings ->> 'pings_enabled')::boolean
                             then hs_end + make_interval(mins => private.setting_int(g, 'ping_interval_minutes')) end
   where id = p_game
  returning * into g;

  if (g.settings ->> 'zone_enabled')::boolean then
    insert into public.zone_state (game_id, center_lat, center_lng, radius_m, next_shrink_at)
    values (p_game, (center ->> 'lat')::double precision, (center ->> 'lng')::double precision,
            (g.settings ->> 'zone_radius_m')::double precision,
            case when (g.settings ->> 'zone_shrink_percent')::numeric > 0
                 then hs_end + make_interval(mins => private.setting_int(g, 'zone_shrink_interval_minutes')) end)
    on conflict (game_id) do nothing;
  end if;

  -- headstart 0 => running right away
  perform private.tick_game(p_game, now_ts);
  select * into g from public.games where id = p_game;
  return g;
end $$;

-- Host ends the game early. Nobody wins.
create function public.end_game(p_game uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare g public.games := private.require_host(p_game);
begin
  if g.status not in ('headstart', 'running') then raise exception 'not_running'; end if;
  perform private.finish_game(p_game, null, now());
end $$;

-- Sent by the app every 5-10 s during headstart and round.
create function public.update_location(p_game uuid, p_lat double precision, p_lng double precision,
                                       p_accuracy double precision default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  me public.players := private.me(p_game);
  g public.games;
  prev public.locations;
  z public.zone_state;
  now_ts timestamptz := now();
  d double precision;
  secs double precision;
  outside boolean;
begin
  if me.id is null then raise exception 'not_member'; end if;
  select * into g from public.games where id = p_game;
  if g.status not in ('headstart', 'running') then raise exception 'not_running'; end if;
  if me.status <> 'active' then return; end if;   -- tagged players stop sharing
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'invalid_location';
  end if;

  -- distance statistics: only count reasonably accurate fixes at plausible speed
  select * into prev from public.locations where player_id = me.id;
  if found and coalesce(p_accuracy, 0) <= 50 and coalesce(prev.accuracy, 0) <= 50 then
    d := private.distance_m(prev.lat, prev.lng, p_lat, p_lng);
    secs := greatest(extract(epoch from now_ts - prev.updated_at), 1);
    if d >= 3 and d / secs <= 12 then  -- ignore GPS jitter and teleports (> 43 km/h)
      update public.players set distance_m = distance_m + d where id = me.id;
    end if;
  end if;

  insert into public.locations (player_id, game_id, lat, lng, accuracy, updated_at)
  values (me.id, p_game, p_lat, p_lng, p_accuracy, now_ts)
  on conflict (player_id) do update
    set lat = excluded.lat, lng = excluded.lng, accuracy = excluded.accuracy, updated_at = excluded.updated_at;

  insert into public.location_track (player_id, game_id, lat, lng, ts)
  values (me.id, p_game, p_lat, p_lng, now_ts);

  -- zone check (runners only, during the round)
  if me.team = 'runner' and g.status = 'running' then
    select * into z from public.zone_state where game_id = p_game;
    if found then
      outside := private.distance_m(z.center_lat, z.center_lng, p_lat, p_lng) > z.radius_m;
      if outside and me.out_of_zone_since is null then
        update public.players set out_of_zone_since = now_ts where id = me.id;
      elsif not outside and me.out_of_zone_since is not null then
        update public.players set out_of_zone_since = null where id = me.id;
      end if;
    end if;
  end if;
end $$;

-- Hunter touched a runner in real life and reports it.
create function public.report_tag(p_game uuid, p_runner uuid)
returns public.tags
language plpgsql security definer set search_path = '' as $$
declare
  me public.players := private.me(p_game);
  r public.players;
  t public.tags;
begin
  if me.id is null then raise exception 'not_member'; end if;
  if me.team <> 'hunter' or me.status <> 'active' then raise exception 'not_hunter'; end if;
  if (select status from public.games where id = p_game) <> 'running' then raise exception 'not_running'; end if;
  select * into r from public.players where id = p_runner and game_id = p_game;
  if not found or r.team <> 'runner' or r.status <> 'active' then raise exception 'invalid_runner'; end if;
  if exists (select 1 from public.tags where runner_id = p_runner and status = 'pending') then
    raise exception 'tag_already_pending';
  end if;
  insert into public.tags (game_id, hunter_id, runner_id) values (p_game, me.id, p_runner)
  returning * into t;
  return t;
end $$;

-- The tagged runner confirms or rejects.
create function public.respond_tag(p_tag uuid, p_confirm boolean)
returns public.tags
language plpgsql security definer set search_path = '' as $$
declare t public.tags; now_ts timestamptz := now();
begin
  select * into t from public.tags where id = p_tag for update;
  if not found then raise exception 'tag_not_found'; end if;
  if not private.owns_player(t.runner_id) then raise exception 'not_your_tag'; end if;
  if t.status <> 'pending' then raise exception 'tag_not_pending'; end if;

  update public.tags
     set status = case when p_confirm then 'confirmed'::public.tag_status else 'rejected'::public.tag_status end,
         resolved_at = now_ts
   where id = p_tag
  returning * into t;
  if p_confirm then perform private.apply_tag(t, now_ts); end if;
  return t;
end $$;

-- Host decides: a rejected tag, or a pending one the runner did not answer in time.
create function public.resolve_tag(p_tag uuid, p_confirm boolean)
returns public.tags
language plpgsql security definer set search_path = '' as $$
declare t public.tags; g public.games; now_ts timestamptz := now();
begin
  select * into t from public.tags where id = p_tag for update;
  if not found then raise exception 'tag_not_found'; end if;
  g := private.require_host(t.game_id);
  if g.status <> 'running' then raise exception 'not_running'; end if;
  if not (t.status = 'rejected'
          or (t.status = 'pending'
              and now_ts >= t.ts + make_interval(secs => private.setting_int(g, 'tag_confirm_seconds')))) then
    raise exception 'tag_not_decidable';
  end if;
  -- a rejected tag can only be overturned while the runner is still in the game
  if not exists (select 1 from public.players where id = t.runner_id and status = 'active') then
    raise exception 'invalid_runner';
  end if;

  update public.tags
     set status = case when p_confirm then 'confirmed'::public.tag_status else 'rejected'::public.tag_status end,
         resolved_at = now_ts, resolved_by_host = true
   where id = p_tag
  returning * into t;
  if p_confirm then perform private.apply_tag(t, now_ts); end if;
  return t;
end $$;

create function public.send_message(p_game uuid, p_text text)
returns public.messages
language plpgsql security definer set search_path = '' as $$
declare
  me public.players := private.me(p_game);
  m public.messages;
  txt text := btrim(coalesce(p_text, ''));
begin
  if me.id is null then raise exception 'not_member'; end if;
  if me.status <> 'active' then raise exception 'not_active'; end if;
  if (select status from public.games where id = p_game) = 'ended' then raise exception 'game_ended'; end if;
  if char_length(txt) not between 1 and 500 then raise exception 'invalid_message'; end if;
  insert into public.messages (game_id, team, player_id, text) values (p_game, me.team, me.id, txt)
  returning * into m;
  return m;
end $$;

-- End-of-game statistics, one row per player.
create function public.game_stats(p_game uuid)
returns table (player_id uuid, name text, team public.team, status public.player_status,
               survived_seconds int, distance_m double precision, tags int)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_member(p_game) then raise exception 'not_member'; end if;
  return query
    select p.id, p.name, p.team, p.status,
           case when p.team = 'runner' and g.headstart_ends_at is not null then
             greatest(0, extract(epoch from coalesce(p.tagged_at, g.ended_at, now()) - g.headstart_ends_at))::int
           end,
           round(p.distance_m::numeric, 0)::double precision,
           (select count(*)::int from public.tags t where t.hunter_id = p.id and t.status = 'confirmed')
      from public.players p
      join public.games g on g.id = p.game_id
     where p.game_id = p_game
     order by p.team, p.name;
end $$;

-- ---------------------------------------------------------------------------
-- Grants: RPCs only for signed-in (incl. anonymous) users.
-- ---------------------------------------------------------------------------
revoke all on all functions in schema public from public, anon;
grant execute on function
  public.create_game(text, jsonb),
  public.join_game(text, text),
  public.set_player_team(uuid, public.team),
  public.update_settings(uuid, jsonb),
  public.remove_player(uuid),
  public.leave_game(uuid),
  public.register_push_token(uuid, text, text),
  public.start_game(uuid),
  public.end_game(uuid),
  public.update_location(uuid, double precision, double precision, double precision),
  public.report_tag(uuid, uuid),
  public.respond_tag(uuid, boolean),
  public.resolve_tag(uuid, boolean),
  public.send_message(uuid, text),
  public.game_stats(uuid)
to authenticated;
