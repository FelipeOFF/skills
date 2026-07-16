#!/usr/bin/env python3
"""
timeline-generator: config management.

Stores per-skill configuration in `~/.claude/skills/timeline-generator/config.json`
so the user does not need to export env vars each session.

Resolution order (highest priority first):
  1. Explicit env var (JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN, LINEAR_API_KEY)
  2. config.json in the skill folder
  3. Missing → caller asks the user (via AskUserQuestion in the workflow)

Usage:
  config.py show                       Print resolved values (masks tokens).
  config.py set KEY=VAL [KEY=VAL ...]  Set keys in config.json.
  config.py unset KEY [KEY ...]        Remove keys from config.json.
  config.py init                       Interactive prompts (stdin) for empty fields.
  config.py get KEY                    Print resolved value for a single key.
"""

from __future__ import annotations
import argparse
import json
import os
import sys
from pathlib import Path

CFG = Path(__file__).resolve().parent.parent / 'config.json'

KNOWN = ['JIRA_BASE_URL', 'JIRA_EMAIL', 'JIRA_API_TOKEN', 'LINEAR_API_KEY']
SECRETS = {'JIRA_API_TOKEN', 'LINEAR_API_KEY'}


def load() -> dict:
    return json.loads(CFG.read_text()) if CFG.exists() else {}


def save(data: dict) -> None:
    CFG.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    CFG.chmod(0o600)


def resolve(key: str):
    """Env wins; fallback to config.json."""
    return os.environ.get(key) or load().get(key) or None


def mask(key: str, val: str) -> str:
    if not val:
        return ''
    if key in SECRETS:
        return val[:4] + '…' + val[-2:] if len(val) > 8 else '***'
    return val


def cmd_show() -> int:
    cfg = load()
    print(f'config.json: {CFG}')
    print(f'  exists: {CFG.exists()}')
    print()
    print('Resolved values (env > config.json):')
    for k in KNOWN:
        v = resolve(k) or ''
        src = 'env' if os.environ.get(k) else ('config' if cfg.get(k) else '—')
        print(f'  {k:18}  [{src:6}]  {mask(k, v)}')
    return 0


def cmd_set(pairs) -> int:
    cfg = load()
    for p in pairs:
        if '=' not in p:
            print(f'Invalid pair (need KEY=VAL): {p}', file=sys.stderr)
            return 2
        k, v = p.split('=', 1)
        k = k.strip().upper()
        if k not in KNOWN:
            print(f'Warning: unknown key {k!r} (will store anyway)', file=sys.stderr)
        cfg[k] = v.strip()
    save(cfg)
    print(f'Saved {len(pairs)} key(s) to {CFG}')
    return 0


def cmd_unset(keys) -> int:
    cfg = load()
    for k in keys:
        cfg.pop(k.strip().upper(), None)
    save(cfg)
    print(f'Removed {len(keys)} key(s) from {CFG}')
    return 0


def cmd_init() -> int:
    cfg = load()
    print('Interactive config — leave blank to skip a field.\n')
    prompts = {
        'JIRA_BASE_URL':  'Jira base URL (e.g. https://yourcompany.atlassian.net)',
        'JIRA_EMAIL':     'Jira email (atlassian account)',
        'JIRA_API_TOKEN': 'Jira API token (id.atlassian.com → Security → API tokens)',
        'LINEAR_API_KEY': 'Linear API key (linear.app/settings/api, format lin_api_...)',
    }
    for k, msg in prompts.items():
        existing = cfg.get(k) or os.environ.get(k)
        hint = f' (current: {mask(k, existing)})' if existing else ''
        v = input(f'{msg}{hint}\n> ').strip()
        if v:
            cfg[k] = v
    save(cfg)
    print(f'\nSaved to {CFG}')
    return 0


def cmd_get(key: str) -> int:
    v = resolve(key.strip().upper())
    if not v:
        return 1
    print(v)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest='cmd', required=True)
    sp.add_parser('show')
    s_set = sp.add_parser('set')
    s_set.add_argument('pairs', nargs='+')
    s_unset = sp.add_parser('unset')
    s_unset.add_argument('keys', nargs='+')
    sp.add_parser('init')
    s_get = sp.add_parser('get')
    s_get.add_argument('key')
    args = ap.parse_args()

    if args.cmd == 'show':  return cmd_show()
    if args.cmd == 'set':   return cmd_set(args.pairs)
    if args.cmd == 'unset': return cmd_unset(args.keys)
    if args.cmd == 'init':  return cmd_init()
    if args.cmd == 'get':   return cmd_get(args.key)
    return 1


if __name__ == '__main__':
    sys.exit(main())
