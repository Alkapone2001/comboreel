-- Secure editorial operations, publishing validation, and immutable audit history.

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated;

-- Editors are content operators, not identity administrators. Role changes are
-- performed only by trusted server code using the service role.
drop policy if exists "admins manage profiles" on public.profiles;

create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null check (action in ('insert', 'update', 'delete')),
  entity_type text not null,
  entity_id uuid not null,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create index admin_audit_log_recent_idx
on public.admin_audit_log (created_at desc);

alter table public.admin_audit_log enable row level security;
create policy "content staff read audit log"
on public.admin_audit_log for select to authenticated
using (public.is_admin());

create or replace function public.audit_content_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  row_id uuid;
begin
  row_id := case when tg_op = 'DELETE' then old.id else new.id end;
  insert into public.admin_audit_log (
    actor_id, action, entity_type, entity_id, before_data, after_data
  ) values (
    auth.uid(), lower(tg_op), tg_table_name, row_id,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger audit_series_change
after insert or update or delete on public.series
for each row execute function public.audit_content_change();
create trigger audit_seasons_change
after insert or update or delete on public.seasons
for each row execute function public.audit_content_change();
create trigger audit_episodes_change
after insert or update or delete on public.episodes
for each row execute function public.audit_content_change();
create trigger audit_subtitles_change
after insert or update or delete on public.episode_subtitles
for each row execute function public.audit_content_change();

create or replace function public.validate_content_publish()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_table_name = 'episodes' and new.status = 'published' then
    if nullif(btrim(new.title), '') is null
       or nullif(btrim(new.stream_uid), '') is null
       or new.duration_seconds <= 0 then
      raise exception 'Episode needs a title, processed video, and duration before publishing.';
    end if;
    new.published_at := coalesce(new.published_at, now());
  elsif tg_table_name = 'series' and new.status = 'published' then
    if nullif(btrim(new.title), '') is null
       or nullif(btrim(new.synopsis), '') is null
       or nullif(btrim(new.poster_url), '') is null
       or nullif(btrim(new.hero_url), '') is null
       or new.release_year is null
       or nullif(btrim(new.age_rating), '') is null then
      raise exception 'Series metadata is incomplete.';
    end if;
    if not exists (
      select 1 from public.episodes e
      where e.series_id = new.id and e.status = 'published'
    ) then
      raise exception 'Publish at least one episode before publishing the series.';
    end if;
    new.published_at := coalesce(new.published_at, now());
  end if;

  if new.status <> 'published' then
    new.published_at := null;
  end if;
  return new;
end;
$$;

create trigger validate_series_publish
before insert or update on public.series
for each row execute function public.validate_content_publish();
create trigger validate_episode_publish
before insert or update on public.episodes
for each row execute function public.validate_content_publish();

create or replace function public.set_episode_publication(
  target_episode_id uuid,
  should_publish boolean
)
returns public.episodes
language plpgsql
security definer set search_path = public
as $$
declare
  result public.episodes;
begin
  if not public.is_admin() then
    raise exception 'Content editor access required.' using errcode = '42501';
  end if;

  update public.episodes
  set status = case when should_publish then 'published'::public.content_status else 'draft'::public.content_status end,
      published_at = case when should_publish then now() else null end
  where id = target_episode_id
  returning * into result;

  if result.id is null then raise exception 'Episode not found.'; end if;
  return result;
end;
$$;

create or replace function public.set_series_publication(
  target_series_id uuid,
  should_publish boolean
)
returns public.series
language plpgsql
security definer set search_path = public
as $$
declare
  result public.series;
begin
  if not public.is_admin() then
    raise exception 'Content editor access required.' using errcode = '42501';
  end if;

  update public.series
  set status = case when should_publish then 'published'::public.content_status else 'draft'::public.content_status end,
      published_at = case when should_publish then now() else null end
  where id = target_series_id
  returning * into result;

  if result.id is null then raise exception 'Series not found.'; end if;
  return result;
end;
$$;

revoke all on function public.set_episode_publication(uuid, boolean) from public;
revoke all on function public.set_series_publication(uuid, boolean) from public;
grant execute on function public.set_episode_publication(uuid, boolean) to authenticated;
grant execute on function public.set_series_publication(uuid, boolean) to authenticated;

create type public.stream_upload_status as enum (
  'waiting_upload', 'uploading', 'queued', 'processing', 'ready', 'error'
);

create table public.stream_uploads (
  id uuid primary key default gen_random_uuid(),
  episode_id uuid not null unique references public.episodes(id) on delete cascade,
  stream_uid text unique,
  status public.stream_upload_status not null default 'waiting_upload',
  percent_complete numeric(5,2) not null default 0 check (percent_complete between 0 and 100),
  error_reason text,
  created_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger stream_uploads_set_updated_at before update on public.stream_uploads
for each row execute function public.set_updated_at();

alter table public.stream_uploads enable row level security;
create policy "content staff read uploads" on public.stream_uploads
for select to authenticated using (public.is_admin());

-- Only Edge Functions using the service role mutate uploads and assign roles.
revoke all on table public.stream_uploads from anon, authenticated;
grant select on table public.stream_uploads to authenticated;

create or replace function public.assign_user_role_server(
  target_user_id uuid,
  new_role public.app_role
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required.' using errcode = '42501';
  end if;
  update public.profiles set role = new_role where id = target_user_id;
  if not found then raise exception 'Profile not found.'; end if;
end;
$$;

revoke all on function public.assign_user_role_server(uuid, public.app_role) from public;
grant execute on function public.assign_user_role_server(uuid, public.app_role) to service_role;
