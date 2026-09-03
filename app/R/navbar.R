# Programmatic navbar switching ------------------------------------------------
#
# switch_navbar_tab() selects a navbar tab from server code, including tabs
# inside navbarMenu() dropdowns. It is the supported path for cross-tab
# navigation (Gene Query jumps, ADR-0003). Under the app's Bootstrap 3 theme,
# shiny::updateNavbarPage() cannot select dropdown tabs (the tab-input binding
# only matches top-level anchors), so the switch is driven through a custom
# message handler registered in app.R's <head> (#main_nav).

switch_navbar_tab <- function(session, value) {
  session$sendCustomMessage("switch-navbar-tab", value)
}
