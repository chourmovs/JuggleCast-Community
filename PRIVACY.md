# Privacy

[Repository home](README.md) · [Documentation index](docs/README.md)

JuggleCast Community operates locally on operator-managed infrastructure, requires no mandatory telemetry, and needs no remote licence service to broadcast. Normal self-hosted operation still creates local application, playback, access and container logs; the operator controls their retention and access.

Information may leave the installation when the operator explicitly configures network destinations such as an Icecast audience endpoint, reverse proxy, update/image registry, or optional Pro licensing. As currently documented, an explicitly enabled Pro licence request may transmit a licence identifier, JuggleCast version, installation identifier, requested entitlement and coarse platform metadata; it must not be required for Community broadcasting.

Operators are responsible for notices, lawful bases, retention, access controls and personal-data handling applicable to listeners, administrators and logged network identifiers. Review configuration and traffic for the exact release deployed.
