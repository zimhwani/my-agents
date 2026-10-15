-- Hair Done: photos are deleted when they should be (privacy policy, "How long we keep it").
--   - Anything a deleted account uploaded (its folder no longer matches a profile), after a 1-day grace.
--   - A verified pro's ID photo and selfie, 7 days after the ID check.
-- The cleanup function lists them here and removes them through the Storage API, because
-- Storage files can't be deleted with SQL.
create or replace function photo_cleanup_candidates(limit_n int default 500)
returns table(bucket_id text, name text)
language sql stable security definer set search_path = public, storage, extensions as $$
  (select o.bucket_id, o.name from storage.objects o
   where o.bucket_id in ('work', 'avatars', 'inspo', 'id-docs')
     and o.created_at < now() - interval '1 day'
     and not exists (select 1 from public.profiles p where p.id::text = (storage.foldername(o.name))[1]))
  union all
  (select o.bucket_id, o.name from storage.objects o
   join public.pros p on p.id::text = (storage.foldername(o.name))[1]
   where o.bucket_id = 'id-docs' and p.is_verified and p.id_checked_at < now() - interval '7 days')
  limit limit_n
$$;
revoke execute on function photo_cleanup_candidates(int) from public, anon, authenticated;
grant execute on function photo_cleanup_candidates(int) to service_role;

-- Daily at 3:17 am Melbourne-ish (16:17 UTC).
select cron.schedule('hairdone-photo-cleanup', '17 16 * * *', $$
  select net.http_post(
    url := 'https://yohqeunmgrxyakviofua.supabase.co/functions/v1/cleanup',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-secret', (select value from private.settings where key = 'cron_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000)
$$);
