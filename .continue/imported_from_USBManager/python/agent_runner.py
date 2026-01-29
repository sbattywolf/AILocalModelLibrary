#!/usr/bin/env python3
import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

ANSI_RE = re.compile(r'\x1b\[[0-9;?]*[ -/]*[@-~]')

def remove_ansi(s: str) -> str:
    if not s:
        return s
    s = ANSI_RE.sub('', s)
    # strip braille/spinner glyphs
    s = re.sub(r'[\u2800-\u28FF]', '', s)
    # remove control chars
    s = ''.join(ch for ch in s if ch.isprintable() or ch in '\t\n')
    return s.strip()

def find_config(root: Path) -> dict:
    cfg = root / '.continue' / 'config.agent'
    if not cfg.exists():
        return {}
    try:
        return json.loads(cfg.read_text(encoding='utf-8'))
    except Exception:
        return {}

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--agent', '-a', help='Agent name')
    p.add_argument('--prompt', '-p', help='Prompt text')
    args = p.parse_args()

    prompt = args.prompt
    if not prompt:
        # try stdin
        try:
            prompt = sys.stdin.read().strip()
        except Exception:
            prompt = ''

    if not prompt:
        print(json.dumps({'error': 'no prompt provided'}))
        sys.exit(2)

    cwd = Path.cwd()
    cfg = find_config(cwd)
    agent_name = args.agent or None
    if not agent_name:
        sel = cwd / '.continue' / 'selected_agent.txt'
        if sel.exists():
            agent_name = sel.read_text(encoding='utf-8').strip()
    if not agent_name:
        agent_name = cfg.get('default', 'CustomAgent')

    selected = None
    for a in cfg.get('agents', []):
        if a.get('name') == agent_name:
            selected = a
            break
    if not selected:
        selected = {'name': 'echo', 'options': {'model': 'none', 'mode': 'echo'}}

    model = selected.get('options', {}).get('model')

    llm_result = {'raw': '', 'cleaned': '', 'exitCode': 1}
    ok = False

    if model and model != 'none' and shutil.which('ollama'):
        cmd = ['ollama', 'run', model, prompt]
        env = os.environ.copy()
        env['TERM'] = 'dumb'
        try:
            proc = subprocess.run(cmd, capture_output=True, env=env, text=True, encoding='utf-8', errors='replace')
            raw = (proc.stdout or '') + '\n' + (proc.stderr or '')
            cleaned = remove_ansi(raw)
            llm_result = {'raw': raw, 'cleaned': cleaned, 'exitCode': proc.returncode}
            ok = proc.returncode == 0
        except FileNotFoundError:
            llm_result = {'raw': 'ollama not found', 'cleaned': 'ollama not found', 'exitCode': 127}
    else:
        # fallback echo
        out = f"[{selected.get('name')}] Echo: {prompt}"
        llm_result = {'raw': out, 'cleaned': out, 'exitCode': 0}
        ok = True

    resp = {
        'agent': selected.get('name'),
        'options': selected.get('options'),
        'prompt': prompt,
        'response': llm_result['cleaned'],
        'rawResponse': llm_result['raw'],
        'ok': ok,
        'exitCode': llm_result['exitCode'],
    }
    sys.stdout.write(json.dumps(resp, ensure_ascii=True))

if __name__ == '__main__':
    main()
