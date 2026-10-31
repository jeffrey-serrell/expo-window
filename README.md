# expo-window

Personal tools and notes, kept in one place.

Each tool has its own folder and a README with setup steps.

## Usage

These tools are Claude Code plugins, and this repository is their marketplace. Add the marketplace once:

```text
/plugin marketplace add jeffrey-serrell/expo-window
```

Then install what you need:

| Plugin | What it does | Install |
| :- | :- | :- |
| [`gcp-bigquery`](plugins/gcp-bigquery/README.md) | Connects Claude Code to Google's BigQuery MCP server to list datasets and tables and run SQL queries, with your own IAM permissions | `/plugin install gcp-bigquery@expo-window` |
| [`gcp-cloud-run`](plugins/gcp-cloud-run/README.md) | Connects Claude Code to Google's Cloud Run MCP server to list, inspect, and deploy Cloud Run services, with your own IAM permissions | `/plugin install gcp-cloud-run@expo-window` |
| [`gcp-gke`](plugins/gcp-gke/README.md) | Connects Claude Code to Google's GKE MCP server to inspect and change clusters, node pools, and Kubernetes resources, with your own IAM permissions | `/plugin install gcp-gke@expo-window` |
| [`gitlab`](plugins/gitlab/README.md) | Connects Claude Code to GitLab's official MCP server for projects, issues, merge requests, pipelines, and code search on GitLab.com or self-managed GitLab | `/plugin install gitlab@expo-window` |
| [`google-developer-knowledge`](plugins/google-developer-knowledge/README.md) | Connects Claude Code to Google's Developer Knowledge MCP server to search and read official Google developer documentation | `/plugin install google-developer-knowledge@expo-window` |
| [`sonarqube`](plugins/sonarqube/README.md) | Connects Claude Code to the SonarQube Cloud-hosted MCP server, read-only, for issues, quality gates, coverage, and security hotspots | `/plugin install sonarqube@expo-window` |
| [`terraform`](plugins/terraform/README.md) | Connects Claude Code to HashiCorp's remote Terraform MCP server (beta) for the Terraform Registry and HCP Terraform workspaces, runs, and variables | `/plugin install terraform@expo-window` |

From a shell instead of a session, use `claude plugin marketplace add jeffrey-serrell/expo-window` and `claude plugin install gitlab@expo-window`. A plugin installed during a session loads after `/reload-plugins` or in your next session.

### Update

Background auto-update is off for this marketplace unless you turn it on. To get new versions:

- In a session, run `/plugin marketplace update expo-window`.
- In your shell, run `claude plugin marketplace update expo-window`, then `claude plugin update gitlab@expo-window`.
- Or turn on auto-update once: run `/plugin`, open **Marketplaces**, select `expo-window`, and select **Enable auto-update**.

### Uninstall

- Remove one plugin: `/plugin uninstall gitlab@expo-window`, or `claude plugin uninstall gitlab@expo-window` in your shell.
- Remove the marketplace and every plugin installed from it: `/plugin marketplace remove expo-window`.

## Authentication

| Plugin | Sign-in | Setup steps |
| :- | :- | :- |
| `gcp-bigquery` | A gcloud access token in `GCP_ACCESS_TOKEN` and a project ID in `GCP_PROJECT_ID`. The token expires after an hour | [Set up authentication](plugins/gcp-bigquery/README.md#set-up-authentication) |
| `gcp-cloud-run` | A gcloud access token in `GCP_ACCESS_TOKEN` and a project ID in `GCP_PROJECT_ID`. The token expires after an hour | [Set up authentication](plugins/gcp-cloud-run/README.md#set-up-authentication) |
| `gcp-gke` | A gcloud access token in `GCP_ACCESS_TOKEN` and a project ID in `GCP_PROJECT_ID`. The token expires after an hour | [Set up authentication](plugins/gcp-gke/README.md#set-up-authentication) |
| `gitlab` | OAuth in the browser, started from `/mcp`. No token is stored in this repository | [Sign in](plugins/gitlab/README.md#sign-in), and [self-managed GitLab](plugins/gitlab/README.md#use-a-self-managed-or-dedicated-instance) |
| `google-developer-knowledge` | A Google Cloud API key in `DEVELOPERKNOWLEDGE_API_KEY` | [Set up authentication](plugins/google-developer-knowledge/README.md#set-up-authentication) |
| `sonarqube` | A SonarQube user token in `SONARQUBE_TOKEN`, and `SONARQUBE_MCP_URL` for the US region or SonarQube Server | [Set up authentication](plugins/sonarqube/README.md#set-up-authentication) |
| `terraform` | An HCP Terraform user or team API token in `TFE_TOKEN` | [Set up authentication](plugins/terraform/README.md#set-up-authentication) |

Plugins that use a token or key read it from an environment variable when Claude Code starts, through a `${VAR}` reference in their `.mcp.json`. Export the variable in the shell you start Claude Code from. No token or key is stored in this repository.

## Contributing

Each plugin goes in `plugins/<name>/` with a `.claude-plugin/plugin.json`, a README, and an entry in [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) whose `name` matches the plugin's. Record changes in [CHANGELOG.md](CHANGELOG.md), and bump the plugin's `version` in `plugin.json` when you release a change, because users stay on their cached copy until it changes.

Before you commit, run the checks. They need the `claude` CLI and `jq` on your `PATH`:

```bash
./scripts/validate.sh
```

The script runs `claude plugin validate` on the marketplace and on every plugin with `--strict`, checks the JSON, and confirms every entry name matches its `plugin.json`. It also fails on any key that Claude Code doesn't recognize in `marketplace.json` or a `plugin.json`, including the directory listing fields such as `privacyPolicyUrl` that `claude plugin validate` lets through. Link a plugin's privacy policy from the Privacy section of its README instead. It exits non-zero on any failure.
