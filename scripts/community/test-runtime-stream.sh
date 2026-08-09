#!/usr/bin/env bash
set -euo pipefail
# Functional qualification for an already configured stack. It reads public endpoints and logs only.
# A station must contain playable audio; use --generate-fixture to create a royalty-free local WAV.
# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

MOUNT="${FLOWCAST_STREAM_MOUNT:-/stream}"
DURATION="${FLOWCAST_STREAM_TEST_SECONDS:-8}"
MIN_BYTES="${FLOWCAST_STREAM_MIN_BYTES:-4096}"
FIXTURE=""
usage() { echo "Usage: test-runtime-stream.sh [--install-dir DIR] [--mount /mount] [--seconds N] [--generate-fixture FILE]"; }
while (($#)); do
  case "$1" in
    --install-dir) FLOWCAST_HOME="${2:?}"; shift 2 ;;
    --mount) MOUNT="${2:?}"; shift 2 ;;
    --seconds) DURATION="${2:?}"; shift 2 ;;
    --generate-fixture) FIXTURE="${2:?}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
if [[ -n "$FIXTURE" ]]; then
  need ffmpeg
  ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=frequency=440:duration=30' -ar 44100 -ac 2 -c:a pcm_s16le -y "$FIXTURE"
  log "Generated local fixture: $FIXTURE (import it through JuggleCast before running qualification)."
  exit 0
fi

for command in docker curl python3; do need "$command"; done
require_install; load_env
[[ "$MOUNT" == /* && "$DURATION" =~ ^[0-9]+$ && "$MIN_BYTES" =~ ^[0-9]+$ ]] || die "Invalid mount or numeric test setting"
expected=(storage-init control engine audio-daemon bliss icecast)
actual="$(compose config --services)"
for service in "${expected[@]}"; do grep -Fxq "$service" <<<"$actual" || die "Missing expected service: $service"; done

storage="$(compose ps -q storage-init)"; [[ -n "$storage" ]] || die "storage-init container is missing"
[[ "$(docker inspect -f '{{.State.Status}}/{{.State.ExitCode}}' "$storage")" == exited/0 ]] || die "storage-init did not exit successfully"
for service in control engine audio-daemon bliss icecast; do
  id="$(compose ps -q "$service")"; [[ -n "$id" ]] || die "$service container is missing"
  [[ "$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id")" == healthy ]] || die "$service is not healthy"
done

base_control="http://127.0.0.1:${FLOWCAST_HTTP_PORT:-8080}"
base_stream="http://127.0.0.1:${FLOWCAST_STREAM_PORT:-8010}"
curl -fsS --max-time 5 "$base_control/api/health" >/dev/null || die "Control /api/health failed"
status="$(mktemp)"; audio="$(mktemp)"; trap 'rm -f "$status" "$audio"' EXIT
curl -fsS --max-time 5 "$base_stream/status-json.xsl" -o "$status" || die "Icecast status JSON failed"
python3 - "$status" "$MOUNT" <<'PY' || die "Configured Icecast mount is not visible"
import json, sys
data=json.load(open(sys.argv[1], encoding="utf-8")); source=data.get("icestats", {}).get("source", [])
if isinstance(source, dict): source=[source]
mount=sys.argv[2]
raise SystemExit(0 if any(item.get("listenurl", "").endswith(mount) or item.get("mount") == mount for item in source) else 1)
PY

engine="$(compose ps -q engine)"; restart_before="$(docker inspect -f '{{.RestartCount}}' "$engine")"
set +e
curl -fsS --max-time "$DURATION" "$base_stream$MOUNT" -o "$audio"
curl_status=$?
set -e
[[ "$curl_status" == 0 || "$curl_status" == 28 ]] || die "Could not read the configured stream (curl status $curl_status)"
bytes="$(wc -c <"$audio")"; (( bytes >= MIN_BYTES )) || die "Audio stream returned only $bytes bytes (minimum $MIN_BYTES)"
restart_after="$(docker inspect -f '{{.RestartCount}}' "$engine")"
[[ "$restart_after" == "$restart_before" ]] || die "Engine restarted during stream test ($restart_before -> $restart_after)"

compose exec -T control python - <<'PY' || die "runtime-state is absent or stale"
import os, time
root="/runtime-state"; newest=max((os.path.getmtime(os.path.join(p,n)) for p,_,ns in os.walk(root) for n in ns), default=0)
raise SystemExit(0 if time.time()-newest <= 120 else 1)
PY
recent_logs="$(compose logs --since "$((DURATION + 120))s" engine 2>&1 || true)"
if grep -Eqi 'Login failed|Could not connect to server\.' <<<"$recent_logs"; then die "Recent engine logs contain an Icecast connection/authentication failure"; fi
if (( $(grep -Eic 'ENGINE_ERROR' <<<"$recent_logs" || true) >= 3 )); then die "Recent engine logs contain persistent ENGINE_ERROR entries"; fi
log "stream_test=PASS mount=$MOUNT bytes=$bytes engine_restarts=$restart_after runtime_state=fresh"
