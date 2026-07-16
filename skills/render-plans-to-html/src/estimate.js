export const DEFAULTS = {
  secondsPerStep: { small: 30, medium: 60, large: 120 },
  tokensPerStep: { small: 1500, medium: 3500, large: 8000 },
  inOutRatio: { in: 0.75, out: 0.25 },
  pricing: {
    opus:   { in: 15,   out: 75 },
    sonnet: { in: 3,    out: 15 },
    haiku:  { in: 0.80, out: 4 },
    codex:  { in: 2,    out: 8 },
  },
};

const KEYWORDS_LARGE = new Set(['refactor', 'vendor', 'e2e', 'migration', 'architecture']);

export function classify(task) {
  if (task.keywords?.some(k => KEYWORDS_LARGE.has(k))) return 'large';
  const steps = task.steps?.length || 0;
  const files = task.filesMentioned?.length || 0;
  if (steps >= 8) return 'large';
  if (steps >= 4 || (files >= 2 && files <= 5)) return 'medium';
  return 'small';
}

function mergeConfig(over = {}) {
  return {
    secondsPerStep: { ...DEFAULTS.secondsPerStep, ...over.secondsPerStep },
    tokensPerStep: { ...DEFAULTS.tokensPerStep, ...over.tokensPerStep },
    inOutRatio: { ...DEFAULTS.inOutRatio, ...over.inOutRatio },
    pricing: {
      opus:   { ...DEFAULTS.pricing.opus,   ...over.pricing?.opus },
      sonnet: { ...DEFAULTS.pricing.sonnet, ...over.pricing?.sonnet },
      haiku:  { ...DEFAULTS.pricing.haiku,  ...over.pricing?.haiku },
      codex:  { ...DEFAULTS.pricing.codex,  ...over.pricing?.codex },
    },
  };
}

export function estimate(tasks, configOver = {}) {
  const cfg = mergeConfig(configOver);
  let tasksTotal = 0, tasksDone = 0, secondsRemaining = 0, tokensIn = 0, tokensOut = 0;
  const perTask = [];
  for (const task of tasks) {
    const c = classify(task);
    const steps = task.steps || [];
    tasksTotal += steps.length;
    const doneSteps = steps.filter(s => s.done).length;
    tasksDone += doneSteps;
    const pendingSteps = steps.length - doneSteps;
    const secs = pendingSteps * cfg.secondsPerStep[c];
    const tokensTotal = pendingSteps * cfg.tokensPerStep[c];
    secondsRemaining += secs;
    tokensIn += tokensTotal * cfg.inOutRatio.in;
    tokensOut += tokensTotal * cfg.inOutRatio.out;
    perTask.push({ id: task.id, complexity: c, seconds: secs, tokensIn: tokensTotal * cfg.inOutRatio.in, tokensOut: tokensTotal * cfg.inOutRatio.out });
  }
  const perAgent = {};
  for (const [agent, p] of Object.entries(cfg.pricing)) {
    const cost = (tokensIn * p.in + tokensOut * p.out) / 1_000_000;
    perAgent[agent] = { secondsRemaining, costUsd: Math.round(cost * 100) / 100 };
  }
  return {
    totals: { tasksTotal, tasksDone, tasksPending: tasksTotal - tasksDone, secondsRemaining },
    tokens: { tokensIn, tokensOut },
    perTask,
    perAgent,
  };
}
