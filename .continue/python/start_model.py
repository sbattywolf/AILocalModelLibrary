#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
from pathlib import Path

def write_marker(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.replace('\n',' '), encoding='utf-8')

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--model', '-m', required=True)
    p.add_argument('--runtime', choices=['ollama','docker'], default='ollama')
    p.add_argument('--dry-run', action='store_true')
    args = p.parse_args()

    pidfile = Path('.continue') / 'model.pid'
    marker = Path('.continue') / 'model.marker'

    print(f"start_model: runtime={args.runtime} model={args.model} dry_run={args.dry_run}")
    if args.dry_run:
        return

    if args.runtime == 'ollama':
        cmd = ['ollama','serve','--model', args.model]
        proc = subprocess.Popen(cmd)
        write_marker(marker, f"Started ollama {args.model} pid={proc.pid}")
        pidfile.write_text(str(proc.pid), encoding='utf-8')
        print(f"Started ollama pid={proc.pid}")
    else:
        print('docker runtime not implemented in prototype')

if __name__ == '__main__':
    main()
