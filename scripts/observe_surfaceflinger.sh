#!/usr/bin/env bash
set -u

OUT_DIR="${1:-diagnostics}"
SAMPLES="${SAMPLES:-18}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-10}"
mkdir -p "$OUT_DIR"

adb wait-for-device
adb logcat -c || true

first_pid="$(adb shell pidof surfaceflinger 2>/dev/null | tr -d '\r' | xargs || true)"
pid_changed=0
missing_samples=0

printf 'timestamp,pid\n' > "$OUT_DIR/surfaceflinger-pids.csv"

for ((i=1; i<=SAMPLES; i++)); do
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  pid="$(adb shell pidof surfaceflinger 2>/dev/null | tr -d '\r' | xargs || true)"

  printf '%s,%s\n' "$ts" "$pid" >> "$OUT_DIR/surfaceflinger-pids.csv"

  if [[ -z "$pid" ]]; then
    missing_samples=$((missing_samples + 1))
  elif [[ -n "$first_pid" && "$pid" != "$first_pid" ]]; then
    pid_changed=1
  fi

  if (( i < SAMPLES )); then
    sleep "$INTERVAL_SECONDS"
  fi
done

adb logcat -d > "$OUT_DIR/logcat.txt" 2>&1 || true

grep -E \
  'hasReadColorBufferDma|mapper\.ranchu|RegionSampling|Fatal signal 6 \(SIGABRT\)|surfaceflinger.*SIGABRT' \
  "$OUT_DIR/logcat.txt" > "$OUT_DIR/crash-signatures.txt" || true

crash_signature_lines="$(wc -l < "$OUT_DIR/crash-signatures.txt" | xargs)"

{
  echo "first_surfaceflinger_pid=$first_pid"
  echo "surfaceflinger_pid_changed=$pid_changed"
  echo "surfaceflinger_missing_samples=$missing_samples"
  echo "crash_signature_lines=$crash_signature_lines"
} | tee "$OUT_DIR/observation-result.txt"
