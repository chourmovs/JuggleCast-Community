# Docker Control

[Repository home](../../README.md) · [Documentation index](../README.md) · [Previous guide](backup-update-rollback.md) · [Next guide](troubleshoot-stream.md)

## Objective

Choose and verify the root-equivalent service-control integration.

## Prerequisites

A trusted administrator, local Docker Engine and review of the Docker socket risk.

## Procedure

1. For the validated rc.6 installer default, install normally to enable Docker Control, or append `--no-docker-control` to opt out.
2. Confirm that the detected Unix socket and numeric GID are correct in the installation result; do not manually broaden socket permissions.
3. Run `sudo /opt/flowcast/scripts/community/doctor.sh`.
4. Restrict the JuggleCast interface to trusted administrators.

## Expected result

When enabled, authenticated service controls work; when explicitly disabled, broadcasting continues without those UI controls.

## Verification

Confirm the `docker_control` result reported by installation/diagnostics and exercise a non-disruptive status view.

## Troubleshooting

A missing/non-Unix socket or insufficient access is an installation error. Prefer disabling the integration rather than weakening host permissions.

## Rollback

To change an existing rc.6 installation, use the documented updater choice; `sudo /opt/flowcast/scripts/community/update.sh --version 0.1.0-rc.6 --enable-docker-control` opts in after review. Restore the prior explicit choice if validation fails.

## Related documentation

- [Quick start](../community/quick-start.md)
- [Runtime contract](../community/runtime-contract.md)
- [Security policy](../../SECURITY.md)
