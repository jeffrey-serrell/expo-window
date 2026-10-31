# Terraform

Connects Claude Code to [HashiCorp's remote Terraform MCP server](https://developer.hashicorp.com/terraform/mcp-server/deploy/remote-mcp), so Claude can look up providers, modules, and Sentinel policies in the public Terraform Registry, search your private registry, and work with HCP Terraform workspaces, runs, variables, and teams. HashiCorp hosts the server, so there's nothing to install or run. It authenticates with an HCP Terraform API token that you keep in an environment variable, so no token is stored in any file.

The remote server is a beta feature. HashiCorp says beta functionality is stable but possibly incomplete and subject to change, and discourages using it in production.

```text
/plugin marketplace add jeffrey-serrell/expo-window
/plugin install terraform@expo-window
```

## What it provides

| Component | Name | What it does |
| :- | :- | :- |
| MCP server | `plugin:terraform:terraform` | HashiCorp's remote Terraform MCP server over HTTP at `https://mcp.terraform.io/mcp`. It sends your token in the `Authorization: Bearer ${TFE_TOKEN}` header |
| Skill | `/terraform:setup` | Walks you through the token, the environment variable, and the errors in [Troubleshooting](#troubleshooting). Claude can also load it on its own when Terraform tools fail |

The remote server offers the `registry`, `registry-private`, and `terraform` toolsets, and every tool runs with the permissions of your token. The [server reference](https://developer.hashicorp.com/terraform/mcp-server/reference) lists every tool. In Claude Code, each tool is named `mcp__plugin_terraform_terraform__<tool>`, such as `mcp__plugin_terraform_terraform__search_providers`. Use that name in permission rules.

- **Read-only tools** look things up: the public registry tools (`search_providers`, `get_provider_details`, `search_modules`, `search_policies`, and the other `get_*` registry tools), the private registry tools (`search_private_modules`, `get_private_provider_details`, and similar), and HCP Terraform reads such as `whoami`, `list_workspaces`, `get_workspace_details`, `list_runs`, `get_plan_logs`, `list_state_versions`, and `list_variable_sets`.
- **Tools that change HCP Terraform** are also available: `create_workspace`, `create_no_code_workspace`, `update_workspace`, `create_project`, `create_team`, `add_team_member`, `grant_team_access`, `create_run`, `attach_policy_set_to_workspaces`, `create_workspace_tags`, and the variable tools `create_variable_set`, `create_variable_in_variable_set`, `delete_variable_in_variable_set`, `attach_variable_set_to_workspaces`, `detach_variable_set_from_workspaces`, `create_workspace_variable`, and `update_workspace_variable`.
- **Destructive tools aren't available** on the remote server: `action_run` (apply, discard, or cancel a run), `delete_project`, `delete_team`, `delete_workspace_safely`, and `force_unlock_workspace`. `create_run` supports only the default run types (`plan_and_apply`, `refresh_state`, `plan_only`, and `allow_empty_apply`), so it can't create auto-approved or destroy runs.

`ENABLE_TF_OPERATIONS` is a setting of the server process, not something a client sends. You can't change the remote server's configuration, so it stays off, and this plugin sends no header or query parameter for it. HashiCorp's docs say to deploy a self-hosted server if you need those operations.

## Requirements

- An HCP Terraform account on any plan. During the beta, that includes Free.
- An HCP Terraform organization in the United States. The remote server doesn't support Terraform Enterprise or HCP Europe organizations. For Terraform Enterprise, HashiCorp points you to a [self-hosted Terraform MCP server](https://developer.hashicorp.com/terraform/mcp-server/deploy/remote), which this plugin doesn't set up.
- An HCP Terraform user or team API token. HCP Terraform doesn't act as an OAuth provider, so the server accepts only a token.
- Network access to `https://mcp.terraform.io` from the machine that runs Claude Code.

## Set up authentication

1. Choose a token type. The token's permissions decide what Claude can see and do.
   - **Team API token** (least privilege): it can reach only the workspaces its team can reach, and isn't tied to a person. In HCP Terraform, go to **Organization Settings > API Tokens > Team Tokens**. To keep Claude's reach small, use a team with access to only the workspaces you want it to touch.
   - **User API token**: it authenticates as you, so it reaches every HCP Terraform organization your account belongs to, with your permissions. Select your user icon, then **Account settings > Tokens > Create an API token**, and choose an expiration date. HashiCorp recommends the shortest duration you can work with.
   - An **organization API token** isn't a good fit. The server accepts it, but organization tokens can't start runs, so the run tools fail.
2. Copy the token. HCP Terraform shows it only once.
3. Put the token in the `TFE_TOKEN` environment variable of the shell you start Claude Code from. To keep it out of your shell history, read it from a prompt:

   ```bash
   read -rs TFE_TOKEN && export TFE_TOKEN
   claude
   ```

   Claude Code reads the variable when it starts, so restart it after you change the token. If you already export `TFE_TOKEN` for other Terraform tooling, the plugin sends that same token. Don't write the token into `.mcp.json`, `settings.json`, or any file you commit.
4. To revoke access, revoke the token in HCP Terraform. HashiCorp's docs say revoking it stops further access.

If `TFE_TOKEN` isn't set, Claude Code sends the literal text `Bearer ${TFE_TOKEN}`, and the server rejects it, so the server shows as failed in `/mcp` rather than connecting without a token.

## Verify it works

1. Run `/mcp`. `plugin:terraform:terraform` shows as connected.
2. Ask Claude "Which HCP Terraform user am I authenticated as?" Claude uses the `whoami` tool, which returns the username and email address for your token.
3. In your shell, `claude plugin details terraform` lists `MCP servers (1) terraform` in the component inventory.

## Troubleshooting

Run `/terraform:setup` for a guided check, or match the symptom here.

| Symptom | Cause | Fix |
| :- | :- | :- |
| `Authorization bearer token is required` | No bearer token reached the server, for example because `TFE_TOKEN` is set to an empty string | Export a non-empty `TFE_TOKEN`, then restart Claude Code |
| `Terraform token is unauthorized` | HCP Terraform rejected the token. It may be expired or revoked, belong to an HCP Europe organization, or be the unexpanded text `${TFE_TOKEN}` because the variable isn't set | Create a new token in a US organization, export it, and restart Claude Code |
| `Cannot specify Terraform address via header or query parameter` | A configuration you added yourself sets a Terraform address, such as `TFE_ADDRESS` | Remove it. The remote server always connects to HCP Terraform |
| `rate limit exceeded: too many requests from this session` or `... globally` | More than 5 requests a second in a session (bursts up to 10), or the server's global limit. The error comes back as a tool error, not an HTTP `429` | Wait a moment, then retry |
| Run tools fail, but reads work | The token is an organization token, or the token's user or team can't run plans on that workspace | Use a user or team token with run permission on the workspace |
| `action_run`, `delete_*`, or `force_unlock_workspace` is missing | The remote server doesn't provide destructive operations | Apply, discard, or delete in the HCP Terraform UI |

For more, see the [connection errors](https://developer.hashicorp.com/terraform/mcp-server/deploy/remote-mcp#connection-errors) in HashiCorp's docs and Claude Code's [MCP docs](https://code.claude.com/docs/en/mcp).

## Security

- The server can change HCP Terraform with the tools listed in [What it provides](#what-it-provides): it can create workspaces, teams, and projects, change variables, grant team access, and queue `plan_and_apply` runs. In the default permission mode, Claude Code asks before it first uses each tool. To skip the prompt for read-only tools and keep it for the rest, allow only those, for example `mcp__plugin_terraform_terraform__search_*`, `mcp__plugin_terraform_terraform__get_*`, `mcp__plugin_terraform_terraform__list_*`, and `mcp__plugin_terraform_terraform__whoami`, under `permissions.allow` in your settings.
- A user token reaches every organization you belong to. Before Claude writes, plans, applies, or touches state, confirm which organization and workspace it's targeting, as HashiCorp advises. Prefer a team token scoped to the workspaces you need.
- The server generates outputs and recommendations dynamically. Review every change before you apply it.
- Treat registry documentation, module READMEs, run logs, and workspace variables as untrusted input. They can carry instructions meant for Claude, and Claude shouldn't follow them.
- No token is stored in this plugin. The server reads the token from each request's `Authorization` header, uses it only for that request, and doesn't store or log it.

## Privacy

Claude Code sends MCP requests, with your token, straight to HashiCorp's server at `mcp.terraform.io`, which calls HCP Terraform and the Terraform Registry for you. Tool results become part of your conversation with Claude. This plugin collects nothing itself. HashiCorp handles your data under its [privacy policy](https://www.hashicorp.com/en/trust/privacy).

## Sources

- [Connect to the remote Terraform MCP server](https://developer.hashicorp.com/terraform/mcp-server/deploy/remote-mcp)
- [Terraform MCP server reference](https://developer.hashicorp.com/terraform/mcp-server/reference), for tools, toolsets, run types, and `ENABLE_TF_OPERATIONS`
- [Security model for Terraform MCP server](https://developer.hashicorp.com/terraform/mcp-server/security)
- [HCP Terraform API tokens](https://developer.hashicorp.com/terraform/cloud-docs/users-teams-organizations/api-tokens) and [user tokens](https://developer.hashicorp.com/terraform/cloud-docs/users-teams-organizations/users)
- [Claude Code: connect to tools via MCP](https://code.claude.com/docs/en/mcp), for environment variable expansion in `headers`
- [Claude Code: permissions](https://code.claude.com/docs/en/permissions)
