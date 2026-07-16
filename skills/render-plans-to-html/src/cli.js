import { Command } from 'commander';
import fs from 'node:fs/promises';
import fsSync from 'node:fs';
import path from 'node:path';
import matter from 'gray-matter';
import { discoverPaths } from './discover.js';
import { classifyDoc } from './classify.js';
import { extractSignals } from './extract.js';
import { renderMarkdown } from './render.js';
import { assembleHtml } from './assemble.js';
import { aggregate } from './aggregate.js';
import { estimate } from './estimate.js';
import { buildOverview } from './overview.js';
import { detectLang, loadMessages } from './i18n.js';

export function parseArgs(argv) {
  const program = new Command();
  program
    .argument('<paths>', 'comma-separated MD files or folder')
    .option('--out <file>', 'output HTML file')
    .option('--title <title>', 'document title')
    .option('--theme <theme>', 'default theme: light|dark|auto', 'auto')
    .option('--lang <lang>', 'force UI language (pt-BR|en|es)')
    .option('--default-agent <agent>', 'default agent for headline metrics: opus|sonnet|haiku|codex', 'sonnet')
    .option('--burndown-commits <n>', 'commits per file in burndown lookup', v => parseInt(v, 10), 12)
    .option('--seconds-per-step-small <n>',  'seconds per small step',  v => parseFloat(v))
    .option('--seconds-per-step-medium <n>', 'seconds per medium step', v => parseFloat(v))
    .option('--seconds-per-step-large <n>',  'seconds per large step',  v => parseFloat(v))
    .option('--tokens-per-step-small <n>',  'tokens per small step',  v => parseFloat(v))
    .option('--tokens-per-step-medium <n>', 'tokens per medium step', v => parseFloat(v))
    .option('--tokens-per-step-large <n>',  'tokens per large step',  v => parseFloat(v))
    .option('--price-opus-in <usd>',   'opus input USD/M',   v => parseFloat(v))
    .option('--price-opus-out <usd>',  'opus output USD/M',  v => parseFloat(v))
    .option('--price-sonnet-in <usd>', 'sonnet input USD/M', v => parseFloat(v))
    .option('--price-sonnet-out <usd>','sonnet output USD/M',v => parseFloat(v))
    .option('--price-haiku-in <usd>',  'haiku input USD/M',  v => parseFloat(v))
    .option('--price-haiku-out <usd>', 'haiku output USD/M', v => parseFloat(v))
    .option('--price-codex-in <usd>',  'codex input USD/M',  v => parseFloat(v))
    .option('--price-codex-out <usd>', 'codex output USD/M', v => parseFloat(v))
    .option('--config <file>', 'JSON config file with the same keys as flags')
    .allowExcessArguments(false)
    .exitOverride();

  const parsed = program.parse(['node', 'render-plans', ...argv]);
  const opts = parsed.opts();
  const rawPaths = parsed.args[0];
  const paths = rawPaths.split(',').map(p => p.trim()).filter(Boolean);
  const out = opts.out || path.join(process.cwd(), 'plans.html');

  const fileCfg = opts.config ? JSON.parse(fsSync.readFileSync(opts.config, 'utf8')) : {};
  const config = mergeFlagsToConfig(fileCfg, opts);

  return {
    paths, out,
    title: opts.title,
    theme: opts.theme,
    lang: opts.lang,
    defaultAgent: opts.defaultAgent,
    burndownCommits: opts.burndownCommits,
    config,
  };
}

function setIfDef(obj, dotted, value) {
  if (value === undefined || Number.isNaN(value)) return;
  const parts = dotted.split('.');
  let cur = obj;
  for (let i = 0; i < parts.length - 1; i++) cur = cur[parts[i]] = cur[parts[i]] || {};
  cur[parts[parts.length - 1]] = value;
}

function mergeFlagsToConfig(file, o) {
  const cfg = JSON.parse(JSON.stringify(file || {}));
  setIfDef(cfg, 'secondsPerStep.small',  o.secondsPerStepSmall);
  setIfDef(cfg, 'secondsPerStep.medium', o.secondsPerStepMedium);
  setIfDef(cfg, 'secondsPerStep.large',  o.secondsPerStepLarge);
  setIfDef(cfg, 'tokensPerStep.small',  o.tokensPerStepSmall);
  setIfDef(cfg, 'tokensPerStep.medium', o.tokensPerStepMedium);
  setIfDef(cfg, 'tokensPerStep.large',  o.tokensPerStepLarge);
  setIfDef(cfg, 'pricing.opus.in',   o.priceOpusIn);
  setIfDef(cfg, 'pricing.opus.out',  o.priceOpusOut);
  setIfDef(cfg, 'pricing.sonnet.in', o.priceSonnetIn);
  setIfDef(cfg, 'pricing.sonnet.out',o.priceSonnetOut);
  setIfDef(cfg, 'pricing.haiku.in',  o.priceHaikuIn);
  setIfDef(cfg, 'pricing.haiku.out', o.priceHaikuOut);
  setIfDef(cfg, 'pricing.codex.in',  o.priceCodexIn);
  setIfDef(cfg, 'pricing.codex.out', o.priceCodexOut);
  return cfg;
}

export async function run(opts) {
  const files = await discoverPaths(opts.paths);
  if (files.length === 0) throw new Error('No markdown files found.');

  const lang = opts.lang ? opts.lang : detectLang({ env: process.env });
  const messages = loadMessages(lang);

  const docs = [];
  for (let i = 0; i < files.length; i++) {
    const file = files[i];
    const raw = await fs.readFile(file, 'utf8');
    const { content, data } = matter(raw);
    const type = classifyDoc(file, content);
    const signals = extractSignals(content);
    const bodyHtml = renderMarkdown(content);
    const baseName = path.basename(file, '.md');
    const title = data.title || signals.toc[0]?.text || baseName;
    docs.push({
      id: `doc-${i}-${baseName.replace(/[^a-z0-9]/gi, '-')}`,
      title, type, bodyHtml, signals,
      rawMd: content,
      path: file,
    });
  }

  const docTitles = Object.fromEntries(docs.map(d => [d.id, d.title]));
  const phase = await aggregate(docs, { gitDir: path.dirname(files[0]), burndownCommits: opts.burndownCommits });
  const est = estimate(phase.tasks, opts.config || {});
  const overviewHtml = buildOverview(phase, est, messages, { defaultAgent: opts.defaultAgent || 'sonnet', docTitles });

  const html = assembleHtml(docs, { title: opts.title || messages.t('overviewTitle'), overviewHtml, messages });
  await fs.writeFile(opts.out, html, 'utf8');
  console.log(`Rendered ${docs.length} document(s) → ${opts.out}`);
}
