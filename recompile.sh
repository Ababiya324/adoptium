#!/usr/bin/env bash
# Retry gh aw compile until the deterministic lock is regenerated (quarterly cron),
# killing any attempt that hangs on gh-aw's intermittent startup stall.
cd "$(dirname "$0")" || exit 2
DET=.github/workflows/quarterly-report-deterministic.lock.yml
marker=$(date +%s)
ok() {
  # newer than marker AND reflects the new quarterly cron in the schedule trigger
  [ -f "$DET" ] || return 1
  local m; m=$(stat -c %Y "$DET")
  [ "$m" -ge "$marker" ] || return 1
  grep -q '1 \*/3 \*' "$DET" || return 1
  return 0
}
for attempt in 1 2 3 4 5 6; do
  echo ">>> attempt $attempt starting $(date +%H:%M:%S)"
  gh aw compile > /tmp/compile_try_$attempt.log 2>&1 &
  pid=$!
  # give each attempt up to 8 minutes, checking every 15s for the fresh lock
  for i in $(seq 1 32); do
    sleep 15
    if ! kill -0 "$pid" 2>/dev/null; then echo "process exited"; break; fi
    if ok; then echo "lock updated mid-run"; break; fi
  done
  if ok; then echo ">>> SUCCESS on attempt $attempt"; taskkill //F //IM gh-aw.exe //T >/dev/null 2>&1; break; fi
  echo ">>> attempt $attempt did not update lock; killing and retrying"
  taskkill //F //IM gh-aw.exe //T >/dev/null 2>&1
  sleep 3
done
echo "=== FINAL STATE ==="
ls -la --time-style=+%H:%M:%S "$DET"
grep -n 'cron' "$DET" | head
