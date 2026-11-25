#!/usr/bin/env bash
# The kept tests: tests/run.sh [-j N] [name...] (names: the files in tests/cases).
# Side by side, N at a time (default half the CPUs); -j 1 runs them one at a time.
# With no name, every case but speed. Each test runs in a scratch HOME with fake
# system commands (tests/lib/fixture.py); install.sh never runs this.
set -uo pipefail
here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# the PATH the tests see is this one: uv's own python (maybe older) stays the runner's
export TK_TEST_PATH=$PATH
if command -v uv >/dev/null; then
  exec uv run --quiet --no-project --with 'pyte==0.8.2' python "$here/lib/runner.py" "$@"
elif python3 -c 'import pyte' 2>/dev/null; then
  exec python3 "$here/lib/runner.py" "$@"
else
  echo "✗ the tests need uv (https://docs.astral.sh/uv/) or python3 with pyte (pip install pyte)" >&2
  exit 2
fi
