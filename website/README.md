# JuggleCast website

Static Astro website for `https://chourmovs.github.io/JuggleCast-Community/`.

## Local setup

Prerequisites: Node.js 22 and npm. Run `npm install`, then `npm run dev`. Use `npm run check` for Astro/TypeScript validation, `npm run build` to generate `dist/`, and `npm run preview` to inspect that build. The dependencies are pinned to exact versions; installation expands their platform-specific transitive graph.

## Architecture

Pages live in `src/pages`, shared metadata and document structure in `src/layouts/BaseLayout.astro`, reusable UI in `src/components`, and dependency-free styling in `src/styles/global.css`. Public assets are copied unchanged to `public`.

To add a page, create an `.astro` file under `src/pages`, wrap it in `BaseLayout`, supply a unique title and description, add a single `h1`, and link it from navigation or a relevant page. `canonical` accepts a path or absolute URL; the site origin and default 1200×630 social image are applied by the layout. Use `noindex` only for pages such as 404.

## Screenshots

Only use reviewed, real and sanitized captures from `docs/assets/screenshots`. Copy (do not move) them into `public/screenshots`, give them descriptive names, retain their dimensions, and add a unique alt and caption in `ScreenshotGallery.astro`. Optimize to WebP only when visual inspection confirms there is no meaningful deterioration.

## GitHub Pages

`.github/workflows/deploy-pages.yml` checks and builds `website/`, uploads `dist`, and deploys with the official Pages actions. The Astro project uses the `/JuggleCast-Community` base path. In repository Settings > Pages, select GitHub Actions and enable Enforce HTTPS when available.

## Search Console and sitemap

Register the GitHub Pages URL in Google Search Console and submit `https://chourmovs.github.io/JuggleCast-Community/sitemap-index.xml`. Astro generates that sitemap during the build and `public/robots.txt` advertises it.
