-- Sign-in for Apple's app reviewer (functions/review-sign-in). Each try at the fixed review code is
-- written here, so it can't be guessed: past 10 tries in an hour, it stops answering for that hour.
create table if not exists private.review_tries (
  at timestamptz not null default now(),
  ok boolean not null
);
create index if not exists review_tries_at_idx on private.review_tries (at);

-- One call does both: counts the last hour's misses, and if there's room, records this try.
create or replace function review_try(p_ok boolean) returns boolean
language plpgsql security definer set search_path = private, public as $$
declare misses int;
begin
  delete from private.review_tries where at < now() - interval '1 day';
  select count(*) into misses from private.review_tries where not ok and at > now() - interval '1 hour';
  if misses >= 10 then return false; end if;
  insert into private.review_tries (ok) values (p_ok);
  return true;
end $$;
revoke execute on function review_try(boolean) from public, anon, authenticated;
