-- Short-lived rewarded-ad claims and atomic, service-only fulfillment.

create type public.rewarded_ad_claim_status as enum ('pending', 'verified', 'expired');

create table public.rewarded_ad_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  episode_id uuid not null references public.episodes(id) on delete cascade,
  status public.rewarded_ad_claim_status not null default 'pending',
  provider_transaction_id text unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '10 minutes'),
  verified_at timestamptz,
  constraint rewarded_claim_verified_fields check (
    (status = 'verified' and provider_transaction_id is not null and verified_at is not null)
    or (status <> 'verified' and verified_at is null)
  )
);

create index rewarded_ad_claims_user_created_idx
on public.rewarded_ad_claims (user_id, created_at desc);

alter table public.rewarded_ad_claims enable row level security;

create policy "users read own rewarded claims"
on public.rewarded_ad_claims for select to authenticated
using (user_id = auth.uid());

create or replace function public.create_rewarded_episode_claim(p_episode_id uuid)
returns table (claim_id uuid, expires_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_claim public.rewarded_ad_claims%rowtype;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.episodes e
    join public.series s on s.id = e.series_id
    where e.id = p_episode_id and e.status = 'published'
      and s.status = 'published' and not e.is_free
  ) then
    raise exception 'episode_not_rewardable' using errcode = 'P0001';
  end if;

  if public.has_episode_access(p_episode_id) then
    raise exception 'episode_already_owned' using errcode = 'P0001';
  end if;

  update public.rewarded_ad_claims c
  set status = 'expired'
  where c.user_id = v_user_id and c.episode_id = p_episode_id
    and c.status = 'pending' and c.expires_at <= now();

  select * into v_claim
  from public.rewarded_ad_claims c
  where c.user_id = v_user_id and c.episode_id = p_episode_id
    and c.status = 'pending' and c.expires_at > now()
  order by c.created_at desc limit 1;

  if v_claim.id is null then
    insert into public.rewarded_ad_claims (user_id, episode_id)
    values (v_user_id, p_episode_id)
    returning * into v_claim;
  end if;

  return query select v_claim.id, v_claim.expires_at;
end;
$$;

create or replace function public.rewarded_episode_claim_status(p_claim_id uuid)
returns table (status public.rewarded_ad_claim_status, episode_id uuid)
language sql
security definer
set search_path = public
stable
as $$
  select case when c.status = 'pending' and c.expires_at <= now()
         then 'expired'::public.rewarded_ad_claim_status else c.status end,
         c.episode_id
  from public.rewarded_ad_claims c
  where c.id = p_claim_id and c.user_id = auth.uid();
$$;

create or replace function public.complete_rewarded_ad_claim_server(
  p_claim_id uuid,
  p_user_id uuid,
  p_provider_transaction_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_claim public.rewarded_ad_claims%rowtype;
begin
  select * into v_claim from public.rewarded_ad_claims
  where id = p_claim_id for update;
  if v_claim.id is null or v_claim.user_id <> p_user_id then return false; end if;
  if v_claim.status = 'verified' then
    return v_claim.provider_transaction_id = p_provider_transaction_id;
  end if;
  if v_claim.status <> 'pending' or v_claim.expires_at <= now() then
    update public.rewarded_ad_claims set status = 'expired'
    where id = p_claim_id and status = 'pending';
    return false;
  end if;

  update public.rewarded_ad_claims
  set status = 'verified', provider_transaction_id = p_provider_transaction_id,
      verified_at = now()
  where id = p_claim_id;

  perform public.grant_rewarded_episode_server(
    v_claim.user_id, v_claim.episode_id, p_provider_transaction_id
  );
  return true;
exception when unique_violation then
  return false;
end;
$$;

revoke all on public.rewarded_ad_claims from anon, authenticated;
grant select on public.rewarded_ad_claims to authenticated;
revoke all on function public.create_rewarded_episode_claim(uuid) from public;
grant execute on function public.create_rewarded_episode_claim(uuid) to authenticated;
revoke all on function public.rewarded_episode_claim_status(uuid) from public;
grant execute on function public.rewarded_episode_claim_status(uuid) to authenticated;
revoke all on function public.complete_rewarded_ad_claim_server(uuid, uuid, text) from public;
grant execute on function public.complete_rewarded_ad_claim_server(uuid, uuid, text) to service_role;
