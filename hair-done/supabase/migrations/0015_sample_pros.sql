-- Sample pros for TestFlight testers to book.
--
--   - pros.is_sample marks them. The seed-samples function creates them (accounts, profiles, services,
--     hours, work photos) and removes them all again: POST {"action":"remove"}. Remove them before
--     launch.
--   - Payments (functions/_shared/stripe.ts payeeFor): a sample pro has no Stripe account, so in test
--     mode a booking with her is charged to the platform alone, no transfer and no fee. In live mode
--     she can't be charged at all.
--   - An autopilot stands in for them every minute: it accepts a request once the client's card is
--     held or saved (as a pro would, through move_booking, so the client gets the usual notice), and
--     answers a client's latest message with a line saying it's a sample.

alter table pros add column if not exists is_sample boolean not null default false;

create or replace function private.sample_autopilot() returns void
language plpgsql security definer set search_path = public, extensions as $$
declare b record; t record;
begin
  -- 1. Requests: accept once the card's in, 20 seconds on so it reads like a person.
  for b in select bk.id, bk.pro_id from bookings bk join pros p on p.id = bk.pro_id
           where p.is_sample and bk.status = 'requested' and bk.hold_state <> 'none'
             and bk.created_at < now() - interval '20 seconds'
  loop
    begin
      perform move_booking(b.id, 'confirmed');
      insert into messages (thread_id, sender_id, text)
        select th.id, b.pro_id, 'Lovely, you''re booked in. See you then. (I''m a sample pro for testing, so this reply is automatic.)'
        from threads th where th.booking_id = b.id;
    exception when others then
      raise warning 'sample autopilot: booking % not accepted: %', b.id, sqlerrm;
    end;
  end loop;

  -- 2. Messages: answer when the latest word in a sample pro's thread is the client's.
  for t in select th.id, th.pro_id from threads th join pros p on p.id = th.pro_id
           where p.is_sample
             and (select m.sender_id from messages m where m.thread_id = th.id order by m.sent_at desc limit 1) = th.client_id
             and (select max(m.sent_at) from messages m where m.thread_id = th.id) < now() - interval '20 seconds'
  loop
    insert into messages (thread_id, sender_id, text)
      values (t.id, t.pro_id, 'Thanks for your message! I''m a sample pro for testing, so this reply is automatic.');
  end loop;
end $$;
revoke all on function private.sample_autopilot() from public;

select cron.schedule('hairdone-sample-autopilot', '* * * * *', $$ select private.sample_autopilot() $$);
