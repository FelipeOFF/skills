import { describe, it, expect } from 'vitest';
import { assembleHtml } from '../src/assemble.js';

describe('assembleHtml', () => {
  it('produces a self-contained HTML with <html>, <style>, <script>', () => {
    const docs = [{
      id: 'doc-0', title: 'Plan', type: 'plan',
      bodyHtml: '<h1>Plan</h1>',
      signals: { checkboxes: { todo: 1, done: 0, total: 1 }, severities: { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0 }, toc: [], refs: [], mermaid: [] },
    }];
    const html = assembleHtml(docs, { title: 'Test' });
    expect(html).toMatch(/<!doctype html>/i);
    expect(html).toContain('<style>');
    expect(html).toContain('<script>');
    expect(html).toContain('<h1>Plan</h1>');
    expect(html).toContain('Test');
  });

  it('embeds nav entry per doc with type badge', () => {
    const docs = [
      { id: 'd0', title: 'A', type: 'plan', bodyHtml: '<p>a</p>', signals: emptySignals() },
      { id: 'd1', title: 'B', type: 'review', bodyHtml: '<p>b</p>', signals: emptySignals() },
    ];
    const html = assembleHtml(docs, { title: 'X' });
    expect(html).toMatch(/data-target="d0"/);
    expect(html).toMatch(/data-target="d1"/);
    expect(html).toMatch(/class="doc-type">plan/);
    expect(html).toMatch(/class="doc-type">review/);
  });
});

function emptySignals() {
  return { checkboxes: { todo: 0, done: 0, total: 0 }, severities: { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0 }, toc: [], refs: [], mermaid: [] };
}

import { loadMessages } from '../src/i18n.js';

describe('assembleHtml with overview', () => {
  it('prepends an overview synthetic doc', () => {
    const docs = [
      { id: 'd0', title: 'A', type: 'plan', bodyHtml: '<p>a</p>', signals: emptySignals() },
    ];
    const html = assembleHtml(docs, { title: 'X', overviewHtml: '<div data-marker="ov"></div>', messages: loadMessages('pt-BR') });
    expect(html).toMatch(/data-target="overview"/);
    expect(html).toMatch(/data-marker="ov"/);
    expect(html).toMatch(/Referências|References/);
  });
});
