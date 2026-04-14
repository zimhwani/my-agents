/**
 * Australian Term Deposit Rate Benchmarker
 * Frontend application - Charts, tables, and interactive comparison tools
 */

// ===== Global State =====
let rateData = null;
let selectedTerm = "12m";
let charts = {};
let sortColumn = 5; // default sort by 12M rate
let sortAsc = false;

const TERM_MONTHS = { "3m": 3, "6m": 6, "12m": 12, "24m": 24, "36m": 36, "60m": 60 };
const TERM_LABELS = { "3m": "3 Months", "6m": "6 Months", "12m": "12 Months", "24m": "24 Months", "36m": "3 Years", "60m": "5 Years" };

const COLORS = {
  bankFirst: "#ed8936",
  bankFirstBg: "rgba(237, 137, 54, 0.15)",
  big4: "#4299e1",
  big4Bg: "rgba(66, 153, 225, 0.15)",
  challenger: "#48bb78",
  challengerBg: "rgba(72, 187, 120, 0.15)",
  mutual: "#9f7aea",
  mutualBg: "rgba(159, 122, 234, 0.15)",
  regional: "#d69e2e",
  regionalBg: "rgba(214, 158, 46, 0.15)",
  creditUnion: "#e53e3e",
  marketAvg: "#718096",
  cashRate: "#e53e3e",
  grid: "#e2e8f0",
};

function getTypeColor(type) {
  const map = {
    "Big 4": COLORS.big4,
    "Challenger": COLORS.challenger,
    "Mutual Bank": COLORS.mutual,
    "Regional": COLORS.regional,
    "Credit Union": COLORS.creditUnion,
  };
  return map[type] || "#a0aec0";
}

function getTypeBgColor(type) {
  const map = {
    "Big 4": COLORS.big4Bg,
    "Challenger": COLORS.challengerBg,
    "Mutual Bank": COLORS.mutualBg,
    "Regional": COLORS.regionalBg,
    "Credit Union": "rgba(229, 62, 62, 0.15)",
  };
  return map[type] || "rgba(160, 174, 192, 0.15)";
}

// ===== Data Loading =====

async function loadData() {
  try {
    const resp = await fetch("/api/rates");
    if (!resp.ok) throw new Error("Failed to load data");
    rateData = await resp.json();
    renderAll();
    document.getElementById("loadingOverlay").classList.add("hidden");
  } catch (err) {
    console.error("Error loading data:", err);
    document.getElementById("loadingOverlay").innerHTML =
      '<div style="text-align:center;color:#e53e3e;"><p>Failed to load rate data.</p><button onclick="loadData()" style="margin-top:1rem;padding:0.5rem 1rem;background:#1a365d;color:white;border:none;border-radius:6px;cursor:pointer;">Retry</button></div>';
  }
}

async function refreshData() {
  const btn = document.getElementById("refreshBtn");
  btn.classList.add("loading");
  btn.disabled = true;

  try {
    const resp = await fetch("/api/refresh", { method: "POST" });
    const result = await resp.json();
    await loadData();
  } catch (err) {
    console.error("Refresh failed:", err);
  } finally {
    btn.classList.remove("loading");
    btn.disabled = false;
  }
}

// ===== Render All =====

function renderAll() {
  if (!rateData) return;
  renderKPIs();
  renderBarChart();
  renderYieldChart();
  renderTypeChart();
  renderSpreadChart();
  renderRBAChart();
  renderHeatmap();
  renderTable();
  renderSources();
  updateHeader();
}

// ===== Header =====

function updateHeader() {
  const cashRate = rateData.cashRate?.current || "--";
  document.getElementById("cashRateBadge").innerHTML = `RBA Cash Rate: <strong>${cashRate}%</strong>`;

  const updated = rateData.lastUpdated
    ? new Date(rateData.lastUpdated).toLocaleDateString("en-AU", { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" })
    : "--";
  document.getElementById("lastUpdated").textContent = `Updated: ${updated}`;
  document.getElementById("footerLastUpdated").textContent = updated;
}

// ===== KPI Cards =====

function renderKPIs() {
  const banks = getFilteredBanks();
  const stats = rateData.marketStats || {};
  const termStats = stats[selectedTerm] || {};
  const bankFirst = rateData.bankFirst;
  const bfRate = bankFirst?.rates?.[selectedTerm];
  const big4Avg = rateData.big4Average?.[selectedTerm];

  // Bank First rate
  document.getElementById("kpiBankFirst").innerHTML = bfRate
    ? `${bfRate.toFixed(2)}<span class="unit">% p.a.</span>`
    : '--<span class="unit">% p.a.</span>';

  // Market average
  const mktAvg = termStats.avg;
  document.getElementById("kpiMarketAvg").innerHTML = mktAvg
    ? `${mktAvg.toFixed(2)}<span class="unit">% p.a.</span>`
    : '--<span class="unit">% p.a.</span>';
  document.getElementById("kpiMarketAvgDetail").textContent = `Across ${termStats.count || 0} providers`;

  // Big 4 average
  document.getElementById("kpiBig4Avg").innerHTML = big4Avg
    ? `${big4Avg.toFixed(2)}<span class="unit">% p.a.</span>`
    : '--<span class="unit">% p.a.</span>';

  // Spread
  if (bfRate && mktAvg) {
    const spread = Math.round((bfRate - mktAvg) * 100);
    const sign = spread >= 0 ? "+" : "";
    document.getElementById("kpiSpread").innerHTML = `${sign}${spread}<span class="unit"> bps</span>`;
    document.getElementById("kpiSpreadDetail").innerHTML = spread >= 0
      ? '<span class="positive">Above market average</span>'
      : '<span class="negative">Below market average</span>';
    const card = document.getElementById("kpiSpreadCard");
    card.classList.remove("positive", "negative");
    card.classList.add(spread >= 0 ? "positive" : "negative");
  }

  // Market best
  document.getElementById("kpiMarketBest").innerHTML = termStats.max
    ? `${termStats.max.toFixed(2)}<span class="unit">% p.a.</span>`
    : '--<span class="unit">% p.a.</span>';

  if (termStats.max) {
    const bestBank = banks.find(b => b.rates[selectedTerm] === termStats.max);
    document.getElementById("kpiMarketBestDetail").textContent = bestBank ? bestBank.name : "Highest available";
  }

  // Ranking
  const sorted = banks
    .filter(b => b.rates[selectedTerm])
    .sort((a, b) => (b.rates[selectedTerm] || 0) - (a.rates[selectedTerm] || 0));
  const rank = sorted.findIndex(b => b.highlight) + 1;
  document.getElementById("kpiRank").innerHTML = rank
    ? `#${rank}<span class="unit" id="kpiRankTotal"> / ${sorted.length}</span>`
    : '--<span class="unit"> / --</span>';

  const rankCard = document.getElementById("kpiRankCard");
  rankCard.classList.remove("positive", "negative", "neutral");
  if (rank && rank <= 3) rankCard.classList.add("positive");
  else if (rank && rank <= sorted.length / 2) rankCard.classList.add("neutral");
  else rankCard.classList.add("negative");

  // Bank First detail
  if (bfRate && big4Avg) {
    const vsBig4 = Math.round((bfRate - big4Avg) * 100);
    const sign2 = vsBig4 >= 0 ? "+" : "";
    document.getElementById("kpiBankFirstDetail").innerHTML = `<span class="${vsBig4 >= 0 ? 'positive' : 'negative'}">${sign2}${vsBig4} bps vs Big 4 avg</span>`;
  }
}

// ===== Filters =====

function getFilteredBanks() {
  if (!rateData?.banks) return [];
  const typeFilter = document.getElementById("filterType")?.value || "all";
  const depositAmt = parseInt(document.getElementById("depositAmount")?.value || "10000");

  return rateData.banks.filter(b => {
    if (typeFilter !== "all" && b.type !== typeFilter) return false;
    if (b.minDeposit && depositAmt < b.minDeposit) return false;
    return true;
  });
}

function applyFilters() {
  renderAll();
}

// ===== Bar Chart =====

function renderBarChart() {
  const banks = getFilteredBanks()
    .filter(b => b.rates[selectedTerm])
    .sort((a, b) => (b.rates[selectedTerm] || 0) - (a.rates[selectedTerm] || 0));

  const labels = banks.map(b => b.name);
  const data = banks.map(b => b.rates[selectedTerm]);
  const bgColors = banks.map(b => b.highlight ? COLORS.bankFirst : getTypeColor(b.type));
  const borderColors = banks.map(b => b.highlight ? "#dd6b20" : getTypeColor(b.type));

  const mktAvg = rateData.marketStats?.[selectedTerm]?.avg;

  if (charts.bar) charts.bar.destroy();

  const ctx = document.getElementById("barChart").getContext("2d");
  charts.bar = new Chart(ctx, {
    type: "bar",
    data: {
      labels,
      datasets: [{
        label: `${TERM_LABELS[selectedTerm]} Rate (% p.a.)`,
        data,
        backgroundColor: bgColors.map(c => c + "cc"),
        borderColor: borderColors,
        borderWidth: banks.map(b => b.highlight ? 3 : 1),
        borderRadius: 4,
        barPercentage: 0.75,
      }],
    },
    options: {
      indexAxis: "y",
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        annotation: mktAvg ? {
          annotations: {
            avgLine: {
              type: "line",
              xMin: mktAvg,
              xMax: mktAvg,
              borderColor: COLORS.marketAvg,
              borderWidth: 2,
              borderDash: [6, 4],
              label: {
                display: true,
                content: `Mkt Avg: ${mktAvg.toFixed(2)}%`,
                position: "start",
                backgroundColor: COLORS.marketAvg,
                font: { size: 11 },
              },
            },
          },
        } : {},
        tooltip: {
          callbacks: {
            label: (ctx) => {
              const bank = banks[ctx.dataIndex];
              let label = `${ctx.parsed.x.toFixed(2)}% p.a.`;
              if (mktAvg) {
                const diff = Math.round((ctx.parsed.x - mktAvg) * 100);
                label += ` (${diff >= 0 ? "+" : ""}${diff} bps vs avg)`;
              }
              return label;
            },
            afterLabel: (ctx) => {
              const bank = banks[ctx.dataIndex];
              return `Type: ${bank.type} | Min: $${(bank.minDeposit || 0).toLocaleString()}`;
            },
          },
        },
      },
      scales: {
        x: {
          beginAtZero: false,
          min: Math.max(0, (Math.min(...data) || 3) - 0.5),
          title: { display: true, text: "Interest Rate (% p.a.)", font: { weight: "bold" } },
          grid: { color: COLORS.grid },
        },
        y: {
          grid: { display: false },
          ticks: {
            font: (ctx) => ({
              weight: banks[ctx.index]?.highlight ? "bold" : "normal",
              size: banks[ctx.index]?.highlight ? 13 : 11,
            }),
            color: (ctx) => banks[ctx.index]?.highlight ? COLORS.bankFirst : "#4a5568",
          },
        },
      },
    },
  });

  document.getElementById("chartBarSubtitle").textContent = `${TERM_LABELS[selectedTerm]} term deposit rates`;
}

// ===== Yield Curve Chart =====

function renderYieldChart() {
  const terms = ["3m", "6m", "12m", "24m", "36m", "60m"];
  const termLabelsShort = ["3M", "6M", "12M", "24M", "3Y", "5Y"];

  const bankFirst = rateData.bankFirst;
  const bfData = terms.map(t => bankFirst?.rates?.[t] || null);

  const big4Avg = terms.map(t => rateData.big4Average?.[t] || null);
  const challengerAvg = terms.map(t => rateData.challengerAverage?.[t] || null);
  const mktAvg = terms.map(t => rateData.marketStats?.[t]?.avg || null);
  const mktMax = terms.map(t => rateData.marketStats?.[t]?.max || null);
  const mktMin = terms.map(t => rateData.marketStats?.[t]?.min || null);

  if (charts.yield) charts.yield.destroy();

  const ctx = document.getElementById("yieldChart").getContext("2d");
  charts.yield = new Chart(ctx, {
    type: "line",
    data: {
      labels: termLabelsShort,
      datasets: [
        {
          label: "Market Best",
          data: mktMax,
          borderColor: "#48bb7866",
          backgroundColor: "transparent",
          borderWidth: 1,
          borderDash: [4, 4],
          pointRadius: 2,
          order: 5,
        },
        {
          label: "Bank First",
          data: bfData,
          borderColor: COLORS.bankFirst,
          backgroundColor: COLORS.bankFirstBg,
          borderWidth: 3,
          pointRadius: 6,
          pointBackgroundColor: COLORS.bankFirst,
          pointBorderColor: "#fff",
          pointBorderWidth: 2,
          fill: false,
          order: 1,
        },
        {
          label: "Market Average",
          data: mktAvg,
          borderColor: COLORS.marketAvg,
          backgroundColor: "rgba(113, 128, 150, 0.08)",
          borderWidth: 2,
          borderDash: [6, 4],
          pointRadius: 3,
          fill: true,
          order: 3,
        },
        {
          label: "Big 4 Average",
          data: big4Avg,
          borderColor: COLORS.big4,
          backgroundColor: "transparent",
          borderWidth: 2,
          pointRadius: 3,
          order: 2,
        },
        {
          label: "Challenger Average",
          data: challengerAvg,
          borderColor: COLORS.challenger,
          backgroundColor: "transparent",
          borderWidth: 2,
          pointRadius: 3,
          order: 4,
        },
        {
          label: "Market Worst",
          data: mktMin,
          borderColor: "#e53e3e44",
          backgroundColor: "transparent",
          borderWidth: 1,
          borderDash: [4, 4],
          pointRadius: 2,
          order: 6,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: { position: "bottom", labels: { usePointStyle: true, padding: 15 } },
        tooltip: {
          callbacks: {
            label: (ctx) => `${ctx.dataset.label}: ${ctx.parsed.y?.toFixed(2)}% p.a.`,
          },
        },
      },
      scales: {
        y: {
          title: { display: true, text: "Rate (% p.a.)", font: { weight: "bold" } },
          grid: { color: COLORS.grid },
        },
        x: {
          title: { display: true, text: "Term Length", font: { weight: "bold" } },
          grid: { color: COLORS.grid },
        },
      },
    },
  });
}

// ===== Bank Type Chart =====

function renderTypeChart() {
  const terms = ["3m", "6m", "12m", "24m", "36m", "60m"];
  const types = ["Big 4", "Challenger", "Mutual Bank", "Regional"];

  const datasets = types.map(type => {
    const typeBanks = rateData.banks.filter(b => b.type === type);
    const avgData = terms.map(t => {
      const rates = typeBanks.map(b => b.rates[t]).filter(Boolean);
      return rates.length ? +(rates.reduce((a, b) => a + b, 0) / rates.length).toFixed(2) : null;
    });
    return {
      label: type,
      data: avgData,
      backgroundColor: getTypeBgColor(type),
      borderColor: getTypeColor(type),
      borderWidth: 2,
    };
  });

  // Add Bank First
  const bf = rateData.bankFirst;
  if (bf) {
    datasets.unshift({
      label: "Bank First",
      data: terms.map(t => bf.rates[t] || null),
      backgroundColor: COLORS.bankFirstBg,
      borderColor: COLORS.bankFirst,
      borderWidth: 3,
    });
  }

  if (charts.type) charts.type.destroy();

  const ctx = document.getElementById("typeChart").getContext("2d");
  charts.type = new Chart(ctx, {
    type: "radar",
    data: {
      labels: ["3M", "6M", "12M", "24M", "3Y", "5Y"],
      datasets,
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: "bottom", labels: { usePointStyle: true, padding: 12, font: { size: 11 } } },
      },
      scales: {
        r: {
          beginAtZero: false,
          min: 3.5,
          ticks: { stepSize: 0.25, font: { size: 10 } },
          grid: { color: COLORS.grid },
          pointLabels: { font: { size: 12, weight: "bold" } },
        },
      },
    },
  });
}

// ===== Spread Chart =====

function renderSpreadChart() {
  const terms = ["3m", "6m", "12m", "24m", "36m", "60m"];
  const bf = rateData.bankFirst;
  if (!bf) return;

  const spreads = terms.map(t => {
    const bfRate = bf.rates[t];
    const mktAvg = rateData.marketStats?.[t]?.avg;
    if (bfRate && mktAvg) return Math.round((bfRate - mktAvg) * 100);
    return null;
  });

  const big4Spreads = terms.map(t => {
    const bfRate = bf.rates[t];
    const avg = rateData.big4Average?.[t];
    if (bfRate && avg) return Math.round((bfRate - avg) * 100);
    return null;
  });

  if (charts.spread) charts.spread.destroy();

  const ctx = document.getElementById("spreadChart").getContext("2d");
  charts.spread = new Chart(ctx, {
    type: "bar",
    data: {
      labels: ["3M", "6M", "12M", "24M", "3Y", "5Y"],
      datasets: [
        {
          label: "vs Market Avg",
          data: spreads,
          backgroundColor: spreads.map(s => s >= 0 ? "rgba(56, 161, 105, 0.7)" : "rgba(229, 62, 62, 0.7)"),
          borderColor: spreads.map(s => s >= 0 ? "#38a169" : "#e53e3e"),
          borderWidth: 1,
          borderRadius: 4,
        },
        {
          label: "vs Big 4 Avg",
          data: big4Spreads,
          backgroundColor: big4Spreads.map(s => s >= 0 ? "rgba(66, 153, 225, 0.7)" : "rgba(213, 63, 140, 0.7)"),
          borderColor: big4Spreads.map(s => s >= 0 ? "#4299e1" : "#d53f8c"),
          borderWidth: 1,
          borderRadius: 4,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: "bottom", labels: { usePointStyle: true } },
        annotation: {
          annotations: {
            zeroLine: {
              type: "line",
              yMin: 0,
              yMax: 0,
              borderColor: "#718096",
              borderWidth: 2,
            },
          },
        },
        tooltip: {
          callbacks: {
            label: (ctx) => `${ctx.dataset.label}: ${ctx.parsed.y >= 0 ? "+" : ""}${ctx.parsed.y} bps`,
          },
        },
      },
      scales: {
        y: {
          title: { display: true, text: "Spread (basis points)", font: { weight: "bold" } },
          grid: { color: COLORS.grid },
        },
        x: { grid: { display: false } },
      },
    },
  });
}

// ===== RBA Cash Rate Chart =====

function renderRBAChart() {
  const history = rateData.cashRate?.history || [];

  const labels = history.map(h => {
    const d = new Date(h.date);
    return d.toLocaleDateString("en-AU", { month: "short", year: "2-digit" });
  });
  const cashRates = history.map(h => h.rate);

  // Add current term deposit context
  const currentStats = rateData.marketStats?.["12m"] || {};
  const bf12m = rateData.bankFirst?.rates?.["12m"];

  if (charts.rba) charts.rba.destroy();

  const ctx = document.getElementById("rbaChart").getContext("2d");
  charts.rba = new Chart(ctx, {
    type: "line",
    data: {
      labels,
      datasets: [
        {
          label: "RBA Cash Rate",
          data: cashRates,
          borderColor: COLORS.cashRate,
          backgroundColor: "rgba(229, 62, 62, 0.08)",
          borderWidth: 3,
          pointRadius: 5,
          pointBackgroundColor: COLORS.cashRate,
          pointBorderColor: "#fff",
          pointBorderWidth: 2,
          fill: true,
          stepped: "after",
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: "bottom", labels: { usePointStyle: true } },
        annotation: {
          annotations: {
            ...(currentStats.avg ? {
              mktAvgLine: {
                type: "line",
                yMin: currentStats.avg,
                yMax: currentStats.avg,
                borderColor: COLORS.marketAvg,
                borderWidth: 2,
                borderDash: [6, 4],
                label: {
                  display: true,
                  content: `12M Market Avg: ${currentStats.avg}%`,
                  position: "end",
                  backgroundColor: COLORS.marketAvg,
                  font: { size: 11 },
                },
              },
            } : {}),
            ...(bf12m ? {
              bfLine: {
                type: "line",
                yMin: bf12m,
                yMax: bf12m,
                borderColor: COLORS.bankFirst,
                borderWidth: 2,
                borderDash: [8, 4],
                label: {
                  display: true,
                  content: `Bank First 12M: ${bf12m}%`,
                  position: "start",
                  backgroundColor: COLORS.bankFirst,
                  font: { size: 11 },
                },
              },
            } : {}),
            ...(currentStats.max ? {
              bestLine: {
                type: "line",
                yMin: currentStats.max,
                yMax: currentStats.max,
                borderColor: "#38a16966",
                borderWidth: 1,
                borderDash: [4, 4],
                label: {
                  display: true,
                  content: `12M Best: ${currentStats.max}%`,
                  position: "75%",
                  backgroundColor: "#38a169",
                  font: { size: 10 },
                },
              },
            } : {}),
          },
        },
        tooltip: {
          callbacks: {
            label: (ctx) => `Cash Rate: ${ctx.parsed.y.toFixed(2)}%`,
          },
        },
      },
      scales: {
        y: {
          title: { display: true, text: "Rate (%)", font: { weight: "bold" } },
          grid: { color: COLORS.grid },
          min: 3.0,
        },
        x: {
          title: { display: true, text: "Date", font: { weight: "bold" } },
          grid: { color: COLORS.grid },
        },
      },
    },
  });
}

// ===== Heatmap =====

function renderHeatmap() {
  const container = document.getElementById("heatmapContainer");
  const terms = ["3m", "6m", "12m", "24m", "36m", "60m"];
  const banks = getFilteredBanks().sort((a, b) => {
    const aRate = a.rates[selectedTerm] || 0;
    const bRate = b.rates[selectedTerm] || 0;
    return bRate - aRate;
  });

  // Find global min/max for color scaling
  let allRates = [];
  banks.forEach(b => terms.forEach(t => { if (b.rates[t]) allRates.push(b.rates[t]); }));
  const minRate = Math.min(...allRates);
  const maxRate = Math.max(...allRates);

  function rateToColor(rate) {
    if (!rate) return "#f7fafc";
    const ratio = (rate - minRate) / (maxRate - minRate || 1);
    // Green gradient
    const r = Math.round(255 - ratio * 200);
    const g = Math.round(255 - ratio * 30);
    const b = Math.round(255 - ratio * 200);
    return `rgb(${r}, ${g}, ${b})`;
  }

  function rateToTextColor(rate) {
    if (!rate) return "#a0aec0";
    const ratio = (rate - minRate) / (maxRate - minRate || 1);
    return ratio > 0.6 ? "#fff" : "#2d3748";
  }

  let html = '<table style="width:100%;border-collapse:collapse;font-size:0.8rem;">';
  html += '<thead><tr><th style="padding:8px;text-align:left;border-bottom:2px solid #e2e8f0;font-size:0.75rem;color:#718096;">BANK</th>';
  terms.forEach(t => {
    html += `<th style="padding:8px;text-align:center;border-bottom:2px solid #e2e8f0;font-size:0.75rem;color:#718096;">${TERM_LABELS[t]}</th>`;
  });
  html += "</tr></thead><tbody>";

  banks.forEach(bank => {
    const isHighlight = bank.highlight;
    const rowBorder = isHighlight ? "border:2px solid #ed8936;" : "";
    html += `<tr style="${rowBorder}${isHighlight ? "font-weight:700;" : ""}">`;
    html += `<td style="padding:8px;white-space:nowrap;${isHighlight ? "color:#ed8936;" : ""}">${bank.name}</td>`;
    terms.forEach(t => {
      const rate = bank.rates[t];
      const bg = rateToColor(rate);
      const color = rateToTextColor(rate);
      html += `<td style="padding:8px;text-align:center;background:${bg};color:${color};font-weight:600;font-variant-numeric:tabular-nums;">${rate ? rate.toFixed(2) + "%" : "-"}</td>`;
    });
    html += "</tr>";
  });

  html += "</tbody></table>";

  // Color legend
  html += '<div style="display:flex;align-items:center;gap:0.5rem;margin-top:0.75rem;font-size:0.75rem;color:#718096;">';
  html += `<span>Low (${minRate.toFixed(2)}%)</span>`;
  html += '<div style="flex:1;height:8px;border-radius:4px;background:linear-gradient(to right, rgb(255,255,255), rgb(55,225,55));"></div>';
  html += `<span>High (${maxRate.toFixed(2)}%)</span>`;
  html += "</div>";

  container.innerHTML = html;
}

// ===== Rate Table =====

function renderTable() {
  const banks = getFilteredBanks();
  const terms = ["3m", "6m", "12m", "24m", "36m", "60m"];

  // Sort by selected term rate
  const sorted = [...banks].sort((a, b) => {
    const aVal = a.rates[selectedTerm] || 0;
    const bVal = b.rates[selectedTerm] || 0;
    return sortAsc ? aVal - bVal : bVal - aVal;
  });

  const mktAvg = rateData.marketStats?.[selectedTerm]?.avg || 0;

  // Find best rate per term for highlighting
  const bestPerTerm = {};
  terms.forEach(t => {
    const rates = banks.map(b => b.rates[t]).filter(Boolean);
    bestPerTerm[t] = Math.max(...rates);
  });

  const tbody = document.getElementById("rateTableBody");
  tbody.innerHTML = sorted.map((bank, i) => {
    const isHighlight = bank.highlight;
    const rowClass = isHighlight ? 'class="highlight-row"' : "";
    const rate12m = bank.rates[selectedTerm] || 0;
    const diff = rate12m ? Math.round((rate12m - mktAvg) * 100) : null;

    const typeBadgeClass = {
      "Big 4": "badge-big4",
      "Challenger": "badge-challenger",
      "Mutual Bank": "badge-mutual",
      "Regional": "badge-regional",
      "Credit Union": "badge-credit-union",
    }[bank.type] || "";

    return `<tr ${rowClass}>
      <td style="font-weight:700;color:${isHighlight ? COLORS.bankFirst : "#718096"}">${i + 1}</td>
      <td>
        <div class="bank-name">
          <a href="${bank.website || "#"}" target="_blank" rel="noopener" style="color:${isHighlight ? COLORS.bankFirst : "inherit"};text-decoration:none;font-weight:${isHighlight ? 700 : 500};">
            ${bank.name}
          </a>
        </div>
      </td>
      <td><span class="bank-type-badge ${typeBadgeClass}">${bank.type}</span></td>
      ${terms.map(t => {
        const r = bank.rates[t];
        const isBest = r === bestPerTerm[t];
        const cellClass = isBest ? "rate-cell best" : "rate-cell";
        return `<td class="${cellClass}">${r ? r.toFixed(2) + "%" : "-"}</td>`;
      }).join("")}
      <td>$${(bank.minDeposit || 0).toLocaleString()}</td>
      <td class="vs-market ${diff > 0 ? "above" : diff < 0 ? "below" : "equal"}">
        ${diff !== null ? (diff >= 0 ? "+" : "") + diff + " bps" : "-"}
      </td>
    </tr>`;
  }).join("");
}

function filterTable() {
  const search = document.getElementById("tableSearch").value.toLowerCase();
  const rows = document.getElementById("rateTableBody").querySelectorAll("tr");
  rows.forEach(row => {
    const text = row.textContent.toLowerCase();
    row.style.display = text.includes(search) ? "" : "none";
  });
}

function sortTable(col) {
  if (sortColumn === col) {
    sortAsc = !sortAsc;
  } else {
    sortColumn = col;
    sortAsc = false;
  }
  renderTable();
}

// ===== Calculator =====

function calculateEarnings() {
  const deposit = parseFloat(document.getElementById("calcDeposit").value) || 50000;
  const term = document.getElementById("calcTerm").value;
  const months = TERM_MONTHS[term];
  const banks = getFilteredBanks()
    .filter(b => b.rates[term])
    .sort((a, b) => (b.rates[term] || 0) - (a.rates[term] || 0));

  const results = banks.map(bank => {
    const rate = bank.rates[term];
    const interest = deposit * (rate / 100) * (months / 12);
    return { name: bank.name, rate, interest, highlight: bank.highlight, type: bank.type };
  });

  const bf = results.find(r => r.highlight);
  const best = results[0];

  let html = '<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:1rem;margin-bottom:1rem;">';

  if (bf) {
    html += `<div style="background:#fffaf0;border:2px solid #ed8936;border-radius:8px;padding:1rem;">
      <div style="font-size:0.8rem;color:#718096;font-weight:600;">BANK FIRST EARNINGS</div>
      <div style="font-size:1.5rem;font-weight:800;color:#ed8936;">$${bf.interest.toFixed(2)}</div>
      <div style="font-size:0.8rem;color:#718096;">at ${bf.rate.toFixed(2)}% over ${TERM_LABELS[term]}</div>
    </div>`;
  }
  if (best) {
    html += `<div style="background:#f0fff4;border:2px solid #38a169;border-radius:8px;padding:1rem;">
      <div style="font-size:0.8rem;color:#718096;font-weight:600;">BEST AVAILABLE (${best.name})</div>
      <div style="font-size:1.5rem;font-weight:800;color:#38a169;">$${best.interest.toFixed(2)}</div>
      <div style="font-size:0.8rem;color:#718096;">at ${best.rate.toFixed(2)}% over ${TERM_LABELS[term]}</div>
    </div>`;
  }
  if (bf && best) {
    const diff = best.interest - bf.interest;
    html += `<div style="background:#f7fafc;border:2px solid #e2e8f0;border-radius:8px;padding:1rem;">
      <div style="font-size:0.8rem;color:#718096;font-weight:600;">POTENTIAL DIFFERENCE</div>
      <div style="font-size:1.5rem;font-weight:800;color:${diff > 0 ? "#e53e3e" : "#38a169"};">$${Math.abs(diff).toFixed(2)}</div>
      <div style="font-size:0.8rem;color:#718096;">${diff > 0 ? "Less" : "More"} with Bank First vs best</div>
    </div>`;
  }
  html += "</div>";

  // Full table
  html += '<div style="max-height:300px;overflow-y:auto;">';
  html += '<table style="width:100%;border-collapse:collapse;font-size:0.8rem;">';
  html += '<tr style="background:#f7fafc;"><th style="padding:6px;text-align:left;">Bank</th><th style="padding:6px;text-align:right;">Rate</th><th style="padding:6px;text-align:right;">Interest Earned</th><th style="padding:6px;text-align:right;">Total at Maturity</th></tr>';
  results.forEach(r => {
    const rowStyle = r.highlight ? 'background:#fffaf0;font-weight:700;' : '';
    html += `<tr style="${rowStyle}border-bottom:1px solid #e2e8f0;">
      <td style="padding:6px;">${r.name}</td>
      <td style="padding:6px;text-align:right;">${r.rate.toFixed(2)}%</td>
      <td style="padding:6px;text-align:right;color:#38a169;font-weight:600;">$${r.interest.toFixed(2)}</td>
      <td style="padding:6px;text-align:right;font-weight:600;">$${(deposit + r.interest).toFixed(2)}</td>
    </tr>`;
  });
  html += "</table></div>";

  const container = document.getElementById("calcResults");
  container.style.display = "block";
  container.innerHTML = html;
}

// ===== Sources =====

function renderSources() {
  const sources = rateData.dataSources || [];
  const container = document.getElementById("sourcesList");
  container.innerHTML = sources.map(s => `<a href="${s.url}" target="_blank" rel="noopener">${s.name}</a>`).join("");
}

// ===== Term Tab Switching =====

document.getElementById("termTabs").addEventListener("click", (e) => {
  if (e.target.classList.contains("term-tab")) {
    document.querySelectorAll(".term-tab").forEach(t => t.classList.remove("active"));
    e.target.classList.add("active");
    selectedTerm = e.target.dataset.term;
    renderAll();
  }
});

// ===== Init =====

document.addEventListener("DOMContentLoaded", loadData);

// Auto-refresh every 30 minutes on the client side
setInterval(() => loadData(), 30 * 60 * 1000);
