const assert = require("node:assert/strict");
const M = require("./model.js");
const near = (a, b, tol = 0.01, msg) => assert.ok(Math.abs(a - b) <= tol, `${msg}: ${a} vs ${b}`);
const B = M.SCENARIOS.base;

// Unit economics against the real booking: Mati's HD-WS5L was $65 + $15 travel = $80, fee $12.60.
const u80 = M.unit({ ...B, avgPrice: 80 });
near(u80.fee, 12.6, 0.001, "fee on $80"); near(u80.proGets, 70.4, 0.001, "pro gets on $80"); near(u80.clientPays, 83, 0.001, "client pays");
const u = M.unit(B);
near(u.fee, 17.04, 0.001, "base fee"); near(u.card, 120 * 0.0165 + 0.3, 1e-9, "card");
near(u.payout, (117 - 14.04) * 0.005 + 0.25, 1e-9, "payout plus funds routing"); assert.equal(u.connect, 2);
near(u.contribution, 17.04 - (120 * 0.0165 + 0.3) - u.payout - 17.04 * 0.02 - 0.5, 1e-9, "contribution after support");
near(u.lifetime, 1 + 0.35 * (52 / 12 / 6) / 0.06, 1e-9, "lifetime");
// Overseas cities use their price level and Stripe's price in that country.
const ny = M.MARKETS.find((c) => c.name === "New York");
const uny = M.unit(B, ny);
near(uny.proPrice, 117 * 1.35, 1e-9, "NY price"); near(uny.card, (117 * 1.35 + 3) * 0.029 + 0.43, 1e-9, "NY card");
near(uny.payout, 117 * 1.35 * 0.88 * 0.005 + 0.36, 1e-9, "NY payout"); assert.equal(uny.connect, 2.85);
// Every overseas country has Stripe prices, and the AU sliders only move Australia.
assert.ok(M.MARKETS.every((c) => c.country === "AU" || M.STRIPE[c.country]), "Stripe price for every country");
near(M.unit({ ...B, cardPct: 5 }, ny).card, uny.card, 1e-9, "AU slider leaves NY alone");

// Regression: Melbourne with the old marketing, lawyer, card fee and no support or routing cost reproduces the first model
// (base: break-even m8, low cash -5410 in m7, year 1 -4394, year 2 +8550). A 100% reach keeps the ceiling out of the way.
const old = M.simulate({ ...B, marketing: 600, oneOff: 3000, supportPerBooking: 0, reach: 100, proBookedMin: 0, cardPct: 1.75, routingPct: 0 });
assert.equal(old.breakEven, 8); assert.equal(old.lowMonth, 7);
near(old.lowCash, -5410, 2, "old low cash"); near(old.years[0].profit, -4394, 2, "old y1"); near(old.years[1].profit, 8550, 5, "old y2");

// Opening order: Melbourne only; Australia adds 11 cities from auStart every auCadence; Global adds 11 overseas.
assert.deepEqual(M.opening(B).filter((x) => x !== null), [1]);
const au = M.opening({ ...B, region: "australia" });
assert.deepEqual(au.slice(0, 4), [1, 13, 16, 19]); assert.equal(au.filter((x) => x !== null).length, 12);
const gl = M.opening({ ...B, region: "global" });
assert.equal(gl.filter((x) => x !== null).length, M.MARKETS.length);
assert.equal(gl[M.MARKETS.findIndex((c) => c.name === "Auckland")], 37);
assert.equal(gl[M.MARKETS.findIndex((c) => c.name === "London")], 41);

// Supply cap binds when there are no pros; demand binds when there's no marketing and no organic.
const noPros = M.simulate({ ...B, startPros: 0, newPros: 0 });
assert.ok(noPros.months.every((x) => x.bookings === 0 && x.limit === "pros"));
const noDemand = M.simulate({ ...B, marketing: 0, organic: 0 });
assert.ok(noDemand.months.every((x) => x.bookings === 0 && x.limit === "clients"));

// Cash is the running sum of profit; profit = fees - costs; bookings never exceed either side, in every region.
for (const region of ["melbourne", "australia", "global"]) {
  for (const sc of Object.values(M.SCENARIOS)) {
    const r = M.simulate({ ...sc, region, months: M.HORIZON[region] });
    let c = 0;
    for (const x of r.months) {
      c += x.profit; near(x.cash, c, 1e-4, `${region} cash m${x.m}`); near(x.profit, x.fees - x.costs, 1e-6, "profit");
      assert.ok(x.bookings <= x.capacity + 1e-9 && x.bookings <= x.demand + 1e-9, "bookings = min");
    }
    // The ceiling holds: no city reaches more people than its reachable share.
    assert.ok(r.markets.every((mk) => mk.ever <= mk.cap + 1e-6), `${region} ceiling`);
    if (r.moneyBack) assert.ok(r.months[r.moneyBack - 1].cash >= 0 && r.months[r.moneyBack - 2].cash < 0, "money back is the crossing");
  }
}

// A tiny reach caps a city hard: with 0.01% of Melbourne (544 people) it can never serve more than 544 clients.
const tiny = M.simulate({ ...B, reach: 0.01, months: 120 });
assert.ok(tiny.markets[0].ever <= 544 + 1e-6 && tiny.markets[0].ever > 400, `tiny reach ${tiny.markets[0].ever}`);

// Pro sign-ups pause while a city's pros are under the busy threshold, and never otherwise.
const quiet = M.simulate({ ...B, proBookedMin: 100, months: 12 });
near(quiet.months.reduce((n, x) => n + x.recruiting, 0), B.startPros * B.recruitCost, 1e-9, "no hiring when always under-booked");
const open = M.simulate({ ...B, proBookedMin: 0, months: 12 });
near(open.months.reduce((n, x) => n + x.recruiting, 0), (B.startPros + 11 * B.newPros) * B.recruitCost, 1e-9, "hire every month at 0%");

// Country costs: Global pays countryCost once per overseas country (NZ, UK, CA, US, AE, SG = 6).
const g = M.simulate({ ...B, region: "global", months: 120 });
near(g.months.reduce((n, x) => n + x.launch, 0), 6 * B.countryCost, 1e-6, "country costs");
assert.equal(g.months[119].countries, 7);
// GST only on Australian fees.
const gx = M.simulate({ ...M.SCENARIOS.ambitious, region: "global", months: 120 });
for (const x of gx.months) assert.ok(x.gst <= x.auFees / 11 + 1e-9);

// Market: Melbourne's mobile pool is 5.44M people x $450 x 5%; a city's yearly booked value is its last 12 months.
const mk = M.simulate({ ...B, months: 24 }).markets[0];
near(mk.market, 5.44e6 * 450 * 0.05, 1e-3, "Melbourne mobile market");
const m24 = M.simulate({ ...B, months: 24 });
near(mk.yearGmv, m24.months.slice(12).reduce((n, x) => n + x.gmv, 0), 1e-6, "Melbourne year GMV = last 12 months");
near(M.simulate({ ...B, region: "global", months: 120 }).markets.find((c) => c.name === "London").market, 9.1 * 1e6 * 450 * 1.25 * 0.05, 1, "London market at its price level");

// Time cost only when an hourly rate is set.
near(M.simulate({ ...B, hourRate: 50 }).months[0].time, 15 * 50 * 52 / 12, 1e-6, "time cost");

const k = (v) => (Math.abs(v) >= 1e6 ? `${(v / 1e6).toFixed(2)}M` : `${Math.round(v / 100) / 10}k`);
for (const region of ["melbourne", "australia", "global"]) {
  for (const [name, sc] of Object.entries(M.SCENARIOS)) {
    const s = M.simulate({ ...sc, region, months: M.HORIZON[region] });
    const last = s.months[s.months.length - 1], ly = s.years[s.years.length - 1];
    console.log(`${region.padEnd(9)} ${name.padEnd(9)} BE m${s.breakEven ?? "-"} · low ${k(s.lowCash)} (m${s.lowMonth}) back m${s.moneyBack ?? "-"} · GST m${s.gstMonth ?? "-"} · end ${Math.round(last.bookings)} bk/mo, ${Math.round(last.pros)} pros, ${last.live} cities (${last.limit}) · last yr GMV ${k(ly.gmv)} profit ${k(ly.profit)} · cash ${k(last.cash)}`);
  }
}
console.log("ok");
