"""Manual adapter — parses free-form task lists.

Formats (autodetect): bullets, numbered, plain, pipe-separated, markdown checklist.
Inline tags: @assignee #lane !blocked ?in-review ~done *in-progress
"""

import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _config import jira_url as _jira_url  # noqa: E402


TAG_RE = {
    'assignee': re.compile(r'@(\S+)'),
    'lane':     re.compile(r'#(\S+)'),
    'status':   re.compile(r'(!blocked|\?in-review|~done|\*in-progress)'),
    'url':      re.compile(r'https?://\S+'),
    'key':      re.compile(r'\b[A-Z]{2,5}-\d+\b'),
}
STATUS_TAG = {'!blocked': 'blocked', '?in-review': 'in-review', '~done': 'done', '*in-progress': 'in-progress'}
CHECKBOX = {'x': 'done', ' ': 'pending', '/': 'in-progress'}
COLORS = ['#38bdf8', '#F4A261', '#3fb950', '#a78bfa', '#f471b5', '#fbbf24']


def _parse_line(line: str) -> dict:
    raw = line.strip()
    if not raw:
        return None
    raw = re.sub(r'^(\d+\.|\-|\*|•)\s+', '', raw)
    status = 'pending'
    cb = re.match(r'^\[( |x|X|/)\]\s+(.+)$', raw)
    if cb:
        status = CHECKBOX.get(cb.group(1).lower(), 'pending')
        raw = cb.group(2)
    # Pipe-separated
    if '|' in raw and not re.search(r'\b[A-Z]{2,5}-\d+\b', raw.split('|')[0]):
        parts = [p.strip() for p in raw.split('|')]
        label = parts[0]
        if len(parts) > 1:
            status = parts[1] or status
        url = parts[2] if len(parts) > 2 else None
        return {'label': label, 'status': status,
                'links': [{'label': 'link', 'url': url}] if url else []}
    out = {'label': raw, 'status': status, 'links': []}
    for field in ('assignee', 'lane'):
        m = TAG_RE[field].search(raw)
        if m:
            out[field] = m.group(1)
            out['label'] = TAG_RE[field].sub('', out['label']).strip()
    s = TAG_RE['status'].search(raw)
    if s:
        out['status'] = STATUS_TAG[s.group(1)]
        out['label'] = TAG_RE['status'].sub('', out['label']).strip()
    u = TAG_RE['url'].search(raw)
    if u:
        out['links'].append({'label': 'link', 'url': u.group(0)})
        out['label'] = TAG_RE['url'].sub('', out['label']).strip()
    k = TAG_RE['key'].search(raw)
    if k:
        out['links'].insert(0, {'label': k.group(0), 'url': _jira_url(k.group(0))})
    return out


def build(input_str: str, cli_args=None) -> dict:
    text = input_str.strip()
    if text and '\n' not in text and len(text) < 500:
        p = Path(text)
        if p.exists() and p.is_file():
            text = p.read_text()
    if not text:
        text = sys.stdin.read()
    tasks = [t for t in (_parse_line(ln) for ln in text.splitlines()) if t and t['label']]
    if not tasks:
        raise ValueError('No tasks parsed from input')

    total_days = (cli_args and getattr(cli_args, 'days', None)) or max(28, len(tasks) * 3)
    base_date = (cli_args and getattr(cli_args, 'base_date', None)) or date.today().isoformat()

    lanes_map = {}
    for t in tasks:
        lanes_map.setdefault(t.get('lane') or t.get('assignee') or 'tarefas', []).append(t)

    lanes = []
    for i, (k, items) in enumerate(lanes_map.items()):
        per = max(1, total_days // max(1, len(items)))
        c, bars = 1, []
        for idx, t in enumerate(items):
            span = [c, min(c + per, total_days + 1)]
            c = span[1]
            slug = re.sub(r'[^a-z0-9]+', '-', (t['label'] or f'task-{idx}').lower())[:40]
            bars.append({
                'id': f'{slug}-{idx}',
                'label': t['label'][:60],
                'span': span,
                'status': t.get('status', 'pending'),
                'links': t.get('links', []),
            })
        lanes.append({'id': k.lower().replace(' ', '-'), 'label': k, 'color': COLORS[i % len(COLORS)], 'bars': bars})

    return {
        'meta': {
            'title': 'Lista de tarefas',
            'subtitle': 'Manual input',
            'base_date': base_date,
            'total_days': total_days,
            'facts': [f'<strong>{len(tasks)}</strong> tarefas', f'<strong>{len(lanes)}</strong> lanes'],
            'milestones': [],
        },
        'lanes': lanes,
        'pins': [],
    }
