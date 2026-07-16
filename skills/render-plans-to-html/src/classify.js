import path from 'node:path';

const FILENAME_RULES = [
  { type: 'plan', pattern: /^(plan|implementation[-_]?plan)\.md$/i },
  { type: 'review', pattern: /^review\.md$/i },
  { type: 'requirements', pattern: /^requirements\.md$/i },
  { type: 'tasks', pattern: /^tasks\.md$/i },
  { type: 'research', pattern: /^research\.md$/i },
  { type: 'design', pattern: /^design\.md$/i },
  { type: 'verification', pattern: /^verification\.md$/i },
];

const CONTENT_RULES = [
  { type: 'plan', pattern: /implementation plan|## task \d+|^### task \d+/im },
  { type: 'review', pattern: /\b(critical|high|medium|low|severity)\b.*\bfinding\b|## findings/im },
  { type: 'requirements', pattern: /## (acceptance criteria|user stor(y|ies))/im },
  { type: 'tasks', pattern: /^- \[[ x]\]/m },
  { type: 'research', pattern: /## (sources|references|citations)/im },
];

export function classifyDoc(filename, content) {
  const base = path.basename(filename);
  for (const rule of FILENAME_RULES) {
    if (rule.pattern.test(base)) return rule.type;
  }
  for (const rule of CONTENT_RULES) {
    if (rule.pattern.test(content)) return rule.type;
  }
  return 'generic';
}
