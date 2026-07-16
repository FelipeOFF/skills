import { execFileSync } from 'node:child_process';
import path from 'node:path';

const KEYWORD_RE = /\b(refactor|vendor|e2e|migration|architecture)\b/i;
const TASK_HEADING_RE = /^#{2,3}\s+Task\s+([\w.-]+)\s*:\s*(.+?)\s*$/i;
const FILES_BLOCK_RE = /\*\*Files:\*\*([\s\S]*?)(?=\n#{1,6}\s|\n- \[|\n\*\*|\n$)/i;
const FILE_PATH_RE = /[`"']([^\s`"']+\.[a-z0-9]+)[`"']/gi;
const STEP_RE = /^- \[( |x)\]\s+(.+)$/gim;

export function parseTasks(md, docId) {
  const lines = md.split('\n');
  const tasks = [];
  let current = null;
  let buffer = [];

  const flush = () => {
    if (!current) return;
    const body = buffer.join('\n');
    current.steps = collectSteps(body);
    current.filesMentioned = collectFiles(body);
    const titleAndSteps = current.title + '\n' + current.steps.map(s => s.text).join('\n');
    const m = titleAndSteps.match(KEYWORD_RE);
    current.keywords = m ? [m[1].toLowerCase()] : [];
    current.done = current.steps.length > 0 && current.steps.every(s => s.done);
    tasks.push(current);
    current = null;
    buffer = [];
  };

  for (const line of lines) {
    const m = TASK_HEADING_RE.exec(line);
    if (m) {
      flush();
      current = { id: `${docId}-task-${m[1]}`, title: m[2].trim(), docId, steps: [], filesMentioned: [], keywords: [], done: false };
    } else if (current) {
      buffer.push(line);
    }
  }
  flush();

  if (tasks.length === 0) {
    const steps = collectSteps(md);
    if (steps.length > 0) {
      tasks.push({
        id: `${docId}-task-all`,
        title: 'Checklist',
        docId,
        steps,
        filesMentioned: [],
        keywords: [],
        done: steps.every(s => s.done),
      });
    }
  }
  return tasks;
}

function collectSteps(body) {
  const out = [];
  STEP_RE.lastIndex = 0;
  let m;
  while ((m = STEP_RE.exec(body)) !== null) {
    out.push({ text: m[2].trim(), done: m[1].toLowerCase() === 'x' });
  }
  return out;
}

function collectFiles(body) {
  const filesMatch = body.match(FILES_BLOCK_RE);
  if (!filesMatch) return [];
  const block = filesMatch[1];
  const set = new Set();
  FILE_PATH_RE.lastIndex = 0;
  let m;
  while ((m = FILE_PATH_RE.exec(block)) !== null) set.add(m[1]);
  return Array.from(set);
}

export async function aggregate(docs, options = {}) {
  const tasksAll = [];
  const tasksPerDoc = [];
  const severityByDoc = {};
  const severityTotals = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0 };

  for (const d of docs) {
    const tasks = d.rawMd ? parseTasks(d.rawMd, d.id) : [];
    const stepsTotal = tasks.reduce((n, t) => n + t.steps.length, 0);
    const stepsDone = tasks.reduce((n, t) => n + t.steps.filter(s => s.done).length, 0);
    tasksAll.push(...tasks);
    tasksPerDoc.push({ docId: d.id, done: stepsDone, total: stepsTotal });
    severityByDoc[d.id] = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, ...d.signals?.severities };
    for (const k of Object.keys(severityTotals)) severityTotals[k] += severityByDoc[d.id][k] || 0;
  }

  const tasksTotal = tasksPerDoc.reduce((n, p) => n + p.total, 0);
  const tasksDone = tasksPerDoc.reduce((n, p) => n + p.done, 0);

  let burndownTimeline = null;
  if (options.gitDir) {
    burndownTimeline = await computeBurndown(docs, options);
  }

  return {
    totals: { tasksTotal, tasksDone, tasksPending: tasksTotal - tasksDone },
    tasks: tasksAll,
    tasksPerDoc,
    severityTotals,
    severityByDoc,
    burndownTimeline,
  };
}

async function computeBurndown(docs, options) {
  const cwd = options.gitDir;
  const cap = options.burndownCommits || 12;
  let inRepo;
  try {
    execFileSync('git', ['rev-parse', '--git-dir'], { cwd, stdio: 'ignore' });
    inRepo = true;
  } catch { inRepo = false; }
  if (!inRepo) return null;

  const docsWithPath = docs.filter(d => d.path);
  if (docsWithPath.length === 0) return null;

  const commitMap = new Map();
  let order = 0;
  for (const d of docsWithPath) {
    const rel = path.relative(cwd, d.path);
    let log;
    try {
      log = execFileSync('git', ['log', '--reverse', `-${cap}`, '--pretty=%H|%ct', '--', rel], { cwd, encoding: 'utf8' });
    } catch { continue; }
    const lines = log.trim().split('\n').filter(Boolean);
    for (const ln of lines) {
      const [hash, ct] = ln.split('|');
      if (!commitMap.has(hash)) commitMap.set(hash, { hash, ts: parseInt(ct, 10) * 1000, order: order++ });
    }
  }

  for (const commit of commitMap.values()) {
    let total = 0, done = 0;
    for (const d of docsWithPath) {
      const rel = path.relative(cwd, d.path);
      let blob;
      try {
        blob = execFileSync('git', ['show', `${commit.hash}:${rel}`], { cwd, encoding: 'utf8' });
      } catch { continue; }
      const tasks = parseTasks(blob, d.id);
      for (const t of tasks) {
        total += t.steps.length;
        done += t.steps.filter(s => s.done).length;
      }
    }
    commit.total = total;
    commit.done = done;
  }

  const timeline = Array.from(commitMap.values())
    .filter(c => c.total != null)
    .sort((a, b) => (a.ts - b.ts) || (a.order - b.order))
    .map(c => ({ ts: c.ts, hash: c.hash, done: c.done, total: c.total }));

  return timeline.length >= 2 ? timeline : null;
}
