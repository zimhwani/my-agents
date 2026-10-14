-- Hair Done: a pro's hours and days off are replaced in one transaction, so a failed save can't
-- leave her with no hours (ux-audit B6). p_hours is [{"weekday":0-6 (0 = Sunday),"start":540,"end":1020}, ...].
create or replace function save_pro_schedule(p_hours jsonb, p_days_off date[])
returns void language plpgsql security definer set search_path = public, extensions as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not exists (select 1 from pros where id = me) then raise exception 'not_found'; end if;
  if exists (select 1 from jsonb_array_elements(coalesce(p_hours, '[]'::jsonb)) h
             where (h->>'weekday')::int not between 0 and 6
                or (h->>'start')::int < 0 or (h->>'end')::int > 1440
                or (h->>'end')::int <= (h->>'start')::int) then
    raise exception 'bad_hours';
  end if;

  delete from availability where pro_id = me;
  insert into availability (pro_id, weekday, start_minutes, end_minutes)
  select me, (h->>'weekday')::smallint, (h->>'start')::int, (h->>'end')::int
  from jsonb_array_elements(coalesce(p_hours, '[]'::jsonb)) h;

  delete from days_off where pro_id = me;
  insert into days_off (pro_id, day)
  select distinct me, d from unnest(coalesce(p_days_off, '{}'::date[])) d;
end $$;
revoke execute on function save_pro_schedule(jsonb, date[]) from public, anon;
grant execute on function save_pro_schedule(jsonb, date[]) to authenticated;
