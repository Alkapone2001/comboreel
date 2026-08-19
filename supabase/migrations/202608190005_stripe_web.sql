-- Stripe customer ownership, webhook idempotency, and web fulfillment.

alter table public.store_products drop constraint store_products_platform_check;
alter table public.store_products add constraint store_products_platform_check
check (platform in ('apple', 'google', 'stripe'));

insert into public.store_products (platform, product_id, kind, coin_amount) values
  ('stripe', 'comboreel.coins.50', 'coin_pack', 50),
  ('stripe', 'comboreel.coins.120', 'coin_pack', 120),
  ('stripe', 'comboreel.coins.300', 'coin_pack', 300),
  ('stripe', 'comboreel.premium.monthly', 'premium_subscription', null),
  ('stripe', 'comboreel.premium.annual', 'premium_subscription', null);

create table public.stripe_customers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  customer_id text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stripe_webhook_events (
  event_id text primary key,
  event_type text not null,
  processed_at timestamptz not null default now()
);

alter table public.stripe_customers enable row level security;
alter table public.stripe_webhook_events enable row level security;
create policy "users read own stripe customer" on public.stripe_customers
for select to authenticated using (user_id = auth.uid());

create trigger stripe_customers_set_updated_at before update on public.stripe_customers
for each row execute function public.set_updated_at();

create or replace function public.register_stripe_customer_server(
  p_user_id uuid, p_customer_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_customer text;
begin
  select user_id into v_owner from public.stripe_customers
  where customer_id = p_customer_id;
  select customer_id into v_customer from public.stripe_customers
  where user_id = p_user_id;
  if (v_owner is not null and v_owner <> p_user_id)
    or (v_customer is not null and v_customer <> p_customer_id) then
    return false;
  end if;
  insert into public.stripe_customers (user_id, customer_id)
  values (p_user_id, p_customer_id)
  on conflict (user_id) do update set customer_id = excluded.customer_id;
  return true;
end;
$$;

create or replace function public.fulfill_stripe_checkout_server(
  p_event_id text,
  p_user_id uuid,
  p_session_id text,
  p_customer_id text,
  p_subscription_id text,
  p_product_id text,
  p_purchased_at timestamptz,
  p_expires_at timestamptz,
  p_raw_status text
)
returns table (accepted boolean, balance integer, premium_until timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product public.store_products%rowtype;
  v_reference text;
begin
  if exists (select 1 from public.stripe_webhook_events where event_id = p_event_id) then
    return query select true,
      (select w.balance from public.wallets w where w.user_id = p_user_id),
      (select max(e.expires_at) from public.entitlements e
       where e.user_id = p_user_id and e.type = 'premium');
    return;
  end if;
  if not public.register_stripe_customer_server(p_user_id, p_customer_id) then
    return query select false, null::integer, null::timestamptz;
    return;
  end if;
  select * into v_product from public.store_products
  where platform = 'stripe' and product_id = p_product_id and active;
  if v_product.product_id is null then
    raise exception 'unknown_store_product' using errcode = 'P0001';
  end if;

  if v_product.kind = 'coin_pack' then
    perform public.credit_coins_server(
      p_user_id, v_product.coin_amount, 'purchase', 'stripe:' || p_session_id
    );
  else
    if p_subscription_id is null or p_expires_at is null then
      raise exception 'stripe_subscription_data_required' using errcode = 'P0001';
    end if;
    v_reference := 'stripe:' || p_subscription_id;
    insert into public.subscriptions (
      user_id, platform, external_customer_id, external_subscription_id,
      product_id, status, current_period_end, original_transaction_id
    ) values (
      p_user_id, 'stripe', p_customer_id, p_subscription_id, p_product_id,
      case when p_expires_at > now() then 'active'::public.subscription_status
           else 'expired'::public.subscription_status end,
      p_expires_at, p_subscription_id
    ) on conflict (platform, external_subscription_id) do update set
      user_id = excluded.user_id, external_customer_id = excluded.external_customer_id,
      product_id = excluded.product_id, status = excluded.status,
      current_period_end = greatest(subscriptions.current_period_end, excluded.current_period_end);
    insert into public.entitlements (
      user_id, type, source, source_reference, starts_at, expires_at
    ) values (
      p_user_id, 'premium', 'subscription', v_reference,
      coalesce(p_purchased_at, now()), p_expires_at
    ) on conflict (source_reference) where source = 'subscription'
      do update set expires_at = greatest(entitlements.expires_at, excluded.expires_at);
  end if;
  insert into public.stripe_webhook_events (event_id, event_type)
  values (p_event_id, 'checkout.session.completed');
  return query select true,
    (select w.balance from public.wallets w where w.user_id = p_user_id),
    case when v_product.kind = 'premium_subscription' then p_expires_at else null end;
end;
$$;

create or replace function public.reconcile_stripe_subscription_server(
  p_event_id text,
  p_event_type text,
  p_customer_id text,
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
  v_user_id uuid;
  v_status public.subscription_status;
  v_reference text := 'stripe:' || p_subscription_id;
begin
  if exists (select 1 from public.stripe_webhook_events where event_id = p_event_id) then
    return true;
  end if;
  select user_id into v_user_id from public.stripe_customers
  where customer_id = p_customer_id;
  if v_user_id is null then return false; end if;
  if not exists (select 1 from public.store_products
    where platform = 'stripe' and product_id = p_product_id
      and kind = 'premium_subscription' and active) then
    return false;
  end if;
  v_status := case p_raw_status
    when 'trialing' then 'trialing'::public.subscription_status
    when 'active' then 'active'::public.subscription_status
    when 'past_due' then 'past_due'::public.subscription_status
    when 'paused' then 'paused'::public.subscription_status
    when 'canceled' then 'cancelled'::public.subscription_status
    when 'unpaid' then 'expired'::public.subscription_status
    else 'expired'::public.subscription_status end;
  insert into public.subscriptions (
    user_id, platform, external_customer_id, external_subscription_id,
    product_id, status, current_period_end, original_transaction_id
  ) values (
    v_user_id, 'stripe', p_customer_id, p_subscription_id,
    p_product_id, v_status, p_period_end, p_subscription_id
  ) on conflict (platform, external_subscription_id) do update set
    status = excluded.status, product_id = excluded.product_id,
    current_period_end = excluded.current_period_end;
  insert into public.entitlements (
    user_id, type, source, source_reference, starts_at, expires_at
  ) values (
    v_user_id, 'premium', 'subscription', v_reference,
    coalesce(p_period_start, now()),
    case when v_status in ('active', 'trialing') then p_period_end else now() end
  ) on conflict (source_reference) where source = 'subscription'
    do update set expires_at = excluded.expires_at;
  insert into public.stripe_webhook_events (event_id, event_type)
  values (p_event_id, p_event_type);
  return true;
end;
$$;

revoke all on public.stripe_customers from anon, authenticated;
grant select on public.stripe_customers to authenticated;
revoke all on public.stripe_webhook_events from anon, authenticated;
revoke all on function public.register_stripe_customer_server(uuid, text) from public;
grant execute on function public.register_stripe_customer_server(uuid, text) to service_role;
revoke all on function public.fulfill_stripe_checkout_server(
  text, uuid, text, text, text, text, timestamptz, timestamptz, text
) from public;
grant execute on function public.fulfill_stripe_checkout_server(
  text, uuid, text, text, text, text, timestamptz, timestamptz, text
) to service_role;
revoke all on function public.reconcile_stripe_subscription_server(
  text, text, text, text, text, text, timestamptz, timestamptz
) from public;
grant execute on function public.reconcile_stripe_subscription_server(
  text, text, text, text, text, text, timestamptz, timestamptz
) to service_role;
