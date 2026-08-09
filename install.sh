#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  pwd
)"

VERSION_ENV="$SCRIPT_DIR/version.env"
DEFAULT_VERSION=""

if [[ -f "$VERSION_ENV" ]]; then
  DEFAULT_VERSION="$(
    sed -n \
      's/^FLOWCAST_VERSION=//p' \
      "$VERSION_ENV" \
    | head -n 1
  )"
fi

VERSION="${FLOWCAST_VERSION:-$DEFAULT_VERSION}"
INSTALL_DIR="${FLOWCAST_HOME:-/opt/flowcast}"
REPOSITORY="${FLOWCAST_RELEASE_REPOSITORY:-chourmovs/FlowCast-Community}"
RELEASE_BASE_URL="${FLOWCAST_RELEASE_BASE_URL:-}"

START=true
DRY_RUN=false
DOCKER_CONTROL=true
NON_INTERACTIVE=false


usage() {
  cat <<'EOF'
Usage:
  install.sh [options]

Options:
  --version VERSION
      Install a specific JuggleCast Community version.

  --install-dir DIR
      Installation directory.
      Default: /opt/flowcast

  --release-base-url URL
      Override the GitHub release asset base URL.
      Intended primarily for testing.

  --no-start
      Prepare the installation without starting the stack.

  --no-docker-control
      Disable Docker Control and do not mount the Docker socket.

  --docker-control
      Explicitly enable Docker Control.
      Retained as a backwards-compatible alias.

  --non-interactive
      Fail instead of overwriting an existing installation.

  --dry-run
      Validate the host and display the release assets without installing.

  --help, -h
      Display this help.

Docker Control is enabled by default. Docker socket access is effectively
root-equivalent. Use --no-docker-control when the control plane must not manage
Docker services directly.
EOF
}


log() {
  printf '[jugglecast] %s\n' "$*"
}


die() {
  printf '[jugglecast] ERROR: %s\n' "$*" >&2
  exit 1
}


need() {
  command -v "$1" >/dev/null 2>&1 \
    || die "Required command not found: $1"
}


docker_socket_details() {
  local socket="/var/run/docker.sock"

  need stat

  if [[ "${DOCKER_HOST:-}" == unix://* ]]; then
    socket="${DOCKER_HOST#unix://}"
  fi

  [[ -e "$socket" ]] || die \
    "Docker Control is enabled by default, but its socket is absent: $socket. Fix Docker access or rerun with --no-docker-control."

  [[ -S "$socket" ]] || die \
    "Docker Control is enabled by default, but $socket is not a Unix socket. Fix DOCKER_HOST or rerun with --no-docker-control."

  [[ -r "$socket" && -w "$socket" ]] || die \
    "Docker Control is enabled by default, but $socket is not accessible. Fix socket permissions or rerun with --no-docker-control."

  DOCKER_SOCKET="$socket"

  DOCKER_GID="$(
    stat -c '%g' "$socket" 2>/dev/null
  )" || die \
    "Cannot read Docker socket GID with 'stat -c %g'. The stat command may be unavailable or access may have been denied."

  [[ "$DOCKER_GID" =~ ^[0-9]+$ ]] || die \
    "Docker socket returned an invalid group ID."
}


while (($#)); do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || die \
        "--version requires a value"

      VERSION="${2#v}"
      shift 2
      ;;

    --install-dir)
      [[ $# -ge 2 ]] || die \
        "--install-dir requires a value"

      INSTALL_DIR="$2"
      shift 2
      ;;

    --release-base-url)
      [[ $# -ge 2 ]] || die \
        "--release-base-url requires a value"

      RELEASE_BASE_URL="$2"
      shift 2
      ;;

    --no-start)
      START=false
      shift
      ;;

    --docker-control)
      DOCKER_CONTROL=true
      shift
      ;;

    --no-docker-control)
      DOCKER_CONTROL=false
      shift
      ;;

    --non-interactive)
      NON_INTERACTIVE=true
      shift
      ;;

    --dry-run)
      DRY_RUN=true
      shift
      ;;

    --help|-h)
      usage
      exit 0
      ;;

    *)
      die "Unknown option: $1"
      ;;
  esac
done


[[ -n "$VERSION" ]] || die \
  "No release version was supplied. Use --version VERSION or provide version.env next to install.sh."

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$ ]] \
  || die "Invalid JuggleCast version: $VERSION"

[[ "$VERSION" != "latest" ]] || die \
  "The mutable 'latest' version is not supported. Use an immutable release version."


[[ "$(uname -s)" == "Linux" ]] || die \
  "JuggleCast Community requires Linux."

case "$(uname -m)" in
  x86_64|amd64)
    ;;

  aarch64|arm64)
    die \
      "JuggleCast $VERSION is currently published for linux/amd64 only."
    ;;

  *)
    die \
      "Unsupported architecture: $(uname -m). JuggleCast $VERSION is currently published for linux/amd64 only."
    ;;
esac


for command in \
  curl \
  sha256sum \
  openssl \
  docker \
  tar \
  df \
  awk \
  sed \
  mktemp \
  dirname \
  hostname
do
  need "$command"
done


docker compose version >/dev/null 2>&1 || die \
  "Docker Compose v2 is required."

docker info >/dev/null 2>&1 || die \
  "Cannot access the Docker daemon. This installer does not install Docker or invoke sudo automatically."


if [[ "$DOCKER_CONTROL" == true ]]; then
  docker_socket_details
fi


install_parent="$(dirname "$INSTALL_DIR")"

available="$(
  df -Pk "$install_parent" 2>/dev/null \
    | awk 'NR == 2 {print $4}'
)"

if [[ -z "$available" ]]; then
  available="$(
    df -Pk / \
      | awk 'NR == 2 {print $4}'
  )"
fi

[[ "$available" =~ ^[0-9]+$ ]] || die \
  "Unable to determine the available disk space."

((available >= 10485760)) || die \
  "At least 10 GiB free disk space is required."


if [[ -e "$INSTALL_DIR/.env" ]]; then
  message="An existing JuggleCast installation was found at $INSTALL_DIR. Use scripts/community/update.sh, or remove or restore the existing installation before retrying."

  if [[ "$NON_INTERACTIVE" == true ]]; then
    die \
      "$message Non-interactive installation cannot overwrite it."
  fi

  die \
    "$message It will not be overwritten."
fi


TAG="v$VERSION"
ARCHIVE="jugglecast-community-$TAG.tar.gz"
LEGACY_ARCHIVE="flowcast-community-$TAG.tar.gz"
BASE="${RELEASE_BASE_URL:-https://github.com/$REPOSITORY/releases/download/$TAG}"

log \
  "Preparing JuggleCast $VERSION (linux/amd64) in $INSTALL_DIR"


if [[ "$DRY_RUN" == true ]]; then
  log \
    "Would download $ARCHIVE (with $LEGACY_ARCHIVE fallback), checksums.sha256, release-manifest.json and images.lock from $BASE"
  exit 0
fi


TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}

trap cleanup EXIT


download_asset() {
  local asset="$1"

  curl \
    --fail \
    --location \
    --proto '=https' \
    --tlsv1.2 \
    --retry 3 \
    --retry-all-errors \
    --connect-timeout 15 \
    --max-time 600 \
    --output "$TMP/$asset" \
    "$BASE/$asset"
}


log "Downloading $ARCHIVE"

if ! download_asset "$ARCHIVE"; then
  log \
    "$ARCHIVE is unavailable; trying the RC8-compatible asset name."

  ARCHIVE="$LEGACY_ARCHIVE"
  log "Downloading $ARCHIVE"

  download_asset "$ARCHIVE" || die \
    "Neither the JuggleCast nor historical FlowCast archive is available."
fi


for asset in \
  checksums.sha256 \
  release-manifest.json \
  images.lock
do
  log "Downloading $asset"
  download_asset "$asset" || die \
    "Unable to download required release asset: $asset"
done


expected_line="$(
  awk \
    -v file="$ARCHIVE" \
    '$2 == file || $2 == "*" file {print; exit}' \
    "$TMP/checksums.sha256"
)"

[[ -n "$expected_line" ]] || die \
  "No checksum was published for $ARCHIVE."


(
  cd "$TMP"

  printf '%s\n' "$expected_line" \
    | sha256sum -c -
) || die \
  "Checksum verification failed for $ARCHIVE."


manifest_version="$(
  sed -n \
    's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$TMP/release-manifest.json" \
  | head -n 1
)"

[[ -n "$manifest_version" ]] || die \
  "The release manifest does not contain a version."

[[ "$manifest_version" == "$VERSION" ]] || die \
  "Release manifest version '$manifest_version' does not match requested version '$VERSION'."


mkdir -p "$INSTALL_DIR" || die \
  "Cannot create $INSTALL_DIR. Run this script with permissions suitable for the selected installation directory."


tar \
  -xzf "$TMP/$ARCHIVE" \
  -C "$INSTALL_DIR"


cp \
  "$TMP/release-manifest.json" \
  "$TMP/images.lock" \
  "$INSTALL_DIR/"


for required in \
  compose.yml \
  compose.docker-control.yml \
  version.env \
  scripts/community/doctor.sh \
  scripts/community/credentials.sh \
  scripts/community/check-docker-control.sh
do
  [[ -e "$INSTALL_DIR/$required" ]] || die \
    "Release archive is missing $required."
done


archive_version="$(
  sed -n \
    's/^FLOWCAST_VERSION=//p' \
    "$INSTALL_DIR/version.env" \
  | head -n 1
)"

[[ -n "$archive_version" ]] || die \
  "The archived version.env does not define FLOWCAST_VERSION."

[[ "$archive_version" == "$VERSION" ]] || die \
  "The archived version.env declares '$archive_version' instead of '$VERSION'."


secret() {
  openssl rand -hex 24
}


umask 077

source_password="$(secret)"
relay_password="$(secret)"
admin_password="$(secret)"

if [[
  "$source_password" == "$relay_password"
  || "$source_password" == "$admin_password"
  || "$relay_password" == "$admin_password"
]]; then
  die \
    "Secret generation returned duplicate values."
fi


cat >"$INSTALL_DIR/.env" <<EOF
FLOWCAST_VERSION=$VERSION
FLOWCAST_HTTP_PORT=8080
FLOWCAST_STREAM_PORT=8010
FLOWCAST_AUTH_ENABLED=true
FLOWCAST_DOCKER_CONTROL_ENABLED=$DOCKER_CONTROL
FLOWCAST_PUBLIC_URL=
ICECAST_SOURCE_PASSWORD=$source_password
ICECAST_RELAY_PASSWORD=$relay_password
ICECAST_ADMIN_PASSWORD=$admin_password
EOF


if [[ "$DOCKER_CONTROL" == true ]]; then
  printf \
    'FLOWCAST_DOCKER_SOCKET=%s\nFLOWCAST_DOCKER_GID=%s\n' \
    "$DOCKER_SOCKET" \
    "$DOCKER_GID" \
    >>"$INSTALL_DIR/.env"
fi


chmod 600 "$INSTALL_DIR/.env"


compose=(
  docker compose
  --project-directory "$INSTALL_DIR"
  --env-file "$INSTALL_DIR/.env"
  -f "$INSTALL_DIR/compose.yml"
)


if [[ "$DOCKER_CONTROL" == true ]]; then
  log \
    "WARNING: Docker Control mounts $DOCKER_SOCKET into the control service. Docker socket access is effectively root-equivalent."

  compose+=(
    -f "$INSTALL_DIR/compose.docker-control.yml"
  )
fi


service_state() {
  local service="$1"
  local id
  local status
  local health
  local exit_code

  id="$(
    "${compose[@]}" ps -q "$service" 2>/dev/null \
      || true
  )"

  if [[ -z "$id" ]]; then
    printf 'missing'
    return
  fi

  status="$(
    docker inspect \
      -f '{{.State.Status}}' \
      "$id" \
      2>/dev/null \
      || true
  )"

  if [[ "$service" == "storage-init" ]]; then
    exit_code="$(
      docker inspect \
        -f '{{.State.ExitCode}}' \
        "$id" \
        2>/dev/null \
        || true
    )"

    if [[
      "$status" == "exited"
      && "$exit_code" == "0"
    ]]; then
      printf 'complete'
    else
      printf '%s/%s' "$status" "$exit_code"
    fi

    return
  fi

  health="$(
    docker inspect \
      -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
      "$id" \
      2>/dev/null \
      || true
  )"

  printf '%s' "$health"
}


wait_for_stack() {
  local timeout="${FLOWCAST_START_TIMEOUT:-300}"
  local deadline=$((SECONDS + timeout))
  local all_ready
  local service
  local state
  local summary
  local failed=()

  local services=(
    storage-init
    icecast
    bliss
    control
    engine
    audio-daemon
  )

  while ((SECONDS < deadline)); do
    all_ready=true
    summary=""

    for service in "${services[@]}"; do
      state="$(service_state "$service")"
      summary+="$service=$state "

      if [[ "$service" == "storage-init" ]]; then
        [[ "$state" == "complete" ]] \
          || all_ready=false
      else
        [[ "$state" == "healthy" ]] \
          || all_ready=false
      fi
    done

    log "startup: ${summary% }"

    if [[ "$all_ready" == true ]]; then
      return 0
    fi

    sleep 5
  done

  log \
    "Startup did not complete within $timeout seconds."

  "${compose[@]}" ps || true

  for service in "${services[@]}"; do
    state="$(service_state "$service")"

    if [[
      "$service" == "storage-init"
      && "$state" != "complete"
    ]] || [[
      "$service" != "storage-init"
      && "$state" != "healthy"
    ]]; then
      failed+=("$service")

      "${compose[@]}" logs \
        --tail 50 \
        "$service" \
        || true
    fi
  done

  if ((${#failed[@]} > 0)); then
    log \
      "Services not ready: ${failed[*]}"
  fi

  log \
    "Run diagnostics with: FLOWCAST_HOME=$INSTALL_DIR $INSTALL_DIR/scripts/community/doctor.sh"

  return 1
}


check_docker_control() {
  if [[ "$DOCKER_CONTROL" != true ]]; then
    log "docker_control=DISABLED"
    return 0
  fi

  local output

  if ! output="$(
    FLOWCAST_HOME="$INSTALL_DIR" \
      "$INSTALL_DIR/scripts/community/check-docker-control.sh" \
      2>&1
  )"; then
    log \
      "docker_control=FAIL cause=${output//$'\n'/; }"

    return 1
  fi

  log "docker_control=PASS"
}


if [[ "$START" == true ]]; then
  "${compose[@]}" pull
  "${compose[@]}" up -d

  wait_for_stack || die \
    "JuggleCast startup failed."

  check_docker_control || die \
    "Docker Control validation failed. No engine Start, Stop or Restart action was attempted."
else
  log \
    "Installation prepared without starting the JuggleCast stack."

  if [[ "$DOCKER_CONTROL" == true ]]; then
    log \
      "Docker Control will be validated after the services are started."
  else
    log "docker_control=DISABLED"
  fi
fi


lan_ip="$(
  hostname -I 2>/dev/null \
    | awk '{print $1}' \
    || true
)"

display_host="${lan_ip:-localhost}"


log "JuggleCast $VERSION is ready"
log "Control UI:       http://$display_host:8080"
log "Icecast status:   http://$display_host:8010/status-json.xsl"
log "Default mount:    /test.mp3"
log "Public stream:    http://$display_host:8080/listen/test.mp3"
log "Icecast direct:   http://$display_host:8010/test.mp3"

if [[ "$DOCKER_CONTROL" == true ]]; then
  log "Docker Control:   ENABLED"
else
  log "Docker Control:   DISABLED"
fi

log "Credentials:      $INSTALL_DIR/.env (mode 600)"
log "Diagnostics:      FLOWCAST_HOME=$INSTALL_DIR $INSTALL_DIR/scripts/community/doctor.sh"
