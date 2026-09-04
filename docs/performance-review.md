# SpatialBrain — Load Performance Review

Date: 2026-08-20. Scope: review + plan for load performance of the public Shiny app at https://spatialbrain.org/. Decisions from a grilling session; see `docs/adr/` for the recorded decisions.

## Topology (verified)

- Public entry: `spatialbrain.org` → Cloudflare (TLS, HTTP/2/3, edge compression, static edge caching) → Shiny Server (open-source, container `spatialbrain:latest`, rocker/shiny R-4.4.1) on origin port 3838.
- No nginx/traefik in front of Shiny. The peterkilfeather.com nginx container serves a different static site.
- Each visitor connection spawns a fresh R process (`SockJSAdapter`); sessions die on idle. `shiny-server.conf`: `run_as shiny`, port 3838, `app_dir /srv/shiny-server/app`.
- App source: this repo (`/archive/websites/spatialbrain`); the container runs a copy built into the image from the repo `Dockerfile` (14 packages via `install2.r`).
- A monitoring client loads the app roughly every 5 minutes (session-log cadence) — not `check-up.sh` (curl-only, no Shiny session).

## Measured baseline (2026-08-20, live site)

| Metric | Value | How |
|---|---|---|
| HTML TTFB (origin) | 1.19 s | `curl 127.0.0.1:3838` |
| HTML TTFB (via Cloudflare) | 1.29 s | `curl https://spatialbrain.org` |
| First paint / FCP | 236 ms | PerformanceObserver, browser |
| Time-to-interactive (preloader removed) | **≤ 3.42 s** | fresh R session, log-confirmed spawn, DOM preloader-free at 3.42 s post-nav |
| `tidyverse` attach | 0.46 s | in-container `Rscript` |
| Other 10 packages attach | 0.40 s | in-container `Rscript` |
| Static assets (compressed) | ~150 KB total; shiny.min.js 105 KB; spatial_optim.png 447 KB | Cloudflare HIT, `max-age=14400` |
| Eager per-session data reads | ~2.5 MB (metadata_all_cells 1.8 MB + small metas) | readRDS audit |

Container restart → first session also ≤ 3.42 s (host page cache survives restarts).

## Findings

1. **The 5 s budget is already met** (TTI ≤ 3.42 s on a cold session, warm container). The conditional decisions from the design session — package slimming and lazy module init — are therefore **not triggered** (policy: measure first, change only to meet budget).
2. **HTML TTFB ~1.2 s is the largest remaining fixed cost** for every visit. The app HTML is identical for all users (no user-specific content; Shiny sessions are created on websocket connect, not in the HTML), so Cloudflare can edge-cache it. A cache rule with TTL 60–300 s would cut ~1 s per visit for repeat visitors. Currently `cf-cache-status: DYNAMIC` for HTML.
3. **Session-per-visitor model**: each visit costs a fresh R boot (~3.4 s, ~0.9 s of it package attach) and a session-sized memory footprint. Fine at current traffic; the every-5-min monitor adds session churn. If traffic grows, revisit (process pooling, warm standby).
4. **Data is not the startup problem**: eager per-session reads total ~2.5 MB. The 11.2 GB of `input/` (19,241 per-gene RDS ≈ 10.8 GB) is read lazily on gene selection — interaction latency, documented, not targeted. It does make the Docker image ~11 GB and deploys slow.
5. **Repo hygiene debt**: `renv` artifacts stale and unused (lockfile R 4.1.2, missing 4 packages the app loads); two 34 MB GIFs unreferenced; orphaned `app/trap_enrichment.R`; ~60 % of `home.R` commented-out code.
6. Edge layer is healthy: Cloudflare already compresses and edge-caches all static assets (4 h TTL), TLS terminated, HTTP/3 advertised.

## Plan

- **Phase A — Cloudflare HTML cache rule ✅ done 2026-08-20**: cache rule on `spatialbrain.org` + `www.spatialbrain.org` root path — cache eligibility on, edge TTL 300 s (200 only), browser TTL 60 s. Result: root HTML TTFB 1.2 s → ~35 ms (`cf-cache-status: HIT`); content verified identical, no cookies. Rule id `c5858fc9`; delete via Cloudflare → Rules → Cache Rules. Guard held: no dynamic content in HTML before enabling; re-check after any future UI change (browser TTL 60 s bounds update propagation).
- **Phase B — Repo hygiene (agent-executable after approval)**: remove `renv/`, `renv.lock`, `.Rprofile`; delete unreferenced `www/magick`, `www/spatial.gif`, `input/startup/spatial.gif`, orphan `app/trap_enrichment.R`, dead `renderImage` output in `home.R`; strip commented-out blocks in `home.R`. Behavior-neutral; commit separately from any other work.
- **Phase C — Deploy ✅ done 2026-08-20 (first, #3), re-verified 2026-09-04 (#9)**: rebuilt `spatialbrain:latest` from repo, container recreated, fresh-session TTI ≤ 3.23 s (2026-08-20) and 1.99 s (2026-09-04, functionality-review Phase A/B/C build), HTML cache guard intact on both. Note: image is ~11 GB; build/push time is a deploy-time cost, not user-facing.
- **Non-actions (documented, not scheduled)**: package slimming, lazy module init, per-gene data format changes (fst/parquet), monitor identification.

## Risks

- HTML edge caching: low risk (HTML is user-independent today). Guard: confirm no session/auth tokens ever appear in the HTML before enabling.
- Hygiene deletions: all targets verified unreferenced (grep + live-HTML check); `git` history preserves them.
- Deploy: public downtime ~1 min during container restart; schedule for low traffic.
