-- Minimal stand-in for the parts of Supabase the migrations rely on.
-- Used ONLY for local tests on plain Postgres (scripts/test_db.sh).
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;
create schema auth;
create schema extensions;
create publication supabase_realtime;
grant usage on schema auth, extensions, public to anon, authenticated;
create table auth.users (id uuid primary key, is_anonymous boolean default true);
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;
grant execute on function auth.uid() to anon, authenticated;

-- test helpers
create schema tests;
grant usage on schema tests to public;
create table tests.names (name text primary key, id uuid not null);
grant select on tests.names to public;

create function tests.uid(p_name text) returns uuid language sql stable as $$
  select id from tests.names where name = p_name $$;

-- Switch to an (anonymous) signed-in user. Creates the auth user on first use.
create function tests.login(p_name text) returns void language plpgsql as $$
declare u uuid;
begin
  perform set_config('role', 'postgres', false);
  select id into u from tests.names where name = p_name;
  if u is null then
    u := gen_random_uuid();
    insert into tests.names values (p_name, u);
    insert into auth.users (id) values (u);
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, false);
  perform set_config('role', 'authenticated', false);
end $$;

create function tests.as_admin() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', false);
  perform set_config('request.jwt.claims', '', false);
end $$;

create function tests.ok(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if p_cond is distinct from true then raise exception 'FAIL: %', p_msg; end if;
  raise notice 'ok - %', p_msg;
end $$;

-- Runs p_sql and expects an error whose message contains p_expected.
create function tests.throws(p_sql text, p_expected text, p_msg text) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if position(p_expected in sqlerrm) = 0 then
      raise exception 'FAIL: % (expected error "%", got "%")', p_msg, p_expected, sqlerrm;
    end if;
    raise notice 'ok - %', p_msg;
    return;
  end;
  raise exception 'FAIL: % (expected error "%", got none)', p_msg, p_expected;
end $$;
grant execute on all functions in schema tests to public;
