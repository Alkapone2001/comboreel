-- Versioned consent history and privacy lifecycle support.

create type public.privacy_consent_kind as enum (
  'privacy_policy', 'terms', 'analytics', 'push', 'marketing'
);

create table public.privacy_consents (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind public.privacy_consent_kind not null,
  granted boolean not null,
  document_version text not null check (char_length(document_version) between 1 and 40),
  source text not null check (source in ('signup', 'profile', 'system')),
  occurred_at timestamptz not null default now()
);
create index privacy_consents_user_recent_idx on public.privacy_consents (user_id, occurred_at desc);
alter table public.privacy_consents enable row level security;
create policy "users read own consent history" on public.privacy_consents
for select to authenticated using (user_id = auth.uid());
revoke all on public.privacy_consents from anon, authenticated;
grant select on public.privacy_consents to authenticated;

create or replace function public.set_privacy_preference(
  p_kind public.privacy_consent_kind,
  p_granted boolean,
  p_document_version text
)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  if p_kind not in ('analytics', 'push', 'marketing') then raise exception 'invalid_preference'; end if;
  if p_document_version is null or char_length(p_document_version) not between 1 and 40 then raise exception 'invalid_version'; end if;
  if p_kind = 'analytics' then update public.profiles set analytics_opt_in = p_granted where id = v_user_id;
  elsif p_kind = 'push' then update public.profiles set push_opt_in = p_granted where id = v_user_id;
  else update public.profiles set marketing_opt_in = p_granted where id = v_user_id;
  end if;
  insert into public.privacy_consents(user_id, kind, granted, document_version, source)
  values (v_user_id, p_kind, p_granted, p_document_version, 'profile');
  return true;
end; $$;
revoke all on function public.set_privacy_preference(public.privacy_consent_kind, boolean, text) from public;
grant execute on function public.set_privacy_preference(public.privacy_consent_kind, boolean, text) to authenticated;

-- Prevent clients from bypassing consent history by editing opt-in columns.
-- Role assignment remains a service-role operation.
revoke update on public.profiles from authenticated;
grant update (display_name, avatar_url, preferred_language) on public.profiles to authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_privacy text := new.raw_user_meta_data ->> 'privacy_version';
declare v_terms text := new.raw_user_meta_data ->> 'terms_version';
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(new.email, '@', 1)));
  insert into public.wallets (user_id) values (new.id);
  if v_privacy is not null then
    insert into public.privacy_consents(user_id, kind, granted, document_version, source)
    values (new.id, 'privacy_policy', true, v_privacy, 'signup');
  end if;
  if v_terms is not null then
    insert into public.privacy_consents(user_id, kind, granted, document_version, source)
    values (new.id, 'terms', true, v_terms, 'signup');
  end if;
  return new;
end; $$;
