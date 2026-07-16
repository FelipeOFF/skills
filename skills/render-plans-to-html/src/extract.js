const SEVERITIES = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];

export function extractSignals(md) {
  return {
    checkboxes: countCheckboxes(md),
    severities: countSeverities(md),
    toc: buildToc(md),
    refs: collectRefs(md),
    mermaid: extractMermaidBlocks(md),
  };
}

function countCheckboxes(md) {
  const todo = (md.match(/^- \[ \]/gm) || []).length;
  const done = (md.match(/^- \[x\]/gim) || []).length;
  return { todo, done, total: todo + done };
}

function countSeverities(md) {
  const out = Object.fromEntries(SEVERITIES.map(s => [s, 0]));
  const re = /\*\*(CRITICAL|HIGH|MEDIUM|LOW)\*\*/g;
  let m;
  while ((m = re.exec(md)) !== null) out[m[1]]++;
  return out;
}

function buildToc(md) {
  const lines = md.split('\n');
  const toc = [];
  let inFence = false;
  for (const line of lines) {
    if (/^```/.test(line)) inFence = !inFence;
    if (inFence) continue;
    const m = /^(#{1,6})\s+(.+?)\s*$/.exec(line);
    if (m) {
      const level = m[1].length;
      const text = m[2].replace(/[#*`]/g, '').trim();
      const slug = text.toLowerCase().replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '-');
      toc.push({ level, text, slug });
    }
  }
  return toc;
}

function collectRefs(md) {
  const refs = [];
  const re = /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g;
  let m;
  while ((m = re.exec(md)) !== null) refs.push({ text: m[1], url: m[2] });
  return refs;
}

function extractMermaidBlocks(md) {
  const blocks = [];
  const re = /```mermaid\n([\s\S]*?)```/g;
  let m;
  while ((m = re.exec(md)) !== null) blocks.push(m[1].trim());
  return blocks;
}
