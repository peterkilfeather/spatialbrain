# Download Data --------------------------------------------------------------
#
# One-click ZIP of the five analysis tables (TRAP Enrichment, Ageing,
# Alternative Splicing, SN/VTA Region Markers, Cell Type Markers -- the
# latter as the 32 per-cell-type tables) as readable CSVs with the canonical
# columns shown in the app (Gene / LFC / FDR-P; Alternative Splicing has no
# LFC), plus the raw-data links from the paper's Data and code availability
# statement. The analysis result matrices exist only at spatialbrain.org
# (the paper's supplementary tables hold cell-type annotation, spatially
# variable genes, PD GWAS candidates and primers), so the ZIP fulfils the
# paper's own "all processed data ... provided at spatialbrain.org" promise.
#
# ZIP tooling (portability choice, ADR-0004): zip::zipr() writes archives in
# pure R -- no system zip binary -- so the same code runs in local R and in
# the rocker/shiny container (which has no /usr/bin/zip). `zip` is added to
# the Dockerfile install list (ADR-0002). utils::zip() was rejected because
# it shells out to a system binary that is not guaranteed present.

# ZIP entry names: the five analysis tables plus the 32 per-cell-type marker
# tables. Marker tables are named by their published public cell-type names
# (the app's Cell Type Markers selector labels), with ":" and "/" replaced
# by " - " so every entry extracts on Windows too (both are invalid there in
# filenames); the internal symbols (DA_SN, ...) never appear in the ZIP.
download_zip_entries <- function(cell_type_names_rds = "input/startup/cell_type_names.rds") {
  cell_type_names <- readRDS(cell_type_names_rds)
  markers <- paste0("Cell Type Markers - ",
                    gsub("[:/]+ *", " - ", names(cell_type_names)),
                    ".csv")
  entries <- c("TRAP Enrichment.csv",
               "Ageing.csv",
               "Alternative Splicing.csv",
               "SN-VTA Region Markers.csv",
               markers)
  # Key the marker entries by internal cell-type symbol (the same key
  # build_gene_index and the marker file names use) so writers pair each
  # table to its entry by key, never by position: names(cell_type_names)
  # order and list.files order are independent sequences that happen to
  # coincide today.
  names(entries)[5:length(entries)] <- unname(cell_type_names)
  entries
}

# The five analysis tables with the canonical columns shown in the app
# (Gene / LFC / FDR-P; Alternative Splicing reports FDR-P only). Full
# precision from the shipped analysis files; only column names are
# canonicalised (the TRAP source's "Log2 Fold Enrichment" is the app's LFC;
# the SN/VTA source is lowercase in the file). Deterministic, side-effect
# free, path-overridable for verification.
download_analysis_tables <- function(marker_dir = "input/markers/cell_types",
                                      sn_vta_csv = "input/sn_vta/sn_vta_mast.csv",
                                      trap_rds = "input/startup/MB_FRACTION_META.rds",
                                      ageing_rds = "input/startup/MB_AGE_META.rds",
                                      splicing_rds = "input/startup/splicing_meta.rds") {
  trap <- readRDS(trap_rds) %>%
    select(Gene, "LFC" = `Log2 Fold Enrichment`, `FDR-P`)
  ageing <- readRDS(ageing_rds)
  splicing <- readRDS(splicing_rds)
  sn_vta <- read_csv(sn_vta_csv,
                     col_names = c("Gene", "LFC", "FDR-P"),
                     skip = 1,
                     show_col_types = FALSE)
  markers <- list.files(marker_dir, pattern = "\\.rds$", full.names = TRUE) %>%
    setNames(basename(.)) %>%
    lapply(readRDS)
  list(trap = trap, ageing = ageing, splicing = splicing,
       sn_vta = sn_vta, markers = markers)
}

# Write all CSVs into `dir`; returns the entry names (in ZIP order).
download_write_csvs <- function(dir,
                                entries = download_zip_entries(),
                                tables = download_analysis_tables()) {
  write_csv(tables$trap, file.path(dir, entries[1]))
  write_csv(tables$ageing, file.path(dir, entries[2]))
  write_csv(tables$splicing, file.path(dir, entries[3]))
  write_csv(tables$sn_vta, file.path(dir, entries[4]))
  # Pair each marker table to its entry by symbol key (see
  # download_zip_entries); an unknown or missing key fails loudly instead
  # of silently writing a table under the wrong cell-type name.
  marker_entries <- entries[sub("\\.rds$", "", names(tables$markers))]
  stopifnot(length(marker_entries) == length(tables$markers),
            !anyNA(marker_entries),
            !anyDuplicated(marker_entries))
  for (i in seq_along(tables$markers)) {
    write_csv(tables$markers[[i]], file.path(dir, marker_entries[[i]]))
  }
  entries
}

# Build the analysis-tables ZIP at `outfile`; returns `outfile` invisibly.
build_analysis_zip <- function(outfile, ...) {
  dir <- tempfile("spatialbrain-download-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  entries <- download_write_csvs(dir, ...)
  zip::zipr(outfile, files = file.path(dir, entries), root = dir)
  invisible(outfile)
}

# Raw-data links: the paper's Data and code availability statement
# (Kilfeather, Khoo, et al. 2024, Cell Reports 43:113784,
# https://doi.org/10.1016/j.celrep.2024.113784). All accessions verified to
# resolve; the CASR ICC DOI choice is documented in ADR-0004.
download_raw_links <- tibble::tribble(
  ~label, ~url, ~note,
  "GEO GSE215276",
  "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE215276",
  "TRAP RNA-seq raw data",
  "CNGBdb CNP0003397",
  "https://db.cngb.org/search/project/CNP0003397/",
  "Stereo-seq raw data",
  "GitHub: legbar/spatialbrain",
  "https://github.com/legbar/spatialbrain",
  "Analysis code and processed data",
  "Zenodo 10.5281/zenodo.10401701",
  "https://doi.org/10.5281/zenodo.10401701",
  "Analysis code (archived)",
  "protocols.io 10.17504/protocols.io.36wgqj75kvk5/v1",
  "https://doi.org/10.17504/protocols.io.36wgqj75kvk5/v1",
  "Laboratory protocols",
  "Zenodo 10.5281/zenodo.10401754",
  "https://doi.org/10.5281/zenodo.10401754",
  "CASR IHC images",
  "Zenodo 10.5281/zenodo.10476098",
  "https://doi.org/10.5281/zenodo.10476098",
  "CASR ICC images",
  "Zenodo 10.5281/zenodo.10401777",
  "https://doi.org/10.5281/zenodo.10401777",
  "TYROBP IHC images",
  "Zenodo 10.5281/zenodo.10669197",
  "https://doi.org/10.5281/zenodo.10669197",
  "Fura-2 calcium imaging data (Key Resources table)"
)

download_data_UI <- function(id) {
  ns <- NS(id)
  tabPanel("Download Data",
           value = "download_data",
           titlePanel(h1("Download Data", align = 'center')),
           br(),
           fluidRow(
             column(5,
                    offset = 1,
                    h4("All analysis tables, one click"),
                    p("Download the five analysis tables as readable CSVs with the columns shown in the app (Gene / LFC / FDR-P): TRAP Enrichment, Ageing, Alternative Splicing, SN/VTA Region Markers, and Cell Type Markers as the 32 per-cell-type tables."),
                    p(class = 'text-center', downloadButton(
                      ns('download_zip'), 'Download All Data (ZIP)'
                    )),
                    br(),
                    h4("What's in the ZIP"),
                    tags$ul(
                      tags$li("TRAP Enrichment (LFC vs TOTAL)"),
                      tags$li("Ageing (LFC, OLD vs YOUNG)"),
                      tags$li("Alternative Splicing (FDR-P only)"),
                      tags$li("SN/VTA Region Markers (LFC, SN vs VTA)"),
                      tags$li("Cell Type Markers: 32 per-cell-type tables, one CSV per cell type")
                    ),
                    style = 'border-right: 1px solid'
             ),
             column(5,
                    h4("Raw data"),
                    p("Links from the paper's Data and code availability statement (Kilfeather, Khoo, et al., 2024, ", tags$a(href = "https://doi.org/10.1016/j.celrep.2024.113784", target = "_blank", "Cell Reports 43:113784"), ")."),
                    tags$ul(
                      lapply(seq_len(nrow(download_raw_links)), function(i) {
                        tags$li(tags$a(href = download_raw_links$url[i],
                                       target = "_blank",
                                       download_raw_links$label[i]),
                                " — ", download_raw_links$note[i])
                      })
                    ),
                    p(class = "text-muted",
                      "The Data Availability statement and the Key Resources table print different DOIs for the CASR ICC images: 10.5281/zenodo.10476098 (Data Availability) and 10.5281/zenodo.10476097 (Key Resources). Only the Data Availability DOI resolves; it is the one linked above (choice documented in ADR-0004)."),
                    p(class = "text-muted",
                      "All processed data, including results of all analyses, are provided at spatialbrain.org.")
             )
           )
  )
}

download_data_SERVER <- function(id) {
  moduleServer(id, function(input, output, session) {
    # namespace ----
    ns <- session$ns

    output$download_zip <- downloadHandler(
      filename = "spatialbrain-data.zip",
      contentType = "application/zip",
      content = function(file) {
        build_analysis_zip(file)
      }
    )
  })
}
