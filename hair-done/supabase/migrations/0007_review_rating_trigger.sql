-- Saving a review recalculates the pro's rating through refresh_pro_rating(), which signed-in users
-- can't call directly (0003). The trigger runs it on the server's behalf instead. Without this, a
-- client's review was refused with "permission denied for function refresh_pro_rating".
alter function reviews_after_change() security definer;
revoke execute on function reviews_after_change() from public, anon, authenticated;
