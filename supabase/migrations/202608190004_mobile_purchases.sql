-- Server-owned mobile product catalogue and replay-safe purchase fulfillment.

create type public.store_product_kind as enum ('coin_pack', 'premium_subscription');

create table public.store_products (
  platform public.purchase_platform not null check (platform in ('apple', 'google')),
  product_id text not null,
  kind public.store_product_kind not null,
  coin_amount integer check (
    (kind = 'coin_pack' and coin_amount > 0)
    or (kind = 'premium_subscription' and coin_amount is null)
  ),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (platform, product_id)
);

create table public.mobile_purchase_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform public.purchase_platform not null check (platform in ('apple', 'google')),
  provider_transaction_id text not null,
  original_transaction_id text,
  product_id text not null,
  kind public.store_product_kind not null,
  purchased_at timestamptz,
  expires_at timestamptz,
  environment text,
  raw_status text,
  created_at timestamptz not null default now(),
  unique (platform, provider_transaction_id)
);

create index mobile_purchase_events_user_idx
on public.mobile_purchase_events (user_id, created_at desc);

create unique index entitlements_subscription_reference_once_idx
on public.entitlements (source_reference)
where source = 'subscription';

alter table public.store_products enable row level security;
alter table public.mobile_purchase_events enable row level security;

create policy "clients read active store products" on public.store_products
for select to authenticated using (active);
create policy "users read own mobile purchases" on public.mobile_purchase_events
for select to authenticated using (user_id = auth.uid() or public.is_admin());

insert into public.store_products (platform, product_id, kind, coin_amount) values
  ('apple', 'comboreel.coins.50', 'coin_pack', 50),
  ('apple', 'comboreel.coins.120', 'coin_pack', 120),
  ('apple', 'comboreel.coins.300', 'coin_pack', 300),
  ('apple', 'comboreel.premium.monthly', 'premium_subscription', null),
  ('apple', 'comboreel.premium.annual', 'premium_subscription', null),
  ('google', 'comboreel.coins.50', 'coin_pack', 50),
  ('google', 'comboreel.coins.120', 'coin_pack', 120),
  ('google', 'comboreel.coins.300', 'coin_pack', 300),
  ('google', 'comboreel.premium.monthly', 'premium_subscription', null),
  ('google', 'comboreel.premium.annual', 'premium_subscription', null);

create or replace function public.fulfill_mobile_purchase_server(
  p_user_id uuid,
  p_platform public.purchase_platform,
  p_provider_transaction_id text,
  p_original_transaction_id text,
  p_product_id text,
  p_purchased_at timestamptz,
  p_expires_at timestamptz,
  p_environment text,
  p_raw_status text
)
returns table (accepted boolean, balance integer, premium_until timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product public.store_products%rowtype;
  v_existing public.mobile_purchase_events%rowtype;
  v_reference text;
  v_subscription_owner uuid;
  v_current_period_end timestamptz;
begin
  if p_platform not in ('apple', 'google') then
    raise exception 'unsupported_purchase_platform' using errcode = 'P0001';
  end if;
  select * into v_product from public.store_products
  where platform = p_platform and product_id = p_product_id and active;
  if v_product.product_id is null then
    raise exception 'unknown_store_product' using errcode = 'P0001';
  end if;

  select * into v_existing from public.mobile_purchase_events
  where platform = p_platform and provider_transaction_id = p_provider_transaction_id;
  if v_existing.id is not null then
    if v_existing.user_id <> p_user_id or v_existing.product_id <> p_product_id then
      return query select false, null::integer, null::timestamptz;
      return;
    end if;
    if v_product.kind = 'coin_pack' then
      return query select true,
        (select w.balance from public.wallets w where w.user_id = p_user_id),
        null::timestamptz;
      return;
    end if;
    p_expires_at := greatest(p_expires_at, v_existing.expires_at);
    update public.mobile_purchase_events set
      purchased_at = coalesce(p_purchased_at, purchased_at),
      expires_at = greatest(p_expires_at, expires_at),
      raw_status = p_raw_status
    where id = v_existing.id;
  else
    insert into public.mobile_purchase_events (
      user_id, platform, provider_transaction_id, original_transaction_id,
      product_id, kind, purchased_at, expires_at, environment, raw_status
    ) values (
      p_user_id, p_platform, p_provider_transaction_id, p_original_transaction_id,
      p_product_id, v_product.kind, p_purchased_at, p_expires_at,
      p_environment, p_raw_status
    );
  end if;

  if v_product.kind = 'coin_pack' then
    perform public.credit_coins_server(
      p_user_id, v_product.coin_amount, 'purchase',
      p_platform::text || ':' || p_provider_transaction_id
    );
  else
    if p_expires_at is null then
      raise exception 'subscription_expiry_required' using errcode = 'P0001';
    end if;
    v_reference := p_platform::text || ':' || coalesce(
      nullif(p_original_transaction_id, ''), p_provider_transaction_id
    );
    select s.user_id, s.current_period_end
    into v_subscription_owner, v_current_period_end
    from public.subscriptions s
    where s.platform = p_platform
      and s.external_subscription_id = coalesce(
        nullif(p_original_transaction_id, ''), p_provider_transaction_id
      );
    if v_subscription_owner is not null and v_subscription_owner <> p_user_id then
      return query select false, null::integer, null::timestamptz;
      return;
    end if;
    p_expires_at := greatest(p_expires_at, v_current_period_end);
    insert into public.subscriptions (
      user_id, platform, external_subscription_id, product_id, status,
      current_period_end, original_transaction_id
    ) values (
      p_user_id, p_platform, coalesce(nullif(p_original_transaction_id, ''), p_provider_transaction_id),
      p_product_id, case when p_expires_at > now()
        then 'active'::public.subscription_status
        else 'expired'::public.subscription_status end,
      p_expires_at, p_original_transaction_id
    ) on conflict (platform, external_subscription_id) do update set
      user_id = excluded.user_id, product_id = excluded.product_id,
      status = excluded.status, current_period_end = excluded.current_period_end,
      original_transaction_id = excluded.original_transaction_id;

    insert into public.entitlements (
      user_id, type, source, source_reference, starts_at, expires_at
    ) values (
      p_user_id, 'premium', 'subscription', v_reference,
      coalesce(p_purchased_at, now()), p_expires_at
    ) on conflict (source_reference) where source = 'subscription'
      do update set user_id = excluded.user_id, starts_at = excluded.starts_at,
                    expires_at = excluded.expires_at;
  end if;

  return query select true,
    (select w.balance from public.wallets w where w.user_id = p_user_id),
    case when v_product.kind = 'premium_subscription' then p_expires_at else null end;
end;
$$;

revoke all on public.store_products from anon;
grant select on public.store_products to authenticated;
revoke all on public.mobile_purchase_events from anon, authenticated;
grant select on public.mobile_purchase_events to authenticated;
revoke all on function public.fulfill_mobile_purchase_server(
  uuid, public.purchase_platform, text, text, text, timestamptz, timestamptz, text, text
) from public;
grant execute on function public.fulfill_mobile_purchase_server(
  uuid, public.purchase_platform, text, text, text, timestamptz, timestamptz, text, text
) to service_role;
