begin;

insert into auth.users (id, email) values
  ('71717171-7171-4717-8717-717171717171', 'playback-one@example.com'),
  ('72727272-7272-4727-8727-727272727272', 'playback-two@example.com');

do $$
begin
  if exists (
    select 1 from public.profiles
    where id = '71717171-7171-4717-8717-717171717171'
      and (playback_muted or playback_speed <> 1.00)
  ) then
    raise exception 'playback preference defaults are incorrect';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '71717171-7171-4717-8717-717171717171', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

update public.profiles
set playback_muted = true, playback_speed = 1.50
where id = '71717171-7171-4717-8717-717171717171';

update public.profiles
set playback_muted = true, playback_speed = 2.00
where id = '72727272-7272-4727-8727-727272727272';

do $$
begin
  begin
    update public.profiles
    set playback_speed = 1.10
    where id = '71717171-7171-4717-8717-717171717171';
    raise exception 'unsupported playback speed unexpectedly succeeded';
  exception when check_violation then
    null;
  end;
end $$;

reset role;

do $$
begin
  if not exists (
    select 1 from public.profiles
    where id = '71717171-7171-4717-8717-717171717171'
      and playback_muted and playback_speed = 1.50
  ) then
    raise exception 'viewer playback preferences were not persisted';
  end if;
  if exists (
    select 1 from public.profiles
    where id = '72727272-7272-4727-8727-727272727272'
      and (playback_muted or playback_speed <> 1.00)
  ) then
    raise exception 'viewer changed another profile playback preference';
  end if;
end $$;

rollback;
