#!/usr/bin/env bash
# Deploy the lab with Snowflake CLI (snow sql). Scripts run in folder/file order.
#
# Usage:
#   ./deploy.sh -c <connection> [module ...]
#
# Modules: foundation | account_monitoring | security | itops | cowork | tests | all (default)
#   ./deploy.sh -c archetype itops         # only the IT Ops + Security demo
#   ./deploy.sh -c archetype foundation itops
set -euo pipefail

CONN=""
while getopts "c:" opt; do
  case "$opt" in
    c) CONN="$OPTARG" ;;
    *) echo "usage: $0 -c <connection> [module ...]"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[[ -z "$CONN" ]] && { echo "usage: $0 -c <connection> [module ...]"; exit 1; }

ROOT="$(cd "$(dirname "$0")" && pwd)"
MODULES=("${@:-all}")

run_dir() {
  local dir="$1"
  for f in "$ROOT/$dir"/*.sql; do
    echo ">>> $f"
    snow sql -c "$CONN" --enable-templating NONE -f "$f"
  done
}

for m in "${MODULES[@]}"; do
  case "$m" in
    foundation)         run_dir scripts/00_foundation ;;
    account_monitoring) run_dir scripts/10_account_monitoring ;;
    security)           run_dir scripts/20_security ;;
    itops)              run_dir scripts/30_itops_demo ;;
    cowork)             run_dir scripts/90_cowork ;;
    tests)              snow sql -c "$CONN" --enable-templating NONE -f "$ROOT/tests/itops_demo_tests.sql" ;;
    all)
      run_dir scripts/00_foundation
      run_dir scripts/10_account_monitoring
      run_dir scripts/20_security
      run_dir scripts/30_itops_demo
      run_dir scripts/90_cowork
      snow sql -c "$CONN" --enable-templating NONE -f "$ROOT/tests/itops_demo_tests.sql"
      ;;
    *) echo "unknown module: $m"; exit 1 ;;
  esac
done
