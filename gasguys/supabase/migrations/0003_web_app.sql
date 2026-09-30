-- What the live customer web app (src/backend/supabase.ts) needs on top of 0001 and 0002.

-- Customers may change only their own name and language from the browser. 0002's customers_self_write
-- policy decides which row; these column grants decide which columns. The phone number is the login
-- and auth_user is set by the `me` edge function, so the client must not be able to change either.
-- (The web app itself makes these changes through the `me` function; this closes the direct path.)
revoke update on table public.customers from anon, authenticated;
grant update (name, lang) on table public.customers to authenticated;

-- Realtime for refill orders, so the app's refill tracker moves when ops moves an order along.
-- (meters and payments were added in 0002.) Realtime applies each subscriber's RLS SELECT policies.
alter publication supabase_realtime add table refill_orders;
