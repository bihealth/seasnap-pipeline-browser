## Build: docker build --build-arg VERSION=0.6.6 -t ghcr.io/bihealth/seapiper:0.6.6 build
## Base image pinned by digest for reproducibility.
FROM bioconductor/bioconductor_docker@sha256:d274974ec781ce48642f8cb804b0da66b475f221d3587d7cd4d29542fbb29404

# Layer: install OS-level system dependencies needed by R packages and healthcheck.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       libxml2-dev \
       wget \
       libcurl4-openssl-dev \
       libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Build arg controlling heavy Bioconductor package installs.
# Keep this independent from app refs so the next RUN can stay cached.
# ARG is metadata only and does not create a filesystem layer.
ARG BIOC_PKGS=DESeq2,ComplexHeatmap

# Layer: install heavy Bioconductor dependencies (for example DESeq2).
# This layer should remain reusable when later CRAN or GitHub package refs change.
RUN R -q -e "pkgs <- strsplit('${BIOC_PKGS}', ',', fixed = TRUE)[[1]]; \
             pkgs <- trimws(pkgs[nzchar(pkgs)]); \
             if (length(pkgs) > 0) { \
               for (.attempt in seq_len(5)) { \
                 BiocManager::install(pkgs, ask = FALSE, update = FALSE); \
                 .ok <- vapply(pkgs, function(.p) requireNamespace(.p, quietly = TRUE), logical(1)); \
                 if (all(.ok)) break; \
                 message(sprintf('Bioconductor install attempt %d incomplete: %s', .attempt, paste(pkgs[!.ok], collapse = ', '))); \
                 if (.attempt == 5) stop(sprintf('Failed to install Bioconductor package(s): %s', paste(pkgs[!.ok], collapse = ', '))); \
                 Sys.sleep(5); \
               } \
             }"

# Layer: install CRAN dependencies used by the app.
# gghalves is installed from CRAN archive for compatibility with this R base.
RUN R -q -e "install.packages(c('markdown', 'shinyjs', 'curl', 'colorDF', 'lubridate', 'plotly', 'DT', 'cowplot', 'bslib', 'thematic', \
                            'shinydashboard', 'shinyBS', 'shinycssloaders', 'RJSONIO', 'waiter', 'remotes')); \
             remotes::install_version('ggrepel', version='0.9.6', upgrade='never', repos='https://cran.r-project.org'); \
             remotes::install_version('vctrs', version='0.6.5', upgrade='never', repos='https://cran.r-project.org'); \
             remotes::install_version('gghalves', version='0.1.4', upgrade='never', repos='https://cran.r-project.org'); \
             .pkgs <- c('gghalves', 'vctrs', \
             'markdown', 'shinyjs', 'curl', 'colorDF', 'lubridate', 'plotly', 'DT', 'cowplot', 'bslib', 'thematic', \
                            'ggrepel', 'shinydashboard', 'shinyBS', 'shinycssloaders', 'RJSONIO', 'waiter', 'remotes') ; \
             .ok <- vapply(.pkgs, function(.p) requireNamespace(.p, quietly = TRUE), logical(1)); \
             if (!all(.ok)) stop(sprintf('Missing required CRAN package(s): %s', paste(.pkgs[!.ok], collapse = ', ')))"

# Image metadata: exposed app port. No filesystem layer.
EXPOSE 8080

# Build arg used to force reinstall of pinned app dependencies when VERSION changes.
# Declared here so VERSION updates do not invalidate heavy OS/Bioconductor/CRAN layers.
# ARG is metadata only and does not create a filesystem layer.
ARG VERSION=0.6.6

# Build args for pinned app dependency refs (commit SHAs/tags).
# ARG is metadata only and does not create a filesystem layer.
# Change VERSION to force this app-dependency RUN to rebuild.
# tmod currently tracks master upstream.
ARG TMOD_REF=d583238f3559482b02cf34b9304a19b090006aca
ARG RSEASNAP_REF=66f4f705dbee586a5de197322a401652c43d0598
ARG BIOSHMODS_REF=da2d4b00bbe99e1196b532c71d9abb03398e1df2
ARG SEAPIPER_REF=52e1c9c825af257233053f00f67fb8bfb7ff9c11

# Layer: install pinned GitHub/app dependencies and verify required packages exist.
RUN R -q -e "message('Installing pinned app deps for VERSION=${VERSION}'); \
             remotes::install_github('january3/tmod@${TMOD_REF}', upgrade='never'); \
             remotes::install_github('bihealth/Rseasnap@${RSEASNAP_REF}', upgrade='never'); \
             remotes::install_github('bihealth/bioshmods@${BIOSHMODS_REF}', upgrade='never'); \
             remotes::install_github('bihealth/seaPiper@${SEAPIPER_REF}', upgrade='never'); \
             .pkgs <- c('tmod', 'Rseasnap', 'bioshmods', 'seaPiper'); \
             .ok <- vapply(.pkgs, function(.p) requireNamespace(.p, quietly = TRUE), logical(1)); \
             if (!all(.ok)) stop(sprintf('Missing required package(s): %s', paste(.pkgs[!.ok], collapse = ', ')))"

# Layer: create non-root runtime user and writable app directory.
RUN useradd --create-home --uid 10001 appuser \
    && mkdir -p /usr/local/src/app \
    && chown -R appuser:appuser /usr/local/src/app

# Layer: copy source code into the image.
# Keeping COPY late prevents source changes from invalidating heavy dependency layers above.
COPY --chown=appuser:appuser . /usr/local/src/app

# Image metadata/runtime defaults below.
# WORKDIR/USER/HEALTHCHECK/CMD configure runtime behavior.
WORKDIR /usr/local/src/app

USER appuser

# Build arg for image name used in runtime startup logging.
# ARG is metadata only and does not create a filesystem layer.
ARG IMAGE_NAME=ghcr.io/bihealth/seapiper

# Runtime image metadata exposed to app logs.
# ENV sets image metadata (no filesystem content is added).
ENV SEAPIPER_IMAGE_NAME=${IMAGE_NAME}
ENV SEAPIPER_IMAGE_VERSION=${VERSION}

# Runtime liveness probe: container is healthy only if the app responds on port 8080.
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD wget -qO /dev/null http://127.0.0.1:8080/ || exit 1

# Default container command.
CMD ["/usr/local/bin/Rscript", "app.R" ]
