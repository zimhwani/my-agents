"""Self-contained HTML dashboard: R multiple per trade, cumulative R curve,
headline stats and a trade table. No external assets; open the file directly.
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

from .clock import now_et
from .journal import compute_stats
from .models import TradeRecord


def trade_rows(trades: list[TradeRecord]) -> list[dict]:
    rows = []
    for i, t in enumerate(sorted(trades, key=lambda t: t.entry_time), start=1):
        rows.append({
            "n": i, "id": t.id, "symbol": t.symbol, "side": t.side, "qty": t.qty_initial,
            "date": t.entry_time.strftime("%Y-%m-%d"), "entry_time": t.entry_time.strftime("%H:%M"),
            "exit_time": t.last_exit_time.strftime("%H:%M") if t.last_exit_time else "",
            "entry": round(t.entry_price, 2), "stop": round(t.stop_initial, 2),
            "exit": round(t.exit_price_avg, 2) if t.exit_price_avg else None,
            "r": round(t.r_multiple, 2), "pnl": round(t.realized_pnl, 2),
            "risk": round(t.initial_risk_usd, 2),
            "exits": ", ".join(f"{f.reason} {f.qty}@{f.price:.2f}" for f in t.exits),
            "reason": t.reason,
        })
    return rows


def render(trades: list[TradeRecord], title: str = "Trading Bot", generated: datetime | None = None) -> str:
    closed = [t for t in trades if t.status == "CLOSED"]
    rows = trade_rows(closed)
    stats = compute_stats(closed).as_dict()
    if stats["profit_factor"] == float("inf"):
        stats["profit_factor"] = None
    generated = generated or now_et()
    data = json.dumps({"rows": rows, "stats": stats}).replace("</", "<\\/")
    return TEMPLATE.replace("__TITLE__", title).replace("__DATA__", data) \
        .replace("__GENERATED__", generated.strftime("%Y-%m-%d %H:%M ET"))


def write_dashboard(trades: list[TradeRecord], out: str | Path, title: str = "Trading Bot") -> Path:
    p = Path(out)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(render(trades, title), encoding="utf-8")
    return p


TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>R Multiples Dashboard</title>
<style>
:root{
  color-scheme:light;
  --surface:#fcfcfb; --surface-2:#f3f2ef; --border:#e4e2dc;
  --text:#0b0b0b; --text-2:#52514e; --text-3:#84827c;
  --pos:#2a78d6; --neg:#e34948; --line:#2a78d6; --grid:#e8e6e0; --zero:#b4b2ab;
  --good:#0ca30c; --critical:#d03b3b;
}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){
    color-scheme:dark;
    --surface:#1a1a19; --surface-2:#232322; --border:#333331;
    --text:#ffffff; --text-2:#c3c2b7; --text-3:#8f8e86;
    --pos:#3987e5; --neg:#e66767; --line:#3987e5; --grid:#2d2d2b; --zero:#5a5955;
  }
}
:root[data-theme="dark"]{
  color-scheme:dark;
  --surface:#1a1a19; --surface-2:#232322; --border:#333331;
  --text:#ffffff; --text-2:#c3c2b7; --text-3:#8f8e86;
  --pos:#3987e5; --neg:#e66767; --line:#3987e5; --grid:#2d2d2b; --zero:#5a5955;
}
*{box-sizing:border-box}
body{margin:0;background:var(--surface);color:var(--text);font:14px/1.45 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
main{max-width:1100px;margin:0 auto;padding:24px 16px 48px}
h1{font-size:20px;margin:0 0 4px}
.sub{color:var(--text-2);margin:0 0 20px}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin-bottom:24px}
.tile{background:var(--surface-2);border:1px solid var(--border);border-radius:10px;padding:12px 14px}
.tile .k{font-size:12px;color:var(--text-2);text-transform:uppercase;letter-spacing:.04em}
.tile .v{font-size:24px;font-weight:600;margin-top:2px;font-variant-numeric:tabular-nums}
.tile .s{font-size:12px;color:var(--text-3)}
.filters{display:flex;flex-wrap:wrap;gap:12px;align-items:center;margin-bottom:16px}
.filters label{color:var(--text-2);font-size:13px}
select{background:var(--surface-2);color:var(--text);border:1px solid var(--border);border-radius:6px;padding:6px 8px;font:inherit}
.card{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:16px;margin-bottom:20px}
.card h2{font-size:15px;margin:0 0 2px}
.card .d{font-size:12px;color:var(--text-2);margin:0 0 12px}
svg{width:100%;height:auto;display:block;overflow:visible}
.grid line{stroke:var(--grid);stroke-width:1}
.zero{stroke:var(--zero);stroke-width:1}
.axis text{fill:var(--text-3);font-size:11px}
.bar{cursor:pointer}
.bar.pos{fill:var(--pos)} .bar.neg{fill:var(--neg)}
.bar.dim{opacity:.35}
.hit{fill:transparent}
.line{fill:none;stroke:var(--line);stroke-width:2;stroke-linejoin:round;stroke-linecap:round}
.dot{fill:var(--line);stroke:var(--surface);stroke-width:2}
.cross{stroke:var(--text-3);stroke-width:1;stroke-dasharray:3 3}
.tip{position:fixed;pointer-events:none;background:var(--surface-2);color:var(--text);border:1px solid var(--border);border-radius:8px;padding:8px 10px;font-size:12px;box-shadow:0 4px 16px rgba(0,0,0,.15);display:none;z-index:10;max-width:280px}
.tip b{font-variant-numeric:tabular-nums}
table{width:100%;border-collapse:collapse;font-size:13px;font-variant-numeric:tabular-nums}
th,td{padding:7px 8px;border-bottom:1px solid var(--border);text-align:right;white-space:nowrap}
th:first-child,td:first-child,th.l,td.l{text-align:left}
th{color:var(--text-2);font-weight:500;font-size:12px;position:sticky;top:0;background:var(--surface)}
.tbl{overflow:auto;max-height:420px}
.pos-t{color:var(--pos)} .neg-t{color:var(--neg)}
.badge{display:inline-block;padding:1px 6px;border-radius:4px;font-size:11px;border:1px solid var(--border);color:var(--text-2)}
.empty{color:var(--text-3);padding:24px;text-align:center}
.legend{display:flex;gap:16px;font-size:12px;color:var(--text-2);margin-bottom:8px}
.sw{display:inline-block;width:10px;height:10px;border-radius:2px;vertical-align:-1px;margin-right:5px}
</style>
</head>
<body>
<main>
<h1>__TITLE__ · R multiples</h1>
<p class="sub">Generated __GENERATED__ · 1R = the dollars risked from entry to the initial stop. A trade stopped at its original stop is −1R.</p>

<div class="filters">
  <label>Symbol <select id="fSym"><option value="">All</option></select></label>
  <label>Range <select id="fN">
    <option value="0">All trades</option><option value="20">Last 20</option><option value="50">Last 50</option><option value="100">Last 100</option>
  </select></label>
  <label>Side <select id="fSide"><option value="">Both</option><option>LONG</option><option>SHORT</option></select></label>
</div>

<div class="tiles" id="tiles"></div>

<div class="card">
  <h2>R multiple per trade</h2>
  <p class="d">Each bar is one closed trade, in order. Hover for detail.</p>
  <div class="legend"><span><i class="sw" style="background:var(--pos)"></i>Winner (R &gt; 0)</span><span><i class="sw" style="background:var(--neg)"></i>Loser (R &lt; 0)</span></div>
  <div id="bars"></div>
</div>

<div class="card">
  <h2>Cumulative R</h2>
  <p class="d">Equity curve measured in R, so it is independent of account size and position sizing changes.</p>
  <div id="curve"></div>
</div>

<div class="card">
  <h2>Trades</h2>
  <p class="d">Table view of the same data (newest first).</p>
  <div class="tbl"><table id="tbl"></table></div>
</div>
</main>
<div class="tip" id="tip"></div>
<script>
const DATA = __DATA__;
const $ = s => document.querySelector(s);
const tip = $('#tip');
const fmtR = r => (r>0?'+':'') + r.toFixed(2) + 'R';
const fmt$ = v => (v<0?'−$':'$') + Math.abs(v).toLocaleString(undefined,{maximumFractionDigits:0});

// filters
const syms = [...new Set(DATA.rows.map(r=>r.symbol))].sort();
for (const s of syms){ const o=document.createElement('option'); o.textContent=s; $('#fSym').append(o); }
for (const id of ['#fSym','#fN','#fSide']) $(id).addEventListener('change', render);

function filtered(){
  let rows = DATA.rows;
  const s=$('#fSym').value, side=$('#fSide').value, n=+$('#fN').value;
  if (s) rows = rows.filter(r=>r.symbol===s);
  if (side) rows = rows.filter(r=>r.side===side);
  if (n) rows = rows.slice(-n);
  return rows;
}
function stats(rows){
  const rs = rows.map(r=>r.r);
  const wins = rs.filter(r=>r>0.1), losses = rs.filter(r=>r<-0.1);
  const dec = wins.length+losses.length;
  const wr = dec? wins.length/dec : 0;
  const avgW = wins.length? wins.reduce((a,b)=>a+b,0)/wins.length : 0;
  const avgL = losses.length? losses.reduce((a,b)=>a+b,0)/losses.length : 0;
  const gw = rs.filter(r=>r>0).reduce((a,b)=>a+b,0), gl = -rs.filter(r=>r<0).reduce((a,b)=>a+b,0);
  let cum=0, peak=0, dd=0; for (const r of rs){ cum+=r; peak=Math.max(peak,cum); dd=Math.min(dd,cum-peak); }
  return { n: rs.length, wr, total: rs.reduce((a,b)=>a+b,0), avg: rs.length? rs.reduce((a,b)=>a+b,0)/rs.length:0,
    exp: dec? wr*avgW+(1-wr)*avgL : 0, pf: gl>0? gw/gl : (gw>0? Infinity:0), dd, avgW, avgL,
    pnl: rows.reduce((a,r)=>a+r.pnl,0) };
}
function tiles(st){
  const t = [
    ['Trades', st.n, 'closed round trips'],
    ['Win rate', (st.wr*100).toFixed(0)+'%', `avg win ${fmtR(st.avgW)} · avg loss ${fmtR(st.avgL)}`],
    ['Total R', fmtR(st.total), fmt$(st.pnl)],
    ['Expectancy', fmtR(st.exp), 'per trade: win% × avg win + loss% × avg loss'],
    ['Profit factor', st.pf===Infinity? '∞' : st.pf.toFixed(2), 'gross R won ÷ gross R lost'],
    ['Max drawdown', fmtR(st.dd), 'peak-to-trough, in R'],
  ];
  $('#tiles').innerHTML = t.map(([k,v,s])=>`<div class="tile"><div class="k">${k}</div><div class="v">${v}</div><div class="s">${s}</div></div>`).join('');
}
function showTip(e, html){ tip.innerHTML=html; tip.style.display='block'; moveTip(e); }
function moveTip(e){ const x=e.clientX+14, y=e.clientY+14; tip.style.left=Math.min(x, innerWidth-tip.offsetWidth-8)+'px'; tip.style.top=Math.min(y, innerHeight-tip.offsetHeight-8)+'px'; }
function hideTip(){ tip.style.display='none'; }
function tipHtml(r){ return `<b>#${r.n} ${r.symbol}</b> ${r.side} · ${r.date} ${r.entry_time}→${r.exit_time}<br>
  <b class="${r.r>=0?'pos-t':'neg-t'}">${fmtR(r.r)}</b> · ${fmt$(r.pnl)} · risk ${fmt$(r.risk)}<br>
  entry ${r.entry} · stop ${r.stop} · exit ${r.exit ?? '—'}<br><span style="color:var(--text-2)">${r.exits}</span>`; }

function barsChart(rows){
  const W=1000, H=280, m={t:12,r:12,b:28,l:44};
  const iw=W-m.l-m.r, ih=H-m.t-m.b;
  if (!rows.length){ $('#bars').innerHTML='<div class="empty">No closed trades yet.</div>'; return; }
  const rs=rows.map(r=>r.r); const lo=Math.min(0,...rs), hi=Math.max(0,...rs);
  const pad=(hi-lo)*0.08||1; const y0=lo-pad, y1=hi+pad;
  const y=v=>m.t+ih-(v-y0)/(y1-y0)*ih;
  const bw=iw/rows.length, gap=Math.min(2, bw*0.25), w=Math.max(1,bw-gap);
  const ticks=niceTicks(y0,y1,5);
  let s=`<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="R multiple per trade">`;
  s+='<g class="grid">'+ticks.map(t=>`<line x1="${m.l}" x2="${W-m.r}" y1="${y(t)}" y2="${y(t)}"/>`).join('')+'</g>';
  s+='<g class="axis">'+ticks.map(t=>`<text x="${m.l-6}" y="${y(t)+4}" text-anchor="end">${t>0?'+':''}${t}R</text>`).join('')+'</g>';
  s+=`<line class="zero" x1="${m.l}" x2="${W-m.r}" y1="${y(0)}" y2="${y(0)}"/>`;
  rows.forEach((r,i)=>{
    const x=m.l+i*bw+gap/2, top=Math.min(y(r.r),y(0)), h=Math.max(1,Math.abs(y(r.r)-y(0)));
    const rad=Math.min(4,w/2,h);
    const d = r.r>=0
      ? `M${x},${y(0)} v${-(h-rad)} q0,${-rad} ${rad},${-rad} h${w-2*rad} q${rad},0 ${rad},${rad} v${h-rad} z`
      : `M${x},${y(0)} v${h-rad} q0,${rad} ${rad},${rad} h${w-2*rad} q${rad},0 ${rad},${-rad} v${-(h-rad)} z`;
    s+=`<path class="bar ${r.r>=0?'pos':'neg'}" data-i="${i}" d="${d}"/>`;
    s+=`<rect class="hit" data-i="${i}" x="${m.l+i*bw}" y="${m.t}" width="${bw}" height="${ih}"/>`;
  });
  const step=Math.max(1,Math.ceil(rows.length/12));
  s+='<g class="axis">'+rows.map((r,i)=> i%step===0? `<text x="${m.l+i*bw+bw/2}" y="${H-8}" text-anchor="middle">#${r.n}</text>`:'').join('')+'</g>';
  s+='</svg>';
  const el=$('#bars'); el.innerHTML=s;
  el.querySelectorAll('.hit').forEach(h=>{
    const i=+h.dataset.i;
    h.addEventListener('mouseenter',e=>{ el.querySelectorAll('.bar').forEach(b=>b.classList.toggle('dim',+b.dataset.i!==i)); showTip(e,tipHtml(rows[i])); });
    h.addEventListener('mousemove',moveTip);
    h.addEventListener('mouseleave',()=>{ el.querySelectorAll('.bar').forEach(b=>b.classList.remove('dim')); hideTip(); });
  });
}
function curveChart(rows){
  const W=1000, H=260, m={t:12,r:12,b:28,l:44};
  const iw=W-m.l-m.r, ih=H-m.t-m.b;
  if (!rows.length){ $('#curve').innerHTML='<div class="empty">No closed trades yet.</div>'; return; }
  let c=0; const pts=[{i:0,v:0,r:null}]; rows.forEach((r,i)=>{ c+=r.r; pts.push({i:i+1,v:c,r}); });
  const vs=pts.map(p=>p.v); const lo=Math.min(0,...vs), hi=Math.max(0,...vs); const pad=(hi-lo)*0.08||1; const y0=lo-pad,y1=hi+pad;
  const x=i=>m.l+i/(rows.length)*iw, y=v=>m.t+ih-(v-y0)/(y1-y0)*ih;
  const ticks=niceTicks(y0,y1,5);
  let s=`<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Cumulative R">`;
  s+='<g class="grid">'+ticks.map(t=>`<line x1="${m.l}" x2="${W-m.r}" y1="${y(t)}" y2="${y(t)}"/>`).join('')+'</g>';
  s+='<g class="axis">'+ticks.map(t=>`<text x="${m.l-6}" y="${y(t)+4}" text-anchor="end">${t>0?'+':''}${t}R</text>`).join('')+'</g>';
  s+=`<line class="zero" x1="${m.l}" x2="${W-m.r}" y1="${y(0)}" y2="${y(0)}"/>`;
  s+=`<path class="line" d="${pts.map((p,k)=>(k?'L':'M')+x(p.i).toFixed(1)+','+y(p.v).toFixed(1)).join(' ')}"/>`;
  s+=`<line class="cross" id="cx" x1="0" x2="0" y1="${m.t}" y2="${m.t+ih}" style="display:none"/>`;
  s+=`<circle class="dot" id="cd" r="4" style="display:none"/>`;
  s+=`<rect class="hit" id="ch" x="${m.l}" y="${m.t}" width="${iw}" height="${ih}"/>`;
  const step=Math.max(1,Math.ceil(rows.length/12));
  s+='<g class="axis">'+pts.map(p=> p.i && (p.i-1)%step===0? `<text x="${x(p.i)}" y="${H-8}" text-anchor="middle">#${p.i}</text>`:'').join('')+'</g>';
  s+='</svg>';
  const el=$('#curve'); el.innerHTML=s;
  const svg=el.querySelector('svg'), ch=el.querySelector('#ch'), cx=el.querySelector('#cx'), cd=el.querySelector('#cd');
  ch.addEventListener('mousemove',e=>{
    const pt=svg.createSVGPoint(); pt.x=e.clientX; pt.y=e.clientY; const p=pt.matrixTransform(svg.getScreenCTM().inverse());
    const i=Math.max(0,Math.min(rows.length,Math.round((p.x-m.l)/iw*rows.length)));
    const q=pts[i]; cx.setAttribute('x1',x(q.i)); cx.setAttribute('x2',x(q.i)); cx.style.display='';
    cd.setAttribute('cx',x(q.i)); cd.setAttribute('cy',y(q.v)); cd.style.display='';
    showTip(e, q.r? `after trade #${q.r.n} (${q.r.symbol}): <b>${fmtR(q.v)}</b><br>this trade ${fmtR(q.r.r)}` : 'start: <b>0R</b>');
  });
  ch.addEventListener('mouseleave',()=>{ cx.style.display='none'; cd.style.display='none'; hideTip(); });
}
function table(rows){
  const h='<tr><th>#</th><th class="l">Symbol</th><th class="l">Date</th><th class="l">Side</th><th>Qty</th><th>Entry</th><th>Stop</th><th>Exit</th><th>R</th><th>P&amp;L</th><th class="l">Exits</th></tr>';
  const b=[...rows].reverse().map(r=>`<tr><td>${r.n}</td><td class="l"><b>${r.symbol}</b></td><td class="l">${r.date} ${r.entry_time}</td><td class="l"><span class="badge">${r.side}</span></td><td>${r.qty}</td><td>${r.entry.toFixed(2)}</td><td>${r.stop.toFixed(2)}</td><td>${r.exit==null?'—':r.exit.toFixed(2)}</td><td class="${r.r>=0?'pos-t':'neg-t'}"><b>${fmtR(r.r)}</b></td><td class="${r.pnl>=0?'pos-t':'neg-t'}">${fmt$(r.pnl)}</td><td class="l" style="color:var(--text-2)">${r.exits}</td></tr>`).join('');
  $('#tbl').innerHTML = h + (b || '<tr><td colspan="11" class="empty">No closed trades yet.</td></tr>');
}
function niceTicks(lo,hi,n){
  const span=hi-lo, raw=span/n, mag=Math.pow(10,Math.floor(Math.log10(raw))), norm=raw/mag;
  const step=(norm<1.5?1:norm<3?2:norm<7?5:10)*mag; const out=[];
  for (let v=Math.ceil(lo/step)*step; v<=hi; v+=step) out.push(+v.toFixed(6));
  return out;
}
function render(){ const rows=filtered(); tiles(stats(rows)); barsChart(rows); curveChart(rows); table(rows); }
render();
</script>
</body>
</html>
"""
