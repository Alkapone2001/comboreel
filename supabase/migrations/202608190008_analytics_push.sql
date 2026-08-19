-- Consent-gated first-party analytics and server-owned push operations.

alter table public.profiles
add column analytics_opt_in boolean not null default false,
add column push_opt_in boolean not null default false;

create type public.analytics_event_name as enum (
  'app_opened', 'navigation_selected', 'series_opened', 'playback_started',
  'episode_completed', 'favourite_changed', 'coin_unlock_completed',
  'rewarded_unlock_completed', 'purchase_started', 'purchase_completed'
);

create table public.analytics_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  session_id uuid not null,
  event_name public.analytics_event_name not null,
  series_id uuid references public.series(id) on delete set null,
  episode_id uuid references public.episodes(id) on delete set null,
  platform text not null check (platform in ('android', 'ios', 'web', 'desktop')),
  properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  constraint analytics_properties_object check (jsonb_typeof(properties) = 'object'),
  constraint analytics_properties_size check (pg_column_size(properties) <= 2048)
);

create index analytics_events_recent_idx on public.analytics_events (occurred_at desc);
create index analytics_events_name_recent_idx on public.analytics_events (event_name, occurred_at desc);
create index analytics_events_series_recent_idx on public.analytics_events (series_id, occurred_at desc) where series_id is not null;

alter table public.analytics_events enable row level security;
create policy "content staff read analytics" on public.analytics_events
for select to authenticated using (public.is_admin());
revoke all on public.analytics_events from anon, authenticated;
grant select on public.analytics_events to authenticated;

create or replace function public.record_analytics_event(
  p_session_id uuid,
  p_event_name public.analytics_event_name,
  p_platform text,
  p_series_id uuid default null,
  p_episode_id uuid default null,
  p_properties jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_allowed_keys constant text[] := array['source', 'destination', 'method', 'product_id', 'position_seconds'];
  v_key text;
begin
  if v_user_id is null then return false; end if;
  if not exists (select 1 from public.profiles where id = v_user_id and analytics_opt_in) then
    return false;
  end if;
  if p_platform not in ('android', 'ios', 'web', 'desktop') then
    raise exception 'Unsupported analytics platform.';
  end if;
  if jsonb_typeof(coalesce(p_properties, '{}'::jsonb)) <> 'object'
     or pg_column_size(coalesce(p_properties, '{}'::jsonb)) > 2048 then
    raise exception 'Invalid analytics properties.';
  end if;
  for v_key in select jsonb_object_keys(coalesce(p_properties, '{}'::jsonb)) loop
    if not (v_key = any(v_allowed_keys)) then
      raise exception 'Unsupported analytics property: %', v_key;
    end if;
  end loop;
  insert into public.analytics_events (
    user_id, session_id, event_name, series_id, episode_id, platform, properties
  ) values (
    v_user_id, p_session_id, p_event_name, p_series_id, p_episode_id,
    p_platform, coalesce(p_properties, '{}'::jsonb)
  );
  return true;
end;
$$;

revoke all on function public.record_analytics_event(uuid, public.analytics_event_name, text, uuid, uuid, jsonb) from public;
grant execute on function public.record_analytics_event(uuid, public.analytics_event_name, text, uuid, uuid, jsonb) to authenticated;

create or replace function public.analytics_dashboard(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer set search_path = public
as $$
declare
  v_since timestamptz := now() - make_interval(days => greatest(1, least(p_days, 365)));
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Content editor access required.' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'days', greatest(1, least(p_days, 365)),
    'active_viewers', count(distinct user_id),
    'sessions', count(distinct session_id),
    'series_opens', count(*) filter (where event_name = 'series_opened'),
    'playback_starts', count(*) filter (where event_name = 'playback_started'),
    'completions', count(*) filter (where event_name = 'episode_completed'),
    'unlocks', count(*) filter (where event_name in ('coin_unlock_completed', 'rewarded_unlock_completed')),
    'purchases', count(*) filter (where event_name = 'purchase_completed'),
    'completion_rate', case
      when count(*) filter (where event_name = 'playback_started') = 0 then 0
      else round(100.0 * count(*) filter (where event_name = 'episode_completed') /
        count(*) filter (where event_name = 'playback_started'), 1)
    end
  ) into v_result
  from public.analytics_events where occurred_at >= v_since;
  return v_result || jsonb_build_object(
    'top_series', coalesce((
      select jsonb_agg(row_data order by opens desc)
      from (
        select jsonb_build_object('series_id', s.id, 'title', s.title, 'opens', count(*)) row_data,
               count(*) opens
        from public.analytics_events e join public.series s on s.id = e.series_id
        where e.occurred_at >= v_since and e.event_name = 'series_opened'
        group by s.id, s.title order by count(*) desc limit 5
      ) ranked
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.analytics_dashboard(integer) from public;
grant execute on function public.analytics_dashboard(integer) to authenticated;

create type public.push_platform as enum ('android', 'ios', 'web');
create type public.push_campaign_status as enum ('draft', 'sending', 'sent', 'failed', 'cancelled');

create table public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform public.push_platform not null,
  locale text not null default 'en',
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index push_devices_user_idx on public.push_devices (user_id, enabled);

create table public.push_campaigns (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 100),
  body text not null check (char_length(body) between 1 and 240),
  deep_link text check (deep_link is null or deep_link ~ '^comboreel://'),
  audience text not null default 'all_opted_in' check (audience = 'all_opted_in'),
  status public.push_campaign_status not null default 'draft',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  target_count integer not null default 0,
  success_count integer not null default 0,
  failure_count integer not null default 0,
  error_summary text
);

alter table public.push_devices enable row level security;
alter table public.push_campaigns enable row level security;
create policy "content staff read campaigns" on public.push_campaigns
for select to authenticated using (public.is_admin());
create policy "content staff create draft campaigns" on public.push_campaigns
for insert to authenticated with check (
  public.is_admin() and created_by = auth.uid() and status = 'draft'
);
revoke all on public.push_devices from anon, authenticated;
revoke all on public.push_campaigns from anon, authenticated;
grant select, insert on public.push_campaigns to authenticated;

create or replace function public.create_push_campaign(
  p_title text,
  p_body text,
  p_deep_link text default null
)
returns public.push_campaigns
language plpgsql
security definer set search_path = public
as $$
declare v_result public.push_campaigns;
begin
  if not public.is_admin() then
    raise exception 'Content editor access required.' using errcode = '42501';
  end if;
  insert into public.push_campaigns (title, body, deep_link, created_by)
  values (btrim(p_title), btrim(p_body), nullif(btrim(p_deep_link), ''), auth.uid())
  returning * into v_result;
  return v_result;
end;
$$;

revoke all on function public.create_push_campaign(text, text, text) from public;
grant execute on function public.create_push_campaign(text, text, text) to authenticated;
