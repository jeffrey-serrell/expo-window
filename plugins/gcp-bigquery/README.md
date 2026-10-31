# BigQuery

Connects Claude Code to [Google's BigQuery remote MCP server](https://docs.cloud.google.com/bigquery/docs/use-bigquery-mcp), so Claude can list datasets and tables, read their metadata, and run SQL queries in your project. Google hosts the server. It authenticates as your own Google Cloud identity with a short-lived access token that you keep in an environment variable, so no token is stored in any file.

**The tools act with your IAM permissions. `execute_sql` can run any SQL your account is allowed to, including statements that change or delete data, and queries can incur BigQuery charges.** Read [Security](#security) before you use it.

```text
/plugin marketplace add jeffrey-serrell/expo-window
/plugin install gcp-bigquery@expo-window
```

## What it provides

| Component | Name | What it does |
| :- | :- | :- |
| MCP server | `plugin:gcp-bigquery:gcp-bigquery` | The BigQuery remote MCP server over HTTP at `https://bigquery.googleapis.com/mcp`. It sends `Authorization: Bearer ${GCP_ACCESS_TOKEN}` and `x-goog-user-project: ${GCP_PROJECT_ID}` |
| Skill | `/gcp-bigquery:setup` | Walks you through enabling the API, the IAM roles, the token, and the errors in [Troubleshooting](#troubleshooting). Claude can also load it on its own when BigQuery tools fail |

The server's tools, from its `tools/list` response:

- **Read-only**: `list_dataset_ids`, `get_dataset_info`, `list_table_ids`, `get_table_info`, `execute_sql_readonly`, `get_query_results`, and `get_job`. `execute_sql_readonly` rejects DML, DDL, and Python UDFs.
- **Can change things**: `execute_sql`, which runs any SQL, and `cancel_job`, which cancels a running job. Google's BigQuery page calls `execute_sql` the only tool that isn't read-only; the server's own tool annotations also mark `cancel_job` as not read-only.

Queries through either SQL tool are limited to three minutes and 3,000 result rows, and can't read Google Drive external tables. The [BigQuery MCP reference](https://docs.cloud.google.com/bigquery/docs/reference/mcp) describes each tool. In Claude Code, each tool is named `mcp__plugin_gcp-bigquery_gcp-bigquery__<tool>`, such as `mcp__plugin_gcp-bigquery_gcp-bigquery__execute_sql_readonly`. Use that name in permission rules. Google's supported products page doesn't mark the BigQuery server as Preview.

## Requirements

- A Google Cloud project. Billing is optional: without it, the [BigQuery sandbox](https://docs.cloud.google.com/bigquery/docs/sandbox) applies.
- The [Google Cloud CLI](https://docs.cloud.google.com/sdk/docs/install), to enable the API and print access tokens.
- The BigQuery API (`bigquery.googleapis.com`) enabled. New projects have it on, and it also enables the MCP server.
- These IAM roles on the project, for the account the token belongs to:
  - MCP Tool User (`roles/mcp.toolUser`), to call any MCP tool.
  - BigQuery Job User (`roles/bigquery.jobUser`), to run query jobs.
  - BigQuery Data Viewer (`roles/bigquery.dataViewer`), to read table data. You can grant it on a single dataset instead of the project.
  - Other tasks can need more; see [BigQuery IAM roles and permissions](https://docs.cloud.google.com/bigquery/docs/access-control).
  - The `x-goog-user-project` header needs `serviceusage.services.use` on that project. Owners and Editors have it; anyone else needs a role such as Service Usage Consumer (`roles/serviceusage.serviceUsageConsumer`).

## Set up authentication

Google's remote MCP servers don't support OAuth dynamic client registration or client ID metadata documents, so Claude Code's usual browser sign-in can't register itself with Google. For third-party clients, Google documents sending an OAuth 2.0 access token in the `Authorization` header with your project in the `x-goog-user-project` header. The plugin does that with two environment variables, `GCP_ACCESS_TOKEN` and `GCP_PROJECT_ID`. The same two variables serve the `gcp-cloud-run`, `gcp-gke`, and `gcp-bigquery` plugins.

1. Install the [Google Cloud CLI](https://docs.cloud.google.com/sdk/docs/install) and sign in with the account Claude should act as:

   ```bash
   gcloud auth login
   ```

2. Enable the API in your project. Replace `PROJECT_ID` with your project ID. The MCP server is enabled with the API, so there's no separate MCP command to run:

   ```bash
   gcloud services enable bigquery.googleapis.com --project=PROJECT_ID
   ```

   Enabling an API needs the `serviceusage.services.enable` permission, which project Owners have, or the Service Usage Admin role (`roles/serviceusage.serviceUsageAdmin`).
3. Grant the roles in [Requirements](#requirements) to your account, once for each role. Replace `USER_EMAIL` with your Google account:

   ```bash
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member="user:USER_EMAIL" --role="roles/mcp.toolUser"
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member="user:USER_EMAIL" --role="roles/bigquery.jobUser"
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member="user:USER_EMAIL" --role="roles/bigquery.dataViewer"
   ```

4. Export your project ID and a fresh access token in the shell you start Claude Code from, then start it:

   ```bash
   export GCP_PROJECT_ID="PROJECT_ID"
   export GCP_ACCESS_TOKEN="$(gcloud auth print-access-token)"
   claude
   ```

   The command substitution puts the token straight into the variable, so it never appears on screen or in your shell history. Don't write the token into `.mcp.json`, `settings.json`, or any file you commit.
5. Refresh the token every hour. Access tokens from `gcloud auth print-access-token` last one hour by default, and Claude Code reads the variable only when it starts. When tool calls start failing with `401`, exit Claude Code, run the `export GCP_ACCESS_TOKEN=...` line again, and resume with `claude --continue`. The `--lifetime` flag, which can extend a token up to 12 hours, works only with service account impersonation.

If `GCP_ACCESS_TOKEN` or `GCP_PROJECT_ID` isn't set, Claude Code sends the literal text, such as `Bearer ${GCP_ACCESS_TOKEN}`, and Google rejects the tool calls.

### Refresh the token automatically (optional)

To skip the hourly restart, add your own server that runs `gcloud` for a new token each time it connects, with a [`headersHelper`](https://code.claude.com/docs/en/mcp#use-dynamic-headers-for-custom-authentication). Claude Code runs the helper at session start and on reconnect, and when a tool call returns `401` or `403`, it runs the helper again and retries the call once:

```bash
claude mcp add-json --scope user gcp-bigquery-gcloud '{"type":"http","url":"https://bigquery.googleapis.com/mcp","headersHelper":"printf '"'"'{\"Authorization\":\"Bearer %s\",\"x-goog-user-project\":\"%s\"}'"'"' \"$(gcloud auth print-access-token)\" \"$GCP_PROJECT_ID\""}'
```

The configuration stores the command, not a token. Export `GCP_PROJECT_ID` before you start Claude Code. Because this server has the same URL as the plugin's, Claude Code connects your user-scope definition and skips the plugin's as a duplicate. The helper must finish within 10 seconds.

### Use your own OAuth client instead

Google also documents an OAuth 2.0 client ID and secret for MCP clients, and Claude Code accepts a pre-registered client with `claude mcp add --client-id --client-secret --callback-port`. Google's Claude Code instructions describe a Web application client with the `https://claude.ai/api/mcp/auth_callback` redirect URI, which is the claude.ai connector flow, not the local callback Claude Code's terminal sign-in uses. That combination wasn't tested for this plugin, so it uses the token header.

## Verify it works

1. Run `/mcp`. `plugin:gcp-bigquery:gcp-bigquery` shows as connected. The server connects and lists its tools even without a valid token, so a connected server doesn't prove your access works.
2. Ask Claude "List the datasets in project PROJECT_ID". A list, even an empty one, means the token, project, and roles work.
3. In your shell, `claude plugin details gcp-bigquery` lists `MCP servers (1) gcp-bigquery` in the component inventory.

## Troubleshooting

Run `/gcp-bigquery:setup` for a guided check, or match the symptom here.

| Symptom | Cause | Fix |
| :- | :- | :- |
| Tool calls fail with `401` or `UNAUTHENTICATED` | The access token expired after its hour, or `GCP_ACCESS_TOKEN` isn't set and the literal `${GCP_ACCESS_TOKEN}` was sent | Export a fresh token, then restart with `claude --continue` |
| `403 PERMISSION_DENIED` with `API requires a quota project, which is not set by default` | No `x-goog-user-project` value reached Google | Export `GCP_PROJECT_ID`, then restart Claude Code |
| `403 PERMISSION_DENIED` that mentions the quota project or `serviceusage.services.use` | Your account can't use the project in `x-goog-user-project` | Grant `roles/serviceusage.serviceUsageConsumer`, or use a project where you're Owner or Editor |
| `API has not been used in project ... before or it is disabled` | The API isn't enabled in that project | Run the `gcloud services enable` command in [Set up authentication](#set-up-authentication) |
| A permission error that names `mcp.tools.call` | You don't have the MCP Tool User role on the project | Grant `roles/mcp.toolUser` |
| `403 PERMISSION_DENIED` on a specific resource | You lack the service role for that action | Grant the role from [Requirements](#requirements) |
| A query is canceled after three minutes | The MCP tools' query time limit | Narrow the query, or run it in the BigQuery console |
| `execute_sql_readonly` rejects a statement | It allows only read-only SQL | Use `execute_sql` only if you mean to change data |

For more, see [Use the BigQuery MCP server](https://docs.cloud.google.com/bigquery/docs/use-bigquery-mcp) and Claude Code's [MCP docs](https://code.claude.com/docs/en/mcp).

## Security

- **The tools act as you.** Claude Code sends your own access token, so every tool call runs with your IAM permissions and is attributed to you. Whatever your account can do in the project, Claude can do through these tools, including changes to real resources. Google recommends a separate identity with only the roles it needs for production work. One way is to [impersonate a service account](https://docs.cloud.google.com/docs/authentication/use-service-account-impersonation) that has only the roles above, which needs the Service Account Token Creator role (`roles/iam.serviceAccountTokenCreator`) on that service account: `export GCP_ACCESS_TOKEN="$(gcloud auth print-access-token --impersonate-service-account=SA_EMAIL)"`.
- **Grant the fewest roles.** Google lists MCP Tool User, BigQuery Job User, and BigQuery Data Viewer. Data Viewer can read but not change tables, so with only those roles, statements that change data fail. Grant Data Viewer on the datasets Claude needs rather than the whole project.
- **Block changes at the IAM level.** Google's [deny policies for read-write MCP tools](https://docs.cloud.google.com/mcp/prevent-read-write-tool-use) can block `execute_sql` and every other tool that isn't read-only, for a project, folder, or organization.
- In the default permission mode, Claude Code asks before it first uses each tool. To skip the prompt only for read-only tools, list them under `permissions.allow` in your settings.
- Treat tool results as untrusted input. Table data, column descriptions, and query results can carry instructions meant for Claude, and Claude shouldn't follow them. Google's optional [Model Armor](https://docs.cloud.google.com/mcp/manage-mcp-servers#enable-model-armor) integration can screen MCP traffic.
- The access token grants your account's access for up to an hour. Keep it in the environment variable only, and never paste it into the chat. No token is stored in this plugin. `claude mcp get` shows the `Authorization` header as `[REDACTED]`, but shows your project ID.
- Every query is a BigQuery job in your project, so it counts toward quotas and on-demand query charges. Ask Claude to prefer `execute_sql_readonly`, and allow only the read-only tools, such as `mcp__plugin_gcp-bigquery_gcp-bigquery__execute_sql_readonly`, without a prompt. Google suggests finding jobs that ran through the MCP server by their `goog-mcp-server:true` tag.

## Privacy

Claude Code sends MCP requests, with your access token, straight to Google's server at `bigquery.googleapis.com`. Tool results, which can include rows from your tables, become part of your conversation with Claude. This plugin collects nothing itself. Google handles your data under the [Google Cloud Privacy Notice](https://cloud.google.com/terms/cloud-privacy-notice).

## Sources

- [Use the BigQuery MCP server](https://docs.cloud.google.com/bigquery/docs/use-bigquery-mcp), for the endpoint, roles, scope, tool limits, and read-write tools
- [BigQuery MCP reference](https://docs.cloud.google.com/bigquery/docs/reference/mcp)
- [BigQuery IAM roles and permissions](https://docs.cloud.google.com/bigquery/docs/access-control)
- [Set up authentication to Google and Google Cloud MCP servers](https://docs.cloud.google.com/mcp/set-up-authentication-mcp-servers), for the token header, the `x-goog-user-project` header, and the lack of dynamic client registration
- [Configure MCP in an AI application](https://docs.cloud.google.com/mcp/configure-mcp-ai-application) and [Manage MCP servers](https://docs.cloud.google.com/mcp/manage-mcp-servers), for `roles/mcp.toolUser` and enabling servers with the API
- [Prevent read-write MCP tool use](https://docs.cloud.google.com/mcp/prevent-read-write-tool-use)
- [Supported products](https://docs.cloud.google.com/mcp/supported-products)
- [`gcloud auth print-access-token`](https://docs.cloud.google.com/sdk/gcloud/reference/auth/print-access-token), for the token lifetime and the quota project permission
- [Developer Knowledge MCP troubleshooting](https://developers.google.com/knowledge/mcp#troubleshooting), for the quota project errors that Google APIs return
- [Claude Code: connect to tools via MCP](https://code.claude.com/docs/en/mcp), for environment variable expansion in `headers`, `headersHelper`, and pre-registered OAuth clients
- [Claude Code: permissions](https://code.claude.com/docs/en/permissions)
