import { describe, it, expect } from 'vitest';
import { extractSignals } from '../src/extract.js';

describe('extractSignals', () => {
  it('counts checkboxes', () => {
    const md = '- [ ] todo a\n- [x] done b\n- [ ] todo c';
    const r = extractSignals(md);
    expect(r.checkboxes).toEqual({ done: 1, todo: 2, total: 3 });
  });

  it('extracts severity tags', () => {
    const md = '**CRITICAL**: x\n**HIGH**: y\n**LOW**: z\n**HIGH**: w';
    expect(extractSignals(md).severities).toEqual({
      CRITICAL: 1, HIGH: 2, MEDIUM: 0, LOW: 1,
    });
  });

  it('builds heading ToC', () => {
    const md = '# Top\n## Sub A\n## Sub B\n### Deep';
    const toc = extractSignals(md).toc;
    expect(toc).toEqual([
      { level: 1, text: 'Top', slug: 'top' },
      { level: 2, text: 'Sub A', slug: 'sub-a' },
      { level: 2, text: 'Sub B', slug: 'sub-b' },
      { level: 3, text: 'Deep', slug: 'deep' },
    ]);
  });

  it('collects external links as refs', () => {
    const md = 'See [docs](https://example.com/d) and [src](./local.md).';
    const refs = extractSignals(md).refs;
    expect(refs).toContainEqual({ text: 'docs', url: 'https://example.com/d' });
    expect(refs.find(r => r.url === './local.md')).toBeUndefined();
  });

  it('extracts mermaid blocks', () => {
    const md = 'before\n```mermaid\ngraph TD; A-->B\n```\nafter';
    const r = extractSignals(md);
    expect(r.mermaid).toEqual(['graph TD; A-->B']);
  });
});
