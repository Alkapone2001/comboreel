begin;

insert into auth.users (id, email, raw_user_meta_data)
values (
  '11111111-1111-1111-1111-111111111111',
  'viewer@example.com',
  '{"display_name":"Test Viewer"}'::jsonb
);

insert into public.series (
  id, slug, title, synopsis, poster_url, hero_url, release_year, age_rating
) values (
  '22222222-2222-2222-2222-222222222222',
  'test-series',
  'Test Series',
  'Contract test content',
  'https://example.com/poster.jpg',
  'https://example.com/hero.jpg',
  2026,
  '16+'
);

insert into public.episodes (
  id, series_id, episode_number, title, duration_seconds,
  stream_uid, status, is_free, coin_price, published_at
) values (
  '33333333-3333-3333-3333-333333333333',
  '22222222-2222-2222-2222-222222222222',
  6,
  'Locked Episode',
  90,
  'test-stream-uid',
  'published',
  false,
  5,
  now()
);

update public.series set status = 'published'
where id = '22222222-2222-2222-2222-222222222222';

insert into public.episodes (
  id, series_id, episode_number, title, duration_seconds,
  stream_uid, status, is_free, coin_price, published_at
) values (
  '44444444-4444-4444-4444-444444444444',
  '22222222-2222-2222-2222-222222222222',
  7, 'Rewarded Episode', 90, 'test-stream-uid-2',
  'published', false, 5, now()
);

update public.wallets
set balance = 10
where user_id = '11111111-1111-1111-1111-111111111111';

select set_config(
  'request.jwt.claim.sub',
  '11111111-1111-1111-1111-111111111111',
  true
);

select * from public.unlock_episode_with_coins(
  '33333333-3333-3333-3333-333333333333',
  'unlock-contract-test-0001'
);
select * from public.unlock_episode_with_coins(
  '33333333-3333-3333-3333-333333333333',
  'unlock-contract-test-0001'
);

do $$
declare
  v_balance integer;
  v_ledger_count integer;
  v_entitlement_count integer;
begin
  select balance into v_balance
  from public.wallets
  where user_id = '11111111-1111-1111-1111-111111111111';
  if v_balance <> 5 then
    raise exception 'expected balance 5, got %', v_balance;
  end if;

  select count(*) into v_ledger_count
  from public.coin_transactions
  where user_id = '11111111-1111-1111-1111-111111111111'
    and reason = 'episode_unlock';
  if v_ledger_count <> 1 then
    raise exception 'expected one ledger entry, got %', v_ledger_count;
  end if;

  select count(*) into v_entitlement_count
  from public.entitlements
  where user_id = '11111111-1111-1111-1111-111111111111'
    and episode_id = '33333333-3333-3333-3333-333333333333';
  if v_entitlement_count <> 1 then
    raise exception 'expected one entitlement, got %', v_entitlement_count;
  end if;
end;
$$;

do $$
declare
  v_claim_id uuid;
  v_first boolean;
  v_replay boolean;
  v_entitlement_count integer;
begin
  select claim_id into v_claim_id
  from public.create_rewarded_episode_claim(
    '44444444-4444-4444-4444-444444444444'
  );
  select public.complete_rewarded_ad_claim_server(
    v_claim_id, '11111111-1111-1111-1111-111111111111',
    'admob-contract-transaction-0001'
  ) into v_first;
  select public.complete_rewarded_ad_claim_server(
    v_claim_id, '11111111-1111-1111-1111-111111111111',
    'admob-contract-transaction-0001'
  ) into v_replay;
  if not v_first or not v_replay then
    raise exception 'expected original and idempotent replay to succeed';
  end if;
  select count(*) into v_entitlement_count from public.entitlements
  where user_id = '11111111-1111-1111-1111-111111111111'
    and episode_id = '44444444-4444-4444-4444-444444444444'
    and source = 'ad_reward';
  if v_entitlement_count <> 1 then
    raise exception 'expected one rewarded entitlement, got %', v_entitlement_count;
  end if;
end;
$$;

select * from public.fulfill_mobile_purchase_server(
  '11111111-1111-1111-1111-111111111111', 'google',
  'GPA.contract.coin.0001', 'google-token-0001',
  'comboreel.coins.50', now(), null, 'test', 'PURCHASED'
);
select * from public.fulfill_mobile_purchase_server(
  '11111111-1111-1111-1111-111111111111', 'google',
  'GPA.contract.coin.0001', 'google-token-0001',
  'comboreel.coins.50', now(), null, 'test', 'PURCHASED'
);
select * from public.fulfill_mobile_purchase_server(
  '11111111-1111-1111-1111-111111111111', 'apple',
  'apple-contract-sub-0001', 'apple-original-sub-0001',
  'comboreel.premium.monthly', now(), now() + interval '30 days',
  'sandbox', 'ACTIVE'
);
select * from public.fulfill_mobile_purchase_server(
  '11111111-1111-1111-1111-111111111111', 'apple',
  'apple-contract-sub-0001', 'apple-original-sub-0001',
  'comboreel.premium.monthly', now(), now() + interval '30 days',
  'sandbox', 'ACTIVE'
);

do $$
declare
  v_balance integer;
  v_purchase_ledger_count integer;
  v_purchase_event_count integer;
  v_premium_count integer;
begin
  select balance into v_balance from public.wallets
  where user_id = '11111111-1111-1111-1111-111111111111';
  if v_balance <> 55 then
    raise exception 'expected post-purchase balance 55, got %', v_balance;
  end if;
  select count(*) into v_purchase_ledger_count from public.coin_transactions
  where user_id = '11111111-1111-1111-1111-111111111111'
    and reason = 'purchase' and reference_id = 'google:GPA.contract.coin.0001';
  if v_purchase_ledger_count <> 1 then
    raise exception 'expected one purchase ledger entry, got %', v_purchase_ledger_count;
  end if;
  select count(*) into v_purchase_event_count from public.mobile_purchase_events
  where user_id = '11111111-1111-1111-1111-111111111111';
  if v_purchase_event_count <> 2 then
    raise exception 'expected two unique mobile purchase events, got %', v_purchase_event_count;
  end if;
  select count(*) into v_premium_count from public.entitlements
  where user_id = '11111111-1111-1111-1111-111111111111'
    and type = 'premium' and source = 'subscription';
  if v_premium_count <> 1 then
    raise exception 'expected one premium entitlement, got %', v_premium_count;
  end if;
end;
$$;

select public.register_stripe_customer_server(
  '11111111-1111-1111-1111-111111111111', 'cus_contract_0001'
);
select * from public.fulfill_stripe_checkout_server(
  'evt_checkout_coin_0001', '11111111-1111-1111-1111-111111111111',
  'cs_contract_coin_0001', 'cus_contract_0001', null,
  'comboreel.coins.120', now(), null, 'paid'
);
select * from public.fulfill_stripe_checkout_server(
  'evt_checkout_coin_0001', '11111111-1111-1111-1111-111111111111',
  'cs_contract_coin_0001', 'cus_contract_0001', null,
  'comboreel.coins.120', now(), null, 'paid'
);
select * from public.fulfill_stripe_checkout_server(
  'evt_checkout_sub_0001', '11111111-1111-1111-1111-111111111111',
  'cs_contract_sub_0001', 'cus_contract_0001', 'sub_contract_0001',
  'comboreel.premium.monthly', now(), now() + interval '30 days', 'active'
);
select public.reconcile_stripe_subscription_server(
  'evt_sub_cancelled_0001', 'customer.subscription.deleted',
  'cus_contract_0001', 'sub_contract_0001',
  'comboreel.premium.monthly', 'canceled', now() - interval '30 days', now()
);
select public.reconcile_stripe_subscription_server(
  'evt_sub_cancelled_0001', 'customer.subscription.deleted',
  'cus_contract_0001', 'sub_contract_0001',
  'comboreel.premium.monthly', 'canceled', now() - interval '30 days', now()
);

do $$
declare
  v_balance integer;
  v_ledger_count integer;
  v_event_count integer;
  v_status public.subscription_status;
begin
  select balance into v_balance from public.wallets
  where user_id = '11111111-1111-1111-1111-111111111111';
  if v_balance <> 175 then
    raise exception 'expected post-Stripe balance 175, got %', v_balance;
  end if;
  select count(*) into v_ledger_count from public.coin_transactions
  where user_id = '11111111-1111-1111-1111-111111111111'
    and reason = 'purchase' and reference_id = 'stripe:cs_contract_coin_0001';
  if v_ledger_count <> 1 then
    raise exception 'expected one Stripe credit, got %', v_ledger_count;
  end if;
  select count(*) into v_event_count from public.stripe_webhook_events;
  if v_event_count <> 3 then
    raise exception 'expected three unique Stripe events, got %', v_event_count;
  end if;
  select status into v_status from public.subscriptions
  where platform = 'stripe' and external_subscription_id = 'sub_contract_0001';
  if v_status <> 'cancelled' then
    raise exception 'expected cancelled Stripe subscription, got %', v_status;
  end if;
end;
$$;

select public.reverse_mobile_coin_purchase_server(
  'google', 'rtdn-refund-0001', 'voided_purchase', 'google-token-0001'
);
select public.reverse_mobile_coin_purchase_server(
  'google', 'rtdn-refund-0001', 'voided_purchase', 'google-token-0001'
);
select public.reconcile_mobile_subscription_server(
  'apple', 'apple-notification-0001', 'EXPIRED',
  '11111111-1111-1111-1111-111111111111',
  'apple-original-sub-0001', 'comboreel.premium.monthly',
  'expired', now() - interval '30 days', now()
);
select public.reconcile_mobile_subscription_server(
  'apple', 'apple-notification-0001', 'EXPIRED',
  '11111111-1111-1111-1111-111111111111',
  'apple-original-sub-0001', 'comboreel.premium.monthly',
  'expired', now() - interval '30 days', now()
);

do $$
declare
  v_balance integer;
  v_refund_count integer;
  v_provider_event_count integer;
  v_apple_status public.subscription_status;
begin
  select balance into v_balance from public.wallets
  where user_id = '11111111-1111-1111-1111-111111111111';
  if v_balance <> 125 then
    raise exception 'expected chargeback balance 125, got %', v_balance;
  end if;
  select count(*) into v_refund_count from public.coin_transactions
  where user_id = '11111111-1111-1111-1111-111111111111'
    and reason = 'refund'
    and reference_id = 'reversal:google:google-token-0001';
  if v_refund_count <> 1 then
    raise exception 'expected one mobile refund ledger entry, got %', v_refund_count;
  end if;
  select count(*) into v_provider_event_count from public.mobile_provider_events;
  if v_provider_event_count <> 2 then
    raise exception 'expected two unique mobile provider events, got %', v_provider_event_count;
  end if;
  select status into v_apple_status from public.subscriptions
  where platform = 'apple'
    and external_subscription_id = 'apple-original-sub-0001';
  if v_apple_status <> 'expired' then
    raise exception 'expected expired Apple subscription, got %', v_apple_status;
  end if;
end;
$$;

rollback;
