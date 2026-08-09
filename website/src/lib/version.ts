import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const VERSION_PATTERN =
  /^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?$/;

const currentDirectory = path.dirname(
  fileURLToPath(import.meta.url),
);

const repositoryRoot = path.resolve(
  currentDirectory,
  '..',
  '..',
  '..',
);

const versionPath = path.join(
  repositoryRoot,
  'version.env',
);

function readVersionEnvironment(): string {
  if (!fs.existsSync(versionPath)) {
    throw new Error(
      `version.env was not found at ${versionPath}`,
    );
  }

  const assignments = fs
    .readFileSync(versionPath, 'utf-8')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(
      (line) =>
        line.length > 0 &&
        !line.startsWith('#') &&
        line.startsWith('FLOWCAST_VERSION='),
    );

  if (assignments.length !== 1) {
    throw new Error(
      'version.env must contain exactly one FLOWCAST_VERSION assignment',
    );
  }

  const assignment = assignments.at(0);

  if (!assignment) {
    throw new Error(
      'FLOWCAST_VERSION assignment could not be read',
    );
  }

  const separatorIndex = assignment.indexOf('=');

  if (separatorIndex < 0) {
    throw new Error(
      'FLOWCAST_VERSION must use KEY=VALUE syntax',
    );
  }

  const version = assignment
    .slice(separatorIndex + 1)
    .trim();

  if (!version) {
    throw new Error(
      'FLOWCAST_VERSION cannot be empty',
    );
  }

  if (!VERSION_PATTERN.test(version)) {
    throw new Error(
      `Invalid FLOWCAST_VERSION: ${version}`,
    );
  }

  if (version === 'latest') {
    throw new Error(
      'FLOWCAST_VERSION cannot use the mutable latest tag',
    );
  }

  return version;
}

export const flowcastVersion =
  readVersionEnvironment();

export const flowcastTag =
  `v${flowcastVersion}`;

export const installCommand =
  `curl -fsSL https://raw.githubusercontent.com/` +
  `chourmovs/JuggleCast-Community/${flowcastTag}/install.sh` +
  ` | sudo bash -s -- --version ${flowcastVersion}`;
