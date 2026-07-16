"""GSD adapter — reads `.planning/STATE.md`, `ROADMAP.md`, `MILESTONES.md`.

Conventions detected:
- STATE.md frontmatter: milestone, milestone_name, status, progress
- ROADMAP.md:           ### Phase N — Title + Status line + Card Jira links
- MILESTONES.md:        ## vX.Y Title (Complete: YYYY-MM-DD)
"""

import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _config import jira_url as _jira_url  # noqa: E402


STATUS_MAP = {
    'complete': 'done', 'completed': 'done', 'done': 'done',
    'active': 'in-progress', 'in-progress': 'in-progress', 'wip': 'in-progress',
    'blocked': 'blocked',
}


def _read(p: Path) -> str:
    return p.read_text() if p.exists() else ''


def _frontmatter(text: str) -> dict:
    m = re.match(r'^---\s*\n(.+?)\n---\s*\n', text, re.DOTALL)
    if not m:
        return {}
    out = {}
    for line in m.group(1).splitlines():
        if ':' not in line:
            continue
        k, v = line.split(':', 1)
        v = v.strip().strip('"\'')
        if v and not v.startswith(('-', '#')):
            out[k.strip()] = v
    return out


def _phases_from_roadmap(text: str) -> list:
    pat = re.compile(r'^###\s+Phase\s+(\d+)\s*[—\-:]\s*(.+?)$', re.MULTILINE)
    chunks = list(pat.finditer(text))
    phases = []
    for i, m in enumerate(chunks):
        body = text[m.end(): chunks[i + 1].start() if i + 1 < len(chunks) else len(text)]
        status_m = re.search(r'\*\*Status:?\*\*\s*([A-Za-z_\-]+)', body)
        cards = re.findall(r'\b[A-Z]{2,5}-\d+\b', body)
        phases.append({
            'num': int(m.group(1)),
            'title': m.group(2).strip(),
            'status': (status_m.group(1).lower() if status_m else 'pending').replace('_', '-'),
            'cards': list(dict.fromkeys(cards)),
        })
    return phases


def _milestones_done(text: str) -> list:
    pat = re.compile(r'^##\s+(v[\d.]+)\s+(.+?)\s+\(.*?(\d{4}-\d{2}-\d{2})\)', re.MULTILINE)
    return [{'ver': m.group(1), 'title': m.group(2), 'date': m.group(3)} for m in pat.finditer(text)]


def build(input_str: str, cli_args=None) -> dict:
    root = Path(input_str).resolve() if input_str else Path.cwd()
    planning = root / '.planning'
    if not planning.exists():
        for p in [root] + list(root.parents):
            if (p / '.planning').exists():
                planning, root = p / '.planning', p
                break
        else:
            raise FileNotFoundError(f'No .planning/ found in {root}')

    fm = _frontmatter(_read(planning / 'STATE.md'))
    phases = _phases_from_roadmap(_read(planning / 'ROADMAP.md'))
    closed = _milestones_done(_read(planning / 'MILESTONES.md'))

    title = fm.get('milestone_name') or fm.get('milestone') or root.name
    cur_milestone = fm.get('milestone', 'current')

    base_date = (cli_args and getattr(cli_args, 'base_date', None)) or date.today().isoformat()
    total_days = (cli_args and getattr(cli_args, 'days', None)) or max(70, len(phases) * 7 + 14)

    lanes = []
    if phases:
        bar_days = max(1, total_days // max(1, len(phases)))
        bars = []
        cursor = 1
        for p in phases:
            span = [cursor, min(cursor + bar_days, total_days + 1)]
            cursor = span[1]
            bars.append({
                'id': f"phase-{p['num']}",
                'label': f"P{p['num']} {p['title']}",
                'span': span,
                'status': STATUS_MAP.get(p['status'], 'pending'),
                'links': [{'label': c, 'url': _jira_url(c)} for c in p['cards'][:3]],
            })
        lanes = [{'id': 'phases', 'label': f'Milestone {cur_milestone}', 'color': '#38bdf8', 'bars': bars}]

    return {
        'meta': {
            'title': title,
            'subtitle': f'GSD · {root.name}',
            'base_date': base_date,
            'total_days': total_days,
            'show_milestones': False,
            'facts': [
                f'<strong>{len(phases)}</strong> phases',
                f'<strong>{len(closed)}</strong> milestones closed',
                f'Status: <strong>{fm.get("status", "unknown")}</strong>',
            ],
            'milestones': [],
        },
        'lanes': lanes,
        'pins': [],
    }
