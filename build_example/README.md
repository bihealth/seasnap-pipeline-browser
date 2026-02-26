# build_example: Minimal SODAR Shiny Blueprint

This directory is a minimal template for SODAR-backed Shiny containers.

Included behavior:
- starts a temporary HTTP server on port `8080` during startup so users can see progress logs,
- downloads one archive from SODAR (davrods) using env vars,
- unpacks the archive,
- launches a basic Shiny app that shows proof of download/extraction.

What is intentionally not included:
- Bioconductor packages,
- seaPiper/Rseasnap/bioshmods,
- custom analysis logic.

## Build

```bash
bash build_example/build.sh
```

Defaults:
- image: `ghcr.io/bihealth/seapiper-example`
- tag: `0.1.0`

Override:

```bash
IMAGE=ghcr.io/bihealth/seapiper-example TAG=0.1.0 bash build_example/build.sh
```

## Run

1. Copy settings:

```bash
cp build_example/settings.example build_example/settings
```

2. Fill in `IRODS_PATH`, `DAVRODS_SERVER`, `IRODS_TOKEN`, `IRODS_FILE`.

3. Run:

```bash
bash build_example/run.sh
```

The app is available at `http://localhost:8080`.

## Runtime variables

Required:
- `IRODS_PATH`
- `DAVRODS_SERVER`
- `IRODS_TOKEN`
- `IRODS_FILE`

Optional:
- `TITLE` (default: `SODAR Shiny Blueprint`)
- `IMAGE` (default: `ghcr.io/bihealth/seapiper-example`)
- `TAG` (default: `0.1.0`)
- `HOST_PORT` (default: `8080`)

## Blueprint extension points

To adapt this template for another app:
1. Keep `prepare_manifest()` in `run_app.R` for download/unpack.
2. Replace `build_app()` with your real UI/server logic.
3. Add additional R packages in the Dockerfile only when needed.
