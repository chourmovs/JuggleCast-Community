from pathlib import Path
import re
import unittest


ROOT = Path(__file__).parents[1]


class InstallerContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.install = (
            ROOT / "install.sh"
        ).read_text(
            encoding="utf-8"
        )

    def test_default_and_override_version(self):
        self.assertIn(
            'VERSION_ENV="$SCRIPT_DIR/version.env"',
            self.install,
        )

        self.assertIn(
            'if [[ -f "$VERSION_ENV" ]]',
            self.install,
        )

        self.assertIn(
            "'s/^FLOWCAST_VERSION=//p'",
            self.install,
        )

        self.assertIn(
            'VERSION="${FLOWCAST_VERSION:-$DEFAULT_VERSION}"',
            self.install,
        )

        self.assertIn(
            "--version)",
            self.install,
        )

        self.assertIn(
            'VERSION="${2#v}"',
            self.install,
        )

        self.assertNotIn(
            'cat "$SCRIPT_DIR/VERSION"',
            self.install,
        )

        self.assertNotRegex(
            self.install,
            r'VERSION="0\.1\.0-rc\.\d+"',
        )

    def test_amd64_only(self):
        self.assertRegex(
            self.install,
            r"x86_64\|amd64",
        )

        self.assertIn(
            "currently published for linux/amd64 only",
            self.install,
        )

    def test_archive_integrity_and_manifest_version(self):
        self.assertIn(
            "jugglecast-community-$TAG.tar.gz",
            self.install,
        )
        self.assertIn(
            "flowcast-community-$TAG.tar.gz",
            self.install,
        )
        self.assertIn(
            "RC8-compatible asset name",
            self.install,
        )

        self.assertIn(
            "sha256sum -c -",
            self.install,
        )

        self.assertIn(
            "does not match requested version",
            self.install,
        )

        self.assertIn(
            "release-manifest.json",
            self.install,
        )

        self.assertIn(
            "archive_version",
            self.install,
        )

        self.assertIn(
            "$INSTALL_DIR/version.env",
            self.install,
        )

    def test_existing_install_and_secrets(self):
        self.assertIn(
            "existing JuggleCast installation",
            self.install,
        )

        names = re.findall(
            r"^ICECAST_(?:SOURCE|RELAY|ADMIN)_PASSWORD=",
            self.install,
            re.MULTILINE,
        )

        self.assertEqual(
            len(names),
            3,
        )

        self.assertIn(
            "chmod 600",
            self.install,
        )

    def test_override_and_explicit_states(self):
        self.assertIn(
            "compose.docker-control.yml",
            self.install,
        )

        for service in (
            "storage-init",
            "icecast",
            "bliss",
            "control",
            "engine",
            "audio-daemon",
        ):
            with self.subTest(
                service=service
            ):
                self.assertIn(
                    service,
                    self.install,
                )

        self.assertIn(
            "FLOWCAST_START_TIMEOUT:-300",
            self.install,
        )

    def test_dynamic_docker_socket_group_and_validation(self):
        self.assertIn(
            "stat -c '%g'",
            self.install,
        )

        self.assertIn(
            '[[ -S "$socket" ]]',
            self.install,
        )

        self.assertIn(
            "FLOWCAST_DOCKER_GID",
            self.install,
        )

        self.assertIn(
            "check-docker-control.sh",
            self.install,
        )


class ReleaseContractTests(unittest.TestCase):
    def test_assets_and_manual_publication_gate(self):
        workflow = (
            ROOT
            / ".github"
            / "workflows"
            / "release.yml"
        ).read_text(
            encoding="utf-8"
        )

        expected_assets = (
            "jugglecast-community-v"
            "${{ env.FLOWCAST_VERSION }}.tar.gz",
            "flowcast-community-v"
            "${{ env.FLOWCAST_VERSION }}.tar.gz",
            "checksums.sha256",
            "images.lock",
            "release-manifest.json",
            "sbom.spdx.json",
        )

        for asset in expected_assets:
            with self.subTest(
                asset=asset
            ):
                self.assertIn(
                    asset,
                    workflow,
                )

        self.assertIn(
            "if: ${{ inputs.publish }}",
            workflow,
        )

        self.assertIn(
            'echo "FLOWCAST_VERSION=$version" >> "$GITHUB_ENV"',
            workflow,
        )

        self.assertIn(
            "--env-file version.env",
            workflow,
        )

        self.assertNotIn(
            "${{ inputs.version }}",
            workflow,
        )

    def test_exact_archive_content_script(self):
        script = (
            ROOT
            / "scripts"
            / "release"
            / "build-release.sh"
        ).read_text(
            encoding="utf-8"
        )

        required_items = (
            "compose.yml",
            "compose.docker-control.yml",
            ".env.example",
            "version.env",
            "README.md",
            "LICENSE",
            "install.sh",
            "scripts",
            "docs",
        )

        for item in required_items:
            with self.subTest(
                item=item
            ):
                self.assertIn(
                    item,
                    script,
                )

        self.assertIn(
            '"$STAGE/version.env"',
            script,
        )

        self.assertIn(
            '"$EXTRACTED/version.env"',
            script,
        )

        self.assertIn(
            "legacy version files",
            script,
        )

        self.assertIn(
            '"$STAGE/VERSION"',
            script,
        )

        self.assertIn(
            '"$STAGE/versions.env"',
            script,
        )

        self.assertNotIn(
            "git archive",
            script,
        )

    def test_all_public_images_and_amd64_are_checked(self):
        script = (
            ROOT
            / "scripts"
            / "release"
            / "inspect-images.sh"
        ).read_text(
            encoding="utf-8"
        )

        for image in (
            "control",
            "engine",
            "analyzer",
            "bliss",
            "icecast",
        ):
            with self.subTest(
                image=image
            ):
                self.assertIn(
                    image,
                    script,
                )

        self.assertIn(
            "linux",
            script,
        )

        self.assertIn(
            "amd64",
            script,
        )

        self.assertIn(
            "attempt in 1 2 3",
            script,
        )

        self.assertIn(
            "{{json .Image}}",
            script,
        )

    def test_workflow_installs_buildx_before_inspection(self):
        workflow = (
            ROOT
            / ".github"
            / "workflows"
            / "release.yml"
        ).read_text(
            encoding="utf-8"
        )

        setup = workflow.index(
            "docker/setup-buildx-action@v3"
        )

        inspect = workflow.index(
            "scripts/release/inspect-images.sh"
        )

        self.assertLess(
            setup,
            inspect,
        )

    def test_doctor_allow_lists_environment_and_never_dumps_secrets(
        self,
    ):
        doctor = (
            ROOT
            / "scripts"
            / "community"
            / "doctor.sh"
        ).read_text(
            encoding="utf-8"
        )

        common = (
            ROOT
            / "scripts"
            / "lib"
            / "common.sh"
        ).read_text(
            encoding="utf-8"
        )

        self.assertIn(
            "load_env",
            doctor,
        )

        self.assertNotIn(
            'cat "$FLOWCAST_HOME/.env"',
            doctor,
        )

        self.assertNotIn(
            "ICECAST_SOURCE_PASSWORD",
            common,
        )

        self.assertIn(
            "secret values and data contents were intentionally omitted",
            doctor,
        )


if __name__ == "__main__":
    unittest.main()
