# Changelog

All notable changes to this repository are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The marketplace version is `metadata.version` in [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json). Each plugin's version is the `version` in its own `plugin.json`.

## [1.1.1] - 2026-10-30

### Fixed

- Removed the unsupported `privacyPolicyUrl` key from all seven plugin manifests. The Claude app reported it as an unrecognized key in `plugin.json` and stripped it. Each plugin's README already links the vendor's privacy page in its Privacy section, so the link now lives only there.
- Bumped every plugin to 0.1.1 so installed copies pick up the corrected manifests: `gcp-bigquery`, `gcp-cloud-run`, `gcp-gke`, `gitlab`, `google-developer-knowledge`, `sonarqube`, and `terraform`.

## [1.1.0] - 2026-10-30

### Added

- `gcp-bigquery` plugin 0.1.0, which bundles Google's BigQuery remote MCP server over HTTP. It sends a gcloud access token from `GCP_ACCESS_TOKEN` and a quota project from `GCP_PROJECT_ID`, and acts with the user's own IAM permissions.
- `gcp-cloud-run` plugin 0.1.0, which bundles Google's Cloud Run remote MCP server over HTTP with the same token and project headers. `GCP_CLOUD_RUN_MCP_URL` can point it at a regional endpoint.
- `gcp-gke` plugin 0.1.0, which bundles Google's GKE remote MCP server over HTTP with the same token and project headers. `GCP_GKE_MCP_URL` can point it at the read-only toolset.
- `google-developer-knowledge` plugin 0.1.0, which bundles Google's Developer Knowledge MCP server over HTTP with an API key from `DEVELOPERKNOWLEDGE_API_KEY`.
- `sonarqube` plugin 0.1.0, which bundles the SonarQube Cloud-hosted MCP server over HTTP, read-only, with a user token from `SONARQUBE_TOKEN`. `SONARQUBE_MCP_URL` points it at the US region or at SonarQube Server.
- `terraform` plugin 0.1.0, which bundles HashiCorp's remote Terraform MCP server (beta) over HTTP with an HCP Terraform API token from `TFE_TOKEN`.
- Each new plugin includes a `/<plugin>:setup` skill and a README with setup, troubleshooting, and security notes.
- The six plugins in the README's install and authentication tables.

### Changed

- The marketplace lists its plugins in alphabetical order.

## [1.0.0] - 2026-10-30

### Added

- `gitlab` plugin 0.1.0, which bundles GitLab's official remote MCP server over HTTP with OAuth sign-in. `GITLAB_MCP_BASE_URL` points it at a self-managed or Dedicated instance. It includes the `/gitlab:setup` skill and a README with setup and troubleshooting steps.
- Marketplace metadata: a description, a version, and the owner's URL.
- An install table, update, uninstall, authentication, and contributing sections in the README.
- `scripts/validate.sh`, which validates the marketplace and every plugin.
- This changelog.

### Removed

- The `prep-list` placeholder plugin and its `hello` skill. The marketplace's `renames` map records the removal, so Claude Code drops `prep-list` from the settings of anyone who installed it.

## [0.1.0] - 2026-10-30

### Added

- The marketplace, `expo-window`, with one placeholder plugin, `prep-list` 0.1.0, and its `hello` skill, in commit `970dd678`.
