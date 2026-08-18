-- ComboReel initial production schema.
-- Apply with `supabase db push` after linking a Supabase project.

create extension if not exists pgcrypto;

create type public.app_role as enum ('viewer', 'editor', 'admin');
create type public.content_status as enum ('draft', 'processing', 'published', 'archived');
create type public.entitlement_type as enum ('episode', 'series', 'premium');
create type public.entitlement_source as enum ('free', 'ad_reward', 'coins', 'subscription', 'admin');
create type public.subscription_status as enum ('trialing', 'active', 'past_due', 'paused', 'cancelled', 'expired');
create type public.purchase_platform as enum ('apple', 'google', 'stripe', 'admin');
create type public.coin_reason as enum ('purchase', 'rewarded_ad', 'daily_reward', 'episode_unlock', 'refund', 'admin_adjustment');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text check (char_length(display_name) between 1 and 60),
  avatar_url text,
  role public.app_role not null default 'viewer',
  preferred_language text not null default 'en',
  marketing_opt_in boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.genres (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name text not null unique,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.series (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  title text not null check (char_length(title) between 1 and 140),
  synopsis text not null default '',
  poster_url text,
  hero_url text,
  trailer_stream_uid text,
  original_language text not null default 'en',
  release_year integer check (release_year between 1900 and 2200),
  age_rating text,
  status public.content_status not null default 'draft',
  is_featured boolean not null default false,
  published_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint published_series_has_date check (status <> 'published' or published_at is not null)
);

create table public.series_genres (
  series_id uuid not null references public.series(id) on delete cascade,
  genre_id uuid not null references public.genres(id) on delete cascade,
  primary key (series_id, genre_id)
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.series(id) on delete cascade,
  season_number integer not null check (season_number > 0),
  title text,
  created_at timestamptz not null default now(),
  unique (series_id, season_number)
);

create table public.episodes (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.series(id) on delete cascade,
  season_id uuid references public.seasons(id) on delete cascade,
  episode_number integer not null check (episode_number > 0),
  title text not null,
  synopsis text not null default '',
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  thumbnail_url text,
  stream_uid text,
  status public.content_status not null default 'draft',
  is_free boolean not null default false,
  coin_price integer not null default 5 check (coin_price >= 0),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (series_id, episode_number),
  constraint published_episode_ready check (
    status <> 'published' or (published_at is not null and stream_uid is not null and duration_seconds > 0)
  )
);

create table public.episode_subtitles (
  id uuid primary key default gen_random_uuid(),
  episode_id uuid not null references public.episodes(id) on delete cascade,
  language_code text not null,
  label text not null,
  vtt_url text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  unique (episode_id, language_code)
);

create table public.favourites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  series_id uuid not null references public.series(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, series_id)
);

create table public.watch_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  episode_id uuid not null references public.episodes(id) on delete cascade,
  position_seconds integer not null default 0 check (position_seconds >= 0),
  completed boolean not null default false,
  last_watched_at timestamptz not null default now(),
  primary key (user_id, episode_id)
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform public.purchase_platform not null,
  external_customer_id text,
  external_subscription_id text not null,
  product_id text not null,
  status public.subscription_status not null,
  current_period_end timestamptz,
  original_transaction_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (platform, external_subscription_id)
);

create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type public.entitlement_type not null,
  episode_id uuid references public.episodes(id) on delete cascade,
  series_id uuid references public.series(id) on delete cascade,
  source public.entitlement_source not null,
  source_reference text,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  constraint entitlement_target_matches_type check (
    (type = 'episode' and episode_id is not null and series_id is null) or
    (type = 'series' and series_id is not null and episode_id is null) or
    (type = 'premium' and series_id is null and episode_id is null)
  )
);

create table public.wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table public.coin_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount integer not null check (amount <> 0),
  reason public.coin_reason not null,
  reference_id text,
  balance_after integer not null check (balance_after >= 0),
  created_at timestamptz not null default now(),
  unique (user_id, reason, reference_id)
);

create index series_published_idx on public.series (published_at desc) where status = 'published';
create index series_featured_idx on public.series (is_featured, published_at desc) where status = 'published';
create index episodes_series_order_idx on public.episodes (series_id, episode_number) where status = 'published';
create index watch_progress_recent_idx on public.watch_progress (user_id, last_watched_at desc);
create index favourites_recent_idx on public.favourites (user_id, created_at desc);
create index entitlements_user_active_idx on public.entitlements (user_id, expires_at);
create index subscriptions_user_idx on public.subscriptions (user_id, status);
create index coin_transactions_user_idx on public.coin_transactions (user_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger series_set_updated_at before update on public.series
for each row execute function public.set_updated_at();
create trigger episodes_set_updated_at before update on public.episodes
for each row execute function public.set_updated_at();
create trigger subscriptions_set_updated_at before update on public.subscriptions
for each row execute function public.set_updated_at();
create trigger wallets_set_updated_at before update on public.wallets
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(new.email, '@', 1)));
  insert into public.wallets (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('editor', 'admin')
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.genres enable row level security;
alter table public.series enable row level security;
alter table public.series_genres enable row level security;
alter table public.seasons enable row level security;
alter table public.episodes enable row level security;
alter table public.episode_subtitles enable row level security;
alter table public.favourites enable row level security;
alter table public.watch_progress enable row level security;
alter table public.subscriptions enable row level security;
alter table public.entitlements enable row level security;
alter table public.wallets enable row level security;
alter table public.coin_transactions enable row level security;

create policy "profiles read own" on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "profiles update safe own fields" on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid() and role = (select role from public.profiles where id = auth.uid()));
create policy "admins manage profiles" on public.profiles for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "genres publicly readable" on public.genres for select using (true);
create policy "published series publicly readable" on public.series for select using (status = 'published' or public.is_admin());
create policy "published series genres publicly readable" on public.series_genres for select
using (exists (select 1 from public.series s where s.id = series_id and (s.status = 'published' or public.is_admin())));
create policy "published seasons publicly readable" on public.seasons for select
using (exists (select 1 from public.series s where s.id = series_id and (s.status = 'published' or public.is_admin())));
create policy "published episodes publicly readable" on public.episodes for select using (status = 'published' or public.is_admin());
create policy "published subtitles publicly readable" on public.episode_subtitles for select
using (exists (select 1 from public.episodes e where e.id = episode_id and (e.status = 'published' or public.is_admin())));

create policy "admins manage genres" on public.genres for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admins manage series" on public.series for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admins manage series genres" on public.series_genres for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admins manage seasons" on public.seasons for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admins manage episodes" on public.episodes for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admins manage subtitles" on public.episode_subtitles for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "users manage own favourites" on public.favourites for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "users manage own progress" on public.watch_progress for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "users read own subscriptions" on public.subscriptions for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "admins manage subscriptions" on public.subscriptions for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "users read own entitlements" on public.entitlements for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "admins manage entitlements" on public.entitlements for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "users read own wallet" on public.wallets for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "admins manage wallets" on public.wallets for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "users read own coin history" on public.coin_transactions for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "admins manage coin history" on public.coin_transactions for all to authenticated using (public.is_admin()) with check (public.is_admin());

insert into public.genres (slug, name, sort_order) values
  ('romance', 'Romance', 10),
  ('thriller', 'Thriller', 20),
  ('crime', 'Crime', 30),
  ('family-drama', 'Family Drama', 40),
  ('billionaire-drama', 'Billionaire Drama', 50)
on conflict (slug) do nothing;
