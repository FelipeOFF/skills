"""Shared config resolver for adapters. Env wins; falls back to config.json."""
from __future__ import annotations
import json
import os
from pathlib import Path

_CFG = Path(__file__).resolve().parent.parent / 'config.json'


def get(key):
    env = os.environ.get(key)
    if env:
        return env
    if _CFG.exists():
        try:
            return json.loads(_CFG.read_text()).get(key)
        except Exception:
            return None
    return None


def jira_url(card):
    base = (get('JIRA_BASE_URL') or '').rstrip('/')
    return f'{base}/browse/{card}' if base else '#'
