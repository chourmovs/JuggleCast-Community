# Runtime contract

[Repository home](../../README.md) · [Documentation index](../README.md)

The canonical Community distribution has six Compose services: `storage-init`, `icecast`, `bliss`, `audio-daemon`, `engine`, and `control`. The public HTTP mapping targets control port 8088; Bliss listens on 8090; Icecast listens on 8000. `audio-daemon` uses the analyzer OCI image but is never named `analyzer` as a Compose service.

## Persistent state

RC8 separates persistent state into:

- `flowcast-catalog`
- `flowcast-media`
- `flowcast-settings`
- `flowcast-engine-history`
- `flowcast-cache`
- `flowcast-analysis`
- `flowcast-runtime-state`
- `flowcast-backups`
- `icecast-logs`

Control and engine share `/flowcast` and `/data/engine_history`. Engine writes runtime state through `/tmp`, while control reads the same runtime-state volume at `/runtime-state` read-only. Both control and engine wait for a successful `storage-init`.

The RC8 backup/restore workers inspect the running control container to recover the actual persistent volume sources. The following control targets are therefore part of the release contract and must remain real Docker mounts: `/flowcast`, `/data/flowcast`, `/data/flowcast-media`, `/data/engine_history`, and `/data/flowcast-backups`.

## Station statistics and Icecast logs

Icecast persists its access log in the `icecast-logs` volume mounted at `/data/icecast`. Control receives the same volume at `/data/icecast:ro`.

This gives the RC8 statistics collector access to `/data/icecast/access.log` without granting the control plane write access to Icecast logs.

Statistics data and the local HMAC secret are persisted with the JuggleCast catalog state. Raw listener IP addresses are not stored by the statistics subsystem.

The Community defaults are:

```env
FLOWCAST_STATISTICS_SESSION_RETENTION_DAYS=365
FLOWCAST_STATISTICS_SAMPLE_RETENTION_DAYS=90
```

## Runtime validation

Retired `/media`, `/settings`, `/history`, `/analysis`, 8091, and 8092 contracts are forbidden by the runtime audit.

The public manifest mirrors the six-service distribution boundary without containing private source. The five public image names, entrypoint commands, environment keys, dependencies, health checks, and volume targets are enforced by `scripts/audit-runtime-contract.py`.

The engine image's `flowcast-engine --healthcheck` remains authoritative for the Community contract.

## Docker Control

Docker socket access is absent from the base manifest. The explicit `compose.docker-control.yml` override mounts the host Unix socket and adds the socket's detected numeric GID to the non-root control process.

The standard installer enables Docker Control by default. Pass `--no-docker-control` only when the control plane must not manage Docker services. Socket access is effectively root-equivalent and must be treated as a privileged operator capability.
