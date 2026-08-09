# Contributing

[Repository home](README.md) · [Documentation index](docs/README.md) · [Code of Conduct](CODE_OF_CONDUCT.md)

Search existing issues, then use the structured bug or feature form. Bug reports must include the JuggleCast version, OS/architecture, Docker and Compose versions, Docker Control mode, sanitized `doctor.sh` result, reproduction steps, expected and actual behavior, and minimal redacted logs.

Never post `.env`, licence keys, Icecast passwords, tokens, cookies, databases, backups, private media, personal data, private addresses, machine names or confidential URLs. Report vulnerabilities through [private security reporting](SECURITY.md), not public issues.

1. Fork this public repository and create a focused branch.
2. Keep runtime behavior, images and operational contracts unchanged unless the proposed contribution explicitly and safely addresses them.
3. Add tests and documentation, keep links navigable and preserve the tagged install command.
4. Run `git diff --check`, `python3 scripts/docs/validate_docs.py`, `python3 -m unittest discover -s tests -v`, and applicable shell/Compose checks.
5. Submit a pull request using the template and explain security/licensing implications.

Contributions to files in this repository are accepted under its [MIT licence](LICENSE). This does not change image, dependency, commercial or trademark terms; see [licensing layers](docs/legal/licensing.md). Community review and support are best effort with no SLA.

Maintainers preparing a release must follow the [Community release operator runbook](docs/release/community-beta-release.md); its gates remain mandatory and are not duplicated here.
