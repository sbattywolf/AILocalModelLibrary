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
    # Normalize agents list: support entries that are simple strings (agent names)
    norm_agents = []
    for a in (agents or []):
        if isinstance(a, str):
            norm_agents.append({'name': a})
        elif isinstance(a, dict):
            norm_agents.append(a)
        else:
            # skip unknown formats
            continue

    # Helper: parse a skill entry (str or dict) -> (name, weight)
    def parse_skill(s):
        if isinstance(s, str):
            return s, 1
        if isinstance(s, dict):
            name = s.get('name') or s.get('skill')
            try:
                w = int(s.get('weight', 1))
            except Exception:
                w = 1
            return name, max(1, min(5, w))
        return None, 0

    # Gather team-level skills (optional) - support roles top-level keys 'teamSkills' or 'team_skills'
    team_skills = []
    for key in ('teamSkills', 'team_skills'):
        if isinstance(roles or {}, dict) and roles.get(key):
            for s in (roles.get(key) or []):
                n, w = parse_skill(s)
                if n:
                    team_skills.append({'name': n, 'weight': w})

    vram_list = []
    # For summary, include per-agent computed skill list
    agents_skill_summary = []
    for a in norm_agents:
        # prefer explicit vram if present, else 0
        v = None
        if isinstance(a, dict):
            v = a.get('vram')
        if v is None:
            # try role mapping
            r = next((rr for rr in (roles or {}).get('agents', []) if rr.get('name') == a.get('name')), None)
            if r:
                v = r.get('resources', {}).get('vramGB', 0)
            else:
                v = 0
        vram_list.append(int(v or 0))

        # Build agent skill list, merging agent skills and inherited team skills
        agent_skills_raw = []
        if isinstance(a, dict):
            agent_skills_raw = a.get('skills') or []

        # Parse and aggregate weights by skill name
        agg = {}
        # first, agent's own skills
        for s in agent_skills_raw:
            n, w = parse_skill(s)
            if not n:
                continue
            agg.setdefault(n, 0)
            agg[n] += w

        # then inherit team skills: mark as inherited and sum weights
        inherited_names = set()
        # limit team skills applied per agent to at most 3 (configurable later)
        for ts in team_skills[:3]:
            n = ts['name']
            w = ts['weight']
            agg.setdefault(n, 0)
            agg[n] += w
            inherited_names.add(n)

        # Build list of skill dicts
        skills_list = []
        for name, weight in agg.items():
            skills_list.append({'name': name, 'weight': int(weight), 'inherited': name in inherited_names})

        # Warn if any skill's weight grew above 5 (suggest child-agent evaluation)
        for s in skills_list:
            if s['weight'] > 5:
                print(f"WARNING: agent '{a.get('name')}' skill '{s['name']}' weight {s['weight']} > 5; consider child-agent or review.")

        # Enforce max 10 skills per agent; prefer keeping inherited skills first, then highest-weight others
        inherited = [s for s in skills_list if s['inherited']]
        others = [s for s in skills_list if not s['inherited']]
        others.sort(key=lambda x: x['weight'], reverse=True)
        final_skills = inherited + others
        final_skills = final_skills[:10]

        # Sort final list by weight descending
        final_skills.sort(key=lambda x: x['weight'], reverse=True)

        agents_skill_summary.append({'name': a.get('name'), 'skills': final_skills})

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
