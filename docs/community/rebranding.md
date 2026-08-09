# JuggleCast rebranding compatibility

[Repository home](../../README.md) · [Documentation index](../README.md)

JuggleCast is the continuation of FlowCast. The RC9 rebranding changes the product identity and public OCI image names without migrating persistent runtime contracts.

The following historical identifiers intentionally remain unchanged in RC9:

- environment variables beginning with `FLOWCAST_`;
- the default installation directory `/opt/flowcast`;
- the Compose project name `flowcast`;
- named volumes beginning with `flowcast-`;
- internal binaries and entrypoints such as `flowcast-engine` and `flowcast-analyzer`;
- persisted configuration keys, database paths and the `.fcbak` backup format;

The public repository has moved to `chourmovs/JuggleCast-Community`. Existing URLs that use the former `FlowCast-Community` slug are retained only as GitHub redirects; new documentation and installer commands use the JuggleCast slug.

A clean RC9 installation uses the `ghcr.io/chourmovs/jugglecast-*` image family. The release also keeps byte-identical `flowcast-community-v0.1.0-rc.9.tar.gz` and `jugglecast-community-v0.1.0-rc.9.tar.gz` archives so RC8-era tooling can continue resolving the historical filename.

Existing RC8 installations may continue using their current Compose file and the temporary `flowcast-*` image aliases. Persistent volumes must not be renamed or copied into new empty volumes during the rebranding.
