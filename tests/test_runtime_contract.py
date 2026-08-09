from copy import deepcopy
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tarfile
import unittest
from unittest import mock


ROOT = Path(__file__).parents[1]

SPEC = importlib.util.spec_from_file_location(
    "runtime_contract",
    ROOT / "scripts" / "audit-runtime-contract.py",
)

if SPEC is None or SPEC.loader is None:
    raise RuntimeError(
        "Unable to load scripts/audit-runtime-contract.py"
    )

RUNTIME_CONTRACT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNTIME_CONTRACT)


@unittest.skipUnless(
    shutil.which("docker"),
    "Docker Compose is required to render the contract",
)
class RuntimeContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.version = RUNTIME_CONTRACT.current_version()

        cls.images = RUNTIME_CONTRACT.expected_images(
            cls.version
        )

        cls.main = RUNTIME_CONTRACT.render(
            "compose.yml"
        )

        cls.override = RUNTIME_CONTRACT.render(
            "compose.yml",
            "compose.docker-control.yml",
        )

        cls.source = (
            ROOT / "compose.yml"
        ).read_text(
            encoding="utf-8"
        )

    def test_current_contract_passes(self):
        self.assertEqual(
            RUNTIME_CONTRACT.audit(
                self.main,
                self.override,
                self.source,
                self.images,
            ),
            [],
        )

    def test_retired_health_endpoint_is_rejected(self):
        broken = deepcopy(self.main)

        broken[
            "services"
        ][
            "audio-daemon"
        ][
            "healthcheck"
        ][
            "test"
        ] = [
            "CMD",
            "curl",
            "http://localhost:8091/health",
        ]

        errors = RUNTIME_CONTRACT.audit(
            broken,
            self.override,
            self.source,
            self.images,
        )

        self.assertTrue(
            any(
                "8091" in error
                or "8092" in error
                for error in errors
            )
        )

    def test_dependency_cycle_is_rejected(self):
        broken = deepcopy(self.main)

        broken[
            "services"
        ][
            "control"
        ][
            "depends_on"
        ] = {
            "engine": {
                "condition": "service_healthy",
            },
        }

        self.assertTrue(
            RUNTIME_CONTRACT.find_dependency_cycle(
                broken["services"]
            )
        )

    def test_rc8_control_mounts_are_required(self):
        broken = deepcopy(self.main)

        broken["services"]["control"]["volumes"] = [
            volume
            for volume in broken["services"]["control"]["volumes"]
            if volume.get("target") != "/data/flowcast-backups"
        ]

        errors = RUNTIME_CONTRACT.audit(
            broken,
            self.override,
            self.source,
            self.images,
        )

        self.assertTrue(
            any(
                "/data/flowcast-backups" in error
                for error in errors
            )
        )

    def test_statistics_log_mount_must_be_read_only(self):
        broken = deepcopy(self.main)

        for volume in broken["services"]["control"]["volumes"]:
            if volume.get("target") == "/data/icecast":
                volume["read_only"] = False

        errors = RUNTIME_CONTRACT.audit(
            broken,
            self.override,
            self.source,
            self.images,
        )

        self.assertTrue(
            any(
                "Icecast-log mount must be read-only" in error
                for error in errors
            )
        )


class ReleaseArchiveRuntimeTests(unittest.TestCase):
    def test_release_archive_contains_current_runtime(self):
        dist = ROOT / "dist"

        self.addCleanup(
            shutil.rmtree,
            dist,
            True,
        )

        dist.mkdir(
            exist_ok=True
        )

        (
            dist / "images.lock"
        ).write_text(
            "test fixture\n",
            encoding="utf-8",
        )

        version = "0.1.0-rc.91"

        subprocess.run(
            [
                "bash",
                "scripts/release/build-release.sh",
                version,
            ],
            cwd=ROOT,
            check=True,
        )

        archive = (
            dist
            / f"jugglecast-community-v{version}.tar.gz"
        )
        legacy_archive = (
            dist
            / f"flowcast-community-v{version}.tar.gz"
        )

        self.assertTrue(
            archive.is_file()
        )
        self.assertTrue(
            legacy_archive.is_file()
        )
        self.assertEqual(
            archive.read_bytes(),
            legacy_archive.read_bytes(),
        )

        with tarfile.open(
            archive
        ) as package:
            names = set(
                package.getnames()
            )

            self.assertIn(
                "./compose.yml",
                names,
            )

            self.assertIn(
                "./version.env",
                names,
            )

            self.assertIn(
                "./.env.example",
                names,
            )

            self.assertNotIn(
                "./VERSION",
                names,
            )

            self.assertNotIn(
                "./versions.env",
                names,
            )

            compose_file = package.extractfile(
                "./compose.yml"
            )

            version_file = package.extractfile(
                "./version.env"
            )

            env_example_file = package.extractfile(
                "./.env.example"
            )

            self.assertIsNotNone(
                compose_file
            )

            self.assertIsNotNone(
                version_file
            )

            self.assertIsNotNone(
                env_example_file
            )

            compose = (
                compose_file
                .read()
                .decode("utf-8")
            )

            version_env = (
                version_file
                .read()
                .decode("utf-8")
            )

            env_example = (
                env_example_file
                .read()
                .decode("utf-8")
            )

        self.assertIn(
            f"FLOWCAST_VERSION={version}",
            version_env,
        )

        self.assertNotIn(
            "FLOWCAST_VERSION",
            env_example,
        )

        self.assertIn(
            "/usr/local/bin/flowcast-analyzer",
            compose,
        )

        self.assertIn(
            "--healthcheck",
            compose,
        )

        self.assertNotIn(
            "http://localhost:8091/health",
            compose,
        )

        self.assertNotIn(
            "http://localhost:8092/health",
            compose,
        )

        # RC8 runtime additions.
        self.assertIn(
            "flowcast-backups:/data/flowcast-backups",
            compose,
        )
        self.assertIn(
            "icecast-logs:/data/icecast:ro",
            compose,
        )
        self.assertIn(
            "icecast-logs:/data/icecast",
            compose,
        )
        self.assertIn(
            "FLOWCAST_STATISTICS_SESSION_RETENTION_DAYS",
            compose,
        )
        self.assertIn(
            "FLOWCAST_STATISTICS_SAMPLE_RETENTION_DAYS",
            compose,
        )

        self.assertEqual(
            compose,
            (
                ROOT / "compose.yml"
            ).read_text(
                encoding="utf-8"
            ),
        )

    def test_standard_and_opt_in_socket_contract(self):
        source = (
            ROOT / "compose.yml"
        ).read_text(
            encoding="utf-8"
        )

        override = (
            ROOT
            / "compose.docker-control.yml"
        ).read_text(
            encoding="utf-8"
        )

        self.assertNotIn(
            "docker.sock",
            source,
        )

        self.assertIn(
            "docker.sock",
            override,
        )

        self.assertIn(
            "FLOWCAST_DOCKER_GID",
            override,
        )

    def test_rc8_runtime_source_contract(self):
        source = (
            ROOT / "compose.yml"
        ).read_text(
            encoding="utf-8"
        )

        required = (
            "flowcast-backups:/data/flowcast-backups",
            "icecast-logs:/data/icecast:ro",
            "icecast-logs:/data/icecast",
            "FLOWCAST_STATISTICS_SESSION_RETENTION_DAYS",
            "FLOWCAST_STATISTICS_SAMPLE_RETENTION_DAYS",
        )

        for fragment in required:
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, source)

        env_example = (
            ROOT / ".env.example"
        ).read_text(
            encoding="utf-8"
        )

        self.assertIn(
            "FLOWCAST_STATISTICS_SESSION_RETENTION_DAYS=365",
            env_example,
        )
        self.assertIn(
            "FLOWCAST_STATISTICS_SAMPLE_RETENTION_DAYS=90",
            env_example,
        )
        self.assertNotIn(
            "FLOWCAST_VERSION",
            env_example,
        )

    def test_stream_smoke_has_success_and_failure_gates(
        self,
    ):
        script = (
            ROOT
            / "scripts"
            / "community"
            / "test-runtime-stream.sh"
        ).read_text(
            encoding="utf-8"
        )

        required_checks = (
            "status-json.xsl",
            "RestartCount",
            "runtime-state",
            "Login failed",
            "ENGINE_ERROR",
            "stream_test=PASS",
        )

        for check in required_checks:
            with self.subTest(
                check=check
            ):
                self.assertIn(
                    check,
                    script,
                )

    def test_override_render_supplies_a_ci_only_gid(
        self,
    ):
        rendered = '{"services": {}}'

        with mock.patch.object(
            RUNTIME_CONTRACT.subprocess,
            "run",
            return_value=subprocess.CompletedProcess(
                [],
                0,
                rendered,
                "",
            ),
        ) as run:
            RUNTIME_CONTRACT.render(
                "compose.yml",
                "compose.docker-control.yml",
            )

        self.assertEqual(
            run.call_args.kwargs[
                "env"
            ][
                "FLOWCAST_DOCKER_GID"
            ],
            "0",
        )

        env_example = (
            ROOT / ".env.example"
        ).read_text(
            encoding="utf-8"
        )

        self.assertNotIn(
            "FLOWCAST_DOCKER_GID",
            env_example,
        )

    def test_ci_compose_override_render_supplies_gid(
        self,
    ):
        for workflow in (
            "validate.yml",
            "release.yml",
        ):
            with self.subTest(
                workflow=workflow
            ):
                source = (
                    ROOT
                    / ".github"
                    / "workflows"
                    / workflow
                ).read_text(
                    encoding="utf-8"
                )

                self.assertIn(
                    'FLOWCAST_DOCKER_GID: "0"',
                    source,
                )

                self.assertIn(
                    "--env-file .env.example",
                    source,
                )

                self.assertIn(
                    "--env-file version.env",
                    source,
                )

                self.assertIn(
                    "-f compose.yml",
                    source,
                )

                self.assertIn(
                    "-f compose.docker-control.yml",
                    source,
                )

                self.assertIn(
                    "config",
                    source,
                )

                self.assertIn(
                    "--quiet",
                    source,
                )


if __name__ == "__main__":
    unittest.main()
