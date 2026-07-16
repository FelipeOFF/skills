"""Linear adapter — builds Schema from a Linear issue/project URL via GraphQL.

Requires: LINEAR_API_KEY env var (lin_api_xxxx) — get at linear.app/settings/api
"""

import json
import re
import sys
import urllib.request
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _config import get as cfg_get  # noqa: E402


GQL_URL = 'https://api.linear.app/graphql'
STATE_MAP = {'completed': 'done', 'canceled': 'done', 'started': 'in-progress', 'unstarted': 'pending'}
COLORS = ['#38bdf8', '#F4A261', '#3fb950', '#a78bfa', '#f471b5']


def _parse(s: str) -> dict:
    m = re.match(r'^https?://linear\.app/([^/]+)/issue/([A-Z]+-\d+)', s)
    if m:
        return {'kind': 'issue', 'team': m.group(1), 'id': m.group(2)}
    m = re.match(r'^https?://linear\.app/([^/]+)/project/([^/?]+)', s)
    if m:
        return {'kind': 'project', 'team': m.group(1), 'id': m.group(2)}
    m = re.match(r'^([A-Z]+-\d+)$', s.strip())
    if m:
        return {'kind': 'issue', 'id': m.group(1)}
    raise ValueError(f'Invalid Linear input: {s!r}')


def _gql(query: str, variables: dict = None) -> dict:
    key = cfg_get('LINEAR_API_KEY')
    if not key:
        raise RuntimeError('LINEAR_API_KEY required. Set via: python3 scripts/config.py init  OR  env var. '
                           'Get one at linear.app/settings/api')
    payload = json.dumps({'query': query, 'variables': variables or {}}).encode()
    req = urllib.request.Request(GQL_URL, data=payload)
    req.add_header('Authorization', key)
    req.add_header('Content-Type', 'application/json')
    with urllib.request.urlopen(req, timeout=15) as r:
        body = json.loads(r.read())
    if 'errors' in body:
        raise RuntimeError(f'Linear GQL: {body["errors"]}')
    return body['data']


def _project_issues(project_id: str) -> list:
    q = '''query($id: String!){ project(id: $id){ name issues(first: 100){ nodes {
      identifier title state{ name type } assignee{ name } dueDate url
    } } } }'''
    return _gql(q, {'id': project_id})['project']['issues']['nodes']


def build(input_str: str, cli_args=None) -> dict:
    if not input_str:
        raise ValueError('Linear adapter needs --input URL or KEY')
    p = _parse(input_str)
    try:
        if p['kind'] == 'project':
            issues = _project_issues(p['id'])
        else:
            q = '''query($id: String!){ issue(id: $id){ identifier title state{ name type } assignee{ name } dueDate url } }'''
            issues = [_gql(q, {'id': p['id']})['issue']]
    except Exception as e:
        return _stub(input_str, str(e))

    lanes_map = {}
    for it in issues:
        a = (it.get('assignee') or {}).get('name', 'Unassigned')
        lanes_map.setdefault(a, []).append(it)

    total_days = (cli_args and getattr(cli_args, 'days', None)) or max(70, len(issues) * 5)
    base_date = (cli_args and getattr(cli_args, 'base_date', None)) or date.today().isoformat()

    lanes = []
    for i, (a, items) in enumerate(lanes_map.items()):
        per = max(1, total_days // max(1, len(items)))
        c, bars = 1, []
        for it in items:
            span = [c, min(c + per, total_days + 1)]
            c = span[1]
            stype = (it.get('state') or {}).get('type', '').lower()
            bars.append({
                'id': it['identifier'].lower(),
                'label': f"{it['identifier']} {it['title'][:40]}",
                'span': span,
                'status': STATE_MAP.get(stype, 'pending'),
                'links': [{'label': it['identifier'], 'url': it.get('url', '#')}],
            })
        lanes.append({'id': a.lower().replace(' ', '-'), 'label': a, 'color': COLORS[i % len(COLORS)], 'bars': bars})

    return {
        'meta': {
            'title': f"Linear · {p.get('id', 'timeline')}",
            'subtitle': 'Linear project',
            'base_date': base_date,
            'total_days': total_days,
            'facts': [f'<strong>{len(issues)}</strong> issues', f'<strong>{len(lanes)}</strong> assignees'],
            'milestones': [],
        },
        'lanes': lanes,
        'pins': [],
    }


def _stub(inp, err):
    return {
        'meta': {
            'title': 'Linear (stub)',
            'subtitle': f'Linear fetch falhou — {err[:80]}',
            'base_date': date.today().isoformat(),
            'total_days': 70,
            'facts': ['<strong style="color:#ff8a8a">LINEAR_API_KEY env var requerida</strong>'],
            'milestones': [],
        },
        'lanes': [],
        'pins': [],
    }
