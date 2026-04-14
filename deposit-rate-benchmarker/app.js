// State
let product="td", selTerm="12m", charts={};
const C={bf:"#ed8936",b4:"#4299e1",ch:"#48bb78",mu:"#9f7aea",re:"#d69e2e",cu:"#e53e3e",ne:"#38a169",avg:"#718096",gr:"#e2e8f0"};
function tc(t){return{Big4:C.b4,"Big 4":C.b4,Challenger:C.ch,Mutual:C.mu,Regional:C.re,"Credit Union":C.cu,Neobank:C.ne}[t]||"#a0aec0"}
function bb(t){return{Big4:"bb-b4","Big 4":"bb-b4",Challenger:"bb-ch",Mutual:"bb-mu",Regional:"bb-re","Credit Union":"bb-cu",Neobank:"bb-ne"}[t]||"bb-ch"}

// Init
document.addEventListener("DOMContentLoaded",()=>{
  document.getElementById("productTabs").onclick=e=>{
    if(!e.target.classList.contains("tab"))return;
    document.querySelectorAll(".tab").forEach(t=>t.classList.remove("active"));
    e.target.classList.add("active");
    product=e.target.dataset.product;
    selTerm=getTerms()[product==="hl"?0:2]||getTerms()[0];
    renderAll();
  };
  renderAll();
});

function getD(){return DATA[product]}
function getTerms(){return getD().terms}
function getLabels(){return getD().termLabels}
function getBanks(){return getD().banks}
function getBF(){return getBanks().find(b=>b.hl)}

// Stats
function calcStats(banks,terms){
  const s={};
  terms.forEach(t=>{
    const rs=banks.map(b=>b.r[t]).filter(v=>v!=null);
    if(rs.length) s[t]={min:Math.min(...rs),max:Math.max(...rs),avg:+(rs.reduce((a,b)=>a+b,0)/rs.length).toFixed(2),cnt:rs.length};
  });
  return s;
}
function typeAvg(type,term){
  const rs=getBanks().filter(b=>b.t===type).map(b=>b.r[term]).filter(v=>v!=null);
  return rs.length?+(rs.reduce((a,b)=>a+b,0)/rs.length).toFixed(2):null;
}

// ===== RENDER ALL =====
function renderAll(){
  const isHL=product==="hl";
  document.getElementById("heatSection").style.display=product==="sa"?"none":"";
  document.getElementById("calcSection").style.display=product==="sa"?"none":"";
  renderControls();
  renderKPIs();
  renderBar();
  renderCurve();
  renderSpread();
  renderRadar();
  if(product!=="sa") renderHeat();
  if(product!=="sa") renderCalc();
  renderTable();
  // titles
  document.getElementById("barTitle").textContent=product==="td"?"Term Deposit Rate Comparison":product==="hl"?"Home Loan Rate Comparison":"Savings Account Rate Comparison";
  document.getElementById("curveTitle").textContent=product==="td"?"Yield Curve — Bank First vs Market":product==="hl"?"Rate Curve — Fixed Terms":"Rate Breakdown by Type";
  document.getElementById("tblTitle").textContent="Full Comparison — "+getBanks().length+" Banks";
}

// ===== CONTROLS =====
function renderControls(){
  const terms=getTerms(), labels=getLabels();
  let h='<div class="term-tabs">';
  terms.forEach((t,i)=>{
    const act=t===selTerm?" active":"";
    h+=`<button class="tt${act}" onclick="pickTerm('${t}')">${labels[t]}</button>`;
  });
  h+='</div>';
  h+='<div class="flt"><label>Type:</label><select onchange="renderAll()" id="fType"><option value="all">All</option>';
  const types=[...new Set(getBanks().map(b=>b.t))];
  types.forEach(t=>{h+=`<option value="${t}">${t}</option>`});
  h+='</select></div>';
  document.getElementById("controls").innerHTML=h;
}
function pickTerm(t){selTerm=t;renderAll();}

function filtered(){
  const ft=document.getElementById("fType")?.value||"all";
  return getBanks().filter(b=>ft==="all"||b.t===ft);
}

// ===== KPIs =====
function renderKPIs(){
  const banks=filtered(), terms=getTerms(), stats=calcStats(banks,terms);
  const bf=getBF(), st=stats[selTerm]||{}, bfr=bf?.r[selTerm];
  const isHL=product==="hl";
  const lbl=getLabels()[selTerm]||selTerm;
  const b4a=typeAvg("Big 4",selTerm);

  let spread=null,spreadBps=null;
  if(bfr!=null&&st.avg!=null){spread=bfr-st.avg;spreadBps=Math.round(spread*100);}

  // For home loans, lower is better
  const better=isHL?(spreadBps!=null&&spreadBps<0):(spreadBps!=null&&spreadBps>0);
  const sign=spreadBps!=null?(spreadBps>=0?"+":"")+spreadBps:"--";

  let rank=null;
  if(bfr!=null){
    const sorted=[...banks].filter(b=>b.r[selTerm]!=null).sort((a,b)=>isHL?(a.r[selTerm]-b.r[selTerm]):(b.r[selTerm]-a.r[selTerm]));
    rank=sorted.findIndex(b=>b.hl)+1;
  }

  const b4diff=bfr!=null&&b4a!=null?Math.round((bfr-b4a)*100):null;
  const b4better=isHL?(b4diff!=null&&b4diff<0):(b4diff!=null&&b4diff>0);

  let k=`
    <div class="kpi hl"><div class="kpi-label">Bank First ${lbl}</div><div class="kpi-val">${bfr!=null?bfr.toFixed(2):"--"}<span class="u">% p.a.</span></div>
      <div class="kpi-sub">${b4diff!=null?`<span class="${b4better?"g":"r"}">${(b4diff>=0?"+":"")+b4diff} bps vs Big 4</span>`:"--"}</div></div>
    <div class="kpi neu"><div class="kpi-label">Market Avg ${lbl}</div><div class="kpi-val">${st.avg!=null?st.avg.toFixed(2):"--"}<span class="u">% p.a.</span></div>
      <div class="kpi-sub">${st.cnt||0} providers</div></div>
    <div class="kpi neu"><div class="kpi-label">Big 4 Avg ${lbl}</div><div class="kpi-val">${b4a!=null?b4a.toFixed(2):"--"}<span class="u">% p.a.</span></div>
      <div class="kpi-sub">ANZ, CBA, NAB, Westpac</div></div>
    <div class="kpi ${better?"pos":"neg"}"><div class="kpi-label">Bank First vs Market</div><div class="kpi-val">${sign}<span class="u"> bps</span></div>
      <div class="kpi-sub"><span class="${better?"g":"r"}">${better?(isHL?"Below":"Above"):(isHL?"Above":"Below")} market avg</span></div></div>
    <div class="kpi neu"><div class="kpi-label">Market ${isHL?"Lowest":"Best"} ${lbl}</div><div class="kpi-val">${isHL?(st.min!=null?st.min.toFixed(2):"--"):(st.max!=null?st.max.toFixed(2):"--")}<span class="u">% p.a.</span></div>
      <div class="kpi-sub">${isHL?"Lowest rate available":"Highest rate available"}</div></div>
    <div class="kpi ${rank!=null&&rank<=3?"pos":rank!=null&&rank<=8?"neu":"neg"}"><div class="kpi-label">Bank First Rank</div><div class="kpi-val">#${rank||"--"}<span class="u"> / ${banks.filter(b=>b.r[selTerm]!=null).length}</span></div>
      <div class="kpi-sub">Among all providers</div></div>`;
  document.getElementById("kpis").innerHTML=k;
}

// ===== BAR CHART =====
function renderBar(){
  const isHL=product==="hl";
  let banks=filtered().filter(b=>b.r[selTerm]!=null);
  banks.sort((a,b)=>isHL?(a.r[selTerm]-b.r[selTerm]):(b.r[selTerm]-a.r[selTerm]));
  const labels=banks.map(b=>b.n);
  const data=banks.map(b=>b.r[selTerm]);
  const colors=banks.map(b=>b.hl?C.bf:tc(b.t));
  const st=calcStats(getBanks(),getTerms())[selTerm];
  if(charts.bar) charts.bar.destroy();
  const ctx=document.getElementById("barChart").getContext("2d");
  charts.bar=new Chart(ctx,{type:"bar",data:{labels,datasets:[{data,backgroundColor:colors.map(c=>c+"cc"),borderColor:colors,borderWidth:banks.map(b=>b.hl?3:1),borderRadius:3,barPercentage:.75}]},
    options:{indexAxis:"y",responsive:true,maintainAspectRatio:false,plugins:{legend:{display:false},
      annotation:st?{annotations:{avg:{type:"line",xMin:st.avg,xMax:st.avg,borderColor:C.avg,borderWidth:2,borderDash:[6,4],label:{display:true,content:"Avg: "+st.avg+"%",position:"start",backgroundColor:C.avg,font:{size:10}}}}}:{},
      tooltip:{callbacks:{label:c=>{let l=c.parsed.x.toFixed(2)+"% p.a.";if(st){const d=Math.round((c.parsed.x-st.avg)*100);l+=` (${d>=0?"+":""}${d} bps)`;}return l;}}}},
      scales:{x:{beginAtZero:false,min:Math.max(0,(Math.min(...data)||3)-.4),grid:{color:C.gr}},y:{grid:{display:false},ticks:{font:c=>({weight:banks[c.index]?.hl?"bold":"normal",size:banks[c.index]?.hl?12:10}),color:c=>banks[c.index]?.hl?C.bf:"#4a5568"}}}}});
}

// ===== CURVE CHART =====
function renderCurve(){
  const terms=getTerms(), tl=Object.values(getLabels());
  const bf=getBF(), bfd=terms.map(t=>bf?.r[t]||null);
  const st=calcStats(getBanks(),terms);
  const avg=terms.map(t=>st[t]?.avg||null);
  const b4=terms.map(t=>typeAvg("Big 4",t));
  const ch=terms.map(t=>typeAvg("Challenger",t));
  const mu=terms.map(t=>typeAvg("Mutual",t));
  if(charts.curve) charts.curve.destroy();
  const ctx=document.getElementById("curveChart").getContext("2d");
  charts.curve=new Chart(ctx,{type:"line",data:{labels:tl,datasets:[
    {label:"Bank First",data:bfd,borderColor:C.bf,borderWidth:3,pointRadius:5,pointBackgroundColor:C.bf,pointBorderColor:"#fff",pointBorderWidth:2,fill:false,order:1},
    {label:"Market Avg",data:avg,borderColor:C.avg,borderWidth:2,borderDash:[6,4],pointRadius:3,fill:false,order:2},
    {label:"Big 4 Avg",data:b4,borderColor:C.b4,borderWidth:2,pointRadius:3,fill:false,order:3},
    {label:"Challenger Avg",data:ch,borderColor:C.ch,borderWidth:2,pointRadius:3,fill:false,order:4},
    {label:"Mutual Avg",data:mu,borderColor:C.mu,borderWidth:2,pointRadius:3,fill:false,order:5}
  ]},options:{responsive:true,maintainAspectRatio:false,interaction:{mode:"index",intersect:false},plugins:{legend:{position:"bottom",labels:{usePointStyle:true,padding:10,font:{size:10}}}},scales:{y:{grid:{color:C.gr}},x:{grid:{color:C.gr}}}}});
}

// ===== SPREAD CHART =====
function renderSpread(){
  const terms=getTerms(), tl=Object.values(getLabels());
  const bf=getBF(), st=calcStats(getBanks(),terms);
  const isHL=product==="hl";
  const spreads=terms.map(t=>{
    const v=bf?.r[t], a=st[t]?.avg;
    return v!=null&&a!=null?Math.round((v-a)*100):null;
  });
  const b4s=terms.map(t=>{
    const v=bf?.r[t], a=typeAvg("Big 4",t);
    return v!=null&&a!=null?Math.round((v-a)*100):null;
  });
  // For HL negative spread is good
  const goodColor=isHL?"rgba(56,161,105,0.7)":"rgba(56,161,105,0.7)";
  const badColor=isHL?"rgba(229,62,62,0.7)":"rgba(229,62,62,0.7)";
  const col=s=>s==null?"#ccc":isHL?(s<=0?goodColor:badColor):(s>=0?goodColor:badColor);
  if(charts.spread) charts.spread.destroy();
  const ctx=document.getElementById("spreadChart").getContext("2d");
  charts.spread=new Chart(ctx,{type:"bar",data:{labels:tl,datasets:[
    {label:"vs Market Avg",data:spreads,backgroundColor:spreads.map(col),borderRadius:3},
    {label:"vs Big 4 Avg",data:b4s,backgroundColor:b4s.map(s=>s==null?"#ccc":isHL?(s<=0?"rgba(66,153,225,0.7)":"rgba(213,63,140,0.7)"):(s>=0?"rgba(66,153,225,0.7)":"rgba(213,63,140,0.7)")),borderRadius:3}
  ]},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:"bottom",labels:{usePointStyle:true}},annotation:{annotations:{z:{type:"line",yMin:0,yMax:0,borderColor:"#718096",borderWidth:2}}}},scales:{y:{grid:{color:C.gr}},x:{grid:{display:false}}}}});
}

// ===== RADAR =====
function renderRadar(){
  const terms=getTerms(), tl=Object.values(getLabels());
  const types=[...new Set(getBanks().map(b=>b.t))];
  const bf=getBF();
  const ds=[];
  if(bf) ds.push({label:"Bank First",data:terms.map(t=>bf.r[t]),borderColor:C.bf,borderWidth:3,backgroundColor:"rgba(237,137,54,.12)",pointRadius:4});
  types.forEach(type=>{
    ds.push({label:type,data:terms.map(t=>typeAvg(type,t)),borderColor:tc(type),borderWidth:2,backgroundColor:tc(type)+"18",pointRadius:3});
  });
  if(charts.radar) charts.radar.destroy();
  const ctx=document.getElementById("radarChart").getContext("2d");
  const allVals=ds.flatMap(d=>d.data).filter(v=>v!=null);
  const lo=Math.floor(Math.min(...allVals)*2)/2-0.5;
  charts.radar=new Chart(ctx,{type:"radar",data:{labels:tl,datasets:ds},options:{responsive:true,maintainAspectRatio:false,plugins:{legend:{position:"bottom",labels:{usePointStyle:true,padding:8,font:{size:10}}}},scales:{r:{beginAtZero:false,min:lo>0?lo:0,ticks:{stepSize:.25,font:{size:9}},grid:{color:C.gr},pointLabels:{font:{size:11,weight:"bold"}}}}}});
}

// ===== HEATMAP =====
function renderHeat(){
  const banks=filtered().filter(b=>Object.values(b.r).some(v=>v!=null));
  const terms=getTerms(), labels=getLabels();
  const isHL=product==="hl";
  banks.sort((a,b)=>isHL?((a.r[selTerm]||99)-(b.r[selTerm]||99)):((b.r[selTerm]||0)-(a.r[selTerm]||0)));
  let all=[];
  banks.forEach(b=>terms.forEach(t=>{if(b.r[t]!=null)all.push(b.r[t])}));
  const lo=Math.min(...all), hi=Math.max(...all);
  function clr(v){
    if(v==null)return{bg:"#f7fafc",fg:"#a0aec0"};
    const ratio=(v-lo)/(hi-lo||1);
    // For HL: lower=greener; for TD: higher=greener
    const r2=isHL?1-ratio:ratio;
    const r=Math.round(255-r2*200), g=Math.round(255-r2*30), b=Math.round(255-r2*200);
    return{bg:`rgb(${r},${g},${b})`,fg:r2>.6?"#fff":"#2d3748"};
  }
  let h='<table style="width:100%;border-collapse:collapse;font-size:.75rem"><tr><th style="padding:6px;text-align:left;border-bottom:2px solid #e2e8f0;color:#718096">BANK</th>';
  terms.forEach(t=>{h+=`<th style="padding:6px;text-align:center;border-bottom:2px solid #e2e8f0;color:#718096">${labels[t]}</th>`});
  h+="</tr>";
  banks.forEach(bank=>{
    const hl=bank.hl;
    h+=`<tr style="${hl?"border:2px solid #ed8936;font-weight:700":""}"><td style="padding:6px;white-space:nowrap;${hl?"color:#ed8936":"}"}">${bank.n}</td>`;
    terms.forEach(t=>{
      const v=bank.r[t], c=clr(v);
      h+=`<td style="padding:6px;text-align:center;background:${c.bg};color:${c.fg};font-weight:600">${v!=null?v.toFixed(2)+"%":"-"}</td>`;
    });
    h+="</tr>";
  });
  h+="</table>";
  h+=`<div style="display:flex;align-items:center;gap:.4rem;margin-top:.5rem;font-size:.7rem;color:#718096"><span>${isHL?"Best (low)":"Low"} ${lo.toFixed(2)}%</span><div style="flex:1;height:6px;border-radius:3px;background:linear-gradient(to right,${isHL?"rgb(55,225,55),rgb(255,255,255)":"rgb(255,255,255),rgb(55,225,55)"})"></div><span>${isHL?"Worst (high)":"High"} ${hi.toFixed(2)}%</span></div>`;
  document.getElementById("heatmap").innerHTML=h;
}

// ===== TABLE =====
function renderTable(){
  const isHL=product==="hl", isSA=product==="sa";
  const terms=getTerms(), labels=getLabels();
  let banks=filtered().filter(b=>Object.values(b.r).some(v=>v!=null));
  banks.sort((a,b)=>isHL?((a.r[selTerm]||99)-(b.r[selTerm]||99)):((b.r[selTerm]||0)-(a.r[selTerm]||0)));
  const st=calcStats(getBanks(),terms);

  // Best per term
  const best={};
  terms.forEach(t=>{
    const rs=banks.map(b=>b.r[t]).filter(v=>v!=null);
    best[t]=isHL?Math.min(...rs):Math.max(...rs);
  });

  let th="<tr><th>#</th><th>Bank</th><th>Type</th>";
  if(isSA) th+="<th>Product</th><th>Conditions</th>";
  terms.forEach(t=>{th+=`<th>${labels[t]}</th>`});
  if(!isSA) th+="<th>vs Mkt</th>";
  th+="</tr>";
  document.getElementById("tblHead").innerHTML=th;

  let tb="";
  banks.forEach((bank,i)=>{
    const hl=bank.hl, cls=hl?'class="hlr"':"";
    const bfr=bank.r[selTerm], avg=st[selTerm]?.avg;
    const diff=bfr!=null&&avg!=null?Math.round((bfr-avg)*100):null;
    const diffBetter=isHL?(diff!=null&&diff<0):(diff!=null&&diff>0);
    tb+=`<tr ${cls}><td style="font-weight:700;${hl?"color:#ed8936":"color:#718096"}">${i+1}</td>`;
    tb+=`<td style="${hl?"color:#ed8936;font-weight:700":"font-weight:500"}">${bank.n}</td>`;
    tb+=`<td><span class="bb ${bb(bank.t)}">${bank.t}</span></td>`;
    if(isSA){tb+=`<td style="font-size:.75rem">${bank.prod||"-"}</td><td style="font-size:.72rem;color:#718096">${bank.cond||"-"}</td>`;}
    terms.forEach(t=>{
      const v=bank.r[t], isBest=v!=null&&v===best[t];
      tb+=`<td class="${isBest?"best":""}" style="font-weight:600">${v!=null?v.toFixed(2)+"%":"-"}</td>`;
    });
    if(!isSA){
      tb+=`<td class="${diffBetter?"above":"below"}">${diff!=null?(diff>=0?"+":"")+diff+" bps":"-"}</td>`;
    }
    tb+="</tr>";
  });
  document.getElementById("tblBody").innerHTML=tb;
}

function filterTbl(){
  const q=document.getElementById("tblSearch").value.toLowerCase();
  document.querySelectorAll("#tblBody tr").forEach(r=>{r.style.display=r.textContent.toLowerCase().includes(q)?"":"none"});
}

// ===== CALCULATOR =====
function renderCalc(){
  const isTD=product==="td", isHL=product==="hl";
  if(!isTD&&!isHL){document.getElementById("calcInputs").innerHTML="";document.getElementById("calcResults").innerHTML="";return;}
  let h="";
  if(isTD){
    h+=`<div><label>Deposit ($)</label><input type="number" id="cAmt" value="50000" min="500" step="1000"></div>`;
    h+=`<div><label>Term</label><select id="cTerm">${getTerms().map(t=>`<option value="${t}" ${t===selTerm?"selected":""}>${getLabels()[t]}</option>`).join("")}</select></div>`;
    h+=`<div><button onclick="doCalcTD()">Calculate Interest</button></div>`;
  } else {
    h+=`<div><label>Loan Amount ($)</label><input type="number" id="cAmt" value="500000" min="10000" step="10000"></div>`;
    h+=`<div><label>Loan Term (years)</label><input type="number" id="cYrs" value="30" min="1" max="30"></div>`;
    h+=`<div><label>Rate Type</label><select id="cTerm">${getTerms().map(t=>`<option value="${t}" ${t===selTerm?"selected":""}>${getLabels()[t]}</option>`).join("")}</select></div>`;
    h+=`<div><button onclick="doCalcHL()">Calculate Repayment</button></div>`;
  }
  document.getElementById("calcInputs").innerHTML=h;
  document.getElementById("calcResults").innerHTML="";
}

function doCalcTD(){
  const dep=parseFloat(document.getElementById("cAmt").value)||50000;
  const term=document.getElementById("cTerm").value;
  const months={"3m":3,"6m":6,"12m":12,"24m":24,"36m":36,"60m":60}[term]||12;
  const banks=filtered().filter(b=>b.r[term]!=null).sort((a,b)=>(b.r[term]-a.r[term]));
  let h='<div style="max-height:350px;overflow-y:auto;margin-top:.5rem"><table class="tbl"><tr><th>Bank</th><th>Rate</th><th>Interest Earned</th><th>At Maturity</th></tr>';
  banks.forEach(b=>{
    const int=dep*(b.r[term]/100)*(months/12);
    h+=`<tr ${b.hl?'class="hlr"':""}><td>${b.n}</td><td>${b.r[term].toFixed(2)}%</td><td style="color:#38a169;font-weight:600">$${int.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g,",")}</td><td style="font-weight:600">$${(dep+int).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g,",")}</td></tr>`;
  });
  h+="</table></div>";
  document.getElementById("calcResults").innerHTML=h;
}

function doCalcHL(){
  const loan=parseFloat(document.getElementById("cAmt").value)||500000;
  const yrs=parseInt(document.getElementById("cYrs").value)||30;
  const term=document.getElementById("cTerm").value;
  const banks=filtered().filter(b=>b.r[term]!=null).sort((a,b)=>a.r[term]-b.r[term]);
  let h='<div style="max-height:350px;overflow-y:auto;margin-top:.5rem"><table class="tbl"><tr><th>Bank</th><th>Rate</th><th>Monthly Repayment</th><th>Total Interest</th></tr>';
  banks.forEach(b=>{
    const mr=b.r[term]/100/12, n=yrs*12;
    const pmt=mr>0?loan*(mr*Math.pow(1+mr,n))/(Math.pow(1+mr,n)-1):loan/n;
    const tot=pmt*n-loan;
    h+=`<tr ${b.hl?'class="hlr"':""}><td>${b.n}</td><td>${b.r[term].toFixed(2)}%</td><td style="font-weight:600">$${pmt.toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g,",")}</td><td style="color:#e53e3e">$${tot.toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g,",")}</td></tr>`;
  });
  h+="</table></div>";
  document.getElementById("calcResults").innerHTML=h;
}
