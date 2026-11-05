-- Game flow and visibility: headstart, pings, zone, tags, chat, end, stats.
-- Positions around Zurich; zone center 47.3700/8.5400, radius 1000 m.
select tests.login('h1');
create temp table g as select * from public.create_game('Hanna',
  '{"headstart_minutes": 5, "round_minutes": 30, "ping_interval_minutes": 3,
    "zone_center": {"lat": 47.37, "lng": 8.54}, "zone_radius_m": 1000,
    "zone_shrink_interval_minutes": 5, "zone_shrink_percent": 15}');
grant select on g to public;
create temp table ids (name text primary key, id uuid);
grant all on ids to public;

select tests.login('h2'); select public.join_game((select code from g), 'Hugo');
select tests.login('r1'); select public.join_game((select code from g), 'Rita');
select tests.login('r2'); select public.join_game((select code from g), 'Ruedi');
select tests.login('r3'); select public.join_game((select code from g), 'Rosa');
insert into ids select name, id from public.players;

select tests.login('h1');
select tests.throws(format($$select public.update_location(%L, 47.37, 8.54)$$, (select id from g)), 'not_running', 'no locations in lobby');
select public.set_player_team((select id from ids where name = 'Hanna'), 'runner');
select tests.throws(format($$select public.start_game(%L)$$, (select id from g)), 'need_both_teams', 'start needs both teams');
select public.set_player_team((select id from ids where name = 'Hanna'), 'hunter');
select public.set_player_team((select id from ids where name = 'Hugo'), 'hunter');
select public.start_game((select id from g));
select tests.ok((select status = 'headstart' from public.games), 'game in headstart');
select tests.ok((select abs(extract(epoch from ends_at - headstart_ends_at) - 1800) < 1 from public.games), 'round is 30 min after headstart');
select tests.ok((select radius_m = 1000 from public.zone_state), 'zone created');
select tests.login('late');
select tests.throws(format($$select public.join_game(%L, 'Late')$$, (select code from g)), 'game_already_started', 'no joining after start');

-- ---- headstart: everyone shares positions ----
select tests.login('h1'); select public.update_location((select id from g), 47.3700, 8.5400, 5);
select tests.login('h2'); select public.update_location((select id from g), 47.3705, 8.5405, 5);
select tests.login('r1'); select public.update_location((select id from g), 47.3700, 8.5400, 5);
select tests.login('r2'); select public.update_location((select id from g), 47.3720, 8.5410, 5);
select tests.login('r3'); select public.update_location((select id from g), 47.3900, 8.5400, 5);  -- ~2.2 km out

select tests.login('h1');
select tests.ok((select count(*) = 2 from public.locations), 'headstart: hunter sees only hunters');
select tests.throws(format($$select public.report_tag(%L, %L)$$, (select id from g), (select id from ids where name = 'Rita')), 'not_running', 'no tags during headstart');
select tests.login('r1');
select tests.ok((select count(*) = 3 from public.locations), 'headstart: runner sees own team');
select tests.ok((select count(*) = 0 from public.locations l join public.players p on p.id = l.player_id where p.team = 'hunter'), 'runner never sees hunters');

-- ---- round starts (clock driven by the server) ----
select tests.as_admin();
select private.game_tick((select headstart_ends_at - interval '1 second' from public.games where id = (select id from g)));
select tests.ok((select status = 'headstart' from public.games where id = (select id from g)), 'tick before headstart end changes nothing');
select private.game_tick((select headstart_ends_at from public.games where id = (select id from g)));
select tests.ok((select status = 'running' from public.games where id = (select id from g)), 'tick switches to running');
select tests.ok((select out_of_zone_since is not null from public.players where name = 'Rosa'), 'runner outside zone flagged');
select tests.ok((select out_of_zone_since is null from public.players where name = 'Ruedi'), 'runner inside zone not flagged');

select tests.login('h1');
select tests.ok((select count(*) = 2 from public.locations), 'running: hunters still do not see runners live');

-- grace period over => outside runner visible
select tests.as_admin();
update public.players set out_of_zone_since = now() - interval '31 seconds' where name = 'Rosa';
select tests.login('h1');
select tests.ok((select count(*) = 3 from public.locations), 'runner outside zone > 30 s visible to hunters');
select tests.ok((select bool_and(p.name in ('Hanna', 'Hugo', 'Rosa')) from public.locations l join public.players p on p.id = l.player_id), '... and only that runner');

-- ---- pings ----
select tests.as_admin();
select private.game_tick((select next_ping_at from public.games where id = (select id from g)));
select tests.login('h1');
select tests.ok((select count(*) = 3 from public.pings), 'hunters get a ping for every runner');
select tests.ok((select count(*) = 1 from public.pings p join public.players r on r.id = p.runner_id where r.name = 'Ruedi' and abs(p.lat - 47.372) < 1e-9), 'ping holds runner position');
select tests.login('r1');
select tests.ok((select count(*) = 1 from public.pings), 'runner sees only own ping');
select tests.as_admin();
select tests.ok((select next_ping_at = headstart_ends_at + interval '6 minutes' from public.games where id = (select id from g)), 'next ping scheduled');

-- ---- zone shrink ----
select private.game_tick((select next_shrink_at from public.zone_state where game_id = (select id from g)));
select tests.ok((select radius_m = 850 from public.zone_state where game_id = (select id from g)), 'zone shrinks by 15 %');
select tests.ok((select next_shrink_at = (select headstart_ends_at from public.games where id = (select id from g)) + interval '10 minutes' from public.zone_state), 'next shrink scheduled');

-- runner returns into the zone
select tests.login('r3'); select public.update_location((select id from g), 47.3701, 8.5401, 5);
select tests.as_admin();
select tests.ok((select out_of_zone_since is null from public.players where name = 'Rosa'), 'back in zone clears flag');
select tests.ok((select distance_m = 0 from public.players where name = 'Rosa'), 'teleport not counted as distance');
select tests.login('h1');
select tests.ok((select count(*) = 2 from public.locations), 'back in zone => invisible again');

-- distance statistics
select public.update_location((select id from g), 47.37009, 8.5400, 5);  -- ~10 m
select tests.ok((select distance_m between 9 and 11 from public.players where user_id = auth.uid()), 'walked distance counted');

-- ---- team chat ----
select tests.login('r1'); select public.send_message((select id from g), 'Bin beim Brunnen');
select tests.login('h1'); select public.send_message((select id from g), 'Ich geh links');
select tests.ok((select count(*) = 1 and min(text) = 'Ich geh links' from public.messages), 'hunter reads only hunter chat');
select tests.throws($$insert into public.messages (game_id, team, player_id, text) select id, 'runner', (select id from ids where name = 'Hanna'), 'fake' from g$$, 'permission denied', 'no direct chat insert');
select tests.login('r2');
select tests.ok((select count(*) = 1 and min(text) = 'Bin beim Brunnen' from public.messages), 'runner reads only runner chat');

-- ---- tags ----
select tests.login('r2');
select tests.throws(format($$select public.report_tag(%L, %L)$$, (select id from g), (select id from ids where name = 'Rita')), 'not_hunter', 'runners cannot tag');
select tests.login('h1');
create temp table t1 as select * from public.report_tag((select id from g), (select id from ids where name = 'Rita'));
grant select on t1 to public;
select tests.throws(format($$select public.report_tag(%L, %L)$$, (select id from g), (select id from ids where name = 'Rita')), 'tag_already_pending', 'one open tag per runner');
select tests.throws(format($$select public.report_tag(%L, %L)$$, (select id from g), (select id from ids where name = 'Hugo')), 'invalid_runner', 'cannot tag a hunter');
select tests.login('r2');
select tests.throws(format($$select public.respond_tag(%L, true)$$, (select id from t1)), 'not_your_tag', 'only the tagged runner answers');
select tests.login('r1');
select tests.ok((select count(*) = 1 from public.tags where status = 'pending'), 'runner sees pending tag');
select public.respond_tag((select id from t1), true);
select tests.ok((select status = 'tagged' from public.players where name = 'Rita'), 'confirmed tag => runner out');
select tests.ok((select status = 'running' from public.games), 'game goes on while runners left');

-- tagged runner becomes spectator (spectator_view = all)
select tests.ok((select count(*) = 5 from public.locations), 'spectator sees all positions');
select tests.ok((select count(*) = 3 from public.pings), 'spectator sees all pings');
select tests.throws(format($$select public.send_message(%L, 'psst')$$, (select id from g)), 'not_active', 'spectator cannot chat');

-- rejected tag, host decides
select tests.login('h2');
create temp table t2 as select * from public.report_tag((select id from g), (select id from ids where name = 'Ruedi'));
grant select on t2 to public;
select tests.login('r2'); select public.respond_tag((select id from t2), false);
select tests.ok((select status = 'active' from public.players where name = 'Ruedi'), 'rejected tag keeps runner in');
select tests.login('h2');
select tests.throws(format($$select public.resolve_tag(%L, true)$$, (select id from t2)), 'not_host', 'only host resolves');
select tests.login('h1');
select public.resolve_tag((select id from t2), true);
select tests.ok((select status = 'tagged' from public.players where name = 'Ruedi'), 'host overturns rejected tag');

-- unanswered tag: host may decide only after tag_confirm_seconds
select tests.login('h1');
create temp table t3 as select * from public.report_tag((select id from g), (select id from ids where name = 'Rosa'));
grant select on t3 to public;
select tests.throws(format($$select public.resolve_tag(%L, true)$$, (select id from t3)), 'tag_not_decidable', 'host must wait for the runner');
select tests.as_admin();
update public.tags set ts = now() - interval '31 seconds' where id = (select id from t3);
select tests.login('h1');
select public.resolve_tag((select id from t3), true);

-- ---- end ----
select tests.ok((select status = 'ended' and winner = 'hunter' from public.games), 'all runners tagged => hunters win');
select tests.ok((select count(*) = 5 from public.locations), 'after the end everyone sees everything');
select tests.login('r2');
select tests.ok((select count(*) > 0 from public.location_track where player_id <> (select id from ids where name = 'Ruedi')), 'tracks visible after end');
select tests.ok((select count(*) = 5 from public.game_stats((select id from g))), 'stats for every player');
select tests.ok((select tags = 2 from public.game_stats((select id from g)) where name = 'Hanna'), 'stats count tags');
select tests.ok((select survived_seconds is not null from public.game_stats((select id from g)) where name = 'Rita'), 'stats have survival time');
select tests.throws(format($$select public.update_location(%L, 47.37, 8.54)$$, (select id from g)), 'not_running', 'no locations after end');

-- ---- second game: time runs out, spectators with hunter view, no zone ----
select tests.login('h1');
create temp table g2 as select * from public.create_game('Hanna',
  '{"headstart_minutes": 0, "zone_enabled": false, "pings_enabled": false, "spectator_view": "hunter"}');
grant select on g2 to public;
select tests.login('r1'); select public.join_game((select code from g2), 'Rita');
select tests.login('r2'); select public.join_game((select code from g2), 'Ruedi');
select tests.login('h1');
select public.start_game((select id from g2));
select tests.ok((select status = 'running' and next_ping_at is null from public.games where id = (select id from g2)), 'headstart 0 => running at once, pings off');
select tests.ok((select count(*) = 0 from public.zone_state where game_id = (select id from g2)), 'no zone when disabled');
select public.update_location((select id from g2), 47.37, 8.54);
select tests.login('r1'); select public.update_location((select id from g2), 47.38, 8.55);
select tests.login('r2'); select public.update_location((select id from g2), 47.39, 8.56);
select tests.login('h1');
select tests.as_admin();
insert into public.tags (game_id, hunter_id, runner_id, status)
  select g2.id, h.id, r.id, 'confirmed' from g2, public.players h, public.players r
   where h.game_id = g2.id and h.team = 'hunter' and r.game_id = g2.id and r.name = 'Rita';
select private.apply_tag(t, now()) from public.tags t where t.game_id = (select id from g2);
select tests.login('r1');
select tests.ok((select count(*) = 2 and bool_and(p.team = 'hunter' or p.name = 'Rita') from public.locations l join public.players p on p.id = l.player_id where l.game_id = (select id from g2)),
  'spectator_view hunter: sees hunters (and self), not the other runners');
select tests.as_admin();
select private.game_tick((select ends_at from public.games where id = (select id from g2)));
select tests.ok((select status = 'ended' and winner = 'runner' from public.games where id = (select id from g2)), 'time over => runners win');

-- host abort
select tests.login('h1');
create temp table g3 as select * from public.create_game('Hanna', '{"zone_enabled": false}');
grant select on g3 to public;
select tests.login('r1'); select public.join_game((select code from g3), 'Rita');
select tests.login('h1'); select public.start_game((select id from g3)); select public.end_game((select id from g3));
select tests.ok((select status = 'ended' and winner is null from public.games where id = (select id from g3)), 'host abort => no winner');

-- zone center is required when the zone is on
create temp table g4 as select * from public.create_game('Hanna');
grant select on g4 to public;
select tests.login('r1'); select public.join_game((select code from g4), 'Rita');
select tests.login('h1');
select tests.throws(format($$select public.start_game(%L)$$, (select id from g4)), 'zone_center_missing', 'zone needs a center');

-- cleanup after 7 days
select tests.as_admin();
update public.games set created_at = now() - interval '8 days' where id = (select id from g);
select tests.ok((select private.cleanup_old_games() = 1), 'cleanup removes old game');
select tests.ok((select count(*) = 0 from public.location_track where game_id = (select id from g)), 'cleanup removes tracks');
