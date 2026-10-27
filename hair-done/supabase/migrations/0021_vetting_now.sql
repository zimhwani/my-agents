-- Hair Done: vetting runs the moment a pro sends their ID, not on the next 15-minute tick.
-- submit_id_check() sets pros.id_submitted_at; this trigger then asks the vetting function to check
-- everyone waiting. pg_net sends the request only once the update commits, so the function sees it.
-- The 15-minute timer (0020) stays as the backstop: if this call fails, the next tick picks the pro up,
-- and a pro already reviewed for that submission is never checked or emailed twice.

create or replace function private.vetting_on_submit() returns trigger
language plpgsql security definer set search_path = private, public as $$
begin
  perform private.call_vetting();
  return null;
end $$;
revoke execute on function private.vetting_on_submit() from public;

drop trigger if exists pros_vetting_on_submit on public.pros;
create trigger pros_vetting_on_submit
  after update of id_submitted_at on public.pros
  for each row
  when (new.id_submitted_at is not null and new.id_submitted_at is distinct from old.id_submitted_at
        and not new.is_sample and not new.is_verified)
  execute function private.vetting_on_submit();
