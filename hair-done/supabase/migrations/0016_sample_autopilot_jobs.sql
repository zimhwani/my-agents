-- The sample-pro autopilot (0015) now also does the job, so testers see a booking through to paying:
-- two minutes after she accepts, On my way; then Here, Started and Done, about two minutes apart.
-- Those steps are hers alone in move_booking, so the autopilot acts as her for each one (auth.uid()
-- reads request.jwt.claims). It ignores the booked time: a sample job runs straight away.

create or replace function private.sample_autopilot() returns void
language plpgsql security definer set search_path = public, extensions as $$
declare b record; t record; j record; next_status booking_status;
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

  -- 2. The job: one step every two minutes from the last change, acting as her.
  for j in select bk.id, bk.pro_id, bk.status,
                  coalesce((select max(e.at) from booking_events e where e.booking_id = bk.id), bk.updated_at) as since
           from bookings bk join pros p on p.id = bk.pro_id
           where p.is_sample and bk.status in ('confirmed', 'onHerWay', 'arrived', 'inProgress')
  loop
    continue when j.since > now() - interval '2 minutes';
    next_status := case j.status when 'confirmed' then 'onHerWay'::booking_status
                                 when 'onHerWay' then 'arrived'::booking_status
                                 when 'arrived' then 'inProgress'::booking_status
                                 else 'done'::booking_status end;
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', j.pro_id, 'role', 'authenticated')::text, true);
      perform move_booking(j.id, next_status);
      if next_status = 'onHerWay' then
        insert into messages (thread_id, sender_id, text)
          select th.id, j.pro_id, 'On my way! (Sample pro: this job runs on its own, a step every couple of minutes.)'
          from threads th where th.booking_id = j.id;
      end if;
    exception when others then
      raise warning 'sample autopilot: booking % not moved to %: %', j.id, next_status, sqlerrm;
    end;
    perform set_config('request.jwt.claims', '', true);
  end loop;

  -- 3. Messages: answer when the latest word in a sample pro's thread is the client's.
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
