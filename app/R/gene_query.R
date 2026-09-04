# Gene Query ----------------------------------------------------------------
#
# Gene-centric hub (Phase C, ticket 6): a case-insensitive autocomplete over
# the union of the five gene-centric analyses (the 32 cell-type marker tables
# included); a summary table with one row per analysis (Cell Type Markers,
# SN/VTA Region Markers, TRAP Enrichment, Ageing, Alternative Splicing)
# showing status and key statistics (LFC / FDR-P where available --
# Alternative Splicing reports FDR-P only) and "Not tested" for absent
# analyses; and a per-row jump that writes an arriving selection to the
# cross-tab store (ADR-0003) and switches to the analysis tab, which renders
# that gene's existing plots. Genes that are markers of several cell types
# list every matching cell type; the jump delivers the first in
# cell_type_names order, which the Cell Type Markers module resolves to a
# working cell type.

# The five analyses in display order: summary names, navbar tab values, and
# whether the analysis reports an LFC (Alternative Splicing does not).
GENE_QUERY_ANALYSES <- tibble::tibble(
  analysis_id = c("markers", "sn_vta", "trap", "ageing", "splicing"),
  analysis = c("Cell Type Markers", "SN/VTA Region Markers", "TRAP Enrichment",
               "Ageing", "Alternative Splicing"),
  tab_value = c("spatial_markers", "sn_vta", "trap_enrichment", "ageing_TRAP",
                "splicing"),
  has_lfc = c(TRUE, TRUE, TRUE, TRUE, FALSE)
)

# Build the session gene index once: the case-normalised union of the five
# analysis sources (32 marker tables included). One row per gene-analysis
# match (markers: one row per cell type, in cell_type_names order -- the
# module's resolve_cell_type scan order); `key` is the case-normalised
# symbol, `gene` its canonical stored case (verified consistent across all
# five sources). Duplicate rows are removed per source at load.
build_gene_index <- function(marker_dir = "input/markers/cell_types",
                             sn_vta_csv = "input/sn_vta/sn_vta_mast.csv",
                             trap_rds = "input/startup/MB_FRACTION_META.rds",
                             ageing_rds = "input/startup/MB_AGE_META.rds",
                             splicing_rds = "input/startup/splicing_meta.rds",
                             cell_type_names_rds = "input/startup/cell_type_names.rds") {
  cell_type_names <- readRDS(cell_type_names_rds)

  marker_rows <- list.files(marker_dir, pattern = "\\.rds$", full.names = TRUE) %>%
    setNames(basename(.)) %>%
    imap_dfr(~ {
      ct <- sub("\\.rds$", "", .y)
      readRDS(.x) %>%
        distinct(Gene, .keep_all = TRUE) %>%
        transmute(
          gene = Gene,
          analysis = "markers",
          cell_type = ct,
          cell_type_public = names(cell_type_names)[cell_type_names == ct],
          lfc = LFC,
          fdr = `FDR-P`
        )
    }) %>%
    # cell_type_names order = the first matching cell type is the jump target
    # and the source of the summary row's statistics.
    arrange(match(cell_type, cell_type_names))

  sn_vta_rows <- read_csv(sn_vta_csv,
                          col_names = c("Gene", "LFC", "FDR-P"),
                          skip = 1,
                          show_col_types = FALSE) %>%
    distinct(Gene, .keep_all = TRUE) %>%
    transmute(gene = Gene, analysis = "sn_vta",
              cell_type = NA_character_, cell_type_public = NA_character_,
              lfc = LFC, fdr = `FDR-P`)

  trap_rows <- readRDS(trap_rds) %>%
    distinct(Gene, .keep_all = TRUE) %>%
    transmute(gene = Gene, analysis = "trap",
              cell_type = NA_character_, cell_type_public = NA_character_,
              lfc = `Log2 Fold Enrichment`, fdr = `FDR-P`)

  ageing_rows <- readRDS(ageing_rds) %>%
    distinct(Gene, .keep_all = TRUE) %>%
    transmute(gene = Gene, analysis = "ageing",
              cell_type = NA_character_, cell_type_public = NA_character_,
              lfc = LFC, fdr = `FDR-P`)

  splicing_rows <- readRDS(splicing_rds) %>%
    distinct(Gene, .keep_all = TRUE) %>%
    transmute(gene = Gene, analysis = "splicing",
              cell_type = NA_character_, cell_type_public = NA_character_,
              lfc = NA_real_, fdr = `FDR-P`)

  index <- bind_rows(marker_rows, sn_vta_rows, trap_rows, ageing_rows, splicing_rows) %>%
    mutate(key = toupper(gene))

  # One canonical case per symbol across all five sources: the delivered
  # gene must match each module's exact-match lookup. Enforce it so a future
  # data update cannot silently break the canonical-symbol contract.
  conflicting <- index %>%
    group_by(key) %>%
    summarise(n_genes = n_distinct(gene), .groups = "drop") %>%
    filter(n_genes > 1)
  if (nrow(conflicting) > 0) {
    stop("Gene Query index: ", nrow(conflicting),
         " symbol(s) are written in more than one case across the analysis sources",
         " (first: ", conflicting$key[1], "); the canonical-case contract is broken")
  }

  index
}

# The summary table for one gene: one row per analysis with status
# (present/absent) and key statistics. Marker genes list every matching cell
# type (public names, cell_type_names order); the row's statistics are the
# first matching cell type's -- the same cell type the jump delivers.
gene_query_summary <- function(index, gene) {
  rows <- index[index$key == toupper(gene), , drop = FALSE]
  GENE_QUERY_ANALYSES %>%
    rowwise() %>%
    mutate(
      analysis_rows = list(rows[rows$analysis == analysis_id, , drop = FALSE]),
      present = nrow(analysis_rows) > 0,
      cell_types = if (analysis_id == "markers" && present) {
        paste(unique(analysis_rows$cell_type_public), collapse = ", ")
      } else "",
      lfc = if (present) analysis_rows$lfc[1] else NA_real_,
      fdr = if (present) analysis_rows$fdr[1] else NA_real_
    ) %>%
    ungroup() %>%
    select(analysis, cell_types, lfc, fdr, present, has_lfc, tab_value)
}

gene_query_UI <- function(id) {
  ns <- NS(id)
  tabPanel("Gene Query",
           value = "gene_query",
           titlePanel(h1("Gene Query", align = 'center')),
           fluidRow(
             column(6,
                    offset = 3,
                    h4("Search for a gene symbol to see which analyses include it"),
                    selectizeInput(ns("gene"),
                                   label = NULL,
                                   choices = NULL,
                                   width = "100%",
                                   options = list(
                                     placeholder = "e.g. Th, Slc6a3, mt-Nd6 (case-insensitive)"
                                   )),
                    p("Select a gene, then use View to jump to that analysis's tab and see the full detail plots.")
             )
           ),
           br(),
           fluidRow(
             column(10,
                    offset = 1,
                    DT::dataTableOutput(ns("summary")),
                    p("LFC is not reported for Alternative Splicing (FDR-P only). \"Not tested\" means the gene is absent from that analysis.",
                      class = "text-muted")
             )
           )
  )
}

gene_query_SERVER <- function(id, gene_selection) {
  moduleServer(id, function(input, output, session) {
    # namespace ----
    ns <- session$ns

    # The gene index is built once at session start; autocomplete and the
    # summary both read from it.
    gene_index <- build_gene_index()

    # Server-side selectize: the 23.8k-symbol index stays on the server, the
    # client fetches matches per keystroke (shiny's selectizeJSON search is
    # case-insensitive by construction), and the session payload stays small.
    # selected = "" stops shiny's single-select binding from auto-selecting
    # the first option on load (which would show an arbitrary gene's summary
    # before the user searches); req(input$gene) keeps the table empty until
    # a gene is actually chosen.
    updateSelectizeInput(session, "gene",
                         choices = sort(unique(gene_index$gene)),
                         selected = "",
                         server = TRUE)

    output$summary <- DT::renderDataTable({
      req(input$gene)
      gene_query_summary(gene_index, input$gene) %>%
        mutate(
          lfc = case_when(
            !present ~ "Not tested",
            !has_lfc ~ "\u2014",
            TRUE ~ as.character(signif(lfc, 3))
          ),
          fdr = ifelse(present, as.character(signif(fdr, 3)), "Not tested"),
          status = ifelse(present, "Tested", "Not tested"),
          jump = ifelse(
            present,
            sprintf(paste0("<button class='btn btn-xs btn-primary' ",
                           "onclick=\"Shiny.setInputValue('%s', '%s', ",
                           "{priority: 'event'})\">View</button>"),
                    ns("jump"), tab_value),
            ""
          )
        ) %>%
        select(analysis, cell_types, lfc, fdr, status, jump)
    },
    rownames = FALSE,
    escape = FALSE,
    selection = "none",
    server = FALSE,
    colnames = c("Analysis", "Cell types", "LFC", "FDR-P", "Status", ""),
    options = list(dom = "t", ordering = FALSE, paging = FALSE, info = FALSE))

    # Per-row jump: write a one-shot arriving selection (ADR-0003) and switch
    # to the analysis tab. The nonce makes every jump a distinct event --
    # reactiveValues skips re-assignment of identical values, so without it a
    # repeated jump to the same gene would never fire the observers.
    jump_nonce <- 0L
    observeEvent(input$jump, {
      req(input$gene, input$jump)
      tab_value <- input$jump
      if (!(tab_value %in% GENE_QUERY_ANALYSES$tab_value)) return()
      gene <- input$gene
      cell_type <- NULL
      if (tab_value == "spatial_markers") {
        marker_rows <- gene_index[gene_index$key == toupper(gene) &
                                    gene_index$analysis == "markers", , drop = FALSE]
        if (nrow(marker_rows) > 0) cell_type <- marker_rows$cell_type[1]
      }
      jump_nonce <<- jump_nonce + 1L
      gene_selection$arriving <- list(gene = gene, cell_type = cell_type,
                                      nonce = jump_nonce)
      switch_navbar_tab(session, tab_value)
    })
  })
}
