#!/usr/bin/env python3
"""Prepare (never apply) a room-limit migration from a live catalog export.

Use docs/room_limits_rollout_2026_10_31.md. This tool accepts no credentials,
opens no connection, and refuses unexpected function/constraint contracts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

IDENTITY = 'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)'


def literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def prepare(snapshot: dict, *, rollback: bool = False) -> str:
    original = snapshot.get('function_definition')
    if not isinstance(original, str) or not re.search(
        r'CREATE OR REPLACE FUNCTION public\.create_online_room_impl\s*\(',
        original, re.IGNORECASE,
    ):
        raise ValueError('live create_online_room_impl definition required')
    updated = original
    for field, previous, expanded in (
        ('p_question_count', [5, 10, 15], [5, 10, 15, 20, 25, 30, 40, 50]),
        ('p_seconds_per_question', [10, 15, 20, 30, 45, 60],
         [10, 15, 20, 30, 45, 60, 90, 120]),
    ):
        numbers = r'\s*,\s*'.join(map(str, previous))
        pattern = rf'\b{field}\s+not\s+in\s*\(\s*{numbers}\s*\)'
        replacement = field + ' not in (' + ', '.join(map(str, expanded)) + ')'
        updated, count = re.subn(pattern, replacement, updated, flags=re.IGNORECASE)
        if count != 1:
            label = 'question guard' if field == 'p_question_count' else 'duration guard'
            raise ValueError(f'unexpected {label}: expected exactly one known guard')

    changes = []
    constraints = snapshot.get('constraints', [])
    if not isinstance(constraints, list) or len(constraints) != 2:
        raise ValueError('exactly two relevant live CHECK constraints required')
    expected = {
        'question_count': (3, 30, 50),
        'seconds_per_question': (5, 60, 120),
    }
    for constraint in constraints:
        name, definition = constraint.get('name'), constraint.get('definition')
        if not isinstance(name, str) or not name or not isinstance(definition, str):
            raise ValueError('invalid live constraint')
        normalized = re.sub(r'[\s()]', '', definition).lower()
        match = next((field for field, (low, high, _) in expected.items()
                      if normalized == f'check{field}>={low}and{field}<={high}'), None)
        if match is None:
            raise ValueError('unknown live constraint; review it manually')
        _, old_high, new_high = expected.pop(match)
        # Keep pg_get_constraintdef's spelling for the rollback drift guard.
        after, changed = re.subn(rf'(<=\s*){old_high}\b',
                                 lambda m: m[1] + str(new_high), definition)
        if changed != 1:
            raise ValueError('unrecognized live constraint upper bound')
        changes.append((name, definition, after))
    if expected:
        raise ValueError('missing live constraint')

    if rollback:
        original, updated = updated, original
        changes = [(name, after, before) for name, before, after in changes]

    digest = hashlib.md5(original.encode()).hexdigest()
    checks = [
        f"if md5(pg_get_functiondef({literal(IDENTITY)}::regprocedure)) <> {literal(digest)} then",
        "  raise exception 'room limits: live function source changed; export and review again';",
        'end if;',
    ]
    checks += [
        'if (select count(*) from pg_constraint c',
        "  where c.conrelid = 'public.rooms'::regclass and c.contype = 'c'",
        "  and pg_get_constraintdef(c.oid) ~ '(question_count|seconds_per_question)') <> 2 then",
        "  raise exception 'room limits: unexpected live constraints';",
        'end if;',
    ]
    if rollback:
        checks += [
            'if exists (select 1 from public.rooms',
            '  where question_count > 30 OR seconds_per_question > 60) then',
            "  raise exception 'room limits: existing rooms require the expanded limits';",
            'end if;',
        ]
    for name, before, _ in changes:
        checks += [
            'if not exists (select 1 from pg_constraint c',
            "  where c.conrelid = 'public.rooms'::regclass",
            f'  and c.conname = {literal(name)}',
            f'  and pg_get_constraintdef(c.oid) = {literal(before)}) then',
            "  raise exception 'room limits: live constraint changed; export and review again';",
            'end if;',
        ]
    ddl = [f'ALTER TABLE public.rooms DROP CONSTRAINT {identifier(name)};\n'
           f'ALTER TABLE public.rooms ADD CONSTRAINT {identifier(name)} {after};'
           for name, _, after in changes]
    return (
        '-- Generated from the live catalog; requires reviewed diff and owner approval.\n'
        '-- Smoke in a transaction with ROLLBACK before production COMMIT.\n'
        'BEGIN;\nSET LOCAL lock_timeout = \'5s\';\n'
        'LOCK TABLE public.rooms IN ACCESS EXCLUSIVE MODE;\n'
        'DO $room_limits_guard$\nBEGIN\n' + '\n'.join(checks) +
        '\nEND;\n$room_limits_guard$;\n' + updated.rstrip().rstrip(';') + ';\n' +
        '\n'.join(ddl) + '\nCOMMIT;\n'
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('snapshot', type=Path)
    parser.add_argument('--rollback', action='store_true',
                        help='prepare the guarded rollback from the SAME original export')
    args = parser.parse_args()
    print(prepare(json.loads(args.snapshot.read_text()), rollback=args.rollback), end='')


if __name__ == '__main__':
    main()
