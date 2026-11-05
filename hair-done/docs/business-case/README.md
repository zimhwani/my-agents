# Business case model

A month-by-month, city-by-city simulation of Hair Done: Melbourne, then Australia, then 23 cities worldwide.
Published as a private artifact: https://claude.ai/artifact/FGzhcTh6CN1nPusYvg32aB

- `model.js`: the model. Pure: inputs in, months out. Shared by the page and the test.
- `page.html`: the page, with `/*MODEL*/` where the model goes.
- `build.py`: makes `hairdone-business-case.html` (open it in a browser, no server needed).
- `test.cjs`: `node test.cjs` checks the sums and prints every scenario.

Sources (read 30 Oct 2026): populations from each country's statistics office (ABS, Stats NZ, ONS, StatCan,
US Census, Dubai Statistics, SingStat); Stripe prices from stripe.com/<country>/pricing and /connect/pricing;
city price levels from median Fresha listings; market size from IBISWorld (Australian hair and beauty services,
$12.5bn in 2026). Anything marked "guess" in the page is an assumption to replace with real bookings.
