export_plot <- function(file, plot, fmt) {
  if (fmt == "png") {
    ggsave(file, plot, width = 800, height = 800 / 1.5, units = "px", dpi = 300, bg = "white")
  } else {
    w <- 800 / 72
    h <- (800 / 1.5) / 72
    if (fmt == "svg") {
      grDevices::svg(file, width = w, height = h, bg = "white")
    } else {
      grDevices::cairo_pdf(file, width = w, height = h, bg = "white")
    }
    print(plot)
    grDevices::dev.off()
  }
}
