# GitLab

Connects Claude Code to [GitLab's official MCP server](https://docs.gitlab.com/user/model_context_protocol/mcp_server/), so Claude can read and work with your GitLab projects, issues, merge requests, pipelines, and code search. It works with GitLab.com, GitLab Self-Managed, and GitLab Dedicated, and signs in with OAuth, so no token is stored in any file.

```text
/plugin marketplace add jeffrey-serrell/expo-window
/plugin install gitlab@expo-window
```

## What it provides

| Component | Name | What it does |
| :- | :- | :- |
| MCP server | `plugin:gitlab:gitlab` | GitLab's remote MCP server over HTTP at `https://gitlab.com/api/v4/mcp`, or your instance's `/api/v4/mcp` |
| Skill | `/gitlab:setup` | Walks you through sign-in, self-managed setup, and the errors in [Troubleshooting](#troubleshooting). Claude can also load it on its own when GitLab tools fail |

By default the server offers GitLab's default toolsets: `core`, `merge_requests`, `work_items`, `repository`, and `ci`, plus `duo_agent_platform` when GitLab Duo Agent Platform is available to you, and the always-on `meta` tools. The [tools reference](https://docs.gitlab.com/user/model_context_protocol/mcp_server_tools/) lists every tool. In Claude Code, each tool is named `mcp__plugin_gitlab_gitlab__<tool>`, such as `mcp__plugin_gitlab_gitlab__get_project`. Use that name in permission rules.

## Requirements

- A GitLab account on GitLab.com, or on a GitLab Self-Managed or GitLab Dedicated instance. The MCP server is available on the Free, Premium, and Ultimate tiers.
- On Self-Managed and Dedicated, GitLab 19.5 or later, the release where the MCP server became generally available. Earlier releases differ:
  - 18.6 introduced the HTTP transport this plugin uses, as a beta.
  - 18.7 added the `2025-06-18` and `2025-11-25` MCP protocol versions. On 18.6 and earlier, a client can fail with `Server's protocol version is not supported`.
  - Before 19.2, the server required the Premium or Ultimate tier.
- MCP access allowed for you:
  - **GitLab.com**: access is on by default for every top-level group, unless a group Owner turned it off. You need at least one top-level group with access on.
  - **Self-Managed and Dedicated**: access is on by default for the instance, unless an administrator turned it off.
- A browser for the one-time sign-in. Without one on the machine running Claude Code, such as over SSH, use the `--no-browser` flow in [Sign in](#sign-in).

## Sign in

The plugin uses OAuth 2.0 with dynamic client registration. The first time you connect, Claude Code registers itself as an OAuth application on your GitLab instance, you approve access in the browser, and Claude Code stores the access token in its secure credential storage and refreshes it. The plugin requests only the `mcp` scope, the one scope GitLab's MCP endpoint accepts.

1. Install the plugin, then start Claude Code, or run `/reload-plugins` in a running session.
2. Run `/mcp` and select `plugin:gitlab:gitlab`. It shows as needing authentication until you sign in.
3. Choose to authenticate. Your browser opens GitLab's authorization page.
4. Review and approve the request. You're signed in as your own GitLab user, and Claude can see only what that user can see.
5. If the browser can't reach Claude Code after you approve, paste the full callback URL from the browser's address bar into the prompt in Claude Code.

To sign in from your shell instead, run `claude mcp login plugin:gitlab:gitlab`. On a machine with no browser, such as over SSH, add `--no-browser`: Claude Code prints the authorization URL, you open it on your own computer, and you paste the redirect URL back at the prompt. Connect with `ssh -t` so the prompt can read your paste.

To sign out, open `/mcp`, select the server, and choose **Clear authentication**. To revoke access on GitLab's side as well, select your avatar in GitLab, then **Edit profile > Access > Applications**, and revoke the application under **Authorized applications**.

### Use a self-managed or Dedicated instance

The server URL is `${GITLAB_MCP_BASE_URL:-https://gitlab.com}/api/v4/mcp`. To use your own instance, set `GITLAB_MCP_BASE_URL` to its base URL before you start Claude Code:

```bash
export GITLAB_MCP_BASE_URL="https://gitlab.example.com"
```

- Use the URL you open GitLab at, with no trailing slash and no `/api/v4`. If your instance is served under a path, include it, such as `https://example.com/gitlab`.
- Put the line in your shell profile so every session gets it, then restart Claude Code. Or set it once in the `env` block of your user settings file, `~/.claude/settings.json`:

  ```json
  {
    "env": {
      "GITLAB_MCP_BASE_URL": "https://gitlab.example.com"
    }
  }
  ```

- Don't set the variable to an empty string. An empty value counts as set, so the URL becomes `/api/v4/mcp` and the server fails. Unset it to go back to GitLab.com.
- If you switch instances after signing in, clear authentication in `/mcp` and sign in again.

### Instances without dynamic client registration

If an administrator turned off dynamic client registration, sign-in fails with `does not support dynamic client registration`. You then need an OAuth application created ahead of time:

1. In GitLab, create an OAuth application for your user, group, or instance. Select the **mcp** scope, clear **Confidential**, and set the redirect URI to `http://localhost:PORT/callback` with a free port, such as `http://localhost:8765/callback`.
2. Turn the plugin's server off in `/mcp`, so you don't have two GitLab servers.
3. Add GitLab as your own server with the application ID and the same port:

   ```bash
   claude mcp add --scope user --transport http \
     --client-id YOUR_APPLICATION_ID --callback-port 8765 \
     gitlab https://gitlab.example.com/api/v4/mcp
   ```

4. Run `/mcp`, select `gitlab`, and sign in.

### Personal access token instead of OAuth

The plugin signs in only with OAuth. For a run with no browser, such as `claude -p` in CI, GitLab also accepts a [fine-grained personal access token](https://docs.gitlab.com/auth/tokens/fine_grained_access_tokens/) with the **MCP tool** resource and the **Execute** permission. Legacy personal access tokens and project or group access tokens are rejected with `403 insufficient_scope`, even with the `api` scope. GitLab's docs don't say whether a fine-grained token also needs permissions for the resources each tool reads; if a tool fails with a permissions error, add the matching resource permission to the token.

To use a token, add a separate server rather than editing the plugin, and keep the token in an environment variable:

```bash
claude mcp add-json --scope user gitlab-token \
  '{"type":"http","url":"https://gitlab.com/api/v4/mcp","headers":{"Authorization":"Bearer ${GITLAB_MCP_TOKEN}"}}'
```

Single quotes keep your shell from expanding `${GITLAB_MCP_TOKEN}`, so the configuration stores the variable's name, not the token. Export `GITLAB_MCP_TOKEN` before you start Claude Code, and turn the plugin's server off in `/mcp`.

## Verify it works

1. Run `/mcp`. `plugin:gitlab:gitlab` shows as connected.
2. Ask Claude something such as "List my GitLab projects" or "Show the open merge requests assigned to me".
3. In your shell, `claude plugin details gitlab` lists `MCP servers (1) gitlab` in the component inventory.

## Troubleshooting

Run `/gitlab:setup` for a guided check, or match the symptom here.

| Symptom | Cause | Fix |
| :- | :- | :- |
| `403 Forbidden` after sign-in with `MCP server not enabled for any of your groups`. GitLab 19.4 and earlier return `404 Not Found` | On GitLab.com, no top-level group you belong to allows MCP access | A group Owner goes to the top-level group's **Settings > General > Permissions and group features** and selects **Allow connection to GitLab** under **MCP client access** |
| `403 Forbidden` with `MCP server disabled for this instance` | An administrator turned MCP access off for the instance | An administrator goes to **Admin > Settings > General > Visibility and access controls** and selects **Allow connection to GitLab** under **MCP client access** |
| `403 Forbidden` with `insufficient_scope` | The token can't hold the `mcp` scope | Sign in with OAuth, or use a fine-grained token as described above |
| `claude mcp list` shows the URL as `/api/v4/mcp` and reports `Plugin gitlab has an invalid MCP url` | `GITLAB_MCP_BASE_URL` is set to an empty string | Unset it, or set it to your instance URL |
| `429 Too Many Requests` | An MCP or API rate limit. GitLab.com documents per-plan MCP limits, such as 60 requests a minute on Free | Wait for the seconds in `Retry-After`, then retry |
| `Server's protocol version is not supported` | GitLab 18.6 or earlier | Upgrade GitLab to 19.5 or later |
| A tool you expect is missing | Its toolset is opt-in (`wikis`, `code_security`, `orbit`) or needs a feature you don't have | See the [toolsets list](https://docs.gitlab.com/user/model_context_protocol/mcp_server/#select-tool-groups-toolsets) |

The plugin uses GitLab's default toolsets. To choose your own, add GitLab as your own server with the `X-Gitlab-Enabled-Mcp-Server-Toolsets` header, as GitLab's [Claude Code instructions](https://docs.gitlab.com/user/model_context_protocol/mcp_server/#select-tool-groups-toolsets) show, and turn the plugin's server off in `/mcp`.

For more, see [Troubleshooting the GitLab MCP server](https://docs.gitlab.com/user/model_context_protocol/mcp_server_troubleshooting/) and Claude Code's [MCP authentication docs](https://code.claude.com/docs/en/mcp#authenticate-with-remote-mcp-servers).

## Security

- GitLab content such as issues, comments, and files can carry prompt injection. GitLab advises caution, or using the tools only on GitLab objects you trust.
- Some tools change GitLab, such as `accept_merge_request`, `add_commit`, and the `save_*` tools. In the default permission mode, Claude Code asks before it first uses each tool. To skip the prompt for read-only tools and keep it for the rest, allow only those, for example `mcp__plugin_gitlab_gitlab__get_*` and `mcp__plugin_gitlab_gitlab__list_*`, under `permissions.allow` in your settings.
- No token or secret is stored in this plugin. OAuth tokens live in Claude Code's credential storage.

## Privacy

Claude Code sends MCP requests straight to your GitLab instance, and tool results become part of your conversation with Claude. This plugin collects nothing itself. GitLab.com handles your data under the [GitLab privacy statement](https://about.gitlab.com/privacy/). On a self-managed instance, your organization's policy applies.

## Sources

- [GitLab MCP server](https://docs.gitlab.com/user/model_context_protocol/mcp_server/)
- [GitLab MCP server tools](https://docs.gitlab.com/user/model_context_protocol/mcp_server_tools/)
- [Troubleshooting the GitLab MCP server](https://docs.gitlab.com/user/model_context_protocol/mcp_server_troubleshooting/)
- [Allow access to the MCP server for a group](https://docs.gitlab.com/user/group/access_and_permissions/#allow-access-to-the-mcp-server) and [for an instance](https://docs.gitlab.com/administration/settings/visibility_and_access_controls/#allow-access-to-the-mcp-server)
- [GitLab REST API authentication](https://docs.gitlab.com/api/rest/authentication/), for the `mcp` scope challenge and bearer tokens
- [GitLab fine-grained personal access tokens](https://docs.gitlab.com/auth/tokens/fine_grained_access_tokens/) and [the MCP tool permission](https://docs.gitlab.com/auth/tokens/fine_grained_access_tokens_rest/#mcp-tool)
- [GitLab OAuth provider](https://docs.gitlab.com/integration/oauth_provider/), for OAuth applications and authorized applications
- [Claude Code: connect to tools via MCP](https://code.claude.com/docs/en/mcp)
- [Claude Code: permissions](https://code.claude.com/docs/en/permissions)
