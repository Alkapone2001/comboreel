-- Mobile provider lifecycle events, subscription reconciliation, and reversals.

alter table public.wallets drop constraint wallets_balance_check;
alter table public.wallets add constraint wallets_balance_check
check (balance >= -100000);
alter table public.coin_transactions drop constraint coin_transactions_balance_after_check;
alter table public.coin_transactions add constraint coin_transactions_balance_after_check
check (balance_after >= -100000);
alter table public.entitlements add constraint subscription_entitlement_has_expiry
check (source <> 'subscription' or expires_at is not null);

create table public.mobile_provider_events (
  platform public.purchase_platform not null check (platform in ('apple', 'google')),
  provider_event_id text not null,
  event_type text not null,
  processed_at timestamptz not null default now(),
  primary key (platform, provider_event_id)
);

alter table public.mobile_provider_events enable row level security;

create or replace function public.record_mobile_provider_event_server(
  p_platform public.purchase_platform,
  p_provider_event_id text,
  p_event_type text
)
returns boolean
language sql
security definer
set search_path = public
as $$
  insert into public.mobile_provider_events (platform, provider_event_id, event_type)
  values (p_platform, p_provider_event_id, p_event_type)
  on conflict (platform, provider_event_id) do nothing;
  select true;
$$;

create or replace function public.reconcile_mobile_subscription_server(
  p_platform public.purchase_platform,
  p_provider_event_id text,
  p_event_type text,
  p_user_id uuid,
  p_subscription_id text,
  p_product_id text,
  p_raw_status text,
  p_period_start timestamptz,
  p_period_end timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product public.store_products%rowtype;
  v_existing_user uuid;
  v_status public.subscription_status;
  v_entitlement_end timestamptz;
  v_reference text;
begin
  if p_platform not in ('apple', 'google') then return false; end if;
  if exists (select 1 from public.mobile_provider_events
    where platform = p_platform and provider_event_id = p_provider_event_id) then
    return true;
  end if;
  select * into v_product from public.store_products
  where platform = p_platform and product_id = p_product_id
    and kind = 'premium_subscription' and active;
  if v_product.product_id is null or p_user_id is null
    or p_subscription_id is null then return false; end if;
  select s.user_id into v_existing_user from public.subscriptions s
  where s.platform = p_platform and s.external_subscription_id = p_subscription_id;
  if v_existing_user is not null and v_existing_user <> p_user_id then return false; end if;
  v_status := case p_raw_status
    when 'trialing' then 'trialing'::public.subscription_status
    when 'active' then 'active'::public.subscription_status
    when 'grace' then 'active'::public.subscription_status
    when 'past_due' then 'past_due'::public.subscription_status
    when 'paused' then 'paused'::public.subscription_status
    when 'cancelled' then 'cancelled'::public.subscription_status
    else 'expired'::public.subscription_status end;
  if v_status in ('active', 'trialing') and p_period_end is null then return false; end if;
  v_entitlement_end := case when v_status in ('active', 'trialing')
    then p_period_end else least(coalesce(p_period_end, now()), now()) end;
  v_reference := p_platform::text || ':' || p_subscription_id;
  insert into public.subscriptions (
    user_id, platform, external_subscription_id, product_id, status,
    current_period_end, original_transaction_id
  ) values (
    p_user_id, p_platform, p_subscription_id, p_product_id, v_status,
    p_period_end, p_subscription_id
  ) on conflict (platform, external_subscription_id) do update set
    status = excluded.status, product_id = excluded.product_id,
    current_period_end = excluded.current_period_end;
  insert into public.entitlements (
    user_id, type, source, source_reference, starts_at, expires_at
  ) values (
    p_user_id, 'premium', 'subscription', v_reference,
    coalesce(p_period_start, now()), v_entitlement_end
  ) on conflict (source_reference) where source = 'subscription'
    do update set expires_at = excluded.expires_at;
  insert into public.mobile_provider_events (platform, provider_event_id, event_type)
  values (p_platform, p_provider_event_id, p_event_type);
  return true;
end;
$$;

create or replace function public.reverse_mobile_coin_purchase_server(
  p_platform public.purchase_platform,
  p_provider_event_id text,
  p_event_type text,
  p_provider_transaction_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_purchase public.mobile_purchase_events%rowtype;
  v_amount integer;
  v_balance integer;
  v_reference text := 'reversal:' || p_platform::text || ':' || p_provider_transaction_id;
begin
  if p_platform not in ('apple', 'google') then return false; end if;
  if exists (select 1 from public.mobile_provider_events
    where platform = p_platform and provider_event_id = p_provider_event_id) then
    return true;
  end if;
  select * into v_purchase from public.mobile_purchase_events
  where platform = p_platform and kind = 'coin_pack'
    and (provider_transaction_id = p_provider_transaction_id
      or original_transaction_id = p_provider_transaction_id)
  order by created_at desc limit 1 for update;
  if v_purchase.id is null then return false; end if;
  select coin_amount into v_amount from public.store_products
  where platform = p_platform and product_id = v_purchase.product_id;
  if v_amount is null then return false; end if;
  select balance into v_balance from public.wallets
  where user_id = v_purchase.user_id for update;
  if not exists (select 1 from public.coin_transactions
    where user_id = v_purchase.user_id and reason = 'refund'
      and reference_id = v_reference) then
    v_balance := v_balance - v_amount;
    update public.wallets set balance = v_balance where user_id = v_purchase.user_id;
    insert into public.coin_transactions (
      user_id, amount, reason, reference_id, balance_after
    ) values (
      v_purchase.user_id, -v_amount, 'refund', v_reference, v_balance
    );
  end if;
  insert into public.mobile_provider_events (platform, provider_event_id, event_type)
  values (p_platform, p_provider_event_id, p_event_type);
  return true;
end;
$$;

revoke all on public.mobile_provider_events from anon, authenticated;
revoke all on function public.record_mobile_provider_event_server(
  public.purchase_platform, text, text
) from public;
grant execute on function public.record_mobile_provider_event_server(
  public.purchase_platform, text, text
) to service_role;
revoke all on function public.reconcile_mobile_subscription_server(
  public.purchase_platform, text, text, uuid, text, text, text, timestamptz, timestamptz
) from public;
grant execute on function public.reconcile_mobile_subscription_server(
  public.purchase_platform, text, text, uuid, text, text, text, timestamptz, timestamptz
) to service_role;
revoke all on function public.reverse_mobile_coin_purchase_server(
  public.purchase_platform, text, text, text
) from public;
grant execute on function public.reverse_mobile_coin_purchase_server(
  public.purchase_platform, text, text, text
) to service_role;
