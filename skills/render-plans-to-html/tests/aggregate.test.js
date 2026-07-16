import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import { execSync } from 'node:child_process';
import os from 'node:os';
import path from 'node:path';
import { aggregate, parseTasks } from '../src/aggregate.js';

const fixtureMd = fs.readFileSync('tests/fixtures/plan-with-tasks.md', 'utf8');

describe('parseTasks', () => {
  it('finds Task headings with steps and files', () => {
    const tasks = parseTasks(fixtureMd, 'doc-0');
    expect(tasks).toHaveLength(3);
    expect(tasks[0].title).toBe('Foo refactor');
    expect(tasks[0].steps).toHaveLength(3);
    expect(tasks[0].steps.filter(s => s.done)).toHaveLength(1);
    expect(tasks[0].filesMentioned.sort()).toEqual(['src/bar.js', 'src/foo.js']);
  });

  it('detects keywords (refactor, e2e)', () => {
    const tasks = parseTasks(fixtureMd, 'doc-0');
    expect(tasks[0].keywords).toContain('refactor');
    expect(tasks[1].keywords).toContain('e2e');
    expect(tasks[2].keywords).toEqual([]);
  });

  it('falls back to flat checkboxes when no Task heading', () => {
    const md = '# Generic\n- [ ] foo\n- [x] bar';
    const tasks = parseTasks(md, 'doc-1');
    expect(tasks).toHaveLength(1);
    expect(tasks[0].steps).toHaveLength(2);
    expect(tasks[0].steps.filter(s => s.done)).toHaveLength(1);
  });

  it('marks task done only when all steps are done', () => {
    const tasks = parseTasks(fixtureMd, 'doc-0');
    expect(tasks[0].done).toBe(false);
    expect(tasks[2].done).toBe(true);
  });
});

describe('aggregate', () => {
  it('produces phase totals and per-doc rollups', async () => {
    const docs = [
      {
        id: 'd0',
        title: 'Plan',
        type: 'plan',
        rawMd: fixtureMd,
        signals: { severities: { CRITICAL: 1, HIGH: 0, MEDIUM: 2, LOW: 0 } },
      },
    ];
    const phase = await aggregate(docs, { gitDir: null });
    expect(phase.totals.tasksTotal).toBe(12);
    expect(phase.totals.tasksDone).toBe(2);
    expect(phase.totals.tasksPending).toBe(10);
    expect(phase.tasksPerDoc).toEqual([{ docId: 'd0', done: 2, total: 12 }]);
    expect(phase.severityTotals).toEqual({ CRITICAL: 1, HIGH: 0, MEDIUM: 2, LOW: 0 });
    expect(phase.severityByDoc).toEqual({
      d0: { CRITICAL: 1, HIGH: 0, MEDIUM: 2, LOW: 0 },
    });
    expect(phase.tasks).toHaveLength(3);
    expect(phase.burndownTimeline).toBe(null);
  });
});

describe('aggregate burndown', () => {
  it('builds a timeline from a tiny git repo', async () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'rph-burn-'));
    execSync('git init -q', { cwd: tmp });
    execSync('git config user.email t@t.local', { cwd: tmp });
    execSync('git config user.name T', { cwd: tmp });
    const file = path.join(tmp, 'PLAN.md');
    fs.writeFileSync(file, '## Task 1: A\n\n- [ ] s1\n- [ ] s2\n');
    execSync('git add PLAN.md && git commit -q -m c1', { cwd: tmp, shell: '/bin/bash' });
    fs.writeFileSync(file, '## Task 1: A\n\n- [x] s1\n- [ ] s2\n');
    execSync('git add PLAN.md && git commit -q -m c2', { cwd: tmp, shell: '/bin/bash' });
    fs.writeFileSync(file, '## Task 1: A\n\n- [x] s1\n- [x] s2\n');
    execSync('git add PLAN.md && git commit -q -m c3', { cwd: tmp, shell: '/bin/bash' });

    const docs = [
      { id: 'd0', title: 'Plan', type: 'plan', rawMd: fs.readFileSync(file, 'utf8'),
        path: file, signals: { severities: { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0 } } },
    ];
    const phase = await aggregate(docs, { gitDir: tmp, burndownCommits: 12 });
    expect(phase.burndownTimeline).not.toBeNull();
    expect(phase.burndownTimeline.length).toBeGreaterThanOrEqual(2);
    const last = phase.burndownTimeline[phase.burndownTimeline.length - 1];
    expect(last.done).toBe(2);
    expect(last.total).toBe(2);
  });

  it('returns null timeline outside a git repo', async () => {
    const docs = [
      { id: 'd0', title: 'P', type: 'plan', rawMd: '## Task 1: x\n- [ ] a\n', path: '/tmp/nope.md',
        signals: { severities: { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0 } } },
    ];
    const phase = await aggregate(docs, { gitDir: '/no/such/path' });
    expect(phase.burndownTimeline).toBe(null);
  });
});
