import fs from 'node:fs/promises';
import path from 'node:path';

export async function discoverPaths(inputs) {
  const out = [];
  for (const input of inputs) {
    let stat;
    try {
      stat = await fs.stat(input);
    } catch {
      throw new Error(`Path not found: ${input}`);
    }
    if (stat.isFile()) {
      if (input.endsWith('.md')) out.push(path.resolve(input));
    } else if (stat.isDirectory()) {
      const found = await walkDir(input);
      out.push(...found);
    }
  }
  return out;
}

async function walkDir(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const results = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...await walkDir(full));
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      results.push(path.resolve(full));
    }
  }
  return results;
}
