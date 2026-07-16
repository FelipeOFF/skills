const SEVERITY_KEYS = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];

export function buildOverview(phase, estimate, messages, { defaultAgent = 'sonnet', docTitles = {} } = {}) {
  const t = messages.t.bind(messages);
  const lang = messages.lang || 'en';
  const total = phase.totals.tasksTotal;
  const done = phase.totals.tasksDone;
  const percent = total === 0 ? 0 : Math.round((done / total) * 100);
  const agentLabel = t('agent' + cap(defaultAgent));
  const eta = formatHours(estimate.perAgent[defaultAgent].secondsRemaining);
  const cost = formatMoney(estimate.perAgent[defaultAgent].costUsd, lang);
  const etaCodex = formatHours(estimate.perAgent.codex.secondsRemaining);
  const costCodex = formatMoney(estimate.perAgent.codex.costUsd, lang);
  const criticals = phase.severityTotals.CRITICAL || 0;
  const highs = phase.severityTotals.HIGH || 0;

  const cards = [
    card(t('cardTotalTasks'), String(total), ''),
    card(t('cardDone', { percent }), `${done}/${total}`, ''),
    card(t('cardEta', { agent: agentLabel }), eta, ''),
    card(t('cardCost', { agent: agentLabel }), `$${cost}`, ''),
    card(t('cardCritical'), String(criticals), ''),
    card(t('cardHigh'), String(highs), ''),
  ].join('');

  const summary = renderSummary(phase, estimate, messages, { defaultAgent, agentLabel, percent, eta, cost, etaCodex, costCodex, criticals });

  const burndownCfg = buildBurndownCfg(phase, t);
  const severityCfg = buildSeverityCfg(phase, t);
  const tasksDocCfg = buildTasksPerDocCfg(phase, t, docTitles);
  const costCfg = buildCostComparisonCfg(estimate, t);

  const heatmap = renderHeatmap(phase, t, docTitles);

  return `
<div class="overview-grid">${cards}</div>
<div class="overview-summary">${summary}</div>
<div class="charts-grid">
  <div class="chart-card"><h3>${t('chartBurndownTitle')}</h3><canvas data-chart-type="line" data-chart-config='${jsonAttr(burndownCfg)}'></canvas></div>
  <div class="chart-card"><h3>${t('chartSeverityTitle')}</h3><canvas data-chart-type="doughnut" data-chart-config='${jsonAttr(severityCfg)}'></canvas></div>
  <div class="chart-card"><h3>${t('chartTasksPerDocTitle')}</h3><canvas data-chart-type="bar" data-chart-config='${jsonAttr(tasksDocCfg)}'></canvas></div>
  <div class="chart-card"><h3>${t('chartCostComparisonTitle')}</h3><canvas data-chart-type="bar" data-chart-config='${jsonAttr(costCfg)}'></canvas></div>
</div>
<div class="chart-card"><h3>${t('chartHeatmapTitle')}</h3>${heatmap}</div>
`;
}

function renderSummary(phase, est, m, vars) {
  const total = phase.totals.tasksTotal;
  if (total === 0) return m.t('summaryNoTasks');
  if (phase.totals.tasksPending === 0) return m.t('summaryAllDone', { total });
  const doneWord = m.tp('done', phase.totals.tasksDone);
  const critWord = m.tp('crit', vars.criticals);
  return m.t('summaryHeadline', {
    total, done: phase.totals.tasksDone, doneWord, percent: vars.percent,
    eta: vars.eta, agent: vars.agentLabel, cost: vars.cost,
    etaCodex: vars.etaCodex, costCodex: vars.costCodex, critWord,
  });
}

function buildBurndownCfg(phase, t) {
  const labels = [];
  const data = [];
  if (phase.burndownTimeline?.length) {
    for (const p of phase.burndownTimeline) {
      labels.push(new Date(p.ts).toISOString().slice(0, 10));
      data.push(p.total - p.done);
    }
  } else {
    labels.push(t('docLabel'));
    data.push(phase.totals.tasksPending);
  }
  return {
    type: 'line',
    data: { labels, datasets: [{ label: t('tasksMetric'), data, borderColor: '#d97757', backgroundColor: 'rgba(217,119,87,0.15)', tension: 0.3, fill: true }] },
    options: { responsive: true, plugins: { legend: { display: false } } },
  };
}

function buildSeverityCfg(phase, t) {
  return {
    type: 'doughnut',
    data: {
      labels: SEVERITY_KEYS,
      datasets: [{ data: SEVERITY_KEYS.map(k => phase.severityTotals[k] || 0), backgroundColor: ['#dc2626','#ea580c','#ca8a04','#65a30d'] }],
    },
    options: { responsive: true, plugins: { legend: { position: 'bottom' } } },
  };
}

function buildTasksPerDocCfg(phase, t, docTitles) {
  const labels = phase.tasksPerDoc.map(p => docTitles[p.docId] || p.docId);
  const done = phase.tasksPerDoc.map(p => p.done);
  const todo = phase.tasksPerDoc.map(p => p.total - p.done);
  return {
    type: 'bar',
    data: {
      labels,
      datasets: [
        { label: 'Done', data: done, backgroundColor: '#65a30d' },
        { label: 'Pending', data: todo, backgroundColor: '#d97757' },
      ],
    },
    options: { responsive: true, scales: { x: { stacked: true }, y: { stacked: true } } },
  };
}

function buildCostComparisonCfg(est, t) {
  const labels = ['Opus', 'Sonnet', 'Haiku', 'Codex'];
  const cost = ['opus','sonnet','haiku','codex'].map(a => est.perAgent[a].costUsd);
  const eta = ['opus','sonnet','haiku','codex'].map(a => Math.round(est.perAgent[a].secondsRemaining / 36) / 100);
  return {
    type: 'bar',
    data: {
      labels,
      datasets: [
        { label: 'USD', data: cost, backgroundColor: '#d97757', yAxisID: 'y' },
        { label: 'Hours', data: eta, backgroundColor: '#3b82f6', yAxisID: 'y1' },
      ],
    },
    options: {
      responsive: true,
      scales: {
        y:  { type: 'linear', position: 'left',  title: { display: true, text: 'USD' } },
        y1: { type: 'linear', position: 'right', grid: { drawOnChartArea: false }, title: { display: true, text: 'Hours' } },
      },
    },
  };
}

function renderHeatmap(phase, t, docTitles) {
  const docs = phase.tasksPerDoc.map(p => p.docId);
  if (docs.length === 0) return '<div style="color:var(--muted)">No data</div>';
  const cellW = Math.max(60, Math.floor(640 / docs.length));
  const cellH = 40;
  const padL = 100, padT = 20;
  const w = padL + cellW * docs.length;
  const h = padT + cellH * SEVERITY_KEYS.length + 20;
  const max = Math.max(1, ...docs.flatMap(d => SEVERITY_KEYS.map(k => phase.severityByDoc[d]?.[k] || 0)));
  const cells = [];
  SEVERITY_KEYS.forEach((sev, ri) => {
    docs.forEach((docId, ci) => {
      const v = phase.severityByDoc[docId]?.[sev] || 0;
      const a = max === 0 ? 0 : v / max;
      cells.push(`<rect class="heatmap-cell" x="${padL + ci * cellW}" y="${padT + ri * cellH}" width="${cellW}" height="${cellH}" fill="rgba(220,38,38,${a.toFixed(2)})"/>`);
      if (v > 0) cells.push(`<text class="heatmap-label" x="${padL + ci * cellW + cellW/2}" y="${padT + ri * cellH + cellH/2 + 4}" text-anchor="middle">${v}</text>`);
    });
    cells.push(`<text class="heatmap-label" x="${padL - 8}" y="${padT + ri * cellH + cellH/2 + 4}" text-anchor="end">${sev}</text>`);
  });
  docs.forEach((docId, ci) => {
    const label = (docTitles[docId] || docId).slice(0, 12);
    cells.push(`<text class="heatmap-label" x="${padL + ci * cellW + cellW/2}" y="${padT - 6}" text-anchor="middle">${escapeXml(label)}</text>`);
  });
  return `<svg class="heatmap" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg">${cells.join('')}</svg>`;
}

function card(label, value, sub) {
  return `<div class="overview-card"><span class="label">${escapeHtml(label)}</span><span class="value">${escapeHtml(value)}</span><span class="sub">${escapeHtml(sub)}</span></div>`;
}

function jsonAttr(obj) {
  return JSON.stringify(obj).replace(/'/g, '&apos;');
}
function escapeHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
function escapeXml(s) { return escapeHtml(s); }
function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

function formatHours(seconds) {
  if (!seconds) return '0h';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h === 0) return `${m}min`;
  if (m === 0) return `${h}h`;
  return `${h}h${String(m).padStart(2, '0')}`;
}

function formatMoney(usd, lang) {
  try {
    return new Intl.NumberFormat(lang, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(usd);
  } catch {
    return usd.toFixed(2);
  }
}
