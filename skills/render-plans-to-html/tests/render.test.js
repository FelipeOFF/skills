import { describe, it, expect } from 'vitest';
import { renderMarkdown } from '../src/render.js';

describe('renderMarkdown', () => {
  it('renders headings with stable slugs', () => {
    const html = renderMarkdown('## Hello World');
    expect(html).toMatch(/<h2 id="hello-world">Hello World<\/h2>/);
  });

  it('renders checkboxes as status pills', () => {
    const html = renderMarkdown('- [x] done\n- [ ] todo');
    expect(html).toMatch(/class="pill done"/);
    expect(html).toMatch(/class="pill todo"/);
  });

  it('wraps mermaid blocks in <div class="mermaid">', () => {
    const html = renderMarkdown('```mermaid\ngraph TD; A-->B\n```');
    expect(html).toMatch(/<div class="mermaid">graph TD; A--&gt;B<\/div>/);
  });

  it('adds language class to code blocks', () => {
    const html = renderMarkdown('```javascript\nconst x = 1;\n```');
    expect(html).toMatch(/<code class="language-javascript">/);
  });
});
