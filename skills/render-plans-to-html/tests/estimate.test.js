import { describe, it, expect } from 'vitest';
import { estimate, classify, DEFAULTS } from '../src/estimate.js';

const t = (over = {}) => ({ id: 't', title: 'T', docId: 'd', steps: [{text:'s',done:false}], filesMentioned: [], keywords: [], done: false, ...over });

describe('classify', () => {
  it('small: ≤3 steps, ≤1 file, no keyword', () => {
    expect(classify(t({ steps: [1,2,3].map(()=>({text:'',done:false})), filesMentioned: ['a'] }))).toBe('small');
  });
  it('medium: 4-7 steps', () => {
    expect(classify(t({ steps: Array(5).fill({text:'',done:false}) }))).toBe('medium');
  });
  it('medium: 2-5 files', () => {
    expect(classify(t({ filesMentioned: ['a','b','c'] }))).toBe('medium');
  });
  it('large: ≥8 steps', () => {
    expect(classify(t({ steps: Array(8).fill({text:'',done:false}) }))).toBe('large');
  });
  it('large: keyword wins', () => {
    expect(classify(t({ keywords: ['refactor'] }))).toBe('large');
  });
});

describe('estimate', () => {
  it('skips done steps and sums seconds', () => {
    const tasks = [
      t({ steps: [{text:'a',done:true},{text:'b',done:false},{text:'c',done:false}] }),
    ];
    const r = estimate(tasks);
    expect(r.totals.tasksTotal).toBe(3);
    expect(r.totals.tasksDone).toBe(1);
    expect(r.totals.tasksPending).toBe(2);
    expect(r.totals.secondsRemaining).toBe(2 * DEFAULTS.secondsPerStep.small);
  });

  it('computes per-agent USD cost from token totals', () => {
    const tasks = [t({ steps: Array(5).fill({text:'',done:false}) })];
    const r = estimate(tasks);
    expect(r.perAgent.sonnet.costUsd).toBeGreaterThan(0);
    expect(r.perAgent.opus.costUsd).toBeGreaterThan(r.perAgent.sonnet.costUsd);
    expect(r.perAgent.haiku.costUsd).toBeLessThan(r.perAgent.sonnet.costUsd);
  });

  it('respects config overrides', () => {
    const tasks = [t({ steps: [{text:'',done:false}] })];
    const r = estimate(tasks, { secondsPerStep: { small: 999, medium: 999, large: 999 } });
    expect(r.totals.secondsRemaining).toBe(999);
  });

  it('handles zero-task input', () => {
    const r = estimate([]);
    expect(r.totals).toEqual({ tasksTotal: 0, tasksDone: 0, tasksPending: 0, secondsRemaining: 0 });
    expect(r.perAgent.sonnet.costUsd).toBe(0);
  });
});
