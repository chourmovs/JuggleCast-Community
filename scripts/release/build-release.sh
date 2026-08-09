#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: build-release.sh VERSION}"

[[ "$VERSION" =~ ^0\.1\.0-rc\.[0-9]+$ ]] || {
  echo "invalid release version: $VERSION" >&2
  exit 1
}

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/../.."
  pwd
)"

DIST="$ROOT/dist"
STAGE="$DIST/stage"
ARCHIVE="$DIST/jugglecast-community-v$VERSION.tar.gz"
LEGACY_ARCHIVE="$DIST/flowcast-community-v$VERSION.tar.gz"

rm -rf "$STAGE"
mkdir -p "$STAGE"

[[ -f "$DIST/images.lock" ]] || {
  echo "missing release image lock: $DIST/images.lock" >&2
  exit 1
}

cp "$DIST/images.lock" "$STAGE/images.lock"

for path in \
  compose.yml \
  compose.docker-control.yml \
  .env.example \
  version.env \
  README.md \
  LICENSE \
  install.sh \
  scripts \
  docs
do
  [[ -e "$ROOT/$path" ]] || {
    echo "missing release input: $path" >&2
    exit 1
  }

  cp -a "$ROOT/$path" "$STAGE/"
done

find "$STAGE" \
  -type d \
  \( -name __pycache__ -o -name .pytest_cache \) \
  -prune \
  -exec rm -rf {} +

version_assignment_count="$(
  grep -c '^FLOWCAST_VERSION=' "$STAGE/version.env" \
    || true
)"

[[ "$version_assignment_count" -eq 1 ]] || {
  echo \
    "version.env must contain exactly one FLOWCAST_VERSION assignment" \
    >&2
  exit 1
}

sed -i \
  "s/^FLOWCAST_VERSION=.*/FLOWCAST_VERSION=$VERSION/" \
  "$STAGE/version.env"

if grep -q '^FLOWCAST_VERSION=' "$STAGE/.env.example"; then
  echo \
    ".env.example must not define FLOWCAST_VERSION" \
    >&2
  exit 1
fi

if [[ -e "$STAGE/VERSION" || -e "$STAGE/versions.env" ]]; then
  echo \
    "legacy version files must not be included in the release archive" \
    >&2
  exit 1
fi

jq \
  -n \
  --arg version "$VERSION" \
  --arg commit "$(git -C "$ROOT" rev-parse HEAD)" \
  --arg tag "v$VERSION" \
  '{
    schema_version: 1,
    version: $version,
    git_commit: $commit,
    git_tag: $tag,
    platforms: ["linux/amd64"],
    archive: {
      filename: ("jugglecast-community-v" + $version + ".tar.gz"),
      sha256: "pending"
    },
    images_lock: "images.lock"
  }' \
  >"$STAGE/release-manifest.json"

commit_timestamp="$(
  git -C "$ROOT" log -1 --format=%ct
)"

tar \
  --sort=name \
  --mtime="@$commit_timestamp" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -czf "$ARCHIVE" \
  -C "$STAGE" \
  .

# RC8 tooling may still request the historical filename. Both names contain
# byte-identical content and remain covered by the published checksum file.
cp -p "$ARCHIVE" "$LEGACY_ARCHIVE"

EXTRACTED="$(mktemp -d)"

cleanup() {
  rm -rf "$EXTRACTED"
}

trap cleanup EXIT

tar \
  -xzf "$ARCHIVE" \
  -C "$EXTRACTED"

for path in \
  compose.yml \
  compose.docker-control.yml \
  install.sh \
  scripts/community/doctor.sh
do
  cmp \
    "$ROOT/$path" \
    "$EXTRACTED/$path"
done

[[ -f "$EXTRACTED/version.env" ]] || {
  echo "release archive is missing version.env" >&2
  exit 1
}

[[ ! -e "$EXTRACTED/VERSION" ]] || {
  echo "release archive unexpectedly contains VERSION" >&2
  exit 1
}

[[ ! -e "$EXTRACTED/versions.env" ]] || {
  echo "release archive unexpectedly contains versions.env" >&2
  exit 1
}

archive_version="$(
  sed -n \
    's/^FLOWCAST_VERSION=//p' \
    "$EXTRACTED/version.env"
)"

[[ "$archive_version" == "$VERSION" ]] || {
  echo \
    "release archive version '$archive_version' does not match '$VERSION'" \
    >&2
  exit 1
}

if grep -q '^FLOWCAST_VERSION=' "$EXTRACTED/.env.example"; then
  echo \
    "release archive .env.example must not define FLOWCAST_VERSION" \
    >&2
  exit 1
fi

grep \
  -Fq \
  '/usr/local/bin/flowcast-analyzer' \
  "$EXTRACTED/compose.yml"

grep \
  -Fq \
  -- \
  '--healthcheck' \
  "$EXTRACTED/compose.yml"

! grep \
  -Fq \
  'http://localhost:8091/health' \
  "$EXTRACTED/compose.yml"

! grep \
  -Fq \
  'http://localhost:8092/health' \
  "$EXTRACTED/compose.yml"

python3 \
  - "$EXTRACTED" "$VERSION" \
  <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
expected = sys.argv[2]

version_env = root / "version.env"

if not version_env.is_file():
    raise SystemExit("release archive is missing version.env")

content = version_env.read_text(encoding="utf-8")

assignments = re.findall(
    r"^FLOWCAST_VERSION=(.+)$",
    content,
    re.MULTILINE,
)

if assignments != [expected]:
    raise SystemExit(
        "release archive has an invalid version.env: "
        f"{assignments!r}; expected {[expected]!r}"
    )

legacy_files = [
    root / "VERSION",
    root / "versions.env",
]

found_legacy = [
    str(path.relative_to(root))
    for path in legacy_files
    if path.exists()
]

if found_legacy:
    raise SystemExit(
        "release archive contains legacy version files: "
        f"{found_legacy}"
    )

env_example = root / ".env.example"

if "FLOWCAST_VERSION" in env_example.read_text(encoding="utf-8"):
    raise SystemExit(
        ".env.example must not contain FLOWCAST_VERSION"
    )
PY

sha256sum "$ARCHIVE" "$LEGACY_ARCHIVE" \
  | sed "s#  $DIST/#  #" \
  >"$DIST/checksums.sha256"

digest="$(
  cut \
    -d' ' \
    -f1 \
    "$DIST/checksums.sha256"
)"

jq \
  --arg digest "$digest" \
  '.archive.sha256 = $digest' \
  "$STAGE/release-manifest.json" \
  >"$DIST/release-manifest.json"

echo \
  "Built JuggleCast Community release archives: $ARCHIVE and $LEGACY_ARCHIVE"
