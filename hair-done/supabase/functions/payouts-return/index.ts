// Stripe's Connect onboarding sends the pro back to a web address. This page hands her back to the app.
Deno.serve((req) => {
  const done = new URL(req.url).searchParams.get("state") !== "refresh";
  const target = done ? "hairdone://payouts/done" : "hairdone://payouts/refresh";
  const html = `<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Hair Done</title><meta http-equiv="refresh" content="0;url=${target}">
<body style="font:17px -apple-system,system-ui;background:#F8F3EC;color:#241A16;display:grid;place-items:center;height:90vh;margin:0">
<a href="${target}" style="color:#241A16">${done ? "All set. Back to Hair Done" : "Back to Hair Done"}</a></body>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8" } });
});
