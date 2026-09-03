options(repos = BiocManager::repositories())
library(shiny)
library(waiter)
library(shinycssloaders)
library(shinythemes)
library(tidyverse)
library(DT)
library(ggsci)
library(cowplot)
library(shinyWidgets)
library(ggrepel)
library(plotly)


# Define UI
ui <- tagList(
  tags$head(
    tags$style(
      HTML("
      table.dataTable tbody tr.selected {
  pointer-events: none
}")
    ),
    # Programmatic navbar switching. The app's Bootstrap 3 theme limits
    # shiny::updateNavbarPage() to top-level tabs (the tab-input binding only
    # matches top-level anchors), so cross-tab navigation (Gene Query jumps,
    # ADR-0003) goes through this handler; switch_navbar_tab() in R/navbar.R.
    tags$script(HTML("
$(document).on('shiny:connected', function() {
  Shiny.addCustomMessageHandler('switch-navbar-tab', function(value) {
    var $nav = $('#main_nav');
    if (!$nav.length) return;
    var $tab = $nav.find('a[data-value=\"' + value + '\"]');
    if (!$tab.length) return;
    if (window.bootstrap) {
      bootstrap.Tab.getOrCreateInstance($tab[0]).show();
    } else if ($.fn.tab) {
      $tab.tab('show');
    }
  });
});
"))
  ),
  navbarPage(
    id = "main_nav",
    title = "SpatialBrain",
    selected = "home",
    theme = shinytheme("flatly"),
    header = list(
      use_waiter(),
      waiter_preloader(html = tagList(
        spin_fading_circles(),
        h1("Loading SpatialBrain...")
      ),
      fadeout = T)
      
    ),
    home_UI("home"),
    navbarMenu(
      title = "Spatial Transcriptomics",
      "Cell Type Markers",
      spatial_markers_UI("spatial_markers"),
      sn_vta_UI("sn_vta"),
      "Ageing",
      cell_type_numbers_age_UI("cell_type_numbers_age")
    ), 
    navbarMenu(
      title = "TRAP", 
      "Gene-level", 
      trap_enrichment_UI("trap_enrichment"),
      ageing_TRAP_UI("ageing_TRAP"),
      "Transcript-level", 
      # tabPanel("Alternative Splicing in Dopaminergic Neurons")
      splicing_UI("splicing")
    ), 
    gene_query_UI("gene_query"),
    download_data_UI("download_data")
  )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
  # Cross-tab selection store (ADR-0003): session-scoped, carries an arriving
  # gene selection from Gene Query to the analysis modules. `arriving` is
  # NULL (no selection) or a one-shot list(gene = "<symbol>", cell_type =
  # "<cell-type symbol>" or NULL; cell_type is only used by the Cell Type
  # Markers module). Analysis modules observe it and pre-select the gene;
  # direct per-tab use is unaffected.
  gene_selection <- reactiveValues(arriving = NULL)
  
  home_SERVER("home")
  
  metadata_all_cells <- readRDS("input/startup/metadata_all_cells.rds")
  cell_type_names <- readRDS("input/startup/cell_type_names.rds")
  
  sn_vta_SERVER("sn_vta", gene_selection)
  
  spatial_markers_SERVER("spatial_markers", metadata_all_cells, cell_type_names, gene_selection)
  
  cell_type_numbers_age_SERVER("cell_type_numbers_age", cell_type_names)
  
  trap_enrichment_SERVER("trap_enrichment", gene_selection)
  
  ageing_TRAP_SERVER("ageing_TRAP", gene_selection)
  
  splicing_SERVER("splicing", gene_selection)
  
  gene_query_SERVER("gene_query", gene_selection)
  
  download_data_SERVER("download_data")
  
  waiter_hide()
  
}

# Run the application
shinyApp(ui = ui, server = server)
