home_UI <- function(id) {
  ns <- NS(id)
  tabPanel("Home",
           tags$head(
             tags$style(HTML("
      img {
      border: 1;
      max-width: 100%;
    }
    element.style {
      width: 75%;
    }"))
           ),
           br(),
           fluidRow(
             column(4,
                    offset = 1,
                    h1("Welcome to SpatialBrain"),
                    hr(),
                    h3("A platform to view integrated data from the Wade-Martins Laboratory of Molecular Neurodegeneration."),

                    br(),
                    h4(tags$i("Results and data from:")),
                    h4(tags$a(href="https://pubmed.ncbi.nlm.nih.gov/38386560/", tags$strong("Kilfeather P, Khoo JH, Wade-Martins R. Single-cell spatial transcriptomic and translatomic profiling of dopaminergic neurons in health, aging, and disease."), tags$i(" Cell Rep. 2024 Mar 26;43(3):113784. doi: 10.1016/j.celrep.2024.113784. Epub 2024 Feb 21. PMID: 38386560."))),
                    br(),
                    h5("Spatial Transcriptomic Analyses:"),
                    tags$ul(
                      tags$li(tags$strong("Cell Type Markers")),
                      tags$li(tags$strong("SN/VTA Markers in Dopaminergic Neurons")),
                      tags$li(tags$strong("Cell Number Changes in Age")),
                    ),
                    br(),
                    h5("TRAP Analyses:"),
                    tags$ul(
                      tags$li(tags$strong("Dopaminergic Markers")),
                      tags$li(tags$strong("Dopaminergic Ageing")),
                      tags$li(tags$strong("Alternative Splicing in Dopaminergic Neurons")),
                    ),
                    br(),
                    imageOutput(ns("opdc"))
             ),
             column(4,
                    offset = 1,
                    HTML('<center><img src="spatial_optim.png", height="50%"></center>'),
                    br(),
                    br()
             )
           )
  )
}

home_SERVER <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$opdc <- renderImage({
      path_to_jpg <- "input/images/opdc-logo_downsized.jpg"
      # Get width and height of image output
      width  <- session$clientData$output_image_width
      height <- session$clientData$output_image_height

      list(src = path_to_jpg,
           contentType = "image/jpeg",
           width = width,
           height = height,
           alt = "OPDC Logo")

    }, deleteFile = F)
  })
}
