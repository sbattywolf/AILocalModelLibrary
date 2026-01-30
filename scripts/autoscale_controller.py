#!/usr/bin/env python3
"""
Simple Autoscale Controller Prototype
Reads .continue/agents-epic.json and .continue/agent-roles.json and suggests
recommended MaxParallel and MaxVramGB given an available VRAM budget.

This is a lightweight prototype intended for CI and local experimentation.
"""
import argparse
import json
from pathlib import Path
import statistics

def load_json(path: Path):
    if not path.exists():
        return None
    # tolerate BOM if present
    return json.loads(path.read_text(encoding='utf-8-sig'))


def recommend(agents, roles, available_vram_gb, min_parallel=1, max_parallel=16):
    vram_list = []
    for a in agents:
        # prefer explicit vram if present, else 0
        v = a.get('vram')
        if v is None:
            # try role mapping
            r = next((rr for rr in (roles or {}).get('agents', []) if rr.get('name') == a.get('name')), None)
            if r:
                v = r.get('resources', {}).get('vramGB', 0)
            else:
                v = 0
        vram_list.append(int(v or 0))

    if not vram_list:
        return {'MaxParallel': min_parallel, 'MaxVramGB': available_vram_gb, 'reason': 'no agents'}

    median_vram = max(1, int(statistics.median(vram_list)))
    # conservative parallelism: floor available_vram / median per-agent vram
    recommended_parallel = max(min_parallel, min(max_parallel, available_vram_gb // median_vram))
    # ensure at least 1
    recommended_parallel = max(1, recommended_parallel)

    return {
        'MaxParallel': recommended_parallel,
        'MaxVramGB': available_vram_gb,
        'medianAgentVramGB': median_vram,
        'agentCount': len(vram_list),
    }


def atomic_write(path: Path, data: str):
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(data, encoding='utf-8')
    tmp.replace(path)


def append_telemetry(log_path: Path, record: dict):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open('a', encoding='utf-8') as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--available-vram', type=int, default=int(( __import__('os').environ.get('AVAILABLE_VRAM_GB', '24') )), help='Available VRAM in GB')
    p.add_argument('--min-parallel', type=int, default=1)
    p.add_argument('--max-parallel', type=int, default=16)
    p.add_argument('--mapping', default='.continue/agents-epic.json')
    p.add_argument('--roles', default='.continue/agent-roles.json')
    p.add_argument('--watch', type=int, default=0, help='Watch interval seconds (0 = run once)')
    p.add_argument('--apply', action='store_true', help='Write suggestion to .continue/autoscale-suggestion.json')
    p.add_argument('--signal', action='store_true', help='When used with --apply, create an apply request file to signal the monitor')
    args = p.parse_args()

    mapping_path = Path(args.mapping)
    roles_path = Path(args.roles)
    out_path = Path('.continue') / 'autoscale-suggestion.json'
    telemetry_path = Path('.continue') / 'autoscale-metrics.log'
    apply_request = Path('.continue') / 'autoscale-apply.request'

    def load_prev():
        if out_path.exists():
            try:
                return json.loads(out_path.read_text(encoding='utf-8-sig'))
            except Exception:
                return None
        return None

    def significant_change(prev, cur, pct_threshold=0.2, abs_parallel=1):
        if not prev:
            return True
        try:
            p1 = prev.get('recommendation', {}).get('MaxParallel', 0)
            p2 = cur.get('recommendation', {}).get('MaxParallel', 0)
            if abs(p2 - p1) >= abs_parallel:
                return True
            v1 = prev.get('recommendation', {}).get('MaxVramGB', 0)
            v2 = cur.get('recommendation', {}).get('MaxVramGB', 0)
            # percent change
            if v1 == 0:
                return True
            if abs(v2 - v1) / max(1, v1) >= pct_threshold:
                return True
        except Exception:
            return True
        return False


    def run_once():
        mapping = load_json(mapping_path) or []
        roles = load_json(roles_path) or {}
        rec = recommend(mapping, roles, args.available_vram, args.min_parallel, args.max_parallel)
        out = {
            'available_vram_gb': args.available_vram,
            'recommendation': rec,
            'summary': {
                'agents_inspected': len(mapping),
            }
        }
        s = json.dumps(out)
        print(s)

        # telemetry record
        telemetry = {
            'ts': __import__('datetime').datetime.utcnow().isoformat() + 'Z',
            'available_vram_gb': args.available_vram,
            'recommendation': rec,
            'agents_inspected': len(mapping),
        }
        try:
            append_telemetry(telemetry_path, telemetry)
        except Exception:
            pass

        prev = load_prev()
        changed = significant_change(prev, out, pct_threshold=float(__import__('os').environ.get('AUTOSCALE_CHANGE_PCT','0.2')), abs_parallel=int(__import__('os').environ.get('AUTOSCALE_MIN_PAR_CHANGE','1')))

        if args.apply and changed:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            atomic_write(out_path, s)

        if args.apply and args.watch == 0 and args.signal and changed:
            # write a simple apply request file (atomic)
            apply_payload = {
                'ts': __import__('datetime').datetime.utcnow().isoformat() + 'Z',
                'action': 'apply_suggestion',
                'suggestion': rec,
            }
            atomic_write(apply_request, json.dumps(apply_payload))

        return out

    if args.watch and args.watch > 0:
        import time
        try:
            while True:
                run_once()
                time.sleep(args.watch)
        except KeyboardInterrupt:
            print('stopped')
    else:
        run_once()

if __name__ == '__main__':
    main()
