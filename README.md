# CICD Actions

## Installation

### awscli

### kubectl


## NOTES

### SSL Support with Traefik

To later support Traefik SSL, in `basic_app.yml` for the Ingress add `websecure` instead of `web` for the endpoints annotation. The `websecure` port is already configured to use letsencrypt by traefik. It is defined by the `values.yaml` file on the `runner.phamily-dev.com` instance in the `helm/traefik` directory. This has the configuration for the `letsencrypt` certificate resolver and the `websecure` port.

### Environment ConfigMaps

Use config maps for private deployment variables

