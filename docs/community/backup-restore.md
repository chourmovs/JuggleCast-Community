# Backup and restore

[Repository home](../../README.md) · [Documentation index](../README.md)

JuggleCast RC8 has two complementary backup paths: the host-level Community maintenance scripts and the authenticated in-app `.fcbak` workflow.

## In-app `.fcbak` backups

The control plane can create two archive profiles:

- **Essential** — settings, catalog and engine history, without the media library.
- **Full** — the Essential data plus the media library.

Full backups are long-running operations. RC8 launches them as persistent jobs in an isolated worker container and reports progress back to the control UI. The worker uses the same immutable control image and the real persistent mounts exposed by the Community Compose contract.

Generated archives are stored in the persistent `flowcast-backups` volume at `/data/flowcast-backups`.

## Large and resumable uploads

RC8 accepts `.fcbak` imports through a persistent resumable upload path intended for large archives. The browser can pause, resume or cancel a transfer, and an interrupted upload can continue without retransmitting the completed portion.

Partial uploads are not treated as valid backups. An archive is published only after server-side validation succeeds.

## Restore safety

Restore is deliberately stricter than backup creation.

Before a restore starts, JuggleCast:

1. validates the archive and its manifest/checksums;
2. checks archive and media limits;
3. verifies available capacity;
4. acquires the operation/media locks;
5. requires the restore acknowledgements exposed by the UI.

The restore itself runs in an ephemeral Docker worker rather than inside the control HTTP process.

For Full restores, media replacement is transactional: new media are staged on the media volume, then swapped into place. JuggleCast creates a pre-restore snapshot and attempts an automatic rollback if the restore fails.

Docker Control must be available for the worker-driven restore lifecycle. The standard Community installation enables Docker Control; installations created with `--no-docker-control` can still create ordinary Essential backups but cannot perform operations that require Docker worker orchestration.

## Persistent mounts required by RC8

The `control` container must keep true Docker mounts at:

- `/flowcast`
- `/data/flowcast`
- `/data/flowcast-media`
- `/data/engine_history`
- `/data/flowcast-backups`

Do not replace those mounts with container-local directories. The backup and restore workers discover the persistent volume sources by inspecting the running control container.

## Host-level disaster-recovery scripts

The Community maintenance scripts remain useful for host-level recovery:

```bash
sudo /opt/flowcast/scripts/community/backup.sh
```

By default the host-level backup excludes media. Use `--include-media` when an offline archive of the media volume is required.

Restore a host-level archive with:

```bash
sudo /opt/flowcast/scripts/community/restore.sh --backup FILE
```

The host-level path stops the stack while replacing persistent state. Protect those archives as secrets because they include the installation `.env`.

The in-app `.fcbak` workflow and the host-level scripts solve different problems: use `.fcbak` for operator-facing portable backups and transactional restores; keep host-level backups for infrastructure disaster recovery.
