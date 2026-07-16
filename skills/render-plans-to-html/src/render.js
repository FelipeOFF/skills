import { Marked } from 'marked';

function slug(text) {
  return text.toLowerCase().replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '-');
}

function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

const renderer = {
  heading({ tokens, depth }) {
    const text = this.parser.parseInline(tokens);
    const plain = tokens.map(t => t.text || '').join('');
    return `<h${depth} id="${slug(plain)}">${text}</h${depth}>\n`;
  },
  listitem(item) {
    if (item.task) {
      const cls = item.checked ? 'done' : 'todo';
      const label = item.checked ? '✓' : '○';
      const body = this.parser.parse(item.tokens);
      return `<li class="task-item"><span class="pill ${cls}">${label}</span> ${body}</li>\n`;
    }
    return `<li>${this.parser.parse(item.tokens)}</li>\n`;
  },
  code({ text, lang }) {
    if (lang === 'mermaid') {
      return `<div class="mermaid">${escapeHtml(text)}</div>\n`;
    }
    const language = lang ? ` class="language-${lang}"` : '';
    return `<pre><code${language}>${escapeHtml(text)}</code></pre>\n`;
  },
};

export function renderMarkdown(md) {
  const m = new Marked({ gfm: true, breaks: false });
  m.use({ renderer });
  return m.parse(md);
}
