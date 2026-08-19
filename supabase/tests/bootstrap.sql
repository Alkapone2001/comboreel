-- Minimal Supabase primitives for migration/contract tests on plain PostgreSQL.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;
create schema auth;
create table auth.users (
  id uuid primary key,
  email text,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create or replace function auth.uid()
returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create or replace function auth.role()
returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;
