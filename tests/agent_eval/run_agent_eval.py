#!/usr/bin/env python3
"""End-to-end agent evaluation for the SLG IT Ops + Security demo.

Asks COWORK.AGENTS.IT_OPS_SECURITY_AGENT every verified question from the
semantic view (scripts/30_itops_demo/09_itops_security_svw.sql) and checks each
answer against the key fact in expected.tsv (a regex per question).

Usage:
    python3 tests/agent_eval/run_agent_eval.py -c <connection> [--parallel 4]

Requires the `cortex` CLI (`cortex agents run`). Network errors are retried once.
"""
import argparse
import concurrent.futures as cf
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SVW_SQL = ROOT / "scripts/30_itops_demo/09_itops_security_svw.sql"
EXPECTED = pathlib.Path(__file__).with_name("expected.tsv")
AGENT = "COWORK.AGENTS.IT_OPS_SECURITY_AGENT"


def ask(conn, question):
    for _ in range(2):
        r = subprocess.run(["cortex", "agents", "run", "-c", conn, AGENT, question],
                           capture_output=True, text=True, timeout=600)
        out = r.stdout + r.stderr
        if '"error"' not in out[:200]:
            return out
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-c", "--connection", required=True)
    ap.add_argument("--parallel", type=int, default=4)
    args = ap.parse_args()

    questions = dict(re.findall(r"\n  - name: (\w+)\n    question: (.+)", SVW_SQL.read_text()))
    expected = dict(l.rstrip("\n").split("\t", 1) for l in EXPECTED.read_text().splitlines() if l.strip())

    def run(name):
        answer = ask(args.connection, questions[name])
        return name, bool(re.search(expected[name], answer, re.S)), answer

    passed = 0
    with cf.ThreadPoolExecutor(args.parallel) as ex:
        for name, ok, answer in ex.map(run, expected):
            passed += ok
            print(f"{'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f"\n      {answer[:300]!r}"))
    print(f"\n{passed}/{len(expected)} agent answers contain the expected facts")
    sys.exit(0 if passed == len(expected) else 1)


if __name__ == "__main__":
    main()
