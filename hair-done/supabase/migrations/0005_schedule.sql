-- Hair Done: the two timers. Needs pg_cron and pg_net (0003, 0004).

-- Booking timers (auto-decline, lapsed payments, auto-done) every ten minutes.
select cron.schedule('hairdone-sweep', '*/10 * * * *', $$select public.sweep_bookings()$$);

-- The Stripe work that's due, every five minutes. The secret stays in the database.
-- If the project ref changes (a new project), change the URL here.
create or replace function private.call_settle() returns bigint
language sql security definer set search_path = private, extensions as $$
  select net.http_post(
    url := 'https://yohqeunmgrxyakviofua.supabase.co/functions/v1/settle',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-secret', (select value from private.settings where key = 'cron_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 55000)
$$;
revoke execute on function private.call_settle() from public;
select cron.schedule('hairdone-settle', '*/5 * * * *', $$select private.call_settle()$$);
