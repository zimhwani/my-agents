"use client";
import { useState } from "react";
import type { StoredKeys } from "@/lib/client";

/** The traveller's own API keys, kept in this browser only and sent with each request. */
export function KeysPanel({ keys, onSave, status }: { keys: StoredKeys; onSave: (k: StoredKeys) => void; status: { isSample: boolean; claude: boolean } | null }) {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState<StoredKeys>(keys);
  return (
    <section className="panel">
      <div className="track-row">
        <h2 style={{ margin: 0 }}>Live fares</h2>
        <span className="summary-line">
          {status?.isSample ? "Showing sample fares. Add a free SerpApi key to see real Google Flights prices." : "Live Google Flights prices via SerpApi."}
          {status?.claude ? " Voice understanding by Claude." : ""}
        </span>
        <button className="btn small" onClick={() => { setDraft(keys); setOpen(!open); }}>{open ? "Close" : keys.serpApiKey ? "Change keys" : "Add keys"}</button>
      </div>
      {open && (
        <form
          className="form"
          style={{ marginTop: 12 }}
          onSubmit={(e) => {
            e.preventDefault();
            onSave(draft);
            setOpen(false);
          }}
        >
          <label className="field" style={{ gridColumn: "span 2" }}>
            SerpApi key (free at serpapi.com → your account → API key)
            <input id="serpapi-key" type="password" autoComplete="off" value={draft.serpApiKey} onChange={(e) => setDraft({ ...draft, serpApiKey: e.target.value })} placeholder="64-character key" />
          </label>
          <label className="field" style={{ gridColumn: "span 2" }}>
            Anthropic key (optional, for Claude-powered voice)
            <input id="anthropic-key" type="password" autoComplete="off" value={draft.anthropicKey} onChange={(e) => setDraft({ ...draft, anthropicKey: e.target.value })} placeholder="sk-ant-…" />
          </label>
          <div className="form-actions">
            <button className="btn primary" type="submit">Save keys</button>
            <button className="btn ghost" type="button" onClick={() => { setDraft({ serpApiKey: "", anthropicKey: "" }); onSave({ serpApiKey: "", anthropicKey: "" }); setOpen(false); }}>Remove</button>
            <span className="summary-line">Keys stay in this browser and are sent only with your own searches. Each scanned date is one SerpApi search.</span>
          </div>
        </form>
      )}
    </section>
  );
}
