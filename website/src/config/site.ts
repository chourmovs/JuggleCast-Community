import { withBase } from '../lib/paths';

export const site = {
  name: 'JuggleCast Radio Automation',
  shortName: 'JuggleCast',
  slogan: 'Self-hosted scheduling and playout without Liquidsoap',
  signature: 'JuggleCast Radio Automation — self-hosted scheduling and playout without Liquidsoap.',
  description: 'JuggleCast Radio Automation is a self-hosted scheduling and Rust playout platform with configurable transitions, direct Icecast delivery, public station widgets, station statistics and media-aware backup/restore — without Liquidsoap.',
  repository: 'https://github.com/chourmovs/FlowCast-Community',
  docs: 'https://github.com/chourmovs/FlowCast-Community/tree/main/docs',
  releases: 'https://github.com/chourmovs/FlowCast-Community/releases',
  security: 'https://github.com/chourmovs/FlowCast-Community/blob/main/SECURITY.md',
  support: 'https://github.com/chourmovs/FlowCast-Community/issues',
  publicStationUrl: '',
};

export const navLinks = [
  { href: withBase(), label: 'Product' },
  { href: withBase('screenshots'), label: 'Interface' },
  { href: withBase('installation'), label: 'Install' },
  { href: site.docs, label: 'Docs' },
];
