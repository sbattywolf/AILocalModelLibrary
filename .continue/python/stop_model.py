#!/usr/bin/env python3
import argparse
import os
import signal
import subprocess
from pathlib import Path

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--dry-run', action='store_true')
    args = p.parse_args()

    pidfile = Path('.continue') / 'model.pid'
    marker = Path('.continue') / 'model.marker'
    if not pidfile.exists():
        print('PID file not found')
        raise SystemExit(2)
    pid = int(pidfile.read_text(encoding='utf-8').strip())
    print(f"Stopping pid={pid} dry_run={args.dry_run}")
    if args.dry_run:
        return
    try:
        os.kill(pid, signal.SIGTERM)
    except Exception:
        pass
    try:
        pidfile.unlink()
    except Exception:
        pass
    try:
        marker.unlink()
    except Exception:
        pass

if __name__ == '__main__':
    main()
