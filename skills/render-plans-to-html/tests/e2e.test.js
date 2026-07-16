import { describe, it, expect, beforeAll } from 'vitest';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { run } from '../src/cli.js';

describe('e2e v0.2', () => {
  let outFile;
  beforeAll(async () => {
    outFile = path.join(os.tmpdir(), `rph-${Date.now()}.html`);
    await run({
      paths: ['tests/fixtures/plan-sample.md', 'tests/fixtures/review-sample.md', 'tests/fixtures/plan-with-tasks.md'],
      out: outFile,
      title: 'E2E Test',
      theme: 'auto',
      lang: 'pt-BR',
      defaultAgent: 'sonnet',
      burndownCommits: 12,
      config: {},
    });
  });

  it('writes the output HTML', async () => {
    const stat = await fs.stat(outFile);
    expect(stat.size).toBeGreaterThan(1000);
  });

  it('prepends the Overview section with charts and heatmap', async () => {
    const html = await fs.readFile(outFile, 'utf8');
    expect(html).toMatch(/data-target="overview"/);
    expect(html).toMatch(/data-chart-type="line"/);
    expect(html).toMatch(/data-chart-type="doughnut"/);
    expect(html).toMatch(/data-chart-type="bar"/);
    expect(html).toMatch(/<svg[^>]*class="heatmap"/);
  });

  it('localizes chrome to pt-BR', async () => {
    const html = await fs.readFile(outFile, 'utf8');
    expect(html).toMatch(/Buscar documentos/);
    expect(html).toMatch(/Referências/);
  });

  it('keeps the underlying docs intact', async () => {
    const html = await fs.readFile(outFile, 'utf8');
    expect(html).toMatch(/plan-sample/);
    expect(html).toMatch(/review-sample/);
  });
});
