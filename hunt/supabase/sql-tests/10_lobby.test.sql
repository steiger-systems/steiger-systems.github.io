-- Lobby: create, join, teams, settings, permissions.
select tests.login('host');
create temp table g as select * from public.create_game('Hosti');
grant select on g to public;
select tests.ok((select code ~ '^[A-Z0-9]{6}$' from g), 'game code has 6 characters');
select tests.ok((select status = 'lobby' from g), 'new game is in lobby');
select tests.ok((select settings->>'round_minutes' = '30' from g), 'default round 30 min');
select tests.ok((select team = 'hunter' from public.players where game_id = (select id from g)), 'host starts as hunter');

-- direct writes are not allowed
select tests.throws($$insert into public.games (code, host_id) values ('AAAAAA', auth.uid())$$, 'permission denied', 'no direct insert into games');
select tests.throws($$update public.games set status = 'ended'$$, 'permission denied', 'no direct update of games');
select tests.throws($$select private.game_tick()$$, 'permission denied', 'clients cannot run the game clock');

-- join
select tests.login('alice');
select tests.ok((select count(*) = 0 from public.games), 'non-member sees no games');
select tests.throws(format($$select public.join_game('ZZZZZZ', 'Alice')$$), 'game_not_found', 'unknown code');
select tests.throws(format($$select public.join_game(%L, '   ')$$, (select code from g)), 'invalid_name', 'empty name rejected');
select public.join_game(lower((select code from g)), '  Alice  ');
select tests.ok((select name from public.players where user_id = auth.uid()) = 'Alice', 'joined with trimmed name, code case-insensitive');
select tests.ok((select count(*) = 2 from public.players), 'member sees player list');
select public.join_game((select code from g), 'Alice2');
select tests.ok((select count(*) = 2 from public.players), 'rejoin does not duplicate');
select tests.ok((select name from public.players where user_id = auth.uid()) = 'Alice2', 'rejoin renames');

select tests.login('bob');
select public.join_game((select code from g), 'Bob');

-- only the host manages
select tests.login('alice');
select tests.throws(format($$select public.set_player_team(%L, 'hunter')$$,
  (select id from public.players where name = 'Bob')), 'not_host', 'non-host cannot change teams');
select tests.throws(format($$select public.update_settings(%L, '{"round_minutes": 10}')$$, (select id from g)), 'not_host', 'non-host cannot change settings');
select tests.throws(format($$select public.start_game(%L)$$, (select id from g)), 'not_host', 'non-host cannot start');

select tests.login('host');
select public.set_player_team((select id from public.players where name = 'Bob'), 'hunter');
select tests.ok((select team = 'hunter' from public.players where name = 'Bob'), 'host sets team');
select public.set_player_team((select id from public.players where name = 'Bob'), 'runner');

select tests.throws(format($$select public.update_settings(%L, '{"foo": 1}')$$, (select id from g)), 'invalid_setting', 'unknown setting rejected');
select tests.throws(format($$select public.update_settings(%L, '{"round_minutes": 1}')$$, (select id from g)), 'invalid_settings', 'out of range rejected');
select tests.throws(format($$select public.update_settings(%L, '{"zone_center": {"lat": 100, "lng": 8}}')$$, (select id from g)), 'invalid_settings', 'bad zone center rejected');
select public.update_settings((select id from g), '{"round_minutes": 20, "zone_center": {"lat": 47.37, "lng": 8.54}}');
select tests.ok((select settings->>'round_minutes' = '20' and settings->>'ping_interval_minutes' = '3' from public.games),
  'settings merged, others kept');

-- push tokens are private
select public.register_push_token((select id from g), 'tok-host', 'android');
select tests.login('bob');
select tests.ok((select count(*) = 0 from public.push_tokens), 'others cannot read push tokens');
select tests.login('host');
select tests.ok((select count(*) = 1 from public.push_tokens), 'own push token readable');

-- kick + leave
select tests.login('carol');
select public.join_game((select code from g), 'Carol');
select tests.login('host');
select tests.throws(format($$select public.remove_player(%L)$$, (select id from public.players where name = 'Hosti')), 'cannot_remove_host', 'host cannot kick self');
select public.remove_player((select id from public.players where name = 'Carol'));
select tests.ok((select count(*) = 3 from public.players), 'host kicks player');
select tests.login('alice');
select public.leave_game((select id from g));
select tests.ok((select count(*) = 0 from public.players), 'player leaves lobby');

-- other games stay invisible
select tests.login('dave');
select public.create_game('Dave');
select tests.ok((select count(*) = 1 from public.games), 'dave sees only own game');
select tests.login('host');
select tests.ok((select count(*) = 1 from public.games), 'host sees only own game');
select public.leave_game((select id from g));
select tests.ok((select count(*) = 0 from public.games), 'host leaving closes game');
