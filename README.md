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
| [`gitlab`](plugins/gitlab/README.md) | Connects Claude Code to GitLab's official MCP server for projects, issues, merge requests, pipelines, and code search on GitLab.com or self-managed GitLab | `/plugin install gitlab@expo-window` |

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
| `gitlab` | OAuth in the browser, started from `/mcp`. No token is stored in this repository | [Sign in](plugins/gitlab/README.md#sign-in), and [self-managed GitLab](plugins/gitlab/README.md#use-a-self-managed-or-dedicated-instance) |

## Contributing

Each plugin goes in `plugins/<name>/` with a `.claude-plugin/plugin.json`, a README, and an entry in [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) whose `name` matches the plugin's. Record changes in [CHANGELOG.md](CHANGELOG.md), and bump the plugin's `version` in `plugin.json` when you release a change, because users stay on their cached copy until it changes.

Before you commit, run the checks. They need the `claude` CLI on your `PATH`, and use `jq` if it's installed:

```bash
./scripts/validate.sh
```

The script runs `claude plugin validate` on the marketplace and on every plugin with `--strict`, checks the JSON, and confirms every entry name matches its `plugin.json`. It exits non-zero on any failure.
