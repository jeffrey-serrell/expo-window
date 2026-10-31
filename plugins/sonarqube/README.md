# SonarQube

Connects Claude Code to the [SonarQube Cloud-hosted MCP server](https://docs.sonarsource.com/sonarqube-mcp-server/setup/sonarqube-cloud-hosted), so Claude can read your SonarQube projects' issues, quality gates, coverage, duplications, security hotspots, dependency risks, and measures while it works. Sonar hosts the server inside SonarQube Cloud, so there's nothing to install. The plugin connects read-only and authenticates with a SonarQube user token that you keep in an environment variable, so no token is stored in any file. It can also point at the MCP endpoint of a SonarQube Server instance.

```text
/plugin marketplace add jeffrey-serrell/expo-window
/plugin install sonarqube@expo-window
```

## What it provides

| Component | Name | What it does |
| :- | :- | :- |
| MCP server | `plugin:sonarqube:sonarqube` | The SonarQube MCP server over HTTP at `${SONARQUBE_MCP_URL:-https://api.sonarcloud.io/mcp}`. It sends `Authorization: Bearer ${SONARQUBE_TOKEN}` and `SONARQUBE_READ_ONLY: true` |
| Skill | `/sonarqube:setup` | Walks you through the token, the region or instance URL, and the errors in [Troubleshooting](#troubleshooting). Claude can also load it on its own when SonarQube tools fail |

The Cloud-hosted server offers a smaller, fixed set of tools than a self-hosted SonarQube MCP server, from the `analysis`, `coverage`, `dependency-risks`, `duplications`, `quality-gates`, `issues`, `measures`, `projects`, `rules`, and `security-hotspots` toolsets. Sonar Vortex analysis and the SonarQube for IDE bridge tools aren't available there, because they need your local file system. The [tools reference](https://docs.sonarsource.com/sonarqube-mcp-server/reference/tools) describes each tool. In Claude Code, each tool is named `mcp__plugin_sonarqube_sonarqube__<tool>`, such as `mcp__plugin_sonarqube_sonarqube__search_sonar_issues_in_projects`. Use that name in permission rules.

### Read-only mode

The plugin sends the `SONARQUBE_READ_ONLY: true` header, which turns off write operations such as `change_sonar_issue_status` and `change_security_hotspot_status`. Sonar's docs say the Cloud-hosted server is read-only by default, and that on a server you host, a client's header can restrict requests to read-only but can't lift a server-level restriction. Sending the header keeps the plugin read-only on either kind of endpoint.

To allow writes, add your own server with the header set to `false`, as shown in [Choose different settings](#choose-different-settings).

## Requirements

- One of the following:
  - A **SonarQube Cloud** organization in the EU region, the default, or the US region.
  - A **SonarQube Server** 2026.3 or later instance, Developer, Enterprise, or Data Center edition, where an administrator installed the SonarQube MCP Server extension. The instance then serves MCP at `<your SonarQube URL>/mcp`.
- A SonarQube **user token**. Sonar warns that project tokens, global tokens, and scoped organization tokens don't work with the MCP server.
- Network access from the machine that runs Claude Code to `https://api.sonarcloud.io`, `https://api.sonarqube.us`, or your instance.

Without the Server extension, or on Community Build, Sonar documents a self-hosted SonarQube MCP server, such as its Docker image over stdio, or an automated setup with the SonarQube CLI. This plugin uses only the hosted HTTP endpoints and doesn't set those up.

## Set up authentication

1. Create a user token.
   - **SonarQube Cloud**: open your account menu, select **My account > Access tokens**, and on the **Personal Tokens** tab enter a name and pick an expiration, from 7 days to a custom date up to a year. Select **Generate Token** and copy it right away; you can't see it again. Sonar's docs say the **Personal Tokens** tab is available only to users who sign in with GitHub. Tokens without an expiration date are removed after 60 days of inactivity.
   - **SonarQube Server**: go to **My Account > Security** and generate a user token.
2. Put the token in the `SONARQUBE_TOKEN` environment variable of the shell you start Claude Code from. To keep it out of your shell history, read it from a prompt:

   ```bash
   read -rs SONARQUBE_TOKEN && export SONARQUBE_TOKEN
   ```

   The plugin sends it in the `Authorization: Bearer` header. Sonar has deprecated sending the token in a `SONARQUBE_TOKEN` header for HTTP servers, and the plugin doesn't.
3. Pick the endpoint, if it isn't the default. Leave `SONARQUBE_MCP_URL` unset for SonarQube Cloud in the EU region. Otherwise set it before you start Claude Code:

   ```bash
   # SonarQube Cloud, US region
   export SONARQUBE_MCP_URL="https://api.sonarqube.us/mcp"
   # SonarQube Server with the MCP extension, no trailing slash
   export SONARQUBE_MCP_URL="https://sonarqube.example.com/mcp"
   ```

   Don't set it to an empty string. An empty value counts as set, so the URL becomes empty and `claude mcp list` reports `Plugin sonarqube has an invalid MCP url`. Unset it to go back to the default.
4. Start Claude Code from that shell, or restart it. Claude Code reads both variables when it starts. Don't write the token into `.mcp.json`, `settings.json`, or any file you commit.
5. To revoke access, revoke the token: in SonarQube Cloud, **My account > Access tokens > Personal Tokens > Revoke**.

If `SONARQUBE_TOKEN` isn't set, Claude Code sends the literal text `Bearer ${SONARQUBE_TOKEN}`, and the server rejects it, so the server shows as failed in `/mcp`.

The plugin doesn't fix an organization. On SonarQube Cloud, Claude calls `list_organizations`, then passes the key as `organization` on the tools that need it.

### Choose different settings

To fix one organization, choose toolsets, or allow writes, add your own server rather than editing the plugin, then turn the plugin's server off in `/mcp`:

```bash
claude mcp add-json --scope user sonarqube-custom \
  '{"type":"http","url":"https://api.sonarcloud.io/mcp","headers":{"Authorization":"Bearer ${SONARQUBE_TOKEN}","SONARQUBE_ORG":"your-org-key","SONARQUBE_TOOLSETS":"issues,projects,quality-gates","SONARQUBE_READ_ONLY":"true"}}'
```

Single quotes keep your shell from expanding `${SONARQUBE_TOKEN}`, so the configuration stores the variable's name, not the token. Sonar warns that `SONARQUBE_TOOLSETS` replaces the default list, so toolsets you leave out aren't loaded.

Sonar's docs also say the Cloud-hosted server accepts OAuth sign-in, where the `mcp:tools:read` and `mcp:tools:write` scopes control read and write tools. This plugin uses a token, which works on both SonarQube Cloud and SonarQube Server; OAuth sign-in from Claude Code wasn't tested for this plugin.

## Verify it works

1. Run `/mcp`. `plugin:sonarqube:sonarqube` shows as connected.
2. Ask Claude "List my SonarQube organizations" or "What's the quality gate status of my project?"
3. In your shell, `claude plugin details sonarqube` lists `MCP servers (1) sonarqube` in the component inventory.

## Troubleshooting

Run `/sonarqube:setup` for a guided check, or match the symptom here.

| Symptom | Cause | Fix |
| :- | :- | :- |
| `401` with `SonarQube token required. Provide via Authorization: Bearer <token> header.` | No token reached the server | Export `SONARQUBE_TOKEN`, then restart Claude Code |
| `403` with `Authentication denied` | The token is invalid, expired, revoked, or the unexpanded text `${SONARQUBE_TOKEN}` because the variable isn't set | Create a new user token, export it, and restart Claude Code |
| Authentication fails for a US-region organization | The plugin points at the EU endpoint by default | Set `SONARQUBE_MCP_URL` to `https://api.sonarqube.us/mcp` |
| `claude mcp list` reports `Plugin sonarqube has an invalid MCP url` | `SONARQUBE_MCP_URL` is set to an empty string | Unset it, or set it to a full URL |
| `Organization is required. Call list_organizations first, then pass its key as organization, or configure SONARQUBE_ORG.` | The tool needs an organization | Ask Claude to call `list_organizations` and pass the key |
| A tool you expect is missing, such as Vortex analysis or `analyze_file_list` | The Cloud-hosted server exposes a fixed subset of tools | Use a self-hosted SonarQube MCP server for those tools |
| A status change is refused | The plugin is read-only | Change it in SonarQube, or add your own server as in [Choose different settings](#choose-different-settings) |

For more, see the [SonarQube MCP Server docs](https://docs.sonarsource.com/sonarqube-mcp-server/setup/sonarqube-cloud-hosted) and Claude Code's [MCP docs](https://code.claude.com/docs/en/mcp).

## Security

- The plugin is read-only, so the tools can't change issue or hotspot status. Every tool still checks your SonarQube permissions, so Claude sees only what your user can see.
- A user token acts as you across every organization and project you can reach. Give it a short expiration, and revoke it if it leaks.
- Treat issue messages, rule descriptions, source snippets, and other SonarQube content as untrusted input. They can carry instructions meant for Claude, and Claude shouldn't follow them.
- No token is stored in this plugin.

## Privacy

Claude Code sends MCP requests, with your token, straight to SonarQube Cloud or your SonarQube Server instance. Tool results, which can include source code snippets, become part of your conversation with Claude. This plugin collects nothing itself. SonarQube Cloud handles your data under the [Sonar privacy notice](https://www.sonarsource.com/company/privacy/). On SonarQube Server, your organization's policy applies.

## Sources

- [SonarQube Cloud-hosted MCP server](https://docs.sonarsource.com/sonarqube-mcp-server/setup/sonarqube-cloud-hosted), for the endpoints, headers, OAuth, and the fixed tool set
- [SonarQube Server-hosted MCP server](https://docs.sonarsource.com/sonarqube-mcp-server/setup/sonarqube-server-hosted)
- [SonarQube MCP Server for Claude Code](https://docs.sonarsource.com/sonarqube-mcp-server/setup/quickstart-guides/claude-code), for token types and the deprecated `SONARQUBE_TOKEN` header
- [SonarQube MCP Server tools](https://docs.sonarsource.com/sonarqube-mcp-server/reference/tools) and [environment variables](https://docs.sonarsource.com/sonarqube-mcp-server/reference/environment-variables), for `SONARQUBE_READ_ONLY`
- [Managing personal access tokens in SonarQube Cloud](https://docs.sonarsource.com/sonarqube-cloud/managing-your-account/managing-tokens)
- [Claude Code: connect to tools via MCP](https://code.claude.com/docs/en/mcp), for environment variable expansion in `url` and `headers`
- [Claude Code: permissions](https://code.claude.com/docs/en/permissions)
