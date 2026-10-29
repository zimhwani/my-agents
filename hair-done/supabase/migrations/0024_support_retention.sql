-- Hair Done: support emails and replies are kept two years, then deleted, as the privacy policy says
-- (29 Oct 2026, "How long we keep it"). In-app reports stay in public.reports with their booking.
select cron.schedule('hairdone-support-retention', '41 16 * * *', $$
  delete from private.support_items where received_at < now() - interval '2 years'
$$);
