# Dockerfile
FROM rocker/shiny:4.4.1

# Optional: system libs often needed by tidyverse/plotly/etc.
# (rocker/shiny already includes many; add only what you need)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libv8-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CRAN/BioC packages
# install2.r is provided by rocker images
RUN install2.r --error --skipinstalled \
    shiny waiter shinycssloaders shinythemes tidyverse DT ggsci cowplot \
    shinyWidgets ggrepel plotly BiocManager zip

# Ensure BioC repos are available (if you later add BioC pkgs)
RUN R -q -e "options(repos = BiocManager::repositories()); invisible(TRUE)"

# Copy the app into the image
# Expect your app.R at ./app/app.R
COPY --chown=shiny:shiny app /srv/shiny-server/app
COPY --chown=shiny:shiny shiny-server.conf /etc/shiny-server/shiny-server.conf

# Helpful at runtime
ENV SHINY_LOG_STDERR=1
EXPOSE 3838

# shiny-server already runs as non-root 'shiny' user and serves /srv/shiny-server/*
# No CMD needed—the base image’s shiny-server entrypoint is used.
