#!/usr/bin/env python3
"""
Lightweight JSON schema validator for repository artifacts.
Usage: python scripts/validate-json.py
It validates known files and prints a summary exit code non-zero on failures.
"""
import json, sys, pathlib
from jsonschema import Draft7Validator, exceptions

root = pathlib.Path('.')
mapping = {
    '.continue/config.json': 'schemas/config.schema.json',
    '.continue/agent-roles.json': 'schemas/skills.schema.json',
    '.continue/oneagent-config.json': 'schemas/oneagent-skills.schema.json'
}

failures = []
for rel_json, rel_schema in mapping.items():
    jpath = root / rel_json
    spath = root / rel_schema
    if not jpath.exists():
        # skip missing files, not an error here
        continue
    if not spath.exists():
        failures.append((rel_json, False, f'schema missing: {rel_schema}'))
        continue
    try:
        # read with utf-8-sig to tolerate BOMs
        doc = json.loads(jpath.read_text(encoding='utf-8-sig'))
    except Exception as e:
        failures.append((rel_json, False, f'parse error: {e}'))
        continue
    try:
        schema = json.loads(spath.read_text(encoding='utf-8-sig'))
    except Exception as e:
        failures.append((rel_json, False, f'schema parse error: {e}'))
        continue
    validator = Draft7Validator(schema)
    errors = sorted(validator.iter_errors(doc), key=lambda e: list(e.path))
    if errors:
        msgs = []
        for e in errors:
            msgs.append(f"{list(e.path)}: {e.message}")
        failures.append((rel_json, False, '\n'.join(msgs)))
    else:
        print(f'[OK] {rel_json} -> {rel_schema}')

if failures:
    print('\nValidation failures:')
    for f in failures:
        print('-', f[0])
        print('   ', f[2])
    sys.exit(2)

print('\nAll validated files OK')
sys.exit(0)
