"use client";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { PriceCalendar } from "@/components/PriceCalendar";
import { Results } from "@/components/Results";
import { SearchForm } from "@/components/SearchForm";
import { Tracker, type Snapshot } from "@/components/Tracker";
import { VoicePanel } from "@/components/VoicePanel";
import { useSpeech } from "@/hooks/useSpeech";
import { airportLabel } from "@/lib/airports";
import { formatTime, sampleDates, spokenDate, spokenDuration, todayISO } from "@/lib/dates";
import { routeLabel, spokenMoney, spokenOffer, spokenScanSummary } from "@/lib/format";
import { HELP_TEXT, parseIntent } from "@/lib/intent";
import { defaultParams, normalizeParams } from "@/lib/params";
import { sortOffers } from "@/lib/rank";
import type { Intent, InterpretResponse, RankedOffer, ScanResult, SearchParams, SortMode } from "@/lib/types";

const HISTORY_KEY = "flight-agent:history";
const PARAMS_KEY = "flight-agent:params";
const TRACK_KEY = "flight-agent:tracking";

interface Status { provider: "amadeus" | "sample"; isSample: boolean; amadeusEnv: string | null; claude: boolean }

function load<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}
function save(key: string, value: unknown) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* private mode etc. */ }
}

export default function Page() {
  const [params, setParams] = useState<SearchParams>(() => defaultParams());
  const [result, setResult] = useState<ScanResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sort, setSort] = useState<SortMode>("best");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [dateFilter, setDateFilter] = useState<string | null>(null);
  const [status, setStatus] = useState<Status | null>(null);
  const [heard, setHeard] = useState("");
  const [reply, setReply] = useState("Say “search for flights” to begin.");
  const [busy, setBusy] = useState(false);
  const [continuous, setContinuous] = useState(false);
  const [history, setHistory] = useState<Snapshot[]>([]);
  const [tracking, setTracking] = useState<{ enabled: boolean; intervalHours: number }>({ enabled: false, intervalHours: 6 });
  const [nextRunAt, setNextRunAt] = useState<number | null>(null);
  const [priceAlert, setPriceAlert] = useState<string | null>(null);

  const paramsRef = useRef(params);
  paramsRef.current = params;
  const resultRef = useRef(result);
  resultRef.current = result;
  const sortRef = useRef(sort);
  sortRef.current = sort;

  // Restore per-browser state.
  useEffect(() => {
    setHistory(load<Snapshot[]>(HISTORY_KEY, []));
    setParams(normalizeParams(load(PARAMS_KEY, {})));
    setTracking(load(TRACK_KEY, { enabled: false, intervalHours: 6 }));
    fetch("/api/status").then((r) => r.json()).then(setStatus).catch(() => setStatus(null));
  }, []);
  useEffect(() => save(PARAMS_KEY, params), [params]);
  useEffect(() => save(TRACK_KEY, tracking), [tracking]);

  const updateParams = useCallback((patch: Partial<SearchParams>) => {
    setParams((p) => normalizeParams({ ...p, ...patch }));
  }, []);

  const sorted = useMemo(() => {
    if (!result) return [];
    const pool = dateFilter ? result.offers.filter((o) => o.departureDate === dateFilter) : result.offers;
    return sortOffers(pool, sort);
  }, [result, sort, dateFilter]);

  const datesToScan = sampleDates(params.windowStart, params.windowEnd, params.stepDays).length;

  /** Run the scan with the given params and record a tracking snapshot. Returns the result. */
  const runSearch = useCallback(async (p: SearchParams = paramsRef.current): Promise<ScanResult | null> => {
    setLoading(true);
    setError(null);
    setDateFilter(null);
    setSelectedId(null);
    try {
      const res = await fetch("/api/search", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(p) });
      const json = (await res.json()) as ScanResult & { error?: string };
      if (!res.ok || json.error) throw new Error(json.error ?? `Search failed (${res.status})`);
      setResult(json);
      const cheapest = sortOffers(json.offers, "cheapest")[0];
      const best = sortOffers(json.offers, "best")[0];
      const snap: Snapshot = {
        at: json.generatedAt,
        provider: json.provider,
        isSample: json.isSample,
        window: [p.windowStart, p.windowEnd],
        cheapest: cheapest ? { total: cheapest.price.total, currency: cheapest.price.currency, date: cheapest.departureDate, carrier: cheapest.validatingCarrierName } : null,
        best: best ? { total: best.price.total, currency: best.price.currency, date: best.departureDate, carrier: best.validatingCarrierName } : null,
      };
      setHistory((h) => {
        const prev = [...h].reverse().find((s) => s.window[0] === snap.window[0] && s.window[1] === snap.window[1] && s.cheapest);
        if (prev?.cheapest && snap.cheapest && snap.cheapest.total < prev.cheapest.total) {
          setPriceAlert(`Price drop: cheapest fare is now ${spokenMoney(snap.cheapest.total, snap.cheapest.currency)}, down from ${spokenMoney(prev.cheapest.total, prev.cheapest.currency)}.`);
        } else setPriceAlert(null);
        const next = [...h, snap].slice(-200);
        save(HISTORY_KEY, next);
        return next;
      });
      return json;
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  // Tracking loop: re-run while the tab is open.
  useEffect(() => {
    if (!tracking.enabled) { setNextRunAt(null); return; }
    const ms = tracking.intervalHours * 3_600_000;
    setNextRunAt(Date.now() + ms);
    const id = setInterval(() => {
      runSearch().then((r) => {
        setNextRunAt(Date.now() + ms);
        if (r) {
          const cheapest = sortOffers(r.offers, "cheapest")[0];
          if (cheapest) speakRef.current?.(`Tracking update: cheapest fare is ${spokenMoney(cheapest.price.total, cheapest.price.currency)} on ${spokenDate(cheapest.departureDate)}.`);
        }
      });
    }, ms);
    return () => clearInterval(id);
  }, [tracking, runSearch]);

  const speakRef = useRef<((t: string) => Promise<void>) | null>(null);

  const describeOffer = (o: RankedOffer, position: number): string => {
    const out = o.outbound;
    const segs = out.segments.map((s) => `${s.carrierName} ${s.flightNumber} from ${airportLabel(s.from)} at ${formatTime(s.departure)} to ${airportLabel(s.to)} at ${formatTime(s.arrival)}`).join(", then ");
    const lay = out.layovers.map((l) => `${spokenDuration(l.minutes)} in ${airportLabel(l.airport)}${l.overnight ? ", overnight" : ""}`).join(" and ");
    const back = o.inbound ? ` Coming home on ${spokenDate(o.returnDate!)} ${routeLabel(o.inbound)}, ${spokenDuration(o.inbound.durationMin)}.` : "";
    return `${spokenOffer(o, position)} Outbound: ${segs}.${lay ? ` Layover ${lay}.` : ""}${back}${o.badges.length ? ` Tags: ${o.badges.join(", ")}.` : ""}`;
  };

  /** Apply an intent to the app state and return what to say. */
  const applyIntent = useCallback(async (intent: Intent, spoken: string): Promise<string> => {
    const current = paramsRef.current;
    const readTop = (r: ScanResult | null, mode: SortMode, count = 3) => {
      if (!r) return "There are no results yet. Say search for flights first.";
      const list = sortOffers(r.offers, mode);
      return spokenScanSummary(r, list, mode, count);
    };
    switch (intent.type) {
      case "search": {
        const r = await runSearch(current);
        return r ? readTop(r, sortRef.current) : "The search failed. Please try again.";
      }
      case "set_dates": {
        const next = normalizeParams({ ...current, windowStart: intent.windowStart ?? current.windowStart, windowEnd: intent.windowEnd ?? current.windowEnd });
        setParams(next);
        const r = await runSearch(next);
        return r ? `${spoken} ${readTop(r, sortRef.current)}` : "The search failed. Please try again.";
      }
      case "set_passengers": {
        const next = normalizeParams({ ...current, adults: intent.adults ?? current.adults, children: intent.children ?? current.children, infants: intent.infants ?? current.infants });
        setParams(next);
        const r = await runSearch(next);
        return r ? `Now searching for ${next.adults} adults and ${next.children} children. ${readTop(r, sortRef.current)}` : spoken;
      }
      case "set_trip": {
        const next = normalizeParams({ ...current, tripType: intent.tripType ?? current.tripType, stayNights: intent.stayNights ?? current.stayNights });
        setParams(next);
        const r = await runSearch(next);
        return r ? `${spoken} ${readTop(r, sortRef.current)}` : spoken;
      }
      case "set_cabin": {
        const next = normalizeParams({ ...current, cabin: intent.cabin });
        setParams(next);
        const r = await runSearch(next);
        return r ? `${spoken} ${readTop(r, sortRef.current)}` : spoken;
      }
      case "set_sort":
        setSort(intent.sort);
        setDateFilter(null);
        return readTop(resultRef.current, intent.sort);
      case "read_results": {
        const mode = intent.sort ?? sortRef.current;
        if (intent.sort) setSort(intent.sort);
        return readTop(resultRef.current, mode, intent.count ?? 3);
      }
      case "select_offer": {
        const list = resultRef.current ? sortOffers(dateFilter ? resultRef.current.offers.filter((o) => o.departureDate === dateFilter) : resultRef.current.offers, sortRef.current) : [];
        const o = list[intent.index - 1];
        if (!o) return `There is no option ${intent.index}.`;
        setSelectedId(o.id);
        setTimeout(() => document.getElementById(`offer-${intent.index}`)?.scrollIntoView({ behavior: "smooth", block: "center" }), 50);
        return describeOffer(o, intent.index);
      }
      case "track":
        setTracking((t) => ({ enabled: intent.enabled, intervalHours: intent.intervalHours ?? t.intervalHours }));
        if (intent.enabled && !resultRef.current) await runSearch(current);
        return intent.enabled
          ? `Tracking prices every ${intent.intervalHours ?? tracking.intervalHours} hours while this page is open. I will tell you when the cheapest fare drops.`
          : "Stopped tracking prices.";
      case "help":
        return HELP_TEXT;
      case "stop":
        return "";
      default:
        return spoken;
    }
  }, [runSearch, dateFilter, tracking.intervalHours]);

  const handleUtterance = useCallback(async (text: string) => {
    setHeard(text);
    setBusy(true);
    if (typeof window !== "undefined" && "speechSynthesis" in window) window.speechSynthesis.cancel();
    try {
      // Instant local parse; the server (Claude, when configured) refines it.
      let interp: InterpretResponse = { intent: parseIntent(text, todayISO()), speech: "", source: "rules" };
      if (interp.intent.type === "stop") {
        setReply("Okay.");
        return;
      }
      try {
        const r = resultRef.current;
        const res = await fetch("/api/interpret", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            utterance: text,
            params: paramsRef.current,
            lastResult: r ? { datesScanned: r.datesScanned, isSample: r.isSample, top: sortOffers(r.offers, sortRef.current).slice(0, 5).map((o) => ({ price: o.price, validatingCarrierName: o.validatingCarrierName, departureDate: o.departureDate, totalDurationMin: o.totalDurationMin, stops: o.stops })) } : undefined,
          }),
        });
        if (res.ok) interp = (await res.json()) as InterpretResponse;
      } catch {
        /* offline: keep the local parse */
      }
      const say = await applyIntent(interp.intent, interp.speech);
      setReply(say || interp.speech || "Done.");
      if (say) await speakRef.current?.(say);
    } finally {
      setBusy(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [applyIntent]);

  const speech = useSpeech(handleUtterance, { continuous });
  speakRef.current = speech.speak;

  useEffect(() => {
    if (priceAlert) speech.speak(priceAlert);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [priceAlert]);

  return (
    <main className="app">
      <header className="topbar">
        <h1>✈️ Harare Flight Agent <span>· Melbourne → Harare</span></h1>
        <div className="pills">
          {status && (
            <span className={`pill ${status.isSample ? "warn" : "ok"}`}>
              {status.isSample ? "sample fares" : `live fares · Amadeus ${status.amadeusEnv}`}
            </span>
          )}
          {status && <span className={`pill ${status.claude ? "ok" : ""}`}>{status.claude ? "voice: Claude" : "voice: built-in parser"}</span>}
          {tracking.enabled && <span className="pill ok">tracking every {tracking.intervalHours}h</span>}
        </div>
      </header>

      <VoicePanel speech={speech} heard={heard} reply={reply} busy={busy} continuous={continuous} onContinuous={setContinuous} onCommand={handleUtterance} />

      {priceAlert && <div className="notice">{priceAlert}</div>}
      {error && <div className="notice error">{error}</div>}
      {result?.warnings.filter((w) => !w.startsWith("Showing sample")).slice(0, 3).map((w) => (
        <div key={w} className="notice">{w}</div>
      ))}

      <SearchForm params={params} onChange={updateParams} onSearch={() => runSearch()} loading={loading} datesToScan={datesToScan} />

      {result && <PriceCalendar byDate={result.byDate} currency={params.currency} active={dateFilter} onPick={setDateFilter} />}

      <Results offers={sorted} sort={sort} onSort={setSort} selectedId={selectedId} onSelect={setSelectedId} dateFilter={dateFilter} onClearDate={() => setDateFilter(null)} />

      <Tracker
        enabled={tracking.enabled}
        intervalHours={tracking.intervalHours}
        nextRunAt={nextRunAt}
        history={history}
        onToggle={(on) => setTracking((t) => ({ ...t, enabled: on }))}
        onInterval={(h) => setTracking((t) => ({ ...t, intervalHours: h }))}
        onClear={() => { setHistory([]); save(HISTORY_KEY, []); }}
      />

      <footer className="foot">
        {result?.isSample ? "Sample fares are modelled on real MEL–HRE routings and seasonal pricing, not live quotes. " : ""}
        Prices are for the whole party in {params.currency}. “Best” balances price, total travel time, interchange quality and family-friendly timings.
      </footer>
    </main>
  );
}
