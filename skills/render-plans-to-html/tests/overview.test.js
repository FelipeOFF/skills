import { describe, it, expect } from 'vitest';
import { buildOverview } from '../src/overview.js';
import { loadMessages } from '../src/i18n.js';

const phase = {
  totals: { tasksTotal: 12, tasksDone: 2, tasksPending: 10 },
  tasks: [],
  tasksPerDoc: [{ docId: 'd0', done: 2, total: 12 }],
  severityTotals: { CRITICAL: 1, HIGH: 0, MEDIUM: 2, LOW: 0 },
  severityByDoc: { d0: { CRITICAL: 1, HIGH: 0, MEDIUM: 2, LOW: 0 } },
  burndownTimeline: null,
};
const est = {
  totals: { tasksTotal: 12, tasksDone: 2, tasksPending: 10, secondsRemaining: 600 },
  tokens: { tokensIn: 30000, tokensOut: 10000 },
  perTask: [],
  perAgent: {
    opus:   { secondsRemaining: 600, costUsd: 1.5 },
    sonnet: { secondsRemaining: 600, costUsd: 0.3 },
    haiku:  { secondsRemaining: 600, costUsd: 0.05 },
    codex:  { secondsRemaining: 600, costUsd: 0.2 },
  },
};
const docTitles = { d0: 'Plan' };

describe('buildOverview', () => {
  const msgs = loadMessages('pt-BR');
  const html = buildOverview(phase, est, msgs, { defaultAgent: 'sonnet', docTitles });

  it('emits 6 number cards', () => {
    expect((html.match(/overview-card/g) || []).length).toBe(6);
  });

  it('emits 4 chart canvases with data-chart-config', () => {
    expect((html.match(/data-chart-type/g) || []).length).toBe(4);
  });

  it('emits inline SVG heatmap', () => {
    expect(html).toMatch(/<svg[^>]*class="heatmap"/);
    expect(html).toMatch(/heatmap-cell/);
  });

  it('localizes labels via messages', () => {
    expect(html).toContain('Tasks por documento');
    expect(html).toContain('Mapa de riscos');
  });

  it('renders the summary headline with plural agreement', () => {
    expect(html).toMatch(/Esta phase tem 12 tasks, 2 concluídas/);
    expect(html).toMatch(/risco crítico pendente|riscos críticos pendentes/);
  });

  it('shows summaryAllDone when nothing is pending', () => {
    const allDone = { ...phase, totals: { tasksTotal: 5, tasksDone: 5, tasksPending: 0 } };
    const out = buildOverview(allDone, { ...est, totals: { ...est.totals, secondsRemaining: 0 } }, msgs, { defaultAgent: 'sonnet', docTitles });
    expect(out).toMatch(/Todas as 5 tasks concluídas/);
  });
});
