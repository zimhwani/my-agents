"use client";
import { Component, type ReactNode } from "react";

/** If anything throws while drawing, show a way out instead of a blank page. */
export class ErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidCatch(error: Error) {
    console.error("[flight-agent] render failed", error);
  }

  private reset = () => {
    try {
      for (const k of Object.keys(localStorage)) if (k.startsWith("flight-agent:") && k !== "flight-agent:keys") localStorage.removeItem(k);
    } catch { /* storage blocked */ }
    location.reload();
  };

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <main className="app">
        <section className="card" role="alert" style={{ display: "grid", gap: 12, maxWidth: 560, margin: "48px auto" }}>
          <h1 style={{ fontSize: "1.25rem" }}>Something went wrong loading your trip</h1>
          <p className="muted" style={{ margin: 0 }}>
            Saved searches in this browser may be out of date. Resetting them keeps your API keys and starts fresh.
          </p>
          <p className="muted small" style={{ margin: 0 }}>Details: {this.state.error.message}</p>
          <div className="editor-foot">
            <button className="btn primary" onClick={this.reset}>Reset saved searches</button>
            <button className="btn" onClick={() => location.reload()}>Try again</button>
          </div>
        </section>
      </main>
    );
  }
}
