begin;

insert into auth.users (id, email, raw_user_meta_data) values (
  '91919191-9191-4919-8919-919191919191',
  'privacy-viewer@example.com',
  '{"display_name":"Privacy Viewer","privacy_version":"2026-08-19","terms_version":"2026-08-19"}'::jsonb
);

do $$
begin
  if (select count(*) from public.privacy_consents
      where user_id = '91919191-9191-4919-8919-919191919191'
        and kind in ('privacy_policy', 'terms') and granted) <> 2 then
    raise exception 'signup legal acceptance history missing';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '91919191-9191-4919-8919-919191919191', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

select public.set_privacy_preference('analytics', true, '2026-08-19');
select public.set_privacy_preference('analytics', false, '2026-08-19');

do $$
begin
  begin
    update public.profiles set analytics_opt_in = true
    where id = '91919191-9191-4919-8919-919191919191';
    raise exception 'direct opt-in update unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;

reset role;

do $$
begin
  if (select analytics_opt_in from public.profiles
      where id = '91919191-9191-4919-8919-919191919191') then
    raise exception 'withdrawn analytics consent was not persisted';
  end if;
  if (select count(*) from public.privacy_consents
      where user_id = '91919191-9191-4919-8919-919191919191'
        and kind = 'analytics') <> 2 then
    raise exception 'preference history is not append-only';
  end if;
end $$;

delete from auth.users where id = '91919191-9191-4919-8919-919191919191';

do $$
begin
  if exists (select 1 from public.profiles
      where id = '91919191-9191-4919-8919-919191919191')
    or exists (select 1 from public.privacy_consents
      where user_id = '91919191-9191-4919-8919-919191919191') then
    raise exception 'account deletion cascade left privacy data behind';
  end if;
end $$;

rollback;
