## Build: docker build --build-arg VERSION=0.6.0 -t ghcr.io/bihealth/seapiper:0.6.0 build
## Pinned Bioconductor image digest for reproducibility.
FROM bioconductor/bioconductor_docker@sha256:d274974ec781ce48642f8cb804b0da66b475f221d3587d7cd4d29542fbb29404

ARG VERSION=0.6.0

## install system dependencies
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       libxml2-dev \
       wget \
       python3 \
       libcurl4-openssl-dev \
       libssl-dev \
    && rm -rf /var/lib/apt/lists/*

## install R dependencies
RUN R -q -e "install.packages(c('markdown', 'shinyjs', 'curl', 'colorDF', 'lubridate', 'plotly', 'DT', 'cowplot', 'bslib', 'thematic', \
                            'ggrepel', 'shinydashboard', 'shinyBS', 'shinycssloaders', 'RJSONIO', 'waiter', 'remotes'))"
RUN R -q -e "BiocManager::install('DESeq2', ask = FALSE, update = FALSE)"

EXPOSE 8080

## change ARG VERSION on command line to enforce reinstalling seapiper deps
## tmod currently tracks master upstream.
ARG TMOD_REF=d583238f3559482b02cf34b9304a19b090006aca
ARG RSEASNAP_REF=66f4f705dbee586a5de197322a401652c43d0598
ARG BIOSHMODS_REF=59566df2f0604ec9bbe1eeb5d63803468f408ffc
ARG SEAPIPER_REF=v0.1.2
ARG GGHALVES_REF=e5c3c79e79f13a00795a2a7774794252d1980d86
ARG VCTRS_VERSION=0.6.5
RUN R -q -e "message('Installing pinned app deps for VERSION=${VERSION}'); \
             remotes::install_github('erocoar/gghalves@${GGHALVES_REF}', upgrade='never'); \
             remotes::install_github('january3/tmod@${TMOD_REF}', upgrade='never'); \
             remotes::install_github('bihealth/Rseasnap@${RSEASNAP_REF}', upgrade='never'); \
             remotes::install_github('bihealth/bioshmods@${BIOSHMODS_REF}', upgrade='never'); \
             remotes::install_github('bihealth/seaPiper@${SEAPIPER_REF}', upgrade='never'); \
             remotes::install_version('vctrs', version='${VCTRS_VERSION}', upgrade='never', repos='https://packagemanager.rstudio.com/all/__linux__/focal/latest'); \
             .pkgs <- c('tmod', 'Rseasnap', 'bioshmods', 'seaPiper'); \
             .ok <- vapply(.pkgs, function(.p) requireNamespace(.p, quietly = TRUE), logical(1)); \
             if (!all(.ok)) stop(sprintf('Missing required package(s): %s', paste(.pkgs[!.ok], collapse = ', ')))"

RUN useradd --create-home --uid 10001 appuser \
    && mkdir -p /usr/local/src/app \
    && chown -R appuser:appuser /usr/local/src/app

# copy the current folder into the path of the app
COPY --chown=appuser:appuser . /usr/local/src/app

# set working directory to the app
WORKDIR /usr/local/src/app

USER appuser

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD wget -qO /dev/null http://127.0.0.1:8080/ || exit 1

#set the unix commands to run the app
CMD ["/usr/local/bin/Rscript", "app.R" ]
