// Stripe's Connect onboarding sends the pro back to a web address. This hands her back to the app.
// A redirect, not a page: Supabase serves HTML from *.supabase.co as plain text, so a page with a
// link shows as source code. A 302 to the app's own scheme opens Hair Done directly.
Deno.serve((req) => {
  const done = new URL(req.url).searchParams.get("state") !== "refresh";
  const target = done ? "hairdone://payouts/done" : "hairdone://payouts/refresh";
  return new Response(null, { status: 302, headers: { Location: target, "Cache-Control": "no-store" } });
});
