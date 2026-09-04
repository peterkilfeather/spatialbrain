# Gene Query navigates via a shared cross-tab selection store

The Gene Query tab (built per the functionality/visualisation review) is a gene-centric hub: it summarises one gene across the five gene-centric analyses (cell-type markers, SN/VTA markers, TRAP enrichment, ageing, splicing) and lets the user jump to the analysis tab that shows the detail. Rather than re-rendering each analysis's plots inside Gene Query, selection is shared: Gene Query sets a session-level gene selection that the analysis modules observe, pre-selecting that gene and rendering their existing plots. The alternative — embedding copies of each plot inside Gene Query — was rejected because it duplicates rendering logic per tab and lets the two views drift. The cost of the chosen design is a module-communication contract: analysis modules must expose an entry point that accepts an external gene selection, and every future analysis module must do the same. This is why the decision is recorded rather than left implicit. Direct use of a tab (selecting a gene there) is unaffected; the store only carries an arriving selection from Gene Query.

## Implemented contract (Phase C-1)

**Store shape** — a session-scoped `reactiveValues` created in `app/app.R`:

```r
gene_selection <- reactiveValues(arriving = NULL)
```

`arriving` is `NULL` (no selection) or a one-shot list:
`list(gene = "<symbol>", cell_type = "<cell-type symbol>" | NULL)`.
`cell_type` is used only by the Cell Type Markers module (internal symbol,
e.g. `"DA_SN"`); other modules ignore it. Gene Query writes a fresh
selection per jump; with `arriving == NULL` every existing tab behaves
byte-identically.

**Module entry points** — the arriving-selection argument is the seam:

- `gene_query_SERVER(id, gene_selection)` — writes `arriving` on jump.
- `spatial_markers_SERVER(id, metadata_all_cells, cell_type_names, gene_selection)`
  — resolves the cell type: the arriving `cell_type` when it contains the
  gene, else the first of the 32 marker tables that does; switches the cell
  type, then selects the gene's row once the marker table has loaded.
- `sn_vta_SERVER(id, gene_selection)`, `trap_enrichment_SERVER(id, gene_selection)`,
  `ageing_TRAP_SERVER(id, gene_selection)`, `splicing_SERVER(id, gene_selection)`
  — select the gene if present in their meta-table (guard: genes absent from
  a module's table are ignored, so one arriving selection is safe for all
  modules at once).
- The arrived gene is recorded as the module's `jump_landed` default: the
  tables' first-render event (DataTables initialises when the tab is first
  shown and reports `rows_selected = NULL`, which would reset the tab to
  row 1) must not clobber the jump. That same event is the signal that the
  DT is initialized, so the row selection issued while the tab was hidden
  (and dropped) is re-issued there. `jump_landed` stands while the gene
  remains valid for the current table; it is cleared only when the user
  selects a *different* row (the programmatic echo of the jump's own
  `selectRows` selects the same gene must not clear it). A manual cell-type
  switch in the Cell Type Markers tab invalidates the previous table's row
  index and re-selects the arrived gene when it is still a marker of the
  new cell type (otherwise the tab falls back to row 1, as before).

**Navigation** — every `tabPanel` carries an explicit `value` equal to its
module id (`home`, `spatial_markers`, `sn_vta`, `cell_type_numbers_age`,
`trap_enrichment`, `ageing_TRAP`, `splicing`, `gene_query`, `download_data`).
Cross-tab navigation uses `switch_navbar_tab(session, value)` (`app/R/navbar.R`):
under the app's Bootstrap 3 theme, `updateNavbarPage()` cannot select tabs
inside `navbarMenu()` dropdowns (the tab-input binding matches top-level
anchors only), so switching is driven by a custom message handler registered
in `app.R`'s `<head>` on `#main_nav`.

## Implemented contract (Phase C-2)

**Store shape** — `arriving` gains a `nonce` field (the C-1 shape above is
superseded):

```r
list(gene = "<canonical symbol>", cell_type = "<internal symbol>" | NULL,
     nonce = <integer>)
```

`nonce` increments on every jump. `reactiveValues` skips re-assignment of
identical values, so without it a second jump to the same gene (same
`gene` + `cell_type`) would never fire the modules' observers. Analysis
modules read only `gene` and `cell_type`; the nonce is otherwise invisible
to them.

**Gene keys** — Gene Query builds a session gene index once at session
start (`build_gene_index()`, `app/R/gene_query.R`) from the five analysis
sources, the 32 cell-type marker tables included: one row per gene-analysis
match, keyed by `toupper(gene)` with the canonical stored case. Symbols are
written in a single case across all five sources (verified at build), so the
delivered `gene` is canonical and exact-match lookups work in every module.
Autocomplete (`selectizeInput`, server-side) matches case-insensitively —
shiny's `selectizeJSON` search lowercases query and options — so `slc6a3`,
`MT-ND6` and `a230050p20rik` all resolve. Duplicate rows per source are
removed at load (`distinct(Gene)`); the union is 23,781 symbols.

**Summary contract** — `gene_query_summary(index, gene)` returns exactly
five rows, one per analysis in display order: Cell Type Markers, SN/VTA
Region Markers, TRAP Enrichment, Ageing, Alternative Splicing. Status is
"Tested" or "Not tested" (gene absent from that analysis). Statistics: LFC
and FDR-P where the analysis reports them; Alternative Splicing shows
FDR-P only (its LFC cell renders "—"). A gene that is a marker of several
cell types lists every matching cell type (public names, `cell_type_names`
order) and shows the first matching cell type's statistics — the same cell type the jump delivers. Each tested row carries a View button; "Not
tested" rows carry none (there is nothing to jump to).

**Jump** — the View button writes a fresh `arriving` selection
(canonical gene; for the Cell Type Markers row, the first matching cell
type in `cell_type_names` order — the same scan the module falls back to)
and calls `switch_navbar_tab(session, <tab value>)`. Buttons write the
namespaced `jump` input via `Shiny.setInputValue(..., {priority: 'event'})`
so repeat jumps to the same row still fire. A jump to an analysis that does
not contain the gene is impossible from the UI ("Not tested" rows carry no
button); the modules' absent-gene guards make it a harmless no-op anyway.
Direct per-tab
use is unaffected: the store carries only arriving selections and modules
only act on them.
