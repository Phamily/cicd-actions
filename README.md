# CICD Actions

This serves as a repository of scripts for CICD actions specifically for Phamily Rails. Eventually the core should be moved out into a library to be used by this repo. For example, this repo should always define `start_dependencies` and other scripts here so that they don't have to be defined in the code repo.

## Installation

### awscli

### kubectl


## NOTES

### SSL Support with Traefik

To later support Traefik SSL, in `basic_app.yml` for the Ingress add `websecure` instead of `web` for the endpoints annotation. The `websecure` port is already configured to use letsencrypt by traefik. It is defined by the `values.yaml` file on the `runner.phamily-dev.com` instance in the `helm/traefik` directory. This has the configuration for the `letsencrypt` certificate resolver and the `websecure` port.

### Environment ConfigMaps

Use config maps for private deployment variables

