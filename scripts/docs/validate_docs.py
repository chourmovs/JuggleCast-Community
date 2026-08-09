#!/usr/bin/env python3
"""Dependency-free policy checks for JuggleCast public documentation."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VERSION_ENV = ROOT / "version.env"

errors: list[str] = []

REQUIRED_DOCUMENTS = [
    "LICENSE",
    "THIRD_PARTY_NOTICES.md",
    "ACKNOWLEDGEMENTS.md",
    "TRADEMARKS.md",
    "PRIVACY.md",
    "DISCLAIMER.md",
    "SUPPORT.md",
    "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md",
    "SECURITY.md",
    "docs/legal/licensing.md",
]


def read_version() -> str:
    if not VERSION_ENV.is_file():
        errors.append("missing version.env")
        return ""

    matches: list[str] = []

    for raw_line in VERSION_ENV.read_text(
        encoding="utf-8"
    ).splitlines():
        line = raw_line.strip()

        if not line or line.startswith("#"):
            continue

        if line.startswith("FLOWCAST_VERSION="):
            matches.append(
                line.split("=", 1)[1].strip()
            )

    if len(matches) != 1:
        errors.append(
            "version.env must contain exactly one "
            "FLOWCAST_VERSION assignment"
        )
        return ""

    version = matches[0]

    if not re.fullmatch(
        r"[0-9]+\.[0-9]+\.[0-9]+"
        r"(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?",
        version,
    ):
        errors.append(
            f"invalid FLOWCAST_VERSION: {version!r}"
        )

    return version


for document in REQUIRED_DOCUMENTS:
    if not (ROOT / document).is_file():
        errors.append(
            f"missing required document: {document}"
        )

version = read_version()

readme = (ROOT / "README.md").read_text(
    encoding="utf-8"
)

if version:
    install_fragment = (
        "https://raw.githubusercontent.com/"
        "chourmovs/FlowCast-Community/"
        f"v{version}/install.sh"
        " | sudo bash -s -- --version "
        f"{version}"
    )

    if install_fragment not in readme:
        errors.append(
            "README installation command does not "
            "match version.env"
        )

private_repo = re.compile(
    r"github\.com/chourmovs/FlowCast"
    r"(?:[./\s]|$)",
    re.IGNORECASE,
)

private_ip = re.compile(
    r"(?<![\d.])"
    r"(?:"
    r"10\.\d{1,3}\.\d{1,3}\.\d{1,3}"
    r"|192\.168\.\d{1,3}\.\d{1,3}"
    r"|172\.(?:1[6-9]|2\d|3[01])"
    r"\.\d{1,3}\.\d{1,3}"
    r")"
    r"(?![\d.])"
)

placeholder = re.compile(
    r"\b(?:TODO|TBD|FIXME|lorem ipsum)\b",
    re.IGNORECASE,
)

secret = re.compile(
    r"(?i)"
    r"(?:password|token|secret|license_key)"
    r"\s*[:=]\s*"
    r"[\"']?[A-Za-z0-9_./+-]{12,}"
)

link_pattern = re.compile(
    r"!?\[([^\]]*)\]\(([^)]+)\)"
)

markdown_files = (
    list(ROOT.glob("*.md"))
    + list((ROOT / "docs").rglob("*.md"))
)

headings: dict[Path, set[str]] = {}

for path in markdown_files:
    text = path.read_text(encoding="utf-8")
    relative = path.relative_to(ROOT)

    if private_repo.search(text):
        errors.append(
            f"{relative}: private repository URL forbidden"
        )

    if private_ip.search(text):
        errors.append(
            f"{relative}: private IP address forbidden"
        )

    if (
        placeholder.search(text)
        and "explicit" not in text.lower()
    ):
        errors.append(
            f"{relative}: unexplained placeholder marker"
        )

    if secret.search(text):
        errors.append(
            f"{relative}: possible secret assignment"
        )

    slugs: set[str] = set()

    for heading in re.findall(
        r"^#{1,6}\s+(.+?)\s*$",
        text,
        re.MULTILINE,
    ):
        slug = re.sub(
            r"[^\w\- ]",
            "",
            heading.lower(),
        ).strip().replace(" ", "-")

        slugs.add(slug)

    headings[path.resolve()] = slugs

    for match in link_pattern.finditer(text):
        alt = match.group(1)
        target = match.group(2)

        if target.startswith(
            ("http://", "https://", "mailto:", "#")
        ):
            continue

        raw_target = target.split("#", 1)[0]

        destination = (
            (path.parent / raw_target).resolve()
            if raw_target
            else path.resolve()
        )

        if not destination.exists():
            errors.append(
                f"{relative}: broken relative link {target}"
            )

        if (
            match.group(0).startswith("!")
            and not alt.strip()
        ):
            errors.append(
                f"{relative}: image missing alt text"
            )

for path in markdown_files:
    text = path.read_text(encoding="utf-8")
    relative = path.relative_to(ROOT)

    for _, target in link_pattern.findall(text):
        if (
            "#" not in target
            or target.startswith(
                ("http://", "https://")
            )
        ):
            continue

        raw_target, anchor = target.split("#", 1)

        destination = (
            (path.parent / raw_target).resolve()
            if raw_target
            else path.resolve()
        )

        if (
            destination in headings
            and anchor
            and anchor.lower()
            not in headings[destination]
        ):
            errors.append(
                f"{relative}: missing anchor "
                f"#{anchor} in "
                f"{destination.relative_to(ROOT)}"
            )

assets_directory = ROOT / "docs" / "assets"

if assets_directory.is_dir():
    for image in assets_directory.rglob("*"):
        if (
            image.is_file()
            and image.stat().st_size > 5_000_000
        ):
            errors.append(
                f"{image.relative_to(ROOT)}: "
                "image exceeds 5 MB"
            )

for manifest in (
    list(ROOT.glob("*.yml"))
    + list(ROOT.glob("*.yaml"))
):
    if re.search(
        r"AGPL",
        manifest.read_text(encoding="utf-8"),
        re.IGNORECASE,
    ):
        errors.append(
            f"{manifest.name}: unexpected AGPL declaration"
        )

if errors:
    print(
        "\n".join(
            f"ERROR: {error}"
            for error in errors
        )
    )
    sys.exit(1)

print(
    "documentation validation passed: "
    f"{len(markdown_files)} Markdown files, "
    f"version {version}"
)
