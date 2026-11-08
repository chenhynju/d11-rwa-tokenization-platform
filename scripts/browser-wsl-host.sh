#!/usr/bin/env bash
set -eu
export PATH="$HOME/.local/share/fnm/node-versions/v22.23.2/installation/bin:$PATH"
(cd apps/web && exec node node_modules/next/dist/bin/next start --hostname 127.0.0.1 --port 18731) >/tmp/w10-next-smoke.log 2>&1 &
webpid=$!
trap 'kill "$webpid" 2>/dev/null || true' EXIT
for i in {1..40}; do curl -fsS http://127.0.0.1:18731/ >/dev/null 2>&1 && break; sleep .25; done
# Legacy Windows transport removed: use native WSL Playwright.
export PLAYWRIGHT_MODULE="${PLAYWRIGHT_MODULE:-playwright}"
export CHROME_EXECUTABLE="${CHROME_EXECUTABLE:-}"
node scripts/browser-smoke.cjs "$@"
