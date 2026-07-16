import { describe, it, expect } from 'vitest';
import { discoverPaths } from '../src/discover.js';
import path from 'node:path';

const FIXTURES = path.resolve('tests/fixtures/folder');

describe('discoverPaths', () => {
  it('returns single MD file when given a file path', async () => {
    const result = await discoverPaths([path.join(FIXTURES, 'a.md')]);
    expect(result).toEqual([path.join(FIXTURES, 'a.md')]);
  });

  it('walks folder recursively for *.md', async () => {
    const result = await discoverPaths([FIXTURES]);
    expect(result.sort()).toEqual([
      path.join(FIXTURES, 'a.md'),
      path.join(FIXTURES, 'sub/b.md'),
    ].sort());
  });

  it('ignores non-md files', async () => {
    const result = await discoverPaths([FIXTURES]);
    expect(result.find(p => p.endsWith('.txt'))).toBeUndefined();
  });

  it('throws when path does not exist', async () => {
    await expect(discoverPaths(['/no/such/path'])).rejects.toThrow(/not found/);
  });
});
