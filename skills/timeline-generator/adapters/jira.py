"""Jira adapter — builds Schema from a Jira epic URL or issue key.

Uses JIRA_BASE_URL + JIRA_EMAIL + JIRA_API_TOKEN env vars. Falls back to stub schema.
"""

import base64
import json
import re
import sys
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _config import get as cfg_get  # noqa: E402


COLORS = ['#38bdf8', '#F4A261', '#3fb950', '#a78bfa', '#f471b5', '#fbbf24']


def _parse_key(s: str) -> tuple:
    m = re.match(r'^https?://([^/]+)/browse/([A-Z]+-\d+)', s)
    if m:
        return f'https://{m.group(1)}', m.group(2)
    m = re.match(r'^([A-Z]+-\d+)$', s.strip())
    if m:
        return cfg_get('JIRA_BASE_URL') or '', m.group(1)
    raise ValueError(f'Invalid Jira input: {s!r}')


def _api(base: str, path: str, params: dict = None) -> dict:
    token = cfg_get('JIRA_API_TOKEN')
    email = cfg_get('JIRA_EMAIL')
    if not token or not email:
        raise RuntimeError('JIRA_API_TOKEN and JIRA_EMAIL required. '
                           'Set via: python3 scripts/config.py init  OR  env vars. '
                           'Alternative: use --source manual')
    url = base.rstrip('/') + path
    if params:
        url += '?' + urllib.parse.urlencode(params)
    cred = base64.b64encode(f'{email}:{token}'.encode()).decode()
    req = urllib.request.Request(url)
    req.add_header('Authorization', f'Basic {cred}')
    req.add_header('Accept', 'application/json')
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())


def _classify_status(name: str) -> str:
    st = (name or '').lower()
    if st in ('done', 'closed', 'resolved', 'feito'):
        return 'done'
    if 'progress' in st or st == 'em progresso':
        return 'in-progress'
    if 'review' in st or st in ('revisão de código', 'revisao de codigo'):
        return 'in-review'
    if 'block' in st:
        return 'blocked'
    return 'pending'


def build(input_str: str, cli_args=None) -> dict:
    if not input_str:
        raise ValueError('Jira adapter needs --input URL or KEY')
    base, key = _parse_key(input_str)

    try:
        res = {}
        for jql in (f'"Epic Link" = {key}', f'parent = {key}'):
            try:
                res = _api(base, '/rest/api/3/search', {
                    'jql': jql,
                    'fields': 'summary,status,assignee,duedate,priority,issuetype',
                    'maxResults': 100,
                })
                if res.get('issues'):
                    break
            except Exception:
                continue
        issues = res.get('issues', [])
    except Exception as e:
        return _stub_schema(key, str(e))

    lanes_map = {}
    for it in issues:
        assignee = (it['fields'].get('assignee') or {}).get('displayName', 'Unassigned')
        lanes_map.setdefault(assignee, []).append(it)

    total_days = (cli_args and getattr(cli_args, 'days', None)) or max(70, len(issues) * 5)
    base_date = (cli_args and getattr(cli_args, 'base_date', None)) or date.today().isoformat()

    lanes = []
    for i, (assignee, items) in enumerate(lanes_map.items()):
        per_bar = max(1, total_days // max(1, len(items)))
        cursor, bars = 1, []
        for it in items:
            f = it['fields']
            span = [cursor, min(cursor + per_bar, total_days + 1)]
            cursor = span[1]
            bars.append({
                'id': it['key'].lower(),
                'label': f"{it['key']} {f['summary'][:40]}",
                'span': span,
                'status': _classify_status(f['status']['name']),
                'links': [{'label': it['key'], 'url': f"{base}/browse/{it['key']}"}],
            })
        lanes.append({'id': assignee.lower().replace(' ', '-'), 'label': assignee,
                      'color': COLORS[i % len(COLORS)], 'bars': bars})

    return {
        'meta': {
            'title': f'Epic {key}',
            'subtitle': 'Jira · epic timeline',
            'base_date': base_date,
            'total_days': total_days,
            'facts': [f'<strong>{len(issues)}</strong> issues', f'<strong>{len(lanes)}</strong> assignees'],
            'links': [{'label': key, 'url': f'{base}/browse/{key}'}],
            'milestones': [],
        },
        'lanes': lanes,
        'pins': [],
    }


def _stub_schema(key: str, err: str) -> dict:
    return {
        'meta': {
            'title': f'Epic {key} (stub)',
            'subtitle': f'Jira fetch falhou — {err[:80]}',
            'base_date': date.today().isoformat(),
            'total_days': 70,
            'facts': ['<strong style="color:#ff8a8a">Configure JIRA_BASE_URL+JIRA_EMAIL+JIRA_API_TOKEN ou use --source manual</strong>'],
            'milestones': [],
        },
        'lanes': [],
        'pins': [],
    }
