-- Pros (and clients) are "they", not "she", in everything the database writes for people to read:
-- the chat line when a booking moves, and why a time can't be booked. Swaps the words in the live
-- definitions, so nothing else in them changes.
do $$
declare def text;
begin
  def := pg_get_functiondef('public.bookings_on_status()'::regprocedure);
  def := replace(def, $q$coalesce(pro_name, 'She')$q$, $q$coalesce(pro_name, 'Your pro')$q$);
  def := replace(def, $q$'''s on her way.'$q$, $q$'''s on their way.'$q$);
  execute def;

  def := pg_get_functiondef('public.pro_slots(uuid, date, integer, text)'::regprocedure);
  def := replace(def, $q$'Too soon, she needs $q$, $q$'Too soon, they need $q$);
  def := replace(def, $q$'She''s booked'$q$, $q$'They''re booked'$q$);
  execute def;
end $$;
