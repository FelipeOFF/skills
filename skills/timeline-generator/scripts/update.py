#!/usr/bin/env python3
"""timeline-generator: incremental update / hook-driven refresh.

Modes:
  --auto      Re-run stored adapter (config in `<out>.tlconfig.json`).
  --note MSG  Patch bars matching freeform note:
                "PROJ-N done" / "Phase N complete" / "PR #N merged"
  --watch P   Only act if P mtime > stored last_check.
"""

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
GENERATE = HERE / 'generate.py'

DATA_RE = re.compile(
    r'(<script id="timeline-data" type="application/json">\s*)(.*?)(\s*</script>)',
    re.DOTALL,
)


def read_inline_json(html_path: Path) -> dict:
    m = DATA_RE.search(html_path.read_text())
    if not m:
        raise RuntimeError(f'No <script id="timeline-data"> found in {html_path}')
    return json.loads(m.group(2))


def write_inline_json(html_path: Path, data: dict) -> None:
    new_block = json.dumps(data, ensure_ascii=False, indent=2)
    html = DATA_RE.sub(lambda m: m.group(1) + new_block + m.group(3),
                       html_path.read_text(), count=1)
    html_path.write_text(html)


def _iter_bars(data: dict):
    for lane in data.get('lanes', []):
        for bar in lane.get('bars', []):
            yield bar


def apply_note(data: dict, note: str) -> int:
    """Returns number of bars patched to done."""
    note = note.strip()
    patched = 0

    def set_done(bar):
        nonlocal patched
        if bar.get('status') != 'done':
            bar['status'] = 'done'
            patched += 1

    # Phase N done/complete
    m = re.search(r'phase\s+(\d+)\s+(complete|done|finish|concluido|concluído)', note, re.I)
    if m:
        target = f'phase-{m.group(1)}'
        for bar in _iter_bars(data):
            if bar['id'] == target:
                set_done(bar)

    # PROJ-N done|complete|merged
    for m in re.finditer(r'([A-Z]{2,5}-\d+)\s+(done|complete|merged|concluido|concluído)', note, re.I):
        key = m.group(1)
        for bar in _iter_bars(data):
            haystack = bar.get('label', '') + ' ' + ' '.join(l.get('label', '') for l in bar.get('links', []))
            if key in haystack:
                set_done(bar)

    # PR #N merged
    for m in re.finditer(r'PR\s*#?(\d+)\s+merged', note, re.I):
        needle = f'/pull/{m.group(1)}'
        for bar in _iter_bars(data):
            for link in bar.get('links', []):
                if needle in link.get('url', ''):
                    set_done(bar)

    if patched:
        data.setdefault('meta', {})['updated_at'] = datetime.utcnow().isoformat() + 'Z'
    return patched


def regen_auto(html_path: Path) -> int:
    cfg_path = html_path.with_suffix(html_path.suffix + '.tlconfig.json')
    if not cfg_path.exists():
        print(f'[update] no .tlconfig.json next to {html_path.name}; cannot --auto')
        return 1
    cfg = json.loads(cfg_path.read_text())
    cmd = ['python3', str(GENERATE)] + cfg.get('args', [])
    print(f'[update] regen: {" ".join(cmd)}')
    return subprocess.call(cmd)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='docs/timeline.html')
    ap.add_argument('--auto', action='store_true')
    ap.add_argument('--note', default=None)
    ap.add_argument('--watch', default=None)
    args = ap.parse_args()

    html_path = Path(args.out).resolve()
    if not html_path.exists():
        print(f'[update] {html_path} does not exist; nothing to update')
        return 0

    if args.watch:
        watch_path = Path(args.watch)
        if not watch_path.exists():
            return 0
        marker = html_path.with_suffix(html_path.suffix + '.last_check')
        last = float(marker.read_text()) if marker.exists() else 0.0
        cur = watch_path.stat().st_mtime
        if cur <= last:
            return 0
        marker.write_text(str(cur))

    if args.auto:
        return regen_auto(html_path)

    if args.note:
        data = read_inline_json(html_path)
        n = apply_note(data, args.note)
        if n:
            write_inline_json(html_path, data)
            print(f'[update] {n} bar(s) patched · {args.note!r}')
        else:
            print(f'[update] no bars matched note {args.note!r}')
        return 0

    # default: bump updated_at only
    data = read_inline_json(html_path)
    data.setdefault('meta', {})['updated_at'] = datetime.utcnow().isoformat() + 'Z'
    write_inline_json(html_path, data)
    return 0


if __name__ == '__main__':
    sys.exit(main())
