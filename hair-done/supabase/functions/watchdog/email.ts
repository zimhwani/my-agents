// The watchdog's email: subject, plain text and HTML. No I/O, so the test can render it.
import type { Finding, Report } from "./assess.ts";

const TZ = "Australia/Melbourne";
const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

export function subject(mode: string, r: Report) {
  const red = r.findings.filter((f) => f.level === "red").length;
  const amber = r.findings.length - red;
  if (mode === "alert") return `Hair Done alert: ${r.findings[0]?.title ?? "something's wrong"}${red > 1 ? ` (+${red - 1} more)` : ""}`;
  if (!r.findings.length) return "Hair Done: all clear";
  return `Hair Done: ${red ? `${red} need${red === 1 ? "s" : ""} you today` : "nothing urgent"}${amber ? `, ${amber} to watch` : ""}`;
}

function findingText(f: Finding) {
  return [`- [${f.area}] ${f.title}`, f.detail && `  ${f.detail}`, f.quote && `  They wrote: "${f.quote}"`, f.fix && `  Fix: ${f.fix}`]
    .filter(Boolean).join("\n");
}
function findingHtml(f: Finding) {
  const color = f.level === "red" ? "#B3261E" : "#8A5A00";
  return `<tr><td style="padding:10px 0;border-top:1px solid #E7E1D8">
    <div style="font:600 12px -apple-system,Helvetica,sans-serif;color:${color};letter-spacing:.06em;text-transform:uppercase">${esc(f.area)}</div>
    <div style="font:600 16px -apple-system,Helvetica,sans-serif;color:#1C1A17;margin-top:2px">${esc(f.title)}</div>
    ${f.detail ? `<div style="font:14px/1.45 -apple-system,Helvetica,sans-serif;color:#4A453E;margin-top:4px">${esc(f.detail)}</div>` : ""}
    ${f.quote ? `<div style="font:italic 14px/1.45 Georgia,serif;color:#4A453E;margin-top:6px;padding-left:10px;border-left:2px solid #E7E1D8">${esc(f.quote)}</div>` : ""}
    ${f.fix ? `<div style="font:13px/1.45 Menlo,monospace;color:#1C1A17;margin-top:6px;background:#F4EFE7;padding:6px 8px;border-radius:4px">${esc(f.fix)}</div>` : ""}
  </td></tr>`;
}

export function render(mode: string, r: Report, brief: string | null) {
  const when = new Date().toLocaleString("en-AU", { timeZone: TZ, weekday: "long", day: "numeric", month: "long", hour: "numeric", minute: "2-digit" });
  const red = r.findings.filter((f) => f.level === "red");
  const amber = r.findings.filter((f) => f.level === "amber");
  const sections: [string, Finding[]][] = mode === "alert" ? [["New since the last email", red]] : [["Needs you today", red], ["Keep an eye on", amber]];
  const footer = "Read-only: the watchdog can't change bookings, money or accounts. Supabase migration 0019, function watchdog.";

  const text = [
    `${mode === "alert" ? "Hair Done alert" : "Hair Done this morning"}, ${when}`,
    brief && `\n${brief}`,
    ...sections.filter(([, l]) => l.length).map(([h, l]) => `\n${h.toUpperCase()}\n${l.map(findingText).join("\n")}`),
    mode === "digest" && !r.findings.length && "\nNothing needs you. Every check came back clean.",
    mode === "digest" && `\nTHE NUMBERS\n${r.numbers.map((n) => `- ${n}`).join("\n")}`,
    r.blind.length && `\nWHAT I COULDN'T CHECK\n${r.blind.map((b) => `- ${b}`).join("\n")}`,
    `\n${footer}`,
  ].filter(Boolean).join("\n");

  const block = (h: string, inner: string) =>
    `<h2 style="font:600 13px -apple-system,Helvetica,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#6B655C;margin:28px 0 4px">${esc(h)}</h2>${inner}`;
  const html = `<!doctype html><html><body style="margin:0;background:#FBF8F3"><div style="max-width:600px;margin:0 auto;padding:28px 20px">
  <div style="font:italic 26px Georgia,serif;color:#1C1A17">${mode === "alert" ? "Hair Done alert" : "Hair Done this morning"}</div>
  <div style="font:13px -apple-system,Helvetica,sans-serif;color:#6B655C;margin-top:4px">${esc(when)}</div>
  ${brief ? `<p style="font:16px/1.5 -apple-system,Helvetica,sans-serif;color:#1C1A17;margin:20px 0 0">${esc(brief)}</p>` : ""}
  ${sections.filter(([, l]) => l.length).map(([h, l]) => block(`${h} · ${l.length}`, `<table style="width:100%;border-collapse:collapse">${l.map(findingHtml).join("")}</table>`)).join("")}
  ${mode === "digest" && !r.findings.length ? `<p style="font:16px/1.5 -apple-system,Helvetica,sans-serif;color:#1C1A17;margin:20px 0 0">Nothing needs you. Every check came back clean.</p>` : ""}
  ${mode === "digest" ? block("The numbers", `<ul style="font:14px/1.6 -apple-system,Helvetica,sans-serif;color:#4A453E;padding-left:18px;margin:6px 0">${r.numbers.map((n) => `<li>${esc(n)}</li>`).join("")}</ul>`) : ""}
  ${r.blind.length ? block("What I couldn't check", `<ul style="font:14px/1.6 -apple-system,Helvetica,sans-serif;color:#4A453E;padding-left:18px;margin:6px 0">${r.blind.map((b) => `<li>${esc(b)}</li>`).join("")}</ul>`) : ""}
  <p style="font:12px/1.5 -apple-system,Helvetica,sans-serif;color:#8C867D;margin-top:32px">${esc(footer)}</p>
  </div></body></html>`;
  return { text, html };
}

