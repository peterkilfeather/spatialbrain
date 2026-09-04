trap_enrichment_UI <- function(id) {
  ns <- NS(id)
  tabPanel("TRAP Enrichment in Dopaminergic Neurons",
           value = "trap_enrichment",
           titlePanel(h1("TRAP Enrichment in Dopaminergic Neurons", align = 'center')),
           br(),
           fluidRow(
             column(8,
                    offset = 2,
                    plotlyOutput(ns("ma_plot")),
                    # verbatimTextOutput(ns("debug"))
                    )
           ),
           hr(),
           fluidRow(
             column(3,
                    # h4("Data description"),
                    # p("Description of the data and analysis methods"),
                    # tags$ul(
                    #   tags$li("item 1"), 
                    #   tags$li("item 2"),
                    #   tags$li("item 3")
                    # ),
                    h4(helpText("Plot settings")),
                    hr(),
                    checkboxInput(ns("show_unchanged"),
                                  label = "Show Unchanged",
                                  value = T),
                    checkboxInput(ns("show_depleted"),
                                  label = "Show Depleted",
                                  value = T),
                    p(tags$em("To reset your selection, double click within the plot area")),
                    br(),
                    h4(helpText("Definitions")),
                    hr(),
                    p(tags$b("LFC: "), "The log2 fold-change in abundance in TRAP samples, compared to TOTAL"),
                    p(tags$b("FDR-P: "), "The P value, adjusted for multiple comparisons (B&H)"),
                    p(tags$b("TOTAL: "), "Bulk RNA from ventral midbrain"),
                    p(tags$b("TRAP: "), "RNA from DAT-TRAP"),
                    p(tags$b("Enriched/Depleted: "), "FDR-P ≤ 0.01 (sumz meta-analysis), one-sided"),
                    style = 'border-right: 1px solid'
                    ), 
             column(6, 
                    h4("Select a gene to highlight it on the plot"),
                    DT::dataTableOutput(ns("enrichment_table")),
                    
                    ), 
             column(3, 
                    h4(helpText("Download Data")),
                    hr(),
                    p(class = 'text-center', downloadButton(
                      ns('download_table'), 'Download Selected Data'
                    )),
                    # br(),
                    p(class = 'text-center', downloadButton(
                      ns('download_enriched_table'), 'Download All Enriched'
                    )),
                    # br(),
                    p(class = 'text-center', downloadButton(
                      ns('download_all_table'), 'Download All Data'
                    )),
                    style = 'border-left: 1px solid'
                    )
           ))

}

trap_enrichment_SERVER <- function(id, gene_selection) {
  moduleServer(id, function(input, output, session) {
    # namespace ----
    ns <- session$ns
    
            trap_enrichment_vars <- reactiveValues()
    
    trap_enrichment_proxy <- dataTableProxy("enrichment_table")
    
    # Phase C (ADR-0003): arriving selection from Gene Query. One-shot; with
    # no arriving selection the observer never fires and the tab behaves
    # exactly as before. Only genes in the enrichment meta-table are acted
    # on (the MA plot may show a subset filtered by the show-unchanged /
    # show-depleted switches).
    observeEvent(gene_selection$arriving, {
      req(gene_selection$arriving)
      gene <- gene_selection$arriving$gene
      if (!(gene %in% MB_FRACTION_META$Gene)) return()
      # The arrived gene becomes the tab's default (jump_landed; cleared when
      # the user picks a row) so the table's first-render selection event
      # (rows_selected = NULL after the tab is shown) cannot reset to row 1.
      trap_enrichment_vars$jump_landed <- gene
      trap_enrichment_vars$selected_gene <- gene
      trap_enrichment_vars$highlight_markers <- trap_enrichment_vars$plot_data %>%
        filter(external_gene_name == gene)
      # Re-select the gene's row in the currently shown table (read with
      # isolate: the observer is one-shot and must not track the brush
      # filter), so a repeat jump to an already-initialised tab keeps the
      # DT row selection in step with the MA-plot highlight. The first-visit
      # path is handled by the first-render re-issue in the rows_selected
      # observer below (the proxy is not initialised yet here, so this
      # selectRows is a silent no-op then). A gene absent from the current
      # (brush-filtered) table selects nothing.
      row <- which(isolate(table_data())$Gene == gene)
      if (length(row) > 0) selectRows(trap_enrichment_proxy, row[1])
    })
    
    MB_FRACTION_META <-
      readRDS("input/startup/MB_FRACTION_META.rds")
    plot_data <- readRDS("input/startup/MA_plot_data.rds") %>%
      mutate(enrichment = factor(enrichment,
                                 levels = c("Unchanged",
                                            "Depleted",
                                            "Enriched")))
    
    observeEvent(input$show_unchanged | input$show_depleted,
                 {
                   req(plot_data)
                   trap_enrichment_vars$plot_data <- plot_data
                   
                   if (input$show_unchanged == F) {
                     trap_enrichment_vars$plot_data <- trap_enrichment_vars$plot_data %>%
                       filter(enrichment != "Unchanged")
                   }
                   if (input$show_depleted == F) {
                     trap_enrichment_vars$plot_data <- trap_enrichment_vars$plot_data %>%
                       filter(enrichment != "Depleted")
                   }
                   
                   trap_enrichment_vars$plot_data <-
                     trap_enrichment_vars$plot_data %>%
                     arrange(enrichment)
                   
                 })
    
    # Genes TABLE - full table by default; filtered to the brushed MA-plot
    # points while a plotly selection is active (double-click clears it)
    table_data <- reactive({
      selection <- event_data("plotly_selected")
      if (is.null(selection) || nrow(selection) == 0) {
        MB_FRACTION_META
      } else {
        MB_FRACTION_META %>%
          filter(Gene %in% selection$customdata)
      }
    })
    
    output$enrichment_table <- DT::renderDataTable({
      table_data() %>%
        select(Gene,
               "LFC" = `Log2 Fold Enrichment`,
               `FDR-P`)
    },
    selection = "single",
    server = TRUE,
    rownames = FALSE)
    
    observeEvent(c(input$enrichment_table_rows_selected), {
      req(MB_FRACTION_META)
      current_table <- table_data()
      if (is.null(input$enrichment_table_rows_selected)) {
        if (!is.null(trap_enrichment_vars$jump_landed)) {
          # First-render event: the DT is initialized now, so re-issue the
          # row selection that was dropped while the tab was still hidden
          # (only when the gene is in the currently shown table).
          row <- which(current_table$Gene == trap_enrichment_vars$jump_landed)
          if (length(row) > 0) selectRows(trap_enrichment_proxy, row[1])
          return()
        }
        trap_enrichment_vars$selected_gene <- current_table[1,] %>% pull(Gene)
      } else if (!is.na(input$enrichment_table_rows_selected) &&
                 input$enrichment_table_rows_selected <= nrow(current_table)) {
        sel <- current_table[input$enrichment_table_rows_selected, ]$Gene
        trap_enrichment_vars$selected_gene <- sel
        # Clear the jumped default only on a real user selection (a
        # different row); the programmatic echo selects the same gene.
        if (!identical(sel, trap_enrichment_vars$jump_landed)) trap_enrichment_vars$jump_landed <- NULL
      }
      trap_enrichment_vars$highlight_markers <- trap_enrichment_vars$plot_data %>%
        filter(external_gene_name == trap_enrichment_vars$selected_gene)
    }, ignoreNULL = F)
    
    # Interactive MA plot: hover shows gene / LFC / FDR-P; box-select
    # filters the enrichment table (dragmode = "select"; double-click clears)
    output$ma_plot <- renderPlotly({
      req(trap_enrichment_vars$plot_data,
          trap_enrichment_vars$highlight_markers)
      
      pal <- c("#C1C1C1",
               "#1F77B4FF",
               "#2CA02CFF")
      pal <- setNames(pal, c("Unchanged", "Depleted", "Enriched"))
      
      # FDR-P lives in MB_FRACTION_META (1:1 by gene). The ggplot y-axis
      # squishes LFCs > 6 to the 6 limit; mirror that in the display values
      # while tooltips keep the true LFC.
      plot_data <- trap_enrichment_vars$plot_data %>%
        left_join(MB_FRACTION_META, by = c("external_gene_name" = "Gene"),
                  relationship = "many-to-many") %>%
        mutate(y_display = pmin(log2FoldChange, 6),
               hover_text = paste0("<b>", external_gene_name,
                                   "</b><br>LFC: ", signif(log2FoldChange, 3),
                                   "<br>FDR-P: ", signif(`FDR-P`, 3)))
      
      highlight_markers <- trap_enrichment_vars$highlight_markers %>%
        left_join(MB_FRACTION_META, by = c("external_gene_name" = "Gene"),
                  relationship = "many-to-many") %>%
        mutate(y_display = pmin(log2FoldChange, 6))
      
      fig <- plot_ly(
        data = plot_data,
        x = ~ baseMean_C1,
        y = ~ y_display,
        type = "scatter",
        mode = "markers",
        color = ~ enrichment,
        colors = pal,
        opacity = 0.5,
        text = ~ hover_text,
        hoverinfo = "text",
        customdata = ~ external_gene_name
      )
      
      if (nrow(highlight_markers) > 0) {
        highlight_colour <- pal[as.character(highlight_markers$enrichment[1])]
        fig <- fig %>%
          add_trace(
            data = highlight_markers,
            x = ~ baseMean_C1,
            y = ~ y_display,
            type = "scatter",
            mode = "markers+text",
            text = ~ external_gene_name,
            textposition = "top center",
            textfont = list(color = "black", size = 12),
            marker = list(size = 13,
                          color = highlight_colour,
                          line = list(color = "black", width = 1.5)),
            opacity = 1,
            hoverinfo = "skip",
            showlegend = FALSE
          )
      }
      
      fig %>%
        event_register("plotly_selected") %>%
        config(
          displayModeBar = T,
          toImageButtonOptions = list(
            filename = 'TRAP Enrichment Plot',
            width = 1366,
            height =  768
          )
        ) %>%
        layout(
          dragmode = "select",
          xaxis = list(type = "log",
                       # plotly log-axis ranges are in log10 units (ggplot
                       # x-range -1.714..5.484 in log10 space)
                       range = list(-1.714, 5.484),
                       title = "Mean Counts",
                       showline = T,
                       linewidth = 2,
                       linecolor = "black"),
          yaxis = list(range = list(-9.083, 6.718),
                       title = "Log<sub>2</sub> Fold Change",
                       showline = T,
                       linewidth = 2,
                       linecolor = "black"),
          margin = list(t = 75),
          legend = list(title = list(text = '<b>Enrichment</b>'),
                        orientation = 'h',
                        x = 0.5,
                        xanchor = "center",
                        y = 6.5)
        )
    })
    
    # download the filtered data
    output$download_table = downloadHandler(
      'TRAP Enrichment Information.csv',
      content = function(file) {
        write_csv(table_data(), file)
      }
    )
    
    output$download_enriched_table = downloadHandler(
      'TRAP Enrichment Information - All Enriched Genes.csv',
      content = function(file) {
        write_csv(MB_FRACTION_META[MB_FRACTION_META$`FDR-P` < 0.01 &
                                     MB_FRACTION_META$`Log2 Fold Enrichment` > 0, ], file)
      }
    )
    output$download_all_table = downloadHandler(
      'TRAP Enrichment Information - All Genes.csv',
      content = function(file) {
        write_csv(MB_FRACTION_META, file)
      }
    )
    
    # output$debug <- renderPrint(trap_enrichment_vars$plot_data)
    
  })
}
