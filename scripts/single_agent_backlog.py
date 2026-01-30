#!/usr/bin/env python3
"""
Single-agent backlog prototype

Scans the repository for TODO/FIXME markers and source files to produce
a simple backlog proposal and a first-sprint selection saved under
.continue/backlog_proposal.json and .continue/first_sprint.json

Usage: python scripts/single_agent_backlog.py [--capacity N]
"""
import os
import re
import json
import argparse
from pathlib import Path


EXCLUDE_DIRS = {'.git', '.tmp', 'node_modules', '__pycache__', '.venv'}


def is_text_file(path: Path):
    try:
        with path.open('r', encoding='utf-8') as f:
            f.read(1024)
        return True
    except Exception:
        return False


def scan_repo(root: Path):
    items = []
    for dirpath, dirnames, filenames in os.walk(root):
        parts = set(Path(dirpath).parts)
        if parts & EXCLUDE_DIRS:
            continue
        for fname in filenames:
            path = Path(dirpath) / fname
            if not is_text_file(path):
                continue
            try:
                text = path.read_text(encoding='utf-8')
            except Exception:
                continue
            # find TODO/FIXME lines
            for i, line in enumerate(text.splitlines(), start=1):
                if re.search(r'\b(TODO|FIXME)\b', line, re.IGNORECASE):
                    items.append({
                        'source': str(path.relative_to(root)),
                        'line': i,
                        'text': line.strip(),
                        'type': 'todo'
                    })
            # lightweight feature extraction: top-level headings or def/class
            if re.search(r'^#{1,3}\s+', text, re.MULTILINE):
                # doc heading-based candidate
                items.append({'source': str(path.relative_to(root)), 'type': 'doc', 'text': 'Contains headings/documentation'})
            if re.search(r'^\s*(def |class )', text, re.MULTILINE):
                items.append({'source': str(path.relative_to(root)), 'type': 'code', 'text': 'Contains code definitions'})
    return items


def estimate_points(item, root: Path):
    # Simple heuristics: TODO=1-3, doc/code based on file size
    src = root / item.get('source')
    size = 0
    try:
        size = src.stat().st_size
    except Exception:
        size = 0
    if item.get('type') == 'todo':
        base = 2
    elif item.get('type') == 'doc':
        base = 1
    else:
        base = 3
    # scale by file size (per 50KB add 1 point)
    extra = int(size / 50000)
    return max(1, base + extra)


def build_backlog(items, root: Path):
    backlog = []
    seen = set()
    counter = 1
    for it in items:
        key = (it.get('source'), it.get('line', 0), it.get('text', ''))
        if key in seen:
            continue
        seen.add(key)
        points = estimate_points(it, root)
        title = f"Review {Path(it.get('source')).name}: {it.get('text')[:60]}"
        desc = f"Source: {it.get('source')}"
        if it.get('line'):
            desc += f" (line {it.get('line')})"
        backlog.append({
            'id': counter,
            'title': title,
            'description': desc,
            'source': it.get('source'),
            'type': it.get('type'),
            'estimate_points': points,
            'priority': 'high' if it.get('type') == 'todo' else 'medium'
        })
        counter += 1
    # sort by priority then estimate
    backlog.sort(key=lambda x: (0 if x['priority']=='high' else 1, x['estimate_points']))
    return backlog


def select_first_sprint(backlog, capacity=8):
    sprint = []
    total = 0
    for item in backlog:
        if total + item['estimate_points'] <= capacity:
            sprint.append(item)
            total += item['estimate_points']
    return sprint, total


def save_outputs(root: Path, backlog, sprint, total, capacity):
    outdir = root / '.continue'
    outdir.mkdir(exist_ok=True)
    bp = outdir / 'backlog_proposal.json'
    fs = outdir / 'first_sprint.json'
    summary = {
        'backlog_count': len(backlog),
        'sprint_selected': len(sprint),
        'sprint_total_points': total,
        'sprint_capacity': capacity
    }
    bp.write_text(json.dumps({'backlog': backlog, 'summary': summary}, indent=2), encoding='utf-8')
    fs.write_text(json.dumps({'first_sprint': sprint, 'summary': summary}, indent=2), encoding='utf-8')
    print(f"Wrote {bp} and {fs}")


def human_readable(root: Path, backlog, sprint, total, capacity):
    lines = []
    lines.append('Backlog Proposal')
    lines.append('================')
    for b in backlog:
        lines.append(f"{b['id']}. [{b['priority']}] ({b['estimate_points']}pt) {b['title']} -- {b['source']}")
    lines.append('\nFirst sprint (capacity %d):' % capacity)
    lines.append('-------------------------')
    for s in sprint:
        lines.append(f"- {s['id']}. {s['title']} ({s['estimate_points']}pt)")
    lines.append(f"Total points: {total}/{capacity}")
    out = '\n'.join(lines)
    (root / '.continue' / 'first_sprint.txt').write_text(out, encoding='utf-8')
    print(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capacity', type=int, default=8, help='Sprint capacity in points')
    args = parser.parse_args()
    root = Path.cwd()
    print(f"Scanning repo at {root}")
    items = scan_repo(root)
    backlog = build_backlog(items, root)
    sprint, total = select_first_sprint(backlog, capacity=args.capacity)
    save_outputs(root, backlog, sprint, total, args.capacity)
    human_readable(root, backlog, sprint, total, args.capacity)


if __name__ == '__main__':
    main()
