alter table public.profiles
  add column playback_muted boolean not null default false,
  add column playback_speed numeric(3, 2) not null default 1.00,
  add constraint profiles_playback_speed_allowed
    check (playback_speed in (0.75, 1.00, 1.25, 1.50, 2.00));

grant update (playback_muted, playback_speed)
on public.profiles to authenticated;
