cell_type_numbers_age_UI <- function(id) {
  ns <- NS(id)
  tabPanel("Cell Type Numbers with Age",
           value = "cell_type_numbers_age",
           titlePanel(h1("Cell Type Numbers with Age", align = 'center')),
           br(),
           fluidRow(
             column(width = 5,
                    offset = 1,
                    align = "center",
                    # uiOutput(ns("spatial_plot_sized"))
                    plotlyOutput(ns("volcano_plot"), 
                               # height = "500px"
                               # , width = "800px", height = "533px"
                               )
             ), 
             column(width = 5, 
                    # offset = 6, 
                    align = "center",
                    plotOutput(ns("actual_counts_plot"), 
                               # height = "500px"
                               )
                    )
           ),
           fluidRow(
             column(width = 10,
                    offset = 1,
                    align = "center",
                    plotOutput(ns("xy_plot"),
                               heigh = "250px"
                    )
             )
           ),
           hr(),
           fluidRow(
             column(3,
                    h4(tags$i("Testing for age-related changes in cell type abundance was performed using MASC in Stereo-Seq samples")),
                    br(),
                    h4(helpText("Definitions")),
                    hr(),
                    p(tags$b("YOUNG: "), "Mice aged 3-6 months"),
                    p(tags$b("OLD: "), "Mice aged 18-22 months"),
                    p(tags$b("FDR-P: "), "The P value, adjusted for multiple comparisons (B&H)"),
                    p(tags$b("Estimate: "), "Odds ratio for abundance change in aged brains. Positive values indicate an increase in abundance"),
                    p(tags$b("Cell types: "), "32 annotated cell types, incl. 3 age-responsive subtypes; 29 in the published annotation"),
                    
                    style = 'border-right: 1px solid'
             ), 
             column(6, 
                    h4("Select a cell type to view its abundance across age groups"),
                    DT::dataTableOutput(ns("masc_table")),
                    # selectizeInput(ns("cell_type"),
                    #                label = "Select cell type",
                    #                choices = NULL,
                    #                width = "100%")
             ), 
             column(3, 
                    # h3(helpText("Select a cell type to view markers...")),
                    # hr(),
                    # selectizeInput(ns("cell_type"), 
                    #                label = "Select cell type", 
                    #                choices = NULL, 
                    #                width = "100%"),
                    br(),
                    p(class = 'text-center', downloadButton(
                      ns('download_table'), 'Download Overall Results'
                    )),
                    p(class = 'text-center', downloadButton(
                      ns('download_numbers'), 'Download Cell Type Numbers per Brain'
                    )),
                    # p(class = 'text-center', downloadButton(
                    #   ns('download_marker_plot'), 'Download Marker Plot'
                    # )),
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

# server ----
cell_type_numbers_age_SERVER <- function(id, cell_type_names) {
  moduleServer(id, function(input, output, session) {
    # namespace ----
    ns <- session$ns
    
    cell_type_numbers_age_vars <- reactiveValues()
  
    cell_type_numbers_age_vars$masc <- readRDS("input/ageing_cell_type_numbers/data.rds") %>%
      arrange(fdr) %>%
      mutate(across(where(is.numeric), ~ signif(.x, 3)))
    
    output$masc_table <- DT::renderDataTable({
      cell_type_numbers_age_vars$masc %>%
        select(-cell_type, 
               "Cell Type" = cell_type_full, 
               "Estimate" = estimate, 
               "FDR" = fdr)
    },
    selection = "single",
    server = TRUE,
    rownames = FALSE)
    
    observeEvent(c(input$masc_table_rows_selected, input$cell_type), {
      req(cell_type_numbers_age_vars$masc)
      if (is.null(input$masc_table_rows_selected)) {
        cell_type_numbers_age_vars$selected_cell_type <- cell_type_numbers_age_vars$masc[1,] %>% pull(cell_type)
      } else {
        cell_type_numbers_age_vars$selected_cell_type <-
          cell_type_numbers_age_vars$masc[input$masc_table_rows_selected, ]$cell_type
      }
    }, ignoreNULL = F)
    
    # updateSelectizeInput(getDefaultReactiveDomain(), 
    #                      "cell_type", 
    #                      choices = cell_type_names, 
    #                      selected = "DA_SN")
    
    # Interactive volcano: hover shows cell type / estimate / FDR. The
    # fdr < 0.005 labels are boxed annotations laid out against the rendered
    # plot (no overlaps, points visible); row selection in the table still
    # marks the chosen cell type red.
    output$volcano_plot <- renderPlotly({
      req(cell_type_numbers_age_vars$selected_cell_type)
      
      volcano_data <- cell_type_numbers_age_vars$masc %>%
        mutate(x_display = pmax(pmin(estimate, 1.5), -1.5),
               point_colour = ifelse(cell_type ==
                                       cell_type_numbers_age_vars$selected_cell_type,
                                     "red", "black"),
               hover_text = paste0("<b>", cell_type_full,
                                   "</b><br>Estimate: ", estimate,
                                   "<br>FDR: ", fdr))
      
      # Label anchors for the fdr < 0.005 points. Positions were laid out
      # against the rendered plot (no overlaps, points visible; labels sit
      # adjacent to their points — see Phase B verification notes).
      label_anchors <- tibble(
        cell_type_full = c("Microglia: Age-responsive",
                           "Dopaminergic Neurons: Substantia Nigra",
                           "CA1 Neurons",
                           "Dorsal Subiculum Neurons",
                           "Oligodendrocytes: Age-responsive",
                           "Astrocytes: Age-responsive",
                           "GABAergic Neurons: Superior Colliculus",
                           "Limbic/Cortical Neurons: Lsamp+ Rbfox1+"),
        label_x = c(0.967, -0.729, -1.10, 0.209, 0.113, 0.30, 0.413, -0.829),
        label_y = c(7.90, 6.30, 4.09, 4.78, 3.30, 1.15, 1.90, 2.69)
      )
      
      labels <- volcano_data %>%
        filter(fdr < 0.005) %>%
        inner_join(label_anchors, by = "cell_type_full")
      
      fig <- plot_ly(
        data = volcano_data,
        x = ~ x_display,
        y = ~ -log10(fdr),
        type = "scatter",
        mode = "markers",
        marker = list(size = 8,
                      color = ~ point_colour,
                      line = list(color = "black", width = 0.5)),
        text = ~ hover_text,
        hoverinfo = "text",
        showlegend = FALSE
      )
      
      fig %>%
        layout(
          xaxis = list(range = list(-1.65, 1.65),
                       title = "Log<sub>2</sub> OR",
                       showline = T,
                       linewidth = 2,
                       linecolor = "black"),
          yaxis = list(range = list(-0.37, 7.942),
                       title = "-Log<sub>10</sub> FDR",
                       showline = T,
                       linewidth = 2,
                       linecolor = "black"),
          shapes = list(
            list(type = "line", x0 = 0, x1 = 0,
                 y0 = -0.37, y1 = 7.942,
                 line = list(color = "black", dash = "dot")),
            list(type = "line", x0 = -1.65, x1 = 1.65,
                 y0 = -log10(0.01), y1 = -log10(0.01),
                 line = list(color = "black", dash = "dot"))
          ),
          showlegend = FALSE,
          margin = list(l = 60, r = 30, t = 30, b = 40)
        ) %>%
        add_annotations(
          x = labels$label_x,
          y = labels$label_y,
          text = labels$cell_type_full,
          xref = "x",
          yref = "y",
          xanchor = "middle",
          yanchor = "middle",
          showarrow = FALSE,
          cliponaxis = FALSE,
          bgcolor = "white",
          bordercolor = "black",
          borderpad = 1,
          font = list(size = 10)
        )
    })
    
    actual_numbers <- readRDS("input/ageing_cell_type_numbers/actual_numbers.rds")
    
    output$actual_counts_plot <- renderPlot({
      req(cell_type_numbers_age_vars$selected_cell_type)
    actual_numbers %>%
      filter(cell_type_publish == cell_type_numbers_age_vars$selected_cell_type) %>%
      ggplot(aes(x = age, 
                 y = n)) +
      geom_point() +
      theme_cowplot() +
      labs(x = "Age", y = "Number of Cells", title = names(cell_type_names[cell_type_names == cell_type_numbers_age_vars$selected_cell_type]))
    })
    
    xy <- readRDS("input/ageing_cell_type_numbers/xy.rds")
    
    xy <- xy %>% mutate(mouse_id_label = str_replace_all(mouse_id_label, c("^YOUNG: " = "Young ", "^OLD: " = "Old ")))
    
    output$xy_plot <- renderPlot({
      req(xy)
      
      xy %>%
      mutate(
        interest = ifelse(
          cell_type_publish == cell_type_numbers_age_vars$selected_cell_type,
          cell_type_publish,
          "OTHER"
        ),
        size_interest = cell_type_publish == cell_type_numbers_age_vars$selected_cell_type
      ) %>%
        mutate(interest = factor(interest), 
               interest = relevel(interest, ref = cell_type_numbers_age_vars$selected_cell_type)) %>%
        # mutate(interest = ifelse(str_detect(interest, "OTHER"), "OTHER", names(cell_type_names[cell_type_names == cell_type_numbers_age_vars$selected_cell_type]))) %>%
        arrange(desc(interest)) %>%
        ggplot(aes(
          x = x,
          y = -y,
          colour = interest,
          size = size_interest,
          alpha = size_interest
        )) +
        geom_point() +
        scale_color_manual(values = c(pal_d3()(1), "grey")) +
        scale_size_manual(values = c(0.02, 1), guide = 'none') +
        scale_alpha_manual(values = c(0.4, 1), guide = 'none') +
        facet_wrap(vars(mouse_id_label),
                   nrow = 1,
                   scales = "free") +
        theme_minimal() +
        theme(
          rect = element_rect(fill = "transparent"),
          # panel.background = element_rect(fill = 'white', colour = 'white'),
          panel.grid = element_blank(),
          axis.text = element_blank(),
          axis.title = element_blank(),
          plot.title = element_text(hjust = 0.5, face = "bold", size = 18),
          strip.text = element_text(face = "bold", size = 14), 
          legend.position = "none"
        ) +
        labs(title = names(cell_type_names[cell_type_names == cell_type_numbers_age_vars$selected_cell_type]),
             color = "")
    })
    
    # download the data
    output$download_table = downloadHandler(
      filename = function() {
        paste0('Cell type numbers with age - MASC Results.csv')
      },
      content = function(file) {
        write_csv({
          cell_type_numbers_age_vars$masc %>%
            select(-cell_type, 
                   "Cell Type" = cell_type_full, 
                   "Estimate" = estimate, 
                   "FDR" = fdr)
        }, file)
      }
    )
    
    output$download_numbers = downloadHandler(
      filename = function() {
        paste0('Cell type numbers per brain.csv')
      },
      content = function(file) {
        write_csv({
          readRDS("input/ageing_cell_type_numbers/actual_numbers_with_ids.rds")
        }, file)
      }
    )

    # output$debug <- renderPrint(cell_type_numbers_age_vars$selected_cell_type)
    
  })
}
