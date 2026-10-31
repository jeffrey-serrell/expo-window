# Changelog

All notable changes to this repository are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The marketplace version is `metadata.version` in [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json). Each plugin's version is the `version` in its own `plugin.json`.

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
