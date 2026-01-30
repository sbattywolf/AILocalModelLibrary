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
    p.add_argument('--ci', action='store_true', help='CI mode: force no external runtime calls and use echo fallback')
    p.add_argument('--noop', action='store_true', help='No-op mode: return immediately with stub response')
    p.add_argument('--short', action='store_true', help='Return a shortened response (good for CI)')
    p.add_argument('--timeout', type=float, default=10.0, help='Timeout (seconds) for external runtime calls')
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

    # Decide whether to invoke external runtimes.
    # Priority: explicit flags -> environment gates. In CI we prefer echo fallback.
    ollama_disabled = os.environ.get('OLLAMA_DISABLED') == '1'
    run_ollama_flag = os.environ.get('RUN_OLLAMA_INTEGRATION') == '1'
    if args.ci:
        ollama_disabled = True
    if args.noop:
        # immediate stub response for fast CI tests
        resp = {
            'agent': selected.get('name'),
            'options': selected.get('options'),
            'prompt': prompt,
            'response': f"[noop] {prompt}",
            'rawResponse': f"[noop] {prompt}",
            'ok': True,
            'exitCode': 0,
        }
        sys.stdout.write(json.dumps(resp, ensure_ascii=True))
        return

    if model and model != 'none' and (not ollama_disabled) and run_ollama_flag and shutil.which('ollama'):
        cmd = ['ollama', 'run', model, prompt]
        env = os.environ.copy()
        env['TERM'] = 'dumb'
        try:
            # apply timeout from args
            proc = subprocess.run(cmd, capture_output=True, env=env, text=True, encoding='utf-8', errors='replace', timeout=args.timeout)
            raw = (proc.stdout or '') + '\n' + (proc.stderr or '')
            cleaned = remove_ansi(raw)
            llm_result = {'raw': raw, 'cleaned': cleaned, 'exitCode': proc.returncode}
            ok = proc.returncode == 0
        except subprocess.TimeoutExpired as te:
            llm_result = {'raw': f'ollama timeout: {te}', 'cleaned': f'ollama timeout', 'exitCode': 124}
            ok = False
        except FileNotFoundError:
            llm_result = {'raw': 'ollama not found', 'cleaned': 'ollama not found', 'exitCode': 127}
    else:
        # fallback echo
        out = f"[{selected.get('name')}] Echo: {prompt}"
        llm_result = {'raw': out, 'cleaned': out, 'exitCode': 0}
        ok = True

    # Optionally shorten response for CI
    final_response = llm_result['cleaned']
    if args.short and final_response:
        max_chars = int(os.environ.get('AGENT_RUNNER_SHORT_CHARS', '200'))
        if len(final_response) > max_chars:
            final_response = final_response[:max_chars] + '...'

    resp = {
        'agent': selected.get('name'),
        'options': selected.get('options'),
        'prompt': prompt,
        'response': final_response,
        'rawResponse': llm_result['raw'],
        'ok': ok,
        'exitCode': llm_result['exitCode'],
    }
    sys.stdout.write(json.dumps(resp, ensure_ascii=True))

if __name__ == '__main__':
    main()
