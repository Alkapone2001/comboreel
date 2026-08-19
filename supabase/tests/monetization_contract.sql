begin;

insert into auth.users (id, email, raw_user_meta_data)
values (
  '11111111-1111-1111-1111-111111111111',
  'viewer@example.com',
  '{"display_name":"Test Viewer"}'::jsonb
);

insert into public.series (
  id, slug, title, synopsis, status, published_at
) values (
  '22222222-2222-2222-2222-222222222222',
  'test-series',
  'Test Series',
  'Contract test content',
  'published',
  now()
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

rollback;
