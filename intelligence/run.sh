#!/usr/bin/env bash
# Wrapper — Debian doesn't ship `python`, only `python3`.
set -euo pipefail
cd "$(dirname "$0")"
export PYTHONPATH=.

if [[ -f .venv/bin/python3 ]]; then
  exec .venv/bin/python3 -m generator.runner "$@"
fi
exec python3 -m generator.runner "$@"
