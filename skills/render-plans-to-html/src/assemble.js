import { buildHtmlShell } from './template.js';
import { loadMessages } from './i18n.js';

export function assembleHtml(docs, opts = {}) {
  const { title = 'Plans', overviewHtml = null, messages = loadMessages('en') } = opts;
  const allDocs = overviewHtml
    ? [{ id: 'overview', type: 'overview', title: messages.t('overviewTitle'), bodyHtml: overviewHtml, signals: { checkboxes: { todo: 0, done: 0, total: 0 }, severities: { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0 }, toc: [], refs: [], mermaid: [] } }, ...docs]
    : docs;

  const navHtml = allDocs.map(d =>
    `<a href="#${d.id}" data-target="${d.id}"><span class="doc-type">${docTypeLabel(d.type, messages)}</span>${escapeHtml(d.title)}</a>`
  ).join('\n');

  const docsHtml = allDocs.map(d => `
<section class="doc" id="${d.id}">
  <header class="doc-header">
    <h1>${escapeHtml(d.title)} <span class="doc-type">${docTypeLabel(d.type, messages)}</span></h1>
    ${renderMetrics(d.signals, messages)}
  </header>
  ${d.bodyHtml}
  ${renderRefs(d.signals.refs, messages)}
</section>
  `).join('\n');

  return buildHtmlShell({ title, navHtml, docsHtml, messages });
}

function renderMetrics(s, m) {
  const parts = [];
  if (s.checkboxes && s.checkboxes.total > 0) {
    parts.push(`<span class="metric">${m.t('tasksMetric')} <strong>${s.checkboxes.done}/${s.checkboxes.total}</strong></span>`);
  }
  for (const k of ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']) {
    if (s.severities && s.severities[k] > 0) {
      parts.push(`<span class="metric"><span class="severity-${k}">${k}</span> <strong>${s.severities[k]}</strong></span>`);
    }
  }
  if (parts.length === 0) return '';
  return `<div class="metrics">${parts.join('')}</div>`;
}

function renderRefs(refs, m) {
  if (!refs || refs.length === 0) return '';
  const items = refs.map(r => `<li><a href="${r.url}" target="_blank" rel="noopener">${escapeHtml(r.text)}</a> — <code>${escapeHtml(r.url)}</code></li>`).join('');
  return `<aside class="refs"><h3>${m.t('referencesHeading')}</h3><ul>${items}</ul></aside>`;
}

function escapeHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function docTypeLabel(type, messages) {
  const key = 'docType' + type.charAt(0).toUpperCase() + type.slice(1);
  const label = messages.t(key);
  return escapeHtml(label === key ? type : label);
}
