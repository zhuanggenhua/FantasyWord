#!/usr/bin/env bash
# Existing per-script runtime checks; no Unity import or visual acceptance.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
exec python3 tests/run_suites.py "$@"
