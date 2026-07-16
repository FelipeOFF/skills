"""JSON pass-through adapter — input is a path to a Schema JSON file."""
import json
from pathlib import Path


def build(input_str: str, cli_args=None) -> dict:
    if not input_str:
        raise ValueError('JSON adapter needs --input PATH')
    p = Path(input_str)
    if not p.exists():
        raise FileNotFoundError(p)
    return json.loads(p.read_text())
