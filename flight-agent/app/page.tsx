"use client";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { load } from "@/lib/storage";
import { Conversation, VoiceBar } from "@/components/Conversation";
import { PlaneIcon, SettingsIcon } from "@/components/Icons";
import { PriceCalendar } from "@/components/PriceCalendar";
import { Results, ResultsSkeleton } from "@/components/Results";
import { SettingsDrawer, type Theme } from "@/components/SettingsDrawer";
import { SummaryStrip } from "@/components/SummaryStrip";
import { ScanNotes, Tracker, type Snapshot } from "@/components/Tracker";
import { TripSettings } from "@/components/TripSettings";
import { UnderstoodChips, type EditField } from "@/components/UnderstoodChips";
import { useSpeech } from "@/hooks/useSpeech";
import { apiHeaders, apiUrl, loadKeys, saveKeys, type StoredKeys } from "@/lib/client";
import { sampleDates, spokenDate, todayISO } from "@/lib/dates";
import { money, spokenBrief, spokenMoney, spokenOfferDetail, spokenScanSummary } from "@/lib/format";
import { HELP_TEXT, parseIntent } from "@/lib/intent";
import { defaultParams, legsFor, normalizeParams, returnDateFor, whyNoDates, withRoute } from "@/lib/params";
import { sortOffers } from "@/lib/rank";
import type { Intent, InterpretResponse, ScanResult, SearchParams, SortMode } from "@/lib/types";

const HISTORY_KEY = "flight-agent:history";
const PARAMS_KEY = "flight-agent:params";
const TRACK_KEY = "flight-agent:tracking";
const PREFS_KEY = "flight-agent:prefs";

interface Status { provider: "serpapi" | "sample"; isSample: boolean; liveSource: string | null; claude: boolean }
interface Prefs { theme: Theme; handsFree: boolean; speakReplies: boolean }

const GREETING = "When would you like to fly to Harare? Try “mid to late November, back early January”.";

function save(key: string, value: unknown) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* private mode etc. */ }
}

/** Departure dates that will actually be searched (stopovers and fixed returns can rule some out). */
function datesToSearch(p: SearchParams): number {
  return sampleDates(p.windowStart, p.windowEnd, p.stepDays).filter((d) => {
    if (p.tripType === "return" && p.returnDate && !returnDateFor(p, d)) return false;
    return legsFor(p, d, returnDateFor(p, d)) !== null;
  }).length;
}

export default function Page() {
  return (
    <ErrorBoundary>
      <FlightAgent />
    </ErrorBoundary>
  );
}

function FlightAgent() {
  const [params, setParams] = useState<SearchParams>(() => defaultParams());
  const [result, setResult] = useState<ScanResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sort, setSort] = useState<SortMode>("best");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [dateFilter, setDateFilter] = useState<string | null>(null);
  const [status, setStatus] = useState<Status | null>(null);
  const [heard, setHeard] = useState("");
  const [reply, setReply] = useState(GREETING);
  const [busy, setBusy] = useState(false);
  const [history, setHistory] = useState<Snapshot[]>([]);
  const [tracking, setTracking] = useState<{ enabled: boolean; intervalHours: number }>({ enabled: false, intervalHours: 6 });
  const [nextRunAt, setNextRunAt] = useState<number | null>(null);
  const [priceAlert, setPriceAlert] = useState<string | null>(null);
  const [keys, setKeys] = useState<StoredKeys>({ serpApiKey: "", anthropicKey: "" });
  const [prefs, setPrefs] = useState<Prefs>({ theme: "system", handsFree: false, speakReplies: true });
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [editorOpen, setEditorOpen] = useState(false);
  const [editFocus, setEditFocus] = useState<EditField | null>(null);
  const [returnInferred, setReturnInferred] = useState(false);
  const [lastUtterance, setLastUtterance] = useState<string | null>(null);

  const keysRef = useRef(keys);
  keysRef.current = keys;
  const paramsRef = useRef(params);
  paramsRef.current = params;
  const resultRef = useRef(result);
  resultRef.current = result;
  const sortRef = useRef(sort);
  sortRef.current = sort;
  const prefsRef = useRef(prefs);
  prefsRef.current = prefs;

  // Restore per-browser state.
  useEffect(() => {
    setHistory(load<Snapshot[]>(HISTORY_KEY, []).filter((h) => h && typeof h.at === "string" && Array.isArray(h.window)));
    setParams(normalizeParams(load(PARAMS_KEY, {})));
    setTracking(load(TRACK_KEY, { enabled: false, intervalHours: 6 }));
    setPrefs(load(PREFS_KEY, { theme: "system", handsFree: false, speakReplies: true }));
    setKeys(loadKeys());
  }, []);
  useEffect(() => {
    fetch(apiUrl("status"), { headers: apiHeaders(keys, false) }).then((r) => r.json()).then(setStatus).catch(() => setStatus(null));
  }, [keys]);
  useEffect(() => save(PARAMS_KEY, params), [params]);
  useEffect(() => save(TRACK_KEY, tracking), [tracking]);
  useEffect(() => {
    save(PREFS_KEY, prefs);
    const root = document.documentElement;
    if (prefs.theme === "system") delete root.dataset.theme;
    else root.dataset.theme = prefs.theme;
  }, [prefs]);

  const updateParams = useCallback((patch: Partial<SearchParams>) => {
    if ("returnDate" in patch) setReturnInferred(false);
    setParams((p) => normalizeParams({ ...p, ...patch }));
  }, []);

  const sorted = useMemo(() => {
    if (!result) return [];
    const pool = dateFilter ? result.offers.filter((o) => o.departureDate === dateFilter) : result.offers;
    return sortOffers(pool, sort);
  }, [result, sort, dateFilter]);

  const datesCount = datesToSearch(params);
  const clash = datesCount === 0 ? whyNoDates(params) : null;
  const isSample = status?.isSample ?? result?.isSample ?? true;

  /** Run the scan with the given params and record a tracking snapshot. */
  const runSearch = useCallback(async (p: SearchParams = paramsRef.current): Promise<ScanResult | null> => {
    setLoading(true);
    setError(null);
    setDateFilter(null);
    setSelectedId(null);
    try {
      const res = await fetch(apiUrl("search"), { method: "POST", headers: apiHeaders(keysRef.current), body: JSON.stringify(p) });
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
        key: JSON.stringify([p.origin, p.destination, p.windowStart, p.windowEnd, p.tripType, p.returnDate ?? p.stayNights, p.stopover ?? null, p.route ?? null, p.adults, p.children, p.infants, p.cabin, p.maxStops, p.stepDays]),
        cheapest: cheapest ? { total: cheapest.price.total, currency: cheapest.price.currency, date: cheapest.departureDate, carrier: cheapest.validatingCarrierName } : null,
        best: best ? { total: best.price.total, currency: best.price.currency, date: best.departureDate, carrier: best.validatingCarrierName } : null,
      };
      setHistory((h) => {
        const prev = [...h].reverse().find((s) => s.key === snap.key && s.cheapest && s.isSample === snap.isSample);
        if (prev?.cheapest && snap.cheapest && snap.cheapest.total < prev.cheapest.total) {
          setPriceAlert(`Good news: the cheapest fare dropped to ${money(snap.cheapest.total, snap.cheapest.currency)}, down from ${money(prev.cheapest.total, prev.cheapest.currency)}.`);
        } else setPriceAlert(null);
        const next = [...h, snap].slice(-200);
        save(HISTORY_KEY, next);
        return next;
      });
      return json;
    } catch (e) {
      setError(e instanceof Error ? `The search didn’t work: ${e.message}` : "The search didn’t work.");
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  const speakRef = useRef<((t: string) => Promise<void>) | null>(null);

  // Tracking loop: re-run while the tab is open.
  useEffect(() => {
    if (!tracking.enabled) { setNextRunAt(null); return; }
    const ms = tracking.intervalHours * 3_600_000;
    setNextRunAt(Date.now() + ms);
    const id = setInterval(() => {
      runSearch().then((r) => {
        setNextRunAt(Date.now() + ms);
        const cheapest = r ? sortOffers(r.offers, "cheapest")[0] : undefined;
        if (cheapest && prefsRef.current.speakReplies) speakRef.current?.(`Tracking update: cheapest fare is ${spokenMoney(cheapest.price.total, cheapest.price.currency)} on ${spokenDate(cheapest.departureDate)}.`);
      });
    }, ms);
    return () => clearInterval(id);
  }, [tracking, runSearch]);

  /** Apply an intent to the app state and return what to say. */
  const applyIntent = useCallback(async (intent: Intent, spoken: string): Promise<string> => {
    const current = paramsRef.current;
    const searchWith = async (next: SearchParams) => {
      setParams(next);
      const r = await runSearch(next);
      return r ? spokenBrief(r) : "The search didn’t work. Say “try again” or check your connection.";
    };
    switch (intent.type) {
      case "search":
        return searchWith(current);
      case "set_dates": {
        setReturnInferred(!!intent.returnInferred);
        return searchWith(normalizeParams({
          ...current,
          windowStart: intent.windowStart ?? current.windowStart,
          windowEnd: intent.windowEnd ?? current.windowEnd,
          returnDate: intent.returnDate ?? (intent.windowStart ? undefined : current.returnDate),
          tripType: intent.returnDate ? "return" : current.tripType,
        }));
      }
      case "set_step":
        return searchWith(normalizeParams({ ...current, stepDays: intent.stepDays }));
      case "set_route":
        setReturnInferred(false);
        return searchWith(withRoute(current, intent.legs, intent));
      case "set_stopover":
        if (intent.returnDate) setReturnInferred(false);
        return searchWith(normalizeParams({
          ...current,
          route: undefined,
          tripType: current.tripType === "multicity" ? "return" : current.tripType,
          stopover: intent.airport ? { airport: intent.airport, nights: intent.nights ?? current.stopover?.nights ?? 3, leg: intent.leg ?? "outbound" } : undefined,
          ...(intent.windowStart ? { windowStart: intent.windowStart, windowEnd: intent.windowEnd ?? intent.windowStart } : {}),
          ...(intent.returnDate ? { returnDate: intent.returnDate, tripType: "return" as const } : {}),
        }));
      case "set_passengers":
        return searchWith(normalizeParams({ ...current, adults: intent.adults ?? current.adults, children: intent.children ?? current.children, infants: intent.infants ?? current.infants }));
      case "set_trip":
        return searchWith(normalizeParams({ ...current, tripType: intent.tripType ?? current.tripType, stayNights: intent.stayNights ?? current.stayNights, ...(intent.stayNights ? { returnDate: undefined } : {}) }));
      case "set_cabin":
        return searchWith(normalizeParams({ ...current, cabin: intent.cabin }));
      case "set_sort": {
        setSort(intent.sort);
        setDateFilter(null);
        const r = resultRef.current;
        return r ? spokenScanSummary(r, sortOffers(r.offers, intent.sort), intent.sort, 3) : "There are no results yet. Tell me when you’d like to fly.";
      }
      case "read_results": {
        const mode = intent.sort ?? sortRef.current;
        if (intent.sort) setSort(intent.sort);
        const r = resultRef.current;
        return r ? spokenScanSummary(r, sortOffers(r.offers, mode), mode, intent.count ?? 3) : "There are no results yet. Tell me when you’d like to fly.";
      }
      case "select_offer": {
        const r = resultRef.current;
        const list = r ? sortOffers(r.offers, sortRef.current) : [];
        const o = list[intent.index - 1];
        if (!o) return `There is no option ${intent.index}.`;
        setDateFilter(null);
        setSelectedId(o.id);
        setTimeout(() => document.getElementById(`offer-${intent.index}`)?.scrollIntoView({ behavior: "smooth", block: "center" }), 60);
        return spokenOfferDetail(o, intent.index);
      }
      case "track":
        setTracking((t) => ({ enabled: intent.enabled, intervalHours: intent.intervalHours ?? t.intervalHours }));
        if (intent.enabled && !resultRef.current) await runSearch(current);
        return intent.enabled
          ? `I’ll re-check every ${intent.intervalHours ?? tracking.intervalHours} hours while this page is open, and tell you when the cheapest fare drops.`
          : "Stopped tracking prices.";
      case "help":
        return HELP_TEXT;
      case "stop":
        return "";
      default:
        return spoken;
    }
  }, [runSearch, tracking.intervalHours]);

  const handleUtterance = useCallback(async (text: string) => {
    if (/^(try again|retry)$/i.test(text.trim()) && lastUtterance) text = lastUtterance;
    setHeard(text);
    setLastUtterance(text);
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
        const res = await fetch(apiUrl("interpret"), {
          method: "POST",
          headers: apiHeaders(keysRef.current),
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
      if (say && prefsRef.current.speakReplies) await speakRef.current?.(say);
    } finally {
      setBusy(false);
    }
  }, [applyIntent, lastUtterance]);

  const speech = useSpeech(handleUtterance, { continuous: prefs.handsFree });
  speakRef.current = speech.speak;

  useEffect(() => {
    if (priceAlert && prefsRef.current.speakReplies) speech.speak(priceAlert);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [priceAlert]);

  const suggestions = result
    ? ["Read the top three", "Tell me about option 1", params.stopover ? "No stopover" : "Stop over in Dubai for 3 nights", "Check every 2 days"]
    : ["Mid to late November, back early January", "Melbourne to Joburg 2 Dec, Cape Town 3 Dec, Harare 7 Dec, home 5 Jan", "Stop over in Dubai for 3 nights", "Help"];

  const notes = (result?.warnings ?? []).filter((w) => !w.startsWith("Showing sample"));
  const openEditor = (field: EditField) => { setEditFocus(field); setEditorOpen(true); };

  return (
    <main className="app">
      <header className="header">
        <div className="brand">
          <PlaneIcon />
          <h1>Harare <span className="long">Flight Agent</span><span className="short">Flights</span></h1>
          <span className="route-code">{params.origin} → {params.destination}</span>
        </div>
        <div className="header-right">
          <button className={`pill ${isSample ? "sample" : "live"}`} onClick={() => setSettingsOpen(true)} title="Fare source">
            {isSample ? "Sample fares" : "Live · Google Flights"}
          </button>
          {tracking.enabled && <span className="pill track">Tracking every {tracking.intervalHours}h</span>}
          <button className="icon-btn" onClick={() => setSettingsOpen(true)} aria-label="Settings"><SettingsIcon /></button>
        </div>
      </header>

      <Conversation
        speech={speech}
        heard={heard}
        reply={reply}
        busy={busy || loading}
        busyText={loading ? `Checking ${datesCount} date${datesCount === 1 ? "" : "s"}…` : "One moment…"}
        error={error}
        onRetry={() => (lastUtterance ? handleUtterance(lastUtterance) : runSearch())}
        suggestions={suggestions}
        onCommand={handleUtterance}
        handsFree={prefs.handsFree}
        understood={(result || heard) ? <UnderstoodChips params={params} datesCount={datesCount} returnInferred={returnInferred} onEdit={openEditor} /> : null}
      />

      {priceAlert && <div className="alert-good" role="status">{priceAlert}</div>}
      {clash && (
        <div className="inline-error" role="alert">
          <span>{clash}</span>
          <button className="chip" onClick={() => openEditor(params.stopover ? "stopover" : "when")}>Fix it</button>
        </div>
      )}

      <TripSettings
        params={params}
        onChange={updateParams}
        onSearch={async () => { const r = await runSearch(); if (r) setReply(spokenBrief(r)); }}
        loading={loading}
        datesToScan={datesCount}
        open={editorOpen}
        onOpenChange={(o) => { setEditorOpen(o); if (!o) setEditFocus(null); }}
        focus={editFocus}
        showLine={!(result || heard)}
      />

      {isSample && (
        <div className="banner">
          <span>These are sample fares, modelled on real routes. Connect Google Flights for real prices.</span>
          <button className="btn small" onClick={() => setSettingsOpen(true)}>Connect live fares</button>
        </div>
      )}

      {loading && !result ? (
        <ResultsSkeleton />
      ) : result ? (
        <>
          <SummaryStrip
            offers={result.offers}
            sort={sort}
            isSample={result.isSample}
            onPick={(m) => { setSort(m); setDateFilter(null); document.getElementById("results")?.scrollIntoView({ behavior: "smooth", block: "start" }); }}
          />
          <div className="only-phone">
            <PriceCalendar byDate={result.byDate} currency={params.currency} active={dateFilter} onPick={setDateFilter} stepDays={result.params.stepDays} />
          </div>
        </>
      ) : null}

      <div className="results-layout">
        <Results
          offers={sorted}
          sort={sort}
          onSort={setSort}
          selectedId={selectedId}
          onSelect={setSelectedId}
          dateFilter={dateFilter}
          onClearDate={() => setDateFilter(null)}
          isSample={result?.isSample ?? isSample}
          hasSearched={!!result}
        />
        <aside className="rail">
          {result && (
            <div className="only-desktop">
              <PriceCalendar byDate={result.byDate} currency={params.currency} active={dateFilter} onPick={setDateFilter} stepDays={result.params.stepDays} />
            </div>
          )}
          <Tracker
            enabled={tracking.enabled}
            intervalHours={tracking.intervalHours}
            nextRunAt={nextRunAt}
            history={history}
            onToggle={(on) => setTracking((t) => ({ ...t, enabled: on }))}
            onInterval={(h) => setTracking((t) => ({ ...t, intervalHours: h }))}
            onClear={() => { setHistory([]); save(HISTORY_KEY, []); }}
          />
          <ScanNotes notes={notes} />
        </aside>
      </div>

      <footer className="foot">
        Prices are for the whole family in {params.currency}. “Best overall” balances price, travel time, connections and family-friendly timings.
        {result && !result.isSample ? " Live fares come from Google Flights; for return and multi-city trips the price covers every flight, and the later flights are picked when you book." : ""}
      </footer>

      <VoiceBar speech={speech} busy={busy || loading} onCommand={handleUtterance} />

      <SettingsDrawer
        open={settingsOpen}
        onClose={() => setSettingsOpen(false)}
        keys={keys}
        onSaveKeys={(k) => { setKeys(k); saveKeys(k); setResult(null); }}
        isSample={isSample}
        claude={status?.claude ?? false}
        theme={prefs.theme}
        onTheme={(theme) => setPrefs((p) => ({ ...p, theme }))}
        handsFree={prefs.handsFree}
        onHandsFree={(handsFree) => setPrefs((p) => ({ ...p, handsFree }))}
        speakReplies={prefs.speakReplies}
        onSpeakReplies={(speakReplies) => setPrefs((p) => ({ ...p, speakReplies }))}
      />
    </main>
  );
}
