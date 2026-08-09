# Quick start

[Repository home](../../README.md) · [Documentation index](../README.md)

JuggleCast Community RC8 requires linux/amd64, Docker Engine with Compose v2, 4 GB RAM, 10 GB free disk plus media/backup capacity, and free TCP ports 8080 and 8010.

Review and run the tagged installer shown in the repository README with `sudo bash`; the script itself never escalates privileges or installs Docker.

```bash
curl -fsSL \
  https://raw.githubusercontent.com/chourmovs/FlowCast-Community/vVERSION/install.sh \
  | sudo bash -s -- --version VERSION
```

It installs into `/opt/flowcast`, verifies the archive checksum and release version, creates a mode-`0600` `.env`, pulls images, and explicitly waits for `storage-init`, `icecast`, `bliss`, `control`, `engine`, and `audio-daemon`.

Open the interface at `http://localhost:8080` and Icecast at `http://localhost:8010`.

An existing `.env` is never overwritten. Update it with:

```bash
sudo /opt/flowcast/scripts/community/update.sh --version VERSION
```

or back up and deliberately remove/restore the old installation.

## Docker Control default

Docker Control is enabled by default in the standard installer. The Unix socket and its GID are detected during installation, and an inaccessible socket is a hard error.

Pass `--no-docker-control` only when the control plane must not provide Start/Stop/Restart and worker-driven operations. Docker socket access is effectively root-equivalent.

Diagnose a failed startup with:

```bash
sudo /opt/flowcast/scripts/community/doctor.sh
```

Uninstall with `sudo /opt/flowcast/scripts/community/uninstall.sh`; add `--purge-data` only when permanent deletion is intended.

## Functional streaming qualification

On a clean Linux/amd64 host, install Docker Engine and Compose v2, download and review the tagged installer, and run it. Import operator-owned or freely licensed audio through the UI.

If a local test tone is preferable, generate one without committing media:

```bash
sudo /opt/flowcast/scripts/community/test-runtime-stream.sh --generate-fixture /tmp/flowcast-fixture.wav
# Import /tmp/flowcast-fixture.wav, configure/schedule it, then:
sudo /opt/flowcast/scripts/community/test-runtime-stream.sh --mount /stream
```

The test waits for the completed initializer and healthy services, checks both HTTP APIs and the configured mount, consumes audio, checks restart counts and fresh runtime state, and rejects recent persistent engine/Icecast failures.

A successful standard install must report `docker_control=PASS`. Only an explicit `--no-docker-control` installation reports `docker_control=DISABLED`.

## RC8 operational additions

RC8 adds persistent mounts used by the operator-facing backup and statistics features:

- backups: `/data/flowcast-backups`;
- Icecast access logs: `/data/icecast` on Icecast and read-only on control.

The statistics subsystem defaults to 365 days of session history and 90 days of time-series samples.

After installation, use the control UI to test:

1. an Essential `.fcbak` backup;
2. a Full backup on a small media library;
3. the Statistics page for the configured station;
4. a public station page;
5. Normal, Compact and Minimal player widget previews.

The web/player endpoint is port 8080 and the direct Icecast endpoint is port 8010. Container-to-container traffic uses `icecast:8000`. Public player links are same-origin relative unless the optional `FLOWCAST_PUBLIC_URL` reverse-proxy override is set.
