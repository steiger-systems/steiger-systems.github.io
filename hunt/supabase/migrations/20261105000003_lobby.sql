-- Hunt: lobby RPCs (create, join, teams, settings, leave/kick).
-- Errors are raised with stable codes in the message (e.g. 'game_not_found')
-- so the app can map them to German UI texts.

create function private.require_user() returns uuid
language plpgsql stable as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  return auth.uid();
end $$;

create function private.require_host(p_game uuid) returns public.games
language plpgsql stable security definer set search_path = '' as $$
declare g public.games;
begin
  select * into g from public.games where id = p_game;
  if not found then raise exception 'game_not_found'; end if;
  if g.host_id is distinct from auth.uid() then raise exception 'not_host'; end if;
  return g;
end $$;

create function private.clean_name(p_name text) returns text
language plpgsql immutable as $$
declare n text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
begin
  if char_length(n) < 1 or char_length(n) > 24 then
    raise exception 'invalid_name';
  end if;
  return n;
end $$;

create function private.new_game_code() returns text
language plpgsql volatile as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no 0/O, 1/I
  c text;
begin
  loop
    select string_agg(substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1), '')
      into c from generate_series(1, 6);
    exit when not exists (select 1 from public.games where code = c);
  end loop;
  return c;
end $$;

-- Merges and validates settings. Unknown keys and out-of-range values raise.
create function private.validate_settings(p_settings jsonb) returns jsonb
language plpgsql immutable as $$
declare
  s jsonb := private.default_settings() || coalesce(p_settings, '{}'::jsonb);
  k text;
  c jsonb;
begin
  for k in select jsonb_object_keys(s) loop
    if not private.default_settings() ? k then
      raise exception 'invalid_setting: %', k;
    end if;
  end loop;

  if jsonb_typeof(s->'round_minutes') <> 'number' or (s->>'round_minutes')::numeric not between 5 and 240
     or jsonb_typeof(s->'headstart_minutes') <> 'number' or (s->>'headstart_minutes')::numeric not between 0 and 60
     or jsonb_typeof(s->'ping_interval_minutes') <> 'number' or (s->>'ping_interval_minutes')::numeric not between 1 and 60
     or jsonb_typeof(s->'zone_radius_m') <> 'number' or (s->>'zone_radius_m')::numeric not between 50 and 20000
     or jsonb_typeof(s->'zone_shrink_interval_minutes') <> 'number' or (s->>'zone_shrink_interval_minutes')::numeric not between 1 and 60
     or jsonb_typeof(s->'zone_shrink_percent') <> 'number' or (s->>'zone_shrink_percent')::numeric not between 0 and 50
     or jsonb_typeof(s->'zone_min_radius_m') <> 'number' or (s->>'zone_min_radius_m')::numeric not between 20 and 20000
     or jsonb_typeof(s->'zone_grace_seconds') <> 'number' or (s->>'zone_grace_seconds')::numeric not between 0 and 300
     or jsonb_typeof(s->'tag_confirm_seconds') <> 'number' or (s->>'tag_confirm_seconds')::numeric not between 10 and 300
     or jsonb_typeof(s->'pings_enabled') <> 'boolean'
     or jsonb_typeof(s->'zone_enabled') <> 'boolean'
     or coalesce(s->>'spectator_view', '') not in ('all', 'hunter')
  then
    raise exception 'invalid_settings';
  end if;

  c := s->'zone_center';
  if jsonb_typeof(c) <> 'null' then
    if jsonb_typeof(c) <> 'object'
       or jsonb_typeof(c->'lat') <> 'number' or jsonb_typeof(c->'lng') <> 'number'
       or (c->>'lat')::numeric not between -90 and 90
       or (c->>'lng')::numeric not between -180 and 180 then
      raise exception 'invalid_settings';
    end if;
    s := jsonb_set(s, '{zone_center}', jsonb_build_object('lat', c->'lat', 'lng', c->'lng'));
  end if;
  return s;
end $$;

-- ---------------------------------------------------------------------------

create function public.create_game(p_name text, p_settings jsonb default null)
returns public.games
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := private.require_user();
  g public.games;
begin
  insert into public.games (code, host_id, settings)
  values (private.new_game_code(), uid, private.validate_settings(p_settings))
  returning * into g;

  insert into public.players (game_id, user_id, name, team)
  values (g.id, uid, private.clean_name(p_name), 'hunter');
  return g;
end $$;

-- Joining is only possible in the lobby. Re-joining with the same account just
-- renames the existing player (e.g. after an app restart).
create function public.join_game(p_code text, p_name text)
returns public.games
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := private.require_user();
  g public.games;
  n text := private.clean_name(p_name);
begin
  select * into g from public.games where code = upper(btrim(p_code));
  if not found then raise exception 'game_not_found'; end if;

  if exists (select 1 from public.players where game_id = g.id and user_id = uid) then
    if g.status = 'lobby' then
      update public.players set name = n where game_id = g.id and user_id = uid;
    end if;
    return g;
  end if;

  if g.status <> 'lobby' then raise exception 'game_already_started'; end if;
  if (select count(*) from public.players where game_id = g.id) >= 30 then
    raise exception 'game_full';
  end if;

  insert into public.players (game_id, user_id, name) values (g.id, uid, n);
  return g;
end $$;

create function public.set_player_team(p_player uuid, p_team public.team)
returns void
language plpgsql security definer set search_path = '' as $$
declare g public.games;
begin
  select * into g from public.games where id = (select game_id from public.players where id = p_player);
  if not found then raise exception 'player_not_found'; end if;
  perform private.require_host(g.id);
  if g.status <> 'lobby' then raise exception 'not_in_lobby'; end if;
  update public.players set team = p_team where id = p_player;
end $$;

create function public.update_settings(p_game uuid, p_settings jsonb)
returns public.games
language plpgsql security definer set search_path = '' as $$
declare g public.games := private.require_host(p_game);
begin
  if g.status <> 'lobby' then raise exception 'not_in_lobby'; end if;
  update public.games
     set settings = private.validate_settings(g.settings || coalesce(p_settings, '{}'::jsonb))
   where id = p_game
  returning * into g;
  return g;
end $$;

-- Host removes a player from the lobby.
create function public.remove_player(p_player uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare p public.players; g public.games;
begin
  select * into p from public.players where id = p_player;
  if not found then raise exception 'player_not_found'; end if;
  g := private.require_host(p.game_id);
  if g.status <> 'lobby' then raise exception 'not_in_lobby'; end if;
  if p.user_id = g.host_id then raise exception 'cannot_remove_host'; end if;
  delete from public.players where id = p_player;
end $$;

-- Leaving the lobby. If the host leaves, the game is closed.
create function public.leave_game(p_game uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := private.require_user(); g public.games;
begin
  select * into g from public.games where id = p_game;
  if not found then raise exception 'game_not_found'; end if;
  if g.status <> 'lobby' then raise exception 'not_in_lobby'; end if;
  if g.host_id = uid then
    delete from public.games where id = p_game;
  else
    delete from public.players where game_id = p_game and user_id = uid;
  end if;
end $$;

create function public.register_push_token(p_game uuid, p_token text, p_platform text)
returns void
language plpgsql security definer set search_path = '' as $$
declare me public.players := private.me(p_game);
begin
  if me.id is null then raise exception 'not_member'; end if;
  insert into public.push_tokens (player_id, token, platform)
  values (me.id, p_token, p_platform)
  on conflict (player_id) do update set token = excluded.token, platform = excluded.platform, updated_at = now();
end $$;
