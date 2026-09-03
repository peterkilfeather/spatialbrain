splicing_UI <- function(id) {
  ns <- NS(id)
  tabPanel(
    "Alternative Splicing in Dopaminergic Neurons",
    value = "splicing",
    titlePanel(h1("Alternative Splicing in Dopaminergic Neurons", align = 'center')),
    br(),
    fluidRow(column(
      width = 6,
      offset = 3,
      align = "center",
      plotOutput(ns("splicing_plot"),
                 # height = "300px"
                 # , width = "800px", height = "533px")
      ))),
    hr(),
    # fluidRow(
    #   column(12,
    #          plotOutput(ns("marker_violin_plot"))
    # )
    # ),
    fluidRow(
      column(
        3,
        h4(tags$i("Evidence for differential transcript usage was assessed using DRIMSeq on transcript-level counts derived from next-generation and long-read sequencing data of TRAP samples.")),
        br(),
        h4(helpText("Definitions")),
        hr(),
        p(tags$b("TOTAL: "), "Bulk RNA from ventral midbrain"),
        p(tags$b("TRAP: "), "RNA from DAT-TRAP"),
        # tags$ul(tags$li("item 1"),
        #         tags$li("item 2"),
        #         tags$li("item 3")),
        style = 'border-right: 1px solid'
      ),
      column(
        6,
        h4("Select a gene to view its splicing profile"),
        DT::dataTableOutput(ns("splicing_table"))
      ),
      column(
        3,
        h4(helpText("Download Data")),
        hr(),
        radioButtons(ns("plot_format"), "Plot format",
          choices = c("PNG (300 dpi)" = "png", "SVG" = "svg", "PDF" = "pdf"),
          inline = TRUE, selected = "png"),
        p(class = 'text-center', downloadButton(
          ns('download_table'), 'Download Splicing Table'
        )),
        p(class = 'text-center', downloadButton(
          ns('download_plot'), 'Download Splicing Plot'
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
    )
  )
}

splicing_SERVER <- function(id, gene_selection) {
  moduleServer(id, function(input, output, session) {
    # namespace ----
    ns <- session$ns
    
        splicing_vars <- reactiveValues()
    
    splicing_proxy <- dataTableProxy("splicing_table")
    
    # Phase C (ADR-0003): arriving selection from Gene Query. One-shot; with
    # no arriving selection the observer never fires and the tab behaves
    # exactly as before.
    observeEvent(gene_selection$arriving, {
      req(gene_selection$arriving)
      gene <- gene_selection$arriving$gene
      row <- which(splicing_vars$table$Gene == gene)
      if (length(row) == 0) return()
      # The arrived gene becomes the tab's default (jump_landed; cleared when
      # the user picks a row) so the table's first-render selection event
      # (rows_selected = NULL after the tab is shown) cannot reset to row 1.
      splicing_vars$jump_landed <- gene
      splicing_vars$selected_gene <- gene
      splicing_vars$counts <-
        readRDS(paste0("input/splicing/", gene, ".rds")) %>%
        mutate(fraction = ifelse(str_detect(
          sample_name, "TOTAL"), "TOTAL", "TRAP"
        ))
      selectRows(splicing_proxy, row[1])
    })
    
    splicing_vars$table <-
      readRDS("input/startup/splicing_meta.rds")
      # select("Gene" = external_gene_name,
      #        "FDR-P" = adj_pvalue) %>%
      # filter(Gene %in% str_remove(list.files("input/splicing/"), ".rds")) %>%
      # mutate(across(c(`FDR-P`), ~ signif(.x, 3)))
    
    observeEvent(input$splicing_table_rows_selected, {
      splicing_vars$g <-
        splicing_vars$table[input$splicing_table_rows_selected, ]$Gene
    })
    
    # observeEvent(input$cell_type, {
    #   req(input$cell_type)
    #   markers_vars$marker_table <- readRDS(paste0("input/markers/cell_types/", input$cell_type, ".rds")) %>%
    #     filter(lfc > 0)
    # })
    #
    # Splicing table
    output$splicing_table <-
      DT::renderDataTable(
        splicing_vars$table,
        selection = "single",
        rownames = FALSE,
        server = T, 
        width = "60%"
      )
    
    observeEvent(input$splicing_table_rows_selected, {
      req(splicing_vars$table)
      if (is.null(input$splicing_table_rows_selected)) {
        if (!is.null(splicing_vars$jump_landed)) {
          # First-render event: the DT is initialized now, so re-issue the
          # row selection that was dropped while the tab was still hidden.
          row <- which(splicing_vars$table$Gene == splicing_vars$jump_landed)
          if (length(row) > 0) selectRows(splicing_proxy, row[1])
          return()
        }
        splicing_vars$selected_gene <-
          splicing_vars$table[1, ] %>% pull(Gene)
      } else {
        sel <- splicing_vars$table[input$splicing_table_rows_selected,]$Gene
        splicing_vars$selected_gene <- sel
        # Clear the jumped default only on a real user selection (a
        # different row); the programmatic echo selects the same gene.
        if (!identical(sel, splicing_vars$jump_landed)) splicing_vars$jump_landed <- NULL
      }
      splicing_vars$counts <-
        readRDS(paste0("input/splicing/",
                       splicing_vars$selected_gene,
                       ".rds")) %>%
        mutate(fraction = ifelse(str_detect(
          sample_name, "TOTAL"), "TOTAL", "TRAP"
        ))
    }, ignoreNULL = F)
    
    plot_splicing_func <- function() {
      ggplot(data = splicing_vars$counts,
             aes(x = fraction,
                 y = count, 
                 fill = fraction)) +
        facet_wrap(vars(external_transcript_name)) +
        geom_boxplot() +
        geom_point(shape = 21) +
        theme_cowplot() +
        panel_border() +
        scale_fill_d3() +
        scale_y_continuous(limits = c(0, 1)) +
        theme(legend.position = "none") +
        labs(x = "Transcript", 
             y = "Proportion of Expression", 
             title = splicing_vars$selected_gene)
      
    }
    #
    # # observeEvent(input$plot_size, {
    # #   markers_vars$plot_width <- paste0(input$plot_size, "px")
    # #   markers_vars$plot_height <- paste0((input$plot_size / 1.5), "px")
    # # })
    #
    # # output$spatial_plot_sized <- renderUI({
    # #   req(markers_vars$plot_height)
    # #   plotOutput(ns("spatial_plot")
    # #              # width = markers_vars$plot_width,
    # #              # height = markers_vars$plot_height,
    # #              # width = paste0(600, "px"),
    # #              # height = paste0(600/1.5, "px")
    # #              )
    # # })
    #
    output$splicing_plot <- renderPlot({
      req(splicing_vars$counts)
      plot_splicing_func()
    })
  
    # download the data
    output$download_table = downloadHandler(
      paste0('Splicing results - TRAP.csv'),
      content = function(file) {
        write_csv(splicing_vars$table, file)
      }
    )
    
    output$download_plot <- downloadHandler(
      filename = function() {
        paste0("Splicing Plot - ", splicing_vars$selected_gene, ".", input$plot_format)
      },
      content = function(file) {
        export_plot(file, plot_splicing_func(), input$plot_format)
      }
    )
    
    # output$debug <- renderPrint(splicing_vars$counts)
    
    
  })
}
