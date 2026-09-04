# Download Data tab: analysis-table ZIP and raw-data links

The Download Data tab (built per the functionality/visualisation review,
Phase C, ticket 7) gives one-click access to the five published analysis
tables (TRAP Enrichment, Ageing, Alternative Splicing, SN/VTA Region
Markers, Cell Type Markers — the latter as the 32 per-cell-type tables) as
a ZIP of readable CSVs, plus the raw-data links from the paper's Data and
code availability statement. The analysis result matrices exist only at
spatialbrain.org (the paper's supplementary tables S1–S4 hold cell-type
annotation, spatially variable genes, PD GWAS candidates, and primers), so
the ZIP fulfils the paper's own "all processed data ... provided at
spatialbrain.org" promise.

## ZIP contents and canonical columns

- Four analysis CSVs plus 32 per-cell-type marker CSVs (36 entries total) —
  all five analyses, with Cell Type Markers delivered as the 32 per-cell-type
  tables.
- Every CSV carries the canonical columns shown in the app: `Gene`, `LFC`,
  `FDR-P`. Alternative Splicing has no LFC (FDR-P only), matching the app.
  Values keep full precision from the shipped analysis files; only column
  names are canonicalised (the TRAP source's "Log2 Fold Enrichment" is the
  app's LFC; the SN/VTA source is lowercase in the file).
- Marker-table file names use the published public cell-type names (the
  app's Cell Type Markers selector labels) with ":" and "/" replaced by
  " - ", so every entry extracts on Windows too (both characters are
  invalid in Windows file names). The internal symbols (`DA_SN`, ...) never
  appear in the ZIP.

## ZIP tooling (portability)

The ZIP is written with `zip::zipr()` (the CRAN `zip` package), a pure-R
implementation with no system binary dependency. `utils::zip()` was
rejected: it shells out to a system `zip` binary, which is not guaranteed
present in the rocker/shiny container (`/usr/bin/zip` is absent there) —
the same code paths would then behave differently between local R and the
container. The `zip` package is added to the Dockerfile install list
(ADR-0002: the image is the dependency source of truth).

## CASR ICC DOI inconsistency

The paper prints two different DOIs for the CASR ICC images:

- Data and code availability: `10.5281/zenodo.10476098` — resolves to the
  record "ICC data of CASR from Kilfeather et al., 2024".
- Key Resources table: `10.5281/zenodo.10476097` — does not resolve
  (Zenodo 404).

Chosen presentation: the Data Availability DOI (`10.5281/zenodo.10476098`),
the only one that resolves to the record, linked under Raw data with a
one-line note naming the dead Key Resources DOI. The choice is stated in
the Phase C-3 commit message.
