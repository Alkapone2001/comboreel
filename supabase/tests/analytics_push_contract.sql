begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'analytics-viewer@example.com', '{}'::jsonb),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'analytics-editor@example.com', '{}'::jsonb);

update public.profiles set role = 'editor'
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

insert into public.series (
  id, slug, title, synopsis, poster_url, hero_url, release_year, age_rating
) values (
  'cccccccc-cccc-cccc-cccc-cccccccccccc', 'analytics-series',
  'Analytics Series', 'A privacy-safe contract fixture.',
  'https://example.com/poster.jpg', 'https://example.com/hero.jpg', 2026, '16+'
);

insert into public.episodes (
  id, series_id, episode_number, title, duration_seconds, stream_uid
) values (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'cccccccc-cccc-cccc-cccc-cccccccccccc', 1, 'Analytics Pilot', 60, 'analytics-stream'
);

select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $$
declare accepted boolean;
begin
  select public.record_analytics_event(
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'series_opened', 'web',
    'cccccccc-cccc-cccc-cccc-cccccccccccc', null, '{"source":"catalogue"}'::jsonb
  ) into accepted;
  if accepted then raise exception 'analytics was accepted before consent'; end if;
end;
$$;

update public.profiles set analytics_opt_in = true
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

select public.record_analytics_event(
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'series_opened', 'web',
  'cccccccc-cccc-cccc-cccc-cccccccccccc', null, '{"source":"catalogue"}'::jsonb
);
select public.record_analytics_event(
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'playback_started', 'web',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'dddddddd-dddd-dddd-dddd-dddddddddddd', '{"position_seconds":0}'::jsonb
);

select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);

do $$
declare summary jsonb;
begin
  select public.analytics_dashboard(30) into summary;
  if (summary ->> 'active_viewers')::integer <> 1 then
    raise exception 'expected one consented active viewer: %', summary;
  end if;
  if (summary ->> 'playback_starts')::integer <> 1 then
    raise exception 'expected one playback start: %', summary;
  end if;
end;
$$;

select public.create_push_campaign(
  'New episode', 'The next chapter is ready.', 'comboreel://home'
);

do $$
begin
  if (select count(*) from public.push_campaigns where status = 'draft') <> 1 then
    raise exception 'campaign draft was not created';
  end if;
  if has_table_privilege('authenticated', 'public.push_devices', 'insert') then
    raise exception 'authenticated clients can insert device tokens directly';
  end if;
end;
$$;

rollback;
