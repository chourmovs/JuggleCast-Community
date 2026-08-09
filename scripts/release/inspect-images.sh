#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: inspect-images.sh VERSION}"
command -v docker >/dev/null || { echo 'docker is required' >&2; exit 1; }
command -v jq >/dev/null || { echo 'jq is required' >&2; exit 1; }

services=(control engine analyzer bliss icecast)
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

inspect_raw() {
  local reference="$1" output="$2" attempt
  for attempt in 1 2 3; do
    if docker buildx imagetools inspect --raw "$reference" >"$output" 2>"$output.err"; then
      return 0
    fi
    echo "Anonymous inspection attempt $attempt/3 failed for $reference:" >&2
    sed 's/^/  /' "$output.err" >&2
    (( attempt == 3 )) || sleep $((attempt * 5))
  done
  echo "Public image is unavailable or cannot be read anonymously: $reference" >&2
  return 1
}

has_amd64() {
  local reference="$1" manifest="$2" image
  if jq -e '.manifests? | type == "array"' "$manifest" >/dev/null; then
    jq -e 'any(.manifests[]; .platform.os == "linux" and .platform.architecture == "amd64")' "$manifest" >/dev/null
    return
  fi

  # A single-platform manifest does not carry its own platform. Buildx resolves
  # the referenced image configuration so it can still be checked explicitly.
  image="$(docker buildx imagetools inspect --format '{{json .Image}}' "$reference" 2>"$manifest.platform.err")" || {
    echo "Could not resolve platform metadata for $reference:" >&2
    sed 's/^/  /' "$manifest.platform.err" >&2
    return 1
  }
  jq -e '.os == "linux" and .architecture == "amd64"' <<<"$image" >/dev/null
}

for service in "${services[@]}"; do
  reference="ghcr.io/chourmovs/jugglecast-$service:$VERSION"
  manifest="$tmp/$service.json"
  inspect_raw "$reference" "$manifest"
  jq -e . "$manifest" >/dev/null || { echo "Registry returned invalid manifest JSON for $reference" >&2; exit 1; }
  has_amd64 "$reference" "$manifest" || { echo "Image lacks linux/amd64: $reference" >&2; exit 1; }
  docker buildx imagetools inspect "$reference" 2>"$manifest.digest.err" \
    | awk '$1 == "Digest:" {print $2; exit}' >"$tmp/$service.digest" || true
  if ! grep -Eq '^sha256:[0-9a-f]{64}$' "$tmp/$service.digest"; then
    echo "Could not resolve the registry manifest digest for $reference:" >&2
    sed 's/^/  /' "$manifest.digest.err" >&2
    exit 1
  fi
done

jq -n --arg version "$VERSION" --argjson platforms '["linux/amd64"]' \
  --arg c "$(cat "$tmp/control.digest")" --arg e "$(cat "$tmp/engine.digest")" --arg a "$(cat "$tmp/analyzer.digest")" --arg b "$(cat "$tmp/bliss.digest")" --arg i "$(cat "$tmp/icecast.digest")" \
  '{version:$version,platforms:$platforms,images:{control:{reference:("ghcr.io/chourmovs/jugglecast-control:"+$version),digest:$c},engine:{reference:("ghcr.io/chourmovs/jugglecast-engine:"+$version),digest:$e},"audio-daemon":{reference:("ghcr.io/chourmovs/jugglecast-analyzer:"+$version),digest:$a},bliss:{reference:("ghcr.io/chourmovs/jugglecast-bliss:"+$version),digest:$b},icecast:{reference:("ghcr.io/chourmovs/jugglecast-icecast:"+$version),digest:$i}}}'
