# Reverse proxy and TLS

[Repository home](../../README.md) · [Documentation index](../README.md) · [Previous guide](schedule-programming.md) · [Next guide](backup-update-rollback.md)

## Objective

Place an operator-managed TLS reverse proxy in front of JuggleCast without changing internal service ports.

## Prerequisites

A working local installation, a public DNS name and a separately administered reverse proxy/TLS certificate.

## Procedure

1. Keep JuggleCast bound to its configured host ports and restrict them with host/network policy as appropriate.
2. Configure the chosen reverse proxy to forward HTTP and streaming requests to the JuggleCast control endpoint; follow that proxy’s official documentation for WebSocket/streaming support.
3. Set `FLOWCAST_PUBLIC_URL` in `/opt/flowcast/.env` to the exact external HTTPS origin only when an explicit origin is required.
4. From `/opt/flowcast`, apply the documented Compose lifecycle: `docker compose --env-file .env -f compose.yml up -d`. Include `-f compose.docker-control.yml` when Docker Control is enabled.
5. Verify authentication and the same-origin `/listen/test.mp3` endpoint over HTTPS.

## Expected result

The interface and proxied stream load at the external HTTPS origin without mixed-content errors.

## Verification

Run `sudo /opt/flowcast/scripts/community/doctor.sh` locally and test the external URL from another network.

## Troubleshooting

Check proxy forwarding headers, streaming timeouts, certificate chain and DNS. Do not expose the Docker socket or `.env` through the proxy.

## Rollback

Restore the previous `FLOWCAST_PUBLIC_URL` value and proxy configuration, then reapply Compose.

## Related documentation

- [Quick start](../community/quick-start.md)
- [Runtime contract](../community/runtime-contract.md)
- [Security policy](../../SECURITY.md)
