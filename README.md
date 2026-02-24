# seaPiper Pipeline Browser Container

This repository builds and documents the container image used to serve a
seaPiper-based pipeline browser in KIOSC.

Current image:

- Repository: `ghcr.io/bihealth/seapiper`
- Version/tag: `0.6.0`
- Exposed container port: `8080`

## Repository layout

- `build/`: Docker build context (`Dockerfile`, app entrypoint, helper scripts)
- `build.sh`: local helper for image build
- `docker_run.sh`: local helper for `docker run` with environment variables
- `env.example`: template for local runtime configuration

## Build image locally

Use defaults (`ghcr.io/bihealth/seapiper:0.6.0`):

```bash
bash build.sh
```

Override image or tag:

```bash
IMAGE=ghcr.io/bihealth/seapiper TAG=0.6.0 bash build.sh
```

`build.sh` also accepts pinned dependency refs:

- `TMOD_REF`
- `RSEASNAP_REF`
- `BIOSHMODS_REF`
- `SEAPIPER_REF`
- `GGHALVES_REF`

These are passed as Docker build args and default to pinned commit SHAs.

## Run image locally

1. Copy `env.example` to `.env` and fill in your values.
2. Run:

```bash
bash docker_run.sh
```

The app will be available on `http://localhost:8080`.

## Runtime environment variables

Required:

- `IRODS_PATH`: landing-zone path on SODAR/irods
- `DAVRODS_SERVER`: anonymous davrods host
- `IRODS_TOKEN`: read ticket/token
- `datasets`: JSON array describing one or more datasets

Optional:

- `TITLE`: app title (default: `SeaPiper`)
- `IMAGE`: docker image to run (default: `ghcr.io/bihealth/seapiper:0.6.0`)
- `HOST_PORT`: local published port (default: `8080`)

`datasets` format example:

```json
[
  {
    "name": "Example data set",
    "archive": "DE_pipeline.tar.gz",
    "config": "DE_config.yaml"
  }
]
```

## KIOSC deployment checklist

1. Push the image tag to GHCR (example: `0.6.0`).
2. In KIOSC, create/update the container:
   - Repository: `ghcr.io/bihealth/seapiper`
   - Tag: `0.6.0`
   - Container port: `8080`
3. Set environment values:
   - `datasets` (JSON array, same structure as `datasets` above)
   - `IRODS_PATH`
   - `DAVRODS_SERVER`
   - `TITLE` (optional)
4. Store `IRODS_TOKEN` as an environment secret key.

## Legacy notes

Older exploratory notes are in
`creating_shiny_apps_with_kiosc.md`. They are kept for historical context but
are not the authoritative operational guide for the current container.
