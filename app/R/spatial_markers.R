spatial_markers_UI <- function(id) {
  ns <- NS(id)
  tabPanel("Cell Type Markers",
           value = "spatial_markers",
           titlePanel(h1("Cell Type Markers", align = 'center')),
           br(),
           fluidRow(
             column(width = 5,
                    offset = 1,
                    align = "center",
                    # uiOutput(ns("spatial_plot_sized"))
                    plotOutput(ns("spatial_plot"), 
                               height = "600px"
                               # , width = "800px", height = "533px"
                               )
             ), 
             column(width = 5, 
                    # offset = 6, 
                    align = "center",
                    plotOutput(ns("marker_violin_plot"), 
                               height = "600px"
                               )
                    )
           ),
           hr(),
           # fluidRow(
           #   column(12,
           #          plotOutput(ns("marker_violin_plot"))
           # )
           # ),
           fluidRow(
             column(3,
                    h3(helpText("Select a cell type to view markers...")),
                    hr(),
                    selectizeInput(ns("cell_type"), 
                                   label = "Select cell type", 
                                   choices = NULL, 
                                   width = "100%"),
                    br(),
                    # h4("Data description"),
                    # p("Description of the data and analysis methods"),
                    # tags$ul(
                    #   tags$li("item 1"), 
                    #   tags$li("item 2"),
                    #   tags$li("item 3")
                    # ),
                    style = 'border-right: 1px solid'
             ), 
             column(6, 
                    h4("Select a gene to view its spatial expression"),
                    DT::dataTableOutput(ns("spatial_markers"))
             ), 
             column(3, 
                    h4("Definitions"),
                    strong("LFC: "), span("The log2 fold-change in abundance between the cell type of interest and all other cells"),
                    br(),
                    br(),
                    strong("FDR-P "), span("The P value, adjusted for multiple comparisons (B&H)"),
                    hr(),
                    h4("Download Data"),
                    radioButtons(ns("plot_format"), "Plot format",
                      choices = c("PNG (300 dpi)" = "png", "SVG" = "svg", "PDF" = "pdf"),
                      inline = TRUE, selected = "png"),
                    p(class = 'text-center', downloadButton(
                      ns('download_table'), 'Download Markers'
                    )),
                    p(class = 'text-center', downloadButton(
                      ns('download_spatial_plot'), 'Download Spatial Plot'
                    )),
                    p(class = 'text-center', downloadButton(
                      ns('download_marker_plot'), 'Download Marker Plot'
                    )),
                    # numericInput(ns('plot_size'), 
                    #              label = "Plot size (pixels)",
                    #              value = 800),
                    # numericInput(ns('plot_height'), 
                    #              label = "Plot height (pixels)",
                    #              value = 400),
                    # verbatimTextOutput(ns("debug")),
                    style = 'border-left: 1px solid'
             )
           ))
  
}

# markers server ----
spatial_markers_SERVER <- function(id, metadata_all_cells, cell_type_names, gene_selection) {
  moduleServer(id, function(input, output, session) {
    # namespace ----
    ns <- session$ns
    
    
    # results <- read_csv(
    #   "input/sn_vta/sn_vta_mast.csv",
    #   col_names = c("Gene",
    #                 "Log2 Fold-change",
    #                 "Adjusted P Value"),
    #   skip = 1
    # ) %>%
    #   mutate(across(c(`Adjusted P Value`, `Log2 Fold-change`), ~ signif(.x, 3)))
    
    # sn_vta_vars <- reactiveValues()
    # 
    # observeEvent(c(input$cell_type),
    #              {
    #                sn_vta_vars$results_filtered <- results %>%
    #                  # filter(abs(`Log2 Fold-change`) > input$lfc) %>%
    #                  filter(`Adjusted P Value` < input$padj)
    #              })
    
        markers_vars <- reactiveValues()
    
    spatial_markers_proxy <- dataTableProxy("spatial_markers")
    
    # Phase C (ADR-0003): a cell type whose marker table contains `gene` --
    # the arriving selection's cell type when it fits, else the first match
    # across the 32 marker tables.
    resolve_cell_type <- function(gene, cell_type = NULL) {
      if (!is.null(cell_type) &&
          gene %in% readRDS(paste0("input/markers/cell_types/", cell_type, ".rds"))$Gene) {
        return(cell_type)
      }
      for (ct in cell_type_names) {
        if (gene %in% readRDS(paste0("input/markers/cell_types/", ct, ".rds"))$Gene) {
          return(ct)
        }
      }
      NULL
    }
    
    # Phase C (ADR-0003): arriving selection from Gene Query. One-shot; with
    # no arriving selection the observer never fires and the tab behaves
    # exactly as before.
    pending_gene <- NULL
    select_jumped_gene <- function(gene) {
      markers_vars$selected_gene <- gene
      markers_vars$counts <-
        readRDS(paste0("input/markers/counts_per_gene/", gene, ".rds")) %>%
        cbind(metadata_all_cells[, -1])
    }
    
        observeEvent(gene_selection$arriving, {
      req(gene_selection$arriving)
      sel <- gene_selection$arriving
      ct <- resolve_cell_type(sel$gene, sel$cell_type)
      if (is.null(ct)) return()
      # The arrived gene becomes the tab's default while it remains valid for
      # the current cell type (jump_landed; cleared when the user picks a
      # row). This stops the table's first-render selection event (which
      # arrives as rows_selected = NULL after the tab is shown) from
      # resetting the plot to row 1.
      markers_vars$jump_landed <- sel$gene
      if (identical(input$cell_type, ct) && !is.null(markers_vars$marker_table) &&
          sel$gene %in% markers_vars$marker_table$Gene) {
        # already on the right cell type: select directly
        select_jumped_gene(sel$gene)
        selectRows(spatial_markers_proxy,
                   which(markers_vars$marker_table$Gene == sel$gene)[1])
      } else if (!identical(input$cell_type, ct)) {
        # switch cell type, then select once the marker table has loaded
        pending_gene <<- sel$gene
        updateSelectizeInput(session, "cell_type", selected = ct)
      }
      # else: the target cell type is already active without a loaded table
      # (or without the gene) — nothing to switch, drop the jump
    })
    
    observeEvent(markers_vars$marker_table, {
      req(markers_vars$marker_table, pending_gene)
      gene <- pending_gene
      pending_gene <<- NULL
      row <- which(markers_vars$marker_table$Gene == gene)
      if (length(row) == 0) return()
      select_jumped_gene(gene)
      selectRows(spatial_markers_proxy, row[1])
    }, ignoreNULL = FALSE)
  
    updateSelectizeInput(getDefaultReactiveDomain(),  
                         "cell_type", 
                         choices = cell_type_names, 
                         selected = "DA_SN")
    
    observeEvent(input$cell_type, {
      req(input$cell_type)
      markers_vars$marker_table <- readRDS(paste0("input/markers/cell_types/", input$cell_type, ".rds")) %>%
        arrange(desc(LFC))
        # filter(lfc > 0) %>%
        # mutate(across(where(is.numeric), ~ signif(.x, 3)))
      markers_vars$selected_cell_type_public <- names(cell_type_names[cell_type_names == input$cell_type])
    })
    
    # Cell types TABLE
    output$spatial_markers <- DT::renderDataTable({
      # req(input$cell_type)
      # readRDS(paste0("input/markers/cell_types/", input$cell_type, ".rds"))
      markers_vars$marker_table
    },
    selection = "single",
    server = TRUE,
    rownames = FALSE)
    
    # The cell-type change that triggered this observer invalidates any
    # rows_selected index (it belongs to the previous table): treat the pass
    # as having no valid row selection, so an arrived gene that is still a
    # marker of the new cell type is kept (re-selected), and otherwise the
    # tab falls back to row 1 exactly as before.
    prev_cell_type <- NULL
    observeEvent(c(input$spatial_markers_rows_selected, input$cell_type), {
      req(markers_vars$marker_table)
      cell_type_changed <- !identical(prev_cell_type, input$cell_type)
      prev_cell_type <<- input$cell_type
      row_sel <- if (cell_type_changed) NULL else input$spatial_markers_rows_selected
      if (is.null(row_sel) || is.na(row_sel) || row_sel > nrow(markers_vars$marker_table)) {
        # No valid row selection. The index can be stale after a cell-type
        # switch (the tables differ in size), which would otherwise index
        # past the table's rows. When a jumped gene is still valid for this
        # table, (re-)select its row: the table's first-render event
        # (rows_selected = NULL after the tab is shown) is the signal that
        # the DT is now initialized, so a selection issued while it was
        # hidden (and dropped) can be re-issued. Otherwise default to row 1.
        if (!is.null(markers_vars$jump_landed) &&
            markers_vars$jump_landed %in% markers_vars$marker_table$Gene) {
          selectRows(spatial_markers_proxy,
                     which(markers_vars$marker_table$Gene == markers_vars$jump_landed)[1])
        } else {
          markers_vars$selected_gene <- markers_vars$marker_table[1,] %>% pull(Gene)
        }
      } else {
        sel <- markers_vars$marker_table[row_sel, ]$Gene
        markers_vars$selected_gene <- sel
        # Clear the jumped default only on a real user selection (a
        # different row); the programmatic echo of the jump's own selectRows
        # selects the same gene and must not clear it.
        if (!identical(sel, markers_vars$jump_landed)) markers_vars$jump_landed <- NULL
      }
      markers_vars$counts <-
        readRDS(paste0(
          "input/markers/counts_per_gene/",
          markers_vars$selected_gene,
          ".rds"
        )) %>%
        cbind(metadata_all_cells[, -1])
    }, ignoreNULL = F)
    
    plot_spatial_func <- function(){
        # filter(count > 0) %>%
        # arrange(count) %>%
        # mutate(alpha = ifelse(count == 0, 0.01, 1)) %>%
        
        # slice_sample(prop = 0.1) %>%
        ggplot(data = slice_sample(markers_vars$counts[markers_vars$counts$count == 0,], prop = 0.1),
               aes(x = x,
                   y = y,
                   # colour = count
                   # alpha = count
                   # size = count
                   )) +
        geom_point(colour = "lightgrey", size = 0.1) +
        geom_point(data = {arrange(markers_vars$counts[markers_vars$counts$count > 0,], count) %>%
            mutate(count = ifelse(count > quantile(count, 0.99), 
                                  quantile(count, 0.99), 
                                  count)) %>%
            mutate(count = ifelse(count < quantile(count, 0.05), 
                                  0, 
                                  count))}, 
                   aes(colour = count, 
                       size = count)) +
        # geom_point(data = counts[counts$cell_type_publish == selected_cell_type,],
        #            colour = "orange") +
        facet_wrap(vars(mouse_id_presentation_no_genotype),
                   scales = "free") +
        theme_cowplot() +
        panel_border() +
        scale_y_reverse() +
        theme(
          axis.text.x = element_blank(),
          axis.text.y = element_blank(),
          axis.ticks = element_blank(),
          axis.line = element_blank(),
          axis.title = element_blank(),
          # legend.position = "none"
        ) +
        scale_color_gradient(low = "lightgrey", high = "red") +
        # scale_colour_viridis_c(option = "A") +
        # scale_color_gradientn(colours = c("white", "white", "red"),
        #                       breaks = c(0, 3, 12),
        #                       limits = c(0, 12),
        #                       oob = scales::squish) +
        scale_size(range = c(0.1, 2)) +
        # scale_alpha(range = c(0, 1)) +
        labs(colour = "Count", 
             size = "Count", 
             alpha = "Count", 
             title = markers_vars$selected_gene)
    }
    
    # observeEvent(input$plot_size, {
    #   markers_vars$plot_width <- paste0(input$plot_size, "px")
    #   markers_vars$plot_height <- paste0((input$plot_size / 1.5), "px")
    # })
    
    # output$spatial_plot_sized <- renderUI({
    #   req(markers_vars$plot_height)
    #   plotOutput(ns("spatial_plot")
    #              # width = markers_vars$plot_width,
    #              # height = markers_vars$plot_height,
    #              # width = paste0(600, "px"), 
    #              # height = paste0(600/1.5, "px")
    #              )
    # })
    
    output$spatial_plot <- renderPlot({
      req(markers_vars$counts)
      plot_spatial_func()
    })
    
    plot_marker_func <- function(){
      readRDS(paste0("input/markers/counts_per_gene/", markers_vars$selected_gene, ".rds")) %>% 
        full_join(metadata_all_cells) %>%
        ggplot(aes(x = cell_type_public, 
                   y = count)) +
        geom_violin(scale = "width") +
        theme_cowplot() +
        coord_flip() +
        labs(y = "Count", title = markers_vars$selected_gene) +
        theme(axis.title.y = element_blank())
    }
    
    output$marker_violin_plot <- renderPlot({
      req(markers_vars$counts)
      plot_marker_func()
    })
    
    # download the filtered data
    output$download_table = downloadHandler(
      filename = function() {
      paste0('Cell Type Markers - ', markers_vars$selected_cell_type_public, '.csv')
      },
      content = function(file) {
        write_csv(markers_vars$marker_table, file)
      }
    )
    
    output$download_spatial_plot <- downloadHandler(
      filename = function() {
        paste0("Spatial Plot - ", markers_vars$selected_gene, ".", input$plot_format)
      },
      content = function(file) {
        export_plot(file, plot_spatial_func(), input$plot_format)
      }
    )
    
    output$download_marker_plot <- downloadHandler(
      filename = function() {
        paste0("Marker Plot - ", markers_vars$selected_gene, ".", input$plot_format)
      },
      content = function(file) {
        export_plot(file, plot_marker_func(), input$plot_format)
      }
    )

    # output$debug <- renderPrint(reactiveValuesToList(session$clientData))
    
  })
}
