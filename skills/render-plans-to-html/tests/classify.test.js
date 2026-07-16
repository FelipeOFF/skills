import { describe, it, expect } from 'vitest';
import { classifyDoc } from '../src/classify.js';

describe('classifyDoc', () => {
  it('detects PLAN by filename', () => {
    expect(classifyDoc('PLAN.md', '# anything')).toBe('plan');
  });

  it('detects REVIEW by filename', () => {
    expect(classifyDoc('REVIEW.md', '# x')).toBe('review');
  });

  it('detects REQUIREMENTS by filename', () => {
    expect(classifyDoc('REQUIREMENTS.md', '# x')).toBe('requirements');
  });

  it('detects tasks by filename', () => {
    expect(classifyDoc('tasks.md', '# x')).toBe('tasks');
  });

  it('detects RESEARCH by filename', () => {
    expect(classifyDoc('RESEARCH.md', '# x')).toBe('research');
  });

  it('detects plan by content keyword "Implementation Plan"', () => {
    expect(classifyDoc('foo.md', '# Whatever Implementation Plan\n## Task 1')).toBe('plan');
  });

  it('detects review by content with severity markers', () => {
    expect(classifyDoc('foo.md', '## Findings\n- **CRITICAL**: bug\n- **HIGH**: leak')).toBe('review');
  });

  it('falls back to generic', () => {
    expect(classifyDoc('foo.md', '# Some Article\nText here.')).toBe('generic');
  });

  it('classifies dated plan filenames', () => {
    expect(classifyDoc('2026-05-10-feature.md', '# Implementation Plan\n')).toBe('plan');
  });
});
