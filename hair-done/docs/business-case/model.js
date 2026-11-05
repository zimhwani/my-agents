// Hair Done business case: one month at a time, in every city that's open, supply and demand meet and whichever
// is smaller is the number of bookings. Cities open one after another, the way Airbnb grew: seed pros first, then
// clients, then the next city. Pure: inputs in, months out. Shared by the page and its test.
const MODEL = (() => {
  const GST_THRESHOLD = 75000;

  /** Bookings a returning client makes in a month, from "books every N weeks". */
  const perMonth = (weeks) => 52 / 12 / Math.max(1, weeks);

  // Metro populations in millions, latest official estimates (ABS Greater Capital City or Significant Urban Area, Jun 2025;
  // Stats NZ, ONS, StatCan CMA, US Census MSA, Dubai Statistics, SingStat). price = a booking there against Melbourne, in
  // AUD: the median Fresha listing for a gel manicure and a women's cut on 30 Oct 2026 (US haircuts averaged with Square's
  // city price pages). Samples of 10 to 66 salons, so Canberra, Geelong and Hobart especially are rough.
  const MARKETS = [
    { name: "Melbourne", country: "AU", pop: 5.44, price: 1 },
    { name: "Sydney", country: "AU", pop: 5.64, price: 1.01 },
    { name: "Brisbane", country: "AU", pop: 2.83, price: 0.99 },
    { name: "Perth", country: "AU", pop: 2.45, price: 1.19 },
    { name: "Adelaide", country: "AU", pop: 1.49, price: 0.93 },
    { name: "Gold Coast", country: "AU", pop: 0.76, price: 0.93 },
    { name: "Canberra", country: "AU", pop: 0.48, price: 1.24 },
    { name: "Newcastle", country: "AU", pop: 0.54, price: 0.99 },
    { name: "Sunshine Coast", country: "AU", pop: 0.42, price: 1.03 },
    { name: "Geelong", country: "AU", pop: 0.31, price: 0.92 },
    { name: "Wollongong", country: "AU", pop: 0.32, price: 0.79 },
    { name: "Hobart", country: "AU", pop: 0.26, price: 0.85 },
    { name: "Auckland", country: "NZ", pop: 1.8, price: 0.66 },
    { name: "London", country: "UK", pop: 9.1, price: 1.25 },
    { name: "Toronto", country: "CA", pop: 7.11, price: 0.81 },
    { name: "New York", country: "US", pop: 20.11, price: 1.35 },
    { name: "Los Angeles", country: "US", pop: 12.84, price: 1.32 },
    { name: "Dubai", country: "AE", pop: 4.58, price: 1 },
    { name: "Singapore", country: "SG", pop: 6.21, price: 0.96 },
    { name: "Manchester", country: "UK", pop: 3.0, price: 0.83 },
    { name: "Chicago", country: "US", pop: 9.43, price: 1.08 },
    { name: "Vancouver", country: "CA", pop: 3.09, price: 0.78 },
    { name: "Miami", country: "US", pop: 6.39, price: 1.08 },
  ];
  const HOME_POP = MARKETS[0].pop;

  // Stripe's published domestic-card and Connect prices per country, read from stripe.com/<country>/pricing and
  // /connect/pricing on 30 Oct 2026. Fixed parts converted to AUD at that day's rates (NZD .80, GBP 1.90, CAD 1.017,
  // USD 1.423, AED .387, SGD 1.111). Australia's come from the sliders instead, so they can be changed.
  const STRIPE = {
    NZ: { cardPct: 2.65, cardFixed: 0.24, payoutFixed: 0.2, connect: 1.6 },
    UK: { cardPct: 1.5, cardFixed: 0.38, payoutFixed: 0.19, connect: 3.8 },
    CA: { cardPct: 2.9, cardFixed: 0.31, payoutFixed: 0.25, connect: 2.03 },
    US: { cardPct: 2.9, cardFixed: 0.43, payoutFixed: 0.36, connect: 2.85 },
    AE: { cardPct: 2.9, cardFixed: 0.39, payoutFixed: 2.13, connect: 2.91 },
    SG: { cardPct: 3.4, cardFixed: 0.56, payoutFixed: 0.56, connect: 2.22 },
  };
  const stripeFor = (a, country) => country === "AU"
    ? { cardPct: a.cardPct, cardFixed: a.cardFixed, payoutFixed: a.payoutFixed, connect: a.connectMonthly } : STRIPE[country];
  const REGIONS = { melbourne: "Melbourne", australia: "Australia", global: "Global" };

  /** The month each city opens in this region (1 = Melbourne's first month), or null if it doesn't. */
  function opening(a) {
    let au = 0, os = 0;
    return MARKETS.map((c, i) => {
      if (i === 0) return 1;
      if (c.country === "AU") return a.region === "melbourne" ? null : Math.round(a.auStart + (au++) * a.auCadence);
      return a.region === "global" ? Math.round(a.overseasStart + (os++) * a.overseasCadence) : null;
    });
  }

  function unit(a, city = MARKETS[0]) {
    const proPrice = a.avgPrice * city.price;          // services + travel, what the pro sets
    const clientPays = proPrice + a.bookingFee;
    const fee = proPrice * a.takeRate / 100 + a.bookingFee;
    const st = stripeFor(a, city.country);
    const card = clientPays * st.cardPct / 100 + st.cardFixed;
    const payout = (proPrice - proPrice * a.takeRate / 100) * (a.payoutPct + a.routingPct) / 100 + st.payoutFixed;
    const refunds = fee * a.refundPct / 100;
    const contribution = fee - card - payout - refunds - a.supportPerBooking;
    const lifetime = 1 + (a.repeatShare / 100) * perMonth(a.rebookWeeks) / Math.max(0.005, a.repeatChurn / 100);
    return { proPrice, clientPays, fee, card, payout, refunds, support: a.supportPerBooking, contribution, lifetime,
             connect: st.connect, cacPerBooking: a.cac / lifetime, proGets: proPrice - proPrice * a.takeRate / 100 };
  }

  function simulate(a) {
    const opens = opening(a);
    const cities = MARKETS.map((c, i) => ({ ...c, open: opens[i], u: unit(a, c), scale: c.pop / HOME_POP,
      cap: c.pop * 1e6 * a.reach / 100,
      // The city's yearly spend on hair and beauty that goes to mobile pros, in AUD, priced at its own level.
      market: c.pop * 1e6 * a.spendPerPerson * c.price * a.mobileShare / 100, gmvs: [], pros: 0, repeat: 0, ever: 0, last: 0, lastCap: 0, bookings: 0, demand: 0 }));
    const months = [];
    const entered = new Set();
    let cash = 0, gstFrom = null, low = 0, lowMonth = 0;
    const auFeeHistory = [];
    for (let m = 1; m <= a.months; m++) {
      const t = { capacity: 0, demand: 0, bookings: 0, newClients: 0, repeat: 0, pros: 0, gmv: 0, fees: 0, auFees: 0,
        stripe: 0, refunds: 0, support: 0, marketing: 0, recruiting: 0, launch: 0, local: 0, proLimitedDemand: 0, live: 0 };
      for (const c of cities) {
        if (c.open === null || m < c.open) continue;
        const first = m === c.open;
        if (first) {
          c.pros = c.open === 1 ? a.startPros : a.seedPros;
          t.recruiting += c.pros * a.recruitCost;
          if (!entered.has(c.country)) { entered.add(c.country); if (c.country !== "AU") t.launch += a.countryCost; }
        } else {
          // Like Airbnb, grow supply to meet demand: only sign up more pros while the ones there are busy enough.
          const busy = c.lastCap > 0 ? c.last / c.lastCap : 1;
          const hire = busy >= a.proBookedMin / 100 ? a.newPros * c.scale : 0;
          c.pros = c.pros * (1 - a.proChurn / 100) + hire;
          t.recruiting += hire * a.recruitCost;
        }
        const capacity = c.pros * a.perProWeek * 52 / 12;
        const headroom = c.cap > 0 ? Math.max(0, 1 - c.ever / c.cap) : 0;   // fewer new people left to find as a city fills up
        const newClients = (a.marketing * c.scale / Math.max(1, a.cac) + a.organic * c.scale + c.last * a.referral / 100) * headroom;
        const demand = newClients + c.repeat * perMonth(a.rebookWeeks);
        const bookings = Math.min(demand, capacity);
        const served = demand > 0 ? bookings / demand : 0;
        c.ever += newClients * served;
        c.repeat = c.repeat * (1 - a.repeatChurn / 100) + newClients * served * a.repeatShare / 100;
        c.last = bookings; c.lastCap = capacity; c.bookings = bookings; c.demand = demand;
        c.gmvs.push(bookings * c.u.clientPays); if (c.gmvs.length > 12) c.gmvs.shift();

        const fees = bookings * c.u.fee;
        t.capacity += capacity; t.demand += demand; t.bookings += bookings; t.newClients += newClients;
        t.repeat += c.repeat; t.pros += c.pros; t.live += 1;
        if (demand > capacity) t.proLimitedDemand += demand;
        t.gmv += bookings * c.u.clientPays; t.fees += fees;
        if (c.country === "AU") t.auFees += fees;
        t.stripe += bookings * (c.u.card + c.u.payout) + c.pros * c.u.connect;
        t.refunds += bookings * c.u.refunds;
        t.support += bookings * a.supportPerBooking;
        t.marketing += a.marketing * c.scale;
        if (c.open !== 1) t.local += a.cityMonthly;
      }
      const gst = gstFrom !== null && m >= gstFrom ? t.auFees / 11 : 0;   // registered: 1/11 of a GST-inclusive fee goes to the ATO
      const fixed = a.fixedMonthly + a.insuranceYearly * entered.size / 12 + (m === 1 ? a.oneOff : 0);
      const time = a.hoursWeek * a.hourRate * 52 / 12;
      const costs = gst + t.stripe + t.refunds + t.support + t.marketing + t.recruiting + t.launch + t.local + fixed + time;
      const profit = t.fees - costs;
      cash += profit;
      if (cash < low) { low = cash; lowMonth = m; }

      auFeeHistory.push(t.auFees);
      const trailing = auFeeHistory.slice(-12).reduce((n, x) => n + x, 0);
      if (gstFrom === null && trailing >= GST_THRESHOLD) gstFrom = m + 1;

      months.push({ m, ...t, limit: t.proLimitedDemand > t.demand / 2 ? "pros" : "clients", countries: entered.size,
        gst, fixed, time, costs, profit, cash, trailing });
    }
    const breakEven = months.find((x, i) => x.profit > 0 && months.slice(i).every((y) => y.profit > 0));
    const back = lowMonth ? months.find((x) => x.m > lowMonth && x.cash >= 0) : null;
    const year = (k) => months.slice((k - 1) * 12, k * 12);
    const sum = (rows, f) => rows.reduce((n, r) => n + r[f], 0);
    const years = [];
    for (let k = 1; k * 12 <= a.months; k++) years.push({ k, gmv: sum(year(k), "gmv"), fees: sum(year(k), "fees"),
      profit: sum(year(k), "profit"), bookings: sum(year(k), "bookings") });
    return {
      unit: unit(a), months, years,
      breakEven: breakEven ? breakEven.m : null,
      lowCash: low, lowMonth, moneyBack: back ? back.m : null,
      gstMonth: gstFrom !== null ? gstFrom - 1 : null,
      markets: cities.filter((c) => c.open !== null).map((c) => ({ name: c.name, country: c.country, pop: c.pop, open: c.open,
        live: c.open <= a.months, pros: c.pros, bookings: c.bookings, ever: c.ever, cap: c.cap, share: c.cap ? c.ever / c.cap : 0,
        market: c.market, yearGmv: c.gmvs.reduce((n, x) => n + x, 0) * 12 / Math.max(1, c.gmvs.length),
        limit: c.demand > c.pros * a.perProWeek * 52 / 12 ? "pros" : "clients" })),
    };
  }

  // Sources: "app" = what the app and Stripe set up actually do; "spec" = docs/product-spec.md targets;
  // "check" = a published price worth confirming; "guess" = a starting assumption to replace with real numbers.
  const FIELDS = [
    { group: "Price", id: "avgPrice", label: "Average booking in Melbourne, what the pro charges", unit: "$", min: 30, max: 300, step: 1, src: "spec", note: "Services plus travel. The spec assumes about $120 a booking all in. Other cities scale by their own price level." },
    { group: "Price", id: "takeRate", label: "Hair Done's cut from the pro", unit: "%", min: 0, max: 30, step: 0.5, src: "app" },
    { group: "Price", id: "bookingFee", label: "Booking fee the client pays", unit: "$", min: 0, max: 10, step: 0.5, src: "app" },
    { group: "Pros", id: "startPros", label: "Verified pros in Melbourne at the start", unit: "", min: 0, max: 200, step: 1, src: "guess", note: "Today: 1 (Mati). The spec's launch target is 50." },
    { group: "Pros", id: "newPros", label: "New pros signed up each month in Melbourne", unit: "", min: 0, max: 60, step: 1, src: "guess", note: "Other cities scale by population." },
    { group: "Pros", id: "proBookedMin", label: "Only sign up more pros while they're this booked", unit: "%", min: 0, max: 100, step: 5, src: "guess", note: "Grow supply to match demand, as Airbnb does. At 0%, pros keep joining however quiet it is." },
    { group: "Pros", id: "proChurn", label: "Pros who stop each month", unit: "%", min: 0, max: 30, step: 0.5, src: "guess" },
    { group: "Pros", id: "perProWeek", label: "Hair Done bookings a pro can take a week", unit: "", min: 0.5, max: 20, step: 0.5, src: "guess", note: "Their Hair Done share, not their whole week. The spec's pros do 8 to 25 jobs a week in total." },
    { group: "Pros", id: "recruitCost", label: "Cost to sign up a pro", unit: "$", min: 0, max: 500, step: 5, src: "guess" },
    { group: "Clients", id: "organic", label: "Clients who find you for free each month in Melbourne", unit: "", min: 0, max: 500, step: 1, src: "guess", note: "Search, the App Store, Instagram, pros sharing their link. Other cities scale by population." },
    { group: "Clients", id: "referral", label: "New clients per 100 bookings, by word of mouth", unit: "", min: 0, max: 50, step: 1, src: "guess" },
    { group: "Clients", id: "repeatShare", label: "First-time clients who come back", unit: "%", min: 0, max: 90, step: 1, src: "spec", note: "The spec's 60-day target is 35%." },
    { group: "Clients", id: "rebookWeeks", label: "A regular books every", unit: "weeks", min: 1, max: 26, step: 1, src: "guess" },
    { group: "Clients", id: "repeatChurn", label: "Regulars who drift away each month", unit: "%", min: 0.5, max: 40, step: 0.5, src: "guess" },
    { group: "Clients", id: "marketing", label: "Paid marketing a month in Melbourne", unit: "$", min: 0, max: 20000, step: 50, src: "guess", note: "Off: growth is word of mouth only. Other cities spend in proportion to their size." },
    { group: "Clients", id: "cac", label: "Cost to win a client with paid marketing", unit: "$", min: 5, max: 200, step: 1, src: "guess" },
    { group: "Growing", id: "spendPerPerson", label: "Spend on hair and beauty a person a year, Australia", unit: "$", min: 50, max: 2000, step: 10, src: "check", note: "IBISWorld puts Australian hair and beauty services at $12.5bn in 2026, about $450 a person. Other cities scale by their price level." },
    { group: "Growing", id: "mobileShare", label: "Share of that spend that goes to mobile pros", unit: "%", min: 0.5, max: 30, step: 0.5, src: "guess", note: "Nobody publishes this. 3% to 7% is a fair range: mostly event hair, makeup and lashes." },
    { group: "Growing", id: "reach", label: "Share of a city's people who'd ever book a mobile pro", unit: "%", min: 0.1, max: 20, step: 0.1, src: "guess", note: "The ceiling on each city. New clients get harder to find as a city fills up." },
    { group: "Growing", id: "auStart", label: "Second Australian city opens in month", unit: "", min: 2, max: 60, step: 1, src: "guess", note: "Australia and Global only. Sydney, then Brisbane, Perth, Adelaide and smaller cities." },
    { group: "Growing", id: "auCadence", label: "Months between new Australian cities", unit: "", min: 1, max: 24, step: 1, src: "guess" },
    { group: "Growing", id: "overseasStart", label: "First overseas city opens in month", unit: "", min: 6, max: 120, step: 1, src: "guess", note: "Global only. Auckland, London, Toronto, New York, Los Angeles, Dubai, Singapore and on." },
    { group: "Growing", id: "overseasCadence", label: "Months between new overseas cities", unit: "", min: 1, max: 24, step: 1, src: "guess" },
    { group: "Growing", id: "seedPros", label: "Pros a new city opens with", unit: "", min: 0, max: 100, step: 1, src: "guess", note: "Airbnb's playbook: line up supply before the first client arrives." },
    { group: "Growing", id: "cityMonthly", label: "Local running costs per extra city a month", unit: "$", min: 0, max: 10000, step: 50, src: "guess", note: "A local number, help with vetting, the odd pop-up. Melbourne's are in the running costs." },
    { group: "Growing", id: "countryCost", label: "Cost to start in a new country", unit: "$", min: 0, max: 200000, step: 1000, src: "guess", note: "A local company, tax registration, local terms and insurance. Australia has none." },
    { group: "Costs", id: "cardPct", label: "Stripe card fee, Australian cards", unit: "%", min: 0, max: 5, step: 0.05, src: "app", note: "Stripe's Australian price, 30 Oct 2026: 1.65% plus 30c. Overseas cities use Stripe's own price there, from 1.5% (UK) to 3.4% (Singapore)." },
    { group: "Costs", id: "cardFixed", label: "Stripe card fee, fixed part, Australia", unit: "$", min: 0, max: 1, step: 0.05, src: "app" },
    { group: "Costs", id: "payoutPct", label: "Stripe payout to a pro", unit: "%", min: 0, max: 2, step: 0.05, src: "app", note: "0.25% plus 25c a payout in Australia; the same % everywhere. Counted once per booking, which overstates it if pros get one payout a day for several jobs." },
    { group: "Costs", id: "routingPct", label: "Stripe funds routing", unit: "%", min: 0, max: 1, step: 0.05, src: "check", note: "Stripe's Connect pages list 0.25% of payouts on top of the payout fee. Ask Stripe whether the two stack; at 0% they don't." },
    { group: "Costs", id: "payoutFixed", label: "Stripe payout, fixed part, Australia", unit: "$", min: 0, max: 1, step: 0.05, src: "app" },
    { group: "Costs", id: "connectMonthly", label: "Stripe, each pro paid that month, Australia", unit: "$", min: 0, max: 5, step: 0.5, src: "app" },
    { group: "Costs", id: "refundPct", label: "Fees lost to refunds and disputes", unit: "%", min: 0, max: 20, step: 0.5, src: "guess" },
    { group: "Costs", id: "supportPerBooking", label: "Support per booking", unit: "$", min: 0, max: 10, step: 0.1, src: "guess", note: "The support agent's drafts plus someone to send them, once it's more than you." },
    { group: "Costs", id: "fixedMonthly", label: "Running costs a month", unit: "$", min: 0, max: 50000, step: 10, src: "guess", note: "Supabase, Apple, email, Cloudflare, Anthropic, Twilio. About $50 to $100 today." },
    { group: "Costs", id: "insuranceYearly", label: "Hair Done's own insurance a year, per country", unit: "$", min: 0, max: 10000, step: 100, src: "guess", note: "A placeholder until you have a quote." },
    { group: "Costs", id: "oneOff", label: "One-off costs in month 1", unit: "$", min: 0, max: 20000, step: 100, src: "guess", note: "Set to $0. Add a lawyer's review of the pro terms here if you get one." },
    { group: "Costs", id: "hoursWeek", label: "Your hours a week", unit: "h", min: 0, max: 60, step: 1, src: "guess" },
    { group: "Costs", id: "hourRate", label: "What your hour is worth", unit: "$", min: 0, max: 300, step: 5, src: "guess", note: "Leave at $0 to see cash only; set it to see whether the business pays you." },
  ];

  const BASE = { region: "melbourne", months: 24, avgPrice: 117, takeRate: 12, bookingFee: 3, startPros: 10, newPros: 6, proBookedMin: 25, proChurn: 4,
    perProWeek: 3, recruitCost: 40, marketing: 0, cac: 35, organic: 15, referral: 5, repeatShare: 35, rebookWeeks: 6,
    repeatChurn: 6, spendPerPerson: 450, mobileShare: 5, reach: 2, auStart: 13, auCadence: 3, overseasStart: 37, overseasCadence: 4, seedPros: 5,
    cityMonthly: 150, countryCost: 15000, cardPct: 1.65, cardFixed: 0.3, payoutPct: 0.25, routingPct: 0.25,
    payoutFixed: 0.25, connectMonthly: 2, refundPct: 2, supportPerBooking: 0.5, fixedMonthly: 100, insuranceYearly: 1500,
    oneOff: 0, hoursWeek: 15, hourRate: 0 };
  const SCENARIOS = {
    cautious: { ...BASE, startPros: 5, newPros: 3, proChurn: 6, perProWeek: 2, organic: 8, referral: 3, repeatShare: 25,
      repeatChurn: 9, reach: 1, auStart: 19, auCadence: 6, overseasStart: 61, overseasCadence: 6 },
    base: BASE,
    ambitious: { ...BASE, startPros: 30, newPros: 12, proChurn: 3, perProWeek: 4, organic: 40, referral: 8, repeatShare: 45,
      rebookWeeks: 5, repeatChurn: 5, reach: 4, auStart: 7, auCadence: 2, overseasStart: 25, overseasCadence: 3, seedPros: 10 },
  };
  const HORIZON = { melbourne: 24, australia: 60, global: 120 };

  return { simulate, unit, opening, MARKETS, STRIPE, REGIONS, HORIZON, FIELDS, SCENARIOS, GST_THRESHOLD, perMonth };
})();
if (typeof module !== "undefined") module.exports = MODEL;
