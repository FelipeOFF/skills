import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ASSET_DIR = path.join(__dirname, 'assets');
const readAsset = (name) => fs.readFileSync(path.join(ASSET_DIR, name), 'utf8');

export function buildHtmlShell({ title, navHtml, docsHtml, messages }) {
  const styles = readAsset('styles.css');
  const overviewCss = readAsset('overview.css');
  const hljsCss = readAsset('highlight.css');
  const hljsJs = readAsset('highlight.min.js');
  const mermaidJs = readAsset('mermaid.min.js');
  const chartJs = readAsset('chart.umd.min.js');
  const clientJs = readAsset('client.js');
  const lang = messages?.lang || 'en';
  const search = messages ? messages.t('searchPlaceholder') : 'Search documents...';
  const themeLabel = messages ? messages.t('themeBtn') : '🌓 Theme';
  const copyIdle = messages ? messages.t('copyBtn') : 'Copy as prompt';
  const copyDone = messages ? messages.t('copyDone') : 'Copied!';
  return `<!doctype html>
<html lang="${escapeAttr(lang)}">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${escapeHtml(title)}</title>
<style>${styles}\n${overviewCss}\n${hljsCss}</style>
</head>
<body>
<div class="app">
  <aside class="sidebar">
    <h1>${escapeHtml(title)}</h1>
    <input type="search" placeholder="${escapeAttr(search)}" />
    <nav>${navHtml}</nav>
  </aside>
  <main class="main">${docsHtml}</main>
</div>
<button class="theme-toggle">${escapeHtml(themeLabel)}</button>
<button class="copy-prompt" data-idle-text="${escapeAttr(copyIdle)}" data-done-text="${escapeAttr(copyDone)}">${escapeHtml(copyIdle)}</button>
<script>${hljsJs}</script>
<script>hljs.highlightAll();</script>
<script>${mermaidJs}</script>
<script>${chartJs}</script>
<script>${clientJs}</script>
</body>
</html>`;
}

function escapeHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
function escapeAttr(s) { return escapeHtml(s); }
