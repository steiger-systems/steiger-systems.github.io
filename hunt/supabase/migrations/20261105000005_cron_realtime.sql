-- Hunt: scheduling, realtime and final privilege hardening.

-- Internal functions are not callable by clients. Only the helpers that RLS
-- policies use stay executable for `authenticated`.
revoke all on all functions in schema private from public, anon, authenticated;
alter default privileges in schema private revoke execute on functions from public;
grant execute on function
  private.is_member(uuid),
  private.can_see_location(uuid, uuid),
  private.can_see_pings(uuid, uuid),
  private.can_read_team_chat(uuid, public.team),
  private.owns_player(uuid)
to authenticated;

-- Realtime: clients subscribe to changes; Supabase Realtime applies RLS.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table
      public.games, public.players, public.locations, public.pings,
      public.tags, public.zone_state, public.messages;
  else
    raise notice 'publication supabase_realtime not found, skipping (local test database?)';
  end if;
end $$;

-- pg_cron: game clock every 5 seconds, cleanup once a day.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('hunt-game-tick', '5 seconds', 'select private.game_tick()');
    perform cron.schedule('hunt-cleanup', '17 3 * * *', 'select private.cleanup_old_games()');
  else
    raise notice 'pg_cron not available, skipping schedules (local test database?)';
  end if;
end $$;
