#!/usr/bin/env python3
"""timeline-generator: orchestrator. Reads Schema from adapters and renders HTML."""

import argparse
import importlib.util
import json
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL_ROOT = HERE.parent
TEMPLATE = SKILL_ROOT / 'template' / 'timeline.html.template'
TEMPLATE_JS = SKILL_ROOT / 'template' / 'timeline.js'
ADAPTERS = SKILL_ROOT / 'adapters'


def load_adapter(name: str):
    path = ADAPTERS / f'{name}.py'
    if not path.exists():
        raise ImportError(f'adapter not found: {path}')
    spec = importlib.util.spec_from_file_location(f'_tl_adapter_{name}', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def validate_schema(data: dict) -> None:
    meta = data.get('meta')
    if not meta:
        raise ValueError('schema.meta required')
    for k in ('title', 'base_date', 'total_days'):
        if k not in meta:
            raise ValueError(f'schema.meta.{k} required')
    try:
        datetime.strptime(meta['base_date'], '%Y-%m-%d')
    except Exception:
        raise ValueError('schema.meta.base_date must be YYYY-MM-DD')
    if not isinstance(meta['total_days'], int) or meta['total_days'] < 1:
        raise ValueError('schema.meta.total_days must be positive int')

    lanes = data.get('lanes', [])
    if not isinstance(lanes, list):
        raise ValueError('schema.lanes must be list')
    for lane in lanes:
        if 'id' not in lane or 'label' not in lane:
            raise ValueError(f'lane missing id/label: {lane}')
        bars = lane.get('bars', [])
        for bar in bars:
            if 'id' not in bar or 'span' not in bar:
                raise ValueError(f'bar missing id/span: {bar}')
            s, e = bar['span']
            if not (1 <= s < e <= meta['total_days'] + 1):
                raise ValueError(f"bar span out of range [1, {meta['total_days']+1}]: {bar}")
        # Reject overlaps within the same lane
        sorted_bars = sorted(bars, key=lambda b: b['span'][0])
        for i in range(1, len(sorted_bars)):
            prev, cur = sorted_bars[i-1], sorted_bars[i]
            if cur['span'][0] < prev['span'][1]:
                raise ValueError(
                    f"bars overlap in lane '{lane['id']}': "
                    f"{prev['id']} {prev['span']} ↔ {cur['id']} {cur['span']}. "
                    "Put parallel work in separate lanes or fix spans."
                )


def render(data: dict, out_path: Path) -> None:
    data.setdefault('meta', {})['updated_at'] = datetime.utcnow().isoformat() + 'Z'
    html = (TEMPLATE.read_text()
            .replace('{{TITLE}}', data['meta'].get('title', 'Timeline'))
            .replace('{{TIMELINE_DATA_JSON}}', json.dumps(data, ensure_ascii=False, indent=2))
            .replace('{{TIMELINE_JS}}', TEMPLATE_JS.read_text()))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(html)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', required=True, choices=['gsd', 'jira', 'linear', 'manual', 'json'])
    ap.add_argument('--input', default=None, help='URL, path, or inline text depending on source')
    ap.add_argument('--out', default='docs/timeline.html')
    ap.add_argument('--days', type=int, default=None, help='Force total_days')
    ap.add_argument('--title', default=None)
    ap.add_argument('--subtitle', default=None)
    ap.add_argument('--base-date', default=None)
    ap.add_argument('--redesign', action='store_true')
    args = ap.parse_args()

    data = load_adapter(args.source).build(args.input or '', cli_args=args)

    # CLI overrides applied last
    overrides = {'title': args.title, 'subtitle': args.subtitle,
                 'total_days': args.days, 'base_date': args.base_date}
    for k, v in overrides.items():
        if v:
            data['meta'][k] = v

    validate_schema(data)

    if args.redesign:
        print('[redesign-marker] data ready; invoke ui-ux-pro-max with schema:')
        print(json.dumps(data['meta'], ensure_ascii=False))

    out_path = Path(args.out).resolve()
    render(data, out_path)
    lanes = data.get('lanes', [])
    bars = sum(len(l.get('bars', [])) for l in lanes)
    print(f'OK  {out_path}  ({len(lanes)} lanes, {bars} bars, {data["meta"]["total_days"]} days)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
