import json
import subprocess
import sys
from pathlib import Path


def run_agent(prompt: str, agent: str = 'CustomAgent') -> dict:
    script = Path(__file__).resolve().parents[1] / 'agent_runner.py'
    cmd = [sys.executable, str(script), '-a', agent, '-p', prompt]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    out = proc.stdout.strip()
    if not out:
        # sometimes script may print trailing newlines; include stderr
        out = proc.stderr.strip()
    return json.loads(out)


def test_agent_runner_returns_json():
    res = run_agent('unit-test prompt')
    assert isinstance(res, dict)
    assert 'agent' in res
    assert 'response' in res
    assert 'rawResponse' in res
    assert 'ok' in res
