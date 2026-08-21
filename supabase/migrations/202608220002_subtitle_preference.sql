alter table public.profiles
  add column subtitles_enabled boolean not null default true;

grant update (subtitles_enabled)
on public.profiles to authenticated;
