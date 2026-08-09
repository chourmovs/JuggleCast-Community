# JuggleCast Community 0.1.0-rc.8

[Repository home](../../README.md) · [Documentation index](../README.md)

RC8 expands JuggleCast beyond scheduling and playout with four operator-facing capability groups while preserving the same self-hosted, no-Liquidsoap architecture.

## Public station pages and embeddable widgets

Stations can publish listener-safe programming information and generate embeddable widgets for external sites.

RC8 includes:

- public station programming with Now Playing, recently played and upcoming tracks;
- opaque public artwork access without exposing local paths;
- embeddable player, history, upcoming and listener-count widgets;
- three genuinely different player layouts: Normal, Compact and Minimal;
- an authenticated widget configurator for previewing and copying iframe snippets.

## Backup and restore

RC8 adds the `.fcbak` lifecycle:

- Essential backups without media;
- Full backups including the media library;
- persistent full-backup jobs executed by isolated workers;
- resumable browser uploads with Pause, Resume and Cancel;
- strict archive validation before publication;
- transactional restore;
- pre-restore snapshot;
- automatic rollback attempt on failure;
- media locking and capacity checks.

The Community runtime now provides the persistent `flowcast-backups` volume required by these operations.

## Station statistics

RC8 adds station-scoped audience statistics sourced from real Icecast activity.

The control UI exposes Overview, Real-Time and History & Reports views, including:

- live listeners;
- listener sessions;
- time-series samples and trends;
- country breakdowns;
- player-family breakdowns;
- device-family breakdowns.

Icecast access logs are persisted at `/data/icecast/access.log` and mounted read-only into the control plane. Listener identifiers are derived locally with HMAC-SHA256; raw listener IP addresses are not stored by the statistics subsystem.

Default retention is 365 days for sessions and 90 days for time-series samples.

## Runtime compatibility

RC8 Community requires a Compose contract that includes:

- `flowcast-backups:/data/flowcast-backups` on control;
- `icecast-logs:/data/icecast` on Icecast;
- `icecast-logs:/data/icecast:ro` on control;
- statistics retention environment defaults;
- Docker Control for worker-driven restore/full-backup orchestration.

Do not deploy RC8 service images behind an older RC7 Community Compose file: the UI may be present while backup/restore or station statistics are unable to use their required persistent mounts.
