## Minimal blueprint image for SODAR-backed Shiny apps.
FROM rocker/r-ver:4.4.1

# Layer: install minimal OS tools used at runtime.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       wget \
       ca-certificates \
       tar \
       zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Layer: install only shiny and its direct runtime dependencies.
# Validate installation explicitly so the build fails if shiny is missing.
RUN R -q -e "install.packages('shiny', repos='https://cloud.r-project.org'); \
             if (!requireNamespace('shiny', quietly = TRUE)) stop('Failed to install shiny')"

EXPOSE 8080

# Keep all startup logic in the build context for easy copying into other apps.
COPY . /usr/local/src/app
WORKDIR /usr/local/src/app

RUN chmod +x weblog.sh

CMD ["/usr/local/bin/Rscript", "run_app.R"]
