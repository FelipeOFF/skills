const DICTIONARIES = {
  en: {
    sidebarTitle: 'Plans',
    searchPlaceholder: 'Search documents...',
    themeBtn: '🌓 Theme',
    copyBtn: 'Copy as prompt',
    copyDone: 'Copied!',
    referencesHeading: 'References',
    tasksMetric: 'Tasks',
    etaMetric: 'ETA',
    costMetric: 'Cost',
    overviewTitle: 'Overview',
    overviewSubtitle: 'Phase dashboard',
    cardTotalTasks: 'Total tasks',
    cardDone: 'Done ({percent}%)',
    cardEta: 'ETA · {agent}',
    cardCost: 'Cost · {agent}',
    cardCritical: 'Critical',
    cardHigh: 'High',
    chartBurndownTitle: 'Burndown',
    chartSeverityTitle: 'Severity distribution',
    chartTasksPerDocTitle: 'Tasks per document',
    chartHeatmapTitle: 'Risk heatmap',
    chartCostComparisonTitle: 'Cost & ETA per agent',
    summaryHeadline:
      'This phase has {total} tasks, {done} {doneWord} ({percent}%). ETA: {eta} via Claude {agent} (~$ {cost}) or {etaCodex} via Codex (~$ {costCodex}). {critWord}.',
    summaryNoTasks: 'No tasks tracked yet in this phase.',
    summaryAllDone: 'All {total} tasks completed. Nothing pending.',
    agentOpus: 'Opus',
    agentSonnet: 'Sonnet',
    agentHaiku: 'Haiku',
    agentCodex: 'Codex',
    docLabel: 'Document',
    docTypePlan: 'plan',
    docTypeReview: 'review',
    docTypeRequirements: 'requirements',
    docTypeTasks: 'tasks',
    docTypeResearch: 'research',
    docTypeDesign: 'design',
    docTypeVerification: 'verification',
    docTypeGeneric: 'doc',
    docTypeOverview: 'overview',
  },
  'pt-BR': {
    sidebarTitle: 'Planos',
    searchPlaceholder: 'Buscar documentos...',
    themeBtn: '🌓 Tema',
    copyBtn: 'Copiar como prompt',
    copyDone: 'Copiado!',
    referencesHeading: 'Referências',
    tasksMetric: 'Tasks',
    etaMetric: 'ETA',
    costMetric: 'Custo',
    overviewTitle: 'Visão geral',
    overviewSubtitle: 'Dashboard da phase',
    cardTotalTasks: 'Total de tasks',
    cardDone: 'Concluídas ({percent}%)',
    cardEta: 'ETA · {agent}',
    cardCost: 'Custo · {agent}',
    cardCritical: 'Críticos',
    cardHigh: 'Altos',
    chartBurndownTitle: 'Burndown',
    chartSeverityTitle: 'Distribuição de severidade',
    chartTasksPerDocTitle: 'Tasks por documento',
    chartHeatmapTitle: 'Mapa de riscos',
    chartCostComparisonTitle: 'Custo & ETA por agente',
    summaryHeadline:
      'Esta phase tem {total} tasks, {done} {doneWord} ({percent}%). Estimativa: {eta} via Claude {agent} (~US$ {cost}) ou {etaCodex} via Codex (~US$ {costCodex}). {critWord}.',
    summaryNoTasks: 'Nenhuma task rastreada nesta phase ainda.',
    summaryAllDone: 'Todas as {total} tasks concluídas. Nada pendente.',
    agentOpus: 'Opus',
    agentSonnet: 'Sonnet',
    agentHaiku: 'Haiku',
    agentCodex: 'Codex',
    docLabel: 'Documento',
    docTypePlan: 'plano',
    docTypeReview: 'revisão',
    docTypeRequirements: 'requisitos',
    docTypeTasks: 'tarefas',
    docTypeResearch: 'pesquisa',
    docTypeDesign: 'design',
    docTypeVerification: 'verificação',
    docTypeGeneric: 'doc',
    docTypeOverview: 'visão geral',
  },
  es: {
    sidebarTitle: 'Planes',
    searchPlaceholder: 'Buscar documentos...',
    themeBtn: '🌓 Tema',
    copyBtn: 'Copiar como prompt',
    copyDone: '¡Copiado!',
    referencesHeading: 'Referencias',
    tasksMetric: 'Tareas',
    etaMetric: 'ETA',
    costMetric: 'Coste',
    overviewTitle: 'Resumen',
    overviewSubtitle: 'Panel de la fase',
    cardTotalTasks: 'Tareas totales',
    cardDone: 'Hechas ({percent}%)',
    cardEta: 'ETA · {agent}',
    cardCost: 'Coste · {agent}',
    cardCritical: 'Críticos',
    cardHigh: 'Altos',
    chartBurndownTitle: 'Burndown',
    chartSeverityTitle: 'Distribución de severidad',
    chartTasksPerDocTitle: 'Tareas por documento',
    chartHeatmapTitle: 'Mapa de riesgos',
    chartCostComparisonTitle: 'Coste y ETA por agente',
    summaryHeadline:
      'Esta fase tiene {total} tareas, {done} {doneWord} ({percent}%). ETA: {eta} con Claude {agent} (~US$ {cost}) o {etaCodex} con Codex (~US$ {costCodex}). {critWord}.',
    summaryNoTasks: 'Aún no hay tareas registradas en esta fase.',
    summaryAllDone: 'Las {total} tareas están hechas. Nada pendiente.',
    agentOpus: 'Opus',
    agentSonnet: 'Sonnet',
    agentHaiku: 'Haiku',
    agentCodex: 'Codex',
    docLabel: 'Documento',
    docTypePlan: 'plan',
    docTypeReview: 'revisión',
    docTypeRequirements: 'requisitos',
    docTypeTasks: 'tareas',
    docTypeResearch: 'investigación',
    docTypeDesign: 'diseño',
    docTypeVerification: 'verificación',
    docTypeGeneric: 'doc',
    docTypeOverview: 'resumen',
  },
};

const PLURALS = {
  en: {
    done: { one: 'completed', other: 'completed' },
    crit: {
      zero: 'No critical risks',
      one: '1 critical risk pending',
      other: '{n} critical risks pending',
    },
  },
  'pt-BR': {
    done: { one: 'concluída', other: 'concluídas' },
    crit: {
      zero: 'Sem riscos críticos',
      one: '1 risco crítico pendente',
      other: '{n} riscos críticos pendentes',
    },
  },
  es: {
    done: { one: 'hecha', other: 'hechas' },
    crit: {
      zero: 'Sin riesgos críticos',
      one: '1 riesgo crítico pendiente',
      other: '{n} riesgos críticos pendientes',
    },
  },
};

const SUPPORTED = Object.keys(DICTIONARIES);

export function detectLang({ flag, env = process.env } = {}) {
  if (flag) return resolveTag(flag) || 'en';
  const raw = (env.LC_ALL || env.LANG || '').trim();
  return resolveTag(raw) || 'en';
}

function resolveTag(raw) {
  if (!raw) return null;
  const tag = raw.split('.')[0].replace('_', '-');
  if (DICTIONARIES[tag]) return tag;
  const prefix = tag.split('-')[0].toLowerCase();
  const match = SUPPORTED.find(k => k.toLowerCase() === prefix || k.toLowerCase().startsWith(prefix + '-'));
  return match || null;
}

function interpolate(tmpl, vars) {
  return String(tmpl).replace(/\{(\w+)\}/g, (_, k) => (k in vars ? vars[k] : `{${k}}`));
}

export function loadMessages(lang) {
  const dict = DICTIONARIES[lang] || DICTIONARIES.en;
  const plurals = PLURALS[lang] || PLURALS.en;
  return {
    lang,
    t(key, vars = {}) {
      const tmpl = dict[key] ?? DICTIONARIES.en[key] ?? key;
      return interpolate(tmpl, vars);
    },
    tp(key, count, vars = {}) {
      const forms = plurals[key] || PLURALS.en[key];
      if (!forms) return key;
      let form;
      if (count === 0 && forms.zero != null) form = forms.zero;
      else if (count === 1) form = forms.one;
      else form = forms.other;
      return interpolate(form, { ...vars, n: count });
    },
  };
}

export const SUPPORTED_LANGS = SUPPORTED;
