-- Explicit API privileges for projects where PostgREST no longer auto-exposes
-- newly created public tables. RLS remains the row-level authorization layer.

grant select on public.genres, public.series, public.series_genres,
  public.seasons, public.episodes, public.episode_subtitles
to anon, authenticated;
grant execute on function public.is_admin() to anon;

grant insert, update, delete on public.genres, public.series,
  public.series_genres, public.seasons, public.episodes,
  public.episode_subtitles
to authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, avatar_url, preferred_language)
on public.profiles to authenticated;

grant select, insert, delete on public.favourites to authenticated;
grant select, insert, update, delete on public.watch_progress to authenticated;

grant select on public.subscriptions, public.entitlements, public.wallets,
  public.coin_transactions, public.admin_audit_log
to authenticated;

-- Server-side Edge Functions use this role for trusted provider callbacks,
-- lifecycle reconciliation, uploads, and account deletion.
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
