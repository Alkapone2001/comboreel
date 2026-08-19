-- Atomic entitlement and coin-ledger operations.

create unique index entitlements_episode_once_idx
on public.entitlements (user_id, episode_id)
where type = 'episode';

create or replace function public.has_episode_access(p_episode_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1
    from public.episodes e
    where e.id = p_episode_id
      and e.status = 'published'
      and (
        e.is_free
        or exists (
          select 1 from public.entitlements en
          where en.user_id = auth.uid()
            and (en.expires_at is null or en.expires_at > now())
            and (
              (en.type = 'episode' and en.episode_id = e.id)
              or (en.type = 'series' and en.series_id = e.series_id)
              or en.type = 'premium'
            )
        )
        or exists (
          select 1 from public.subscriptions s
          where s.user_id = auth.uid()
            and s.status in ('trialing', 'active')
            and (s.current_period_end is null or s.current_period_end > now())
        )
      )
  );
$$;

revoke all on function public.has_episode_access(uuid) from public;
grant execute on function public.has_episode_access(uuid) to anon, authenticated;

create or replace function public.unlock_episode_with_coins(
  p_episode_id uuid,
  p_idempotency_key text
)
returns table (access_granted boolean, balance integer, already_owned boolean)
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_price integer;
  v_balance integer;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = 'P0001';
  end if;
  if p_idempotency_key is null or char_length(trim(p_idempotency_key)) < 12 then
    raise exception 'invalid_idempotency_key' using errcode = '22023';
  end if;

  select coin_price into v_price
  from public.episodes
  where id = p_episode_id and status = 'published'
  for share;
  if not found then
    raise exception 'episode_not_found' using errcode = 'P0002';
  end if;

  insert into public.wallets (user_id, balance) values (v_user_id, 0)
  on conflict (user_id) do nothing;
  select w.balance into v_balance
  from public.wallets w
  where w.user_id = v_user_id
  for update;

  if public.has_episode_access(p_episode_id) then
    return query select true, v_balance, true;
    return;
  end if;

  if exists (
    select 1 from public.coin_transactions t
    where t.user_id = v_user_id
      and t.reason = 'episode_unlock'
      and t.reference_id = p_idempotency_key
  ) then
    return query select public.has_episode_access(p_episode_id), v_balance, true;
    return;
  end if;

  if v_balance < v_price then
    raise exception 'insufficient_coins' using errcode = 'P0001';
  end if;

  v_balance := v_balance - v_price;
  update public.wallets set balance = v_balance where user_id = v_user_id;
  insert into public.coin_transactions (
    user_id, amount, reason, reference_id, balance_after
  ) values (
    v_user_id, -v_price, 'episode_unlock', p_idempotency_key, v_balance
  );
  insert into public.entitlements (
    user_id, type, episode_id, source, source_reference
  ) values (
    v_user_id, 'episode', p_episode_id, 'coins', p_idempotency_key
  ) on conflict do nothing;

  return query select true, v_balance, false;
end;
$$;

revoke all on function public.unlock_episode_with_coins(uuid, text) from public;
grant execute on function public.unlock_episode_with_coins(uuid, text) to authenticated;

create or replace function public.credit_coins_server(
  p_user_id uuid,
  p_amount integer,
  p_reason public.coin_reason,
  p_reference_id text
)
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_balance integer;
begin
  if p_amount <= 0 then
    raise exception 'credit_amount_must_be_positive' using errcode = '22023';
  end if;
  if p_reason not in ('purchase', 'rewarded_ad', 'daily_reward', 'refund', 'admin_adjustment') then
    raise exception 'invalid_credit_reason' using errcode = '22023';
  end if;
  if p_reference_id is null or char_length(trim(p_reference_id)) < 8 then
    raise exception 'invalid_reference_id' using errcode = '22023';
  end if;

  insert into public.wallets (user_id, balance) values (p_user_id, 0)
  on conflict (user_id) do nothing;
  select w.balance into v_balance
  from public.wallets w
  where w.user_id = p_user_id
  for update;

  if exists (
    select 1 from public.coin_transactions t
    where t.user_id = p_user_id
      and t.reason = p_reason
      and t.reference_id = p_reference_id
  ) then
    return v_balance;
  end if;

  v_balance := v_balance + p_amount;
  update public.wallets set balance = v_balance where user_id = p_user_id;
  insert into public.coin_transactions (
    user_id, amount, reason, reference_id, balance_after
  ) values (
    p_user_id, p_amount, p_reason, p_reference_id, v_balance
  );
  return v_balance;
end;
$$;

revoke all on function public.credit_coins_server(uuid, integer, public.coin_reason, text) from public;
grant execute on function public.credit_coins_server(uuid, integer, public.coin_reason, text) to service_role;

create or replace function public.grant_rewarded_episode_server(
  p_user_id uuid,
  p_episode_id uuid,
  p_provider_event_id text
)
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  if p_provider_event_id is null or char_length(trim(p_provider_event_id)) < 8 then
    raise exception 'invalid_provider_event_id' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.episodes
    where id = p_episode_id and status = 'published'
  ) then
    raise exception 'episode_not_found' using errcode = 'P0002';
  end if;

  insert into public.entitlements (
    user_id, type, episode_id, source, source_reference
  ) values (
    p_user_id, 'episode', p_episode_id, 'ad_reward', p_provider_event_id
  ) on conflict do nothing;
  return true;
end;
$$;

revoke all on function public.grant_rewarded_episode_server(uuid, uuid, text) from public;
grant execute on function public.grant_rewarded_episode_server(uuid, uuid, text) to service_role;
