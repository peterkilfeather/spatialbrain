# Docker image is the dependency source of truth; renv removed

The deployment is a single Docker image built from this repo (`Dockerfile`, `install2.r`). The `renv` lockfile was stale (R 4.1.2 vs container 4.4.1) and missing packages the app actually loads, so it was a false source of truth; renv artifacts were removed. If local development needs reproducibility later, reintroduce renv deliberately and make the Docker build consume it — one record, not two.
