# Google Cloud Run

Connects Claude Code to [Google's Cloud Run remote MCP server](https://docs.cloud.google.com/run/docs/use-cloud-run-mcp), so Claude can list and inspect your Cloud Run services and deploy services from a container image or from source. Google hosts the server. It authenticates as your own Google Cloud identity with a short-lived access token that you keep in an environment variable, so no token is stored in any file.

**The tools act with your IAM permissions, so they can deploy and change real Cloud Run services in your project.** Read [Security](#security) before you use it.

```text
/plugin marketplace add jeffrey-serrell/expo-window
/plugin install gcp-cloud-run@expo-window
```

## What it provides

| Component | Name | What it does |
| :- | :- | :- |
| MCP server | `plugin:gcp-cloud-run:gcp-cloud-run` | The Cloud Run remote MCP server over HTTP at `${GCP_CLOUD_RUN_MCP_URL:-https://run.googleapis.com/mcp}`. It sends `Authorization: Bearer ${GCP_ACCESS_TOKEN}` and `x-goog-user-project: ${GCP_PROJECT_ID}` |
| Skill | `/gcp-cloud-run:setup` | Walks you through enabling the API, the IAM roles, the token, and the errors in [Troubleshooting](#troubleshooting). Claude can also load it on its own when Cloud Run tools fail |

The server's tools, from its `tools/list` response:

- **Read-only**: `get_service` and `list_services`, which take a project, a region, and for `get_service` a service name.
- **Changes Cloud Run**: `deploy_service_from_image`, which deploys an image from Artifact Registry or Docker Hub; `deploy_service_from_archive`, which deploys a `.tar.gz` source archive; and `deploy_service_from_file_contents`, which deploys from source files that Claude sends.

The server also offers a `deploy` prompt, in Preview, which deploys the current working directory. Type `/` in Claude Code to find it; Claude Code marks MCP prompts with `(MCP)`. The [Cloud Run MCP reference](https://docs.cloud.google.com/run/docs/reference/mcp) describes each tool. In Claude Code, each tool is named `mcp__plugin_gcp-cloud-run_gcp-cloud-run__<tool>`, such as `mcp__plugin_gcp-cloud-run_gcp-cloud-run__list_services`. Use that name in permission rules.

The Cloud Run remote MCP server is generally available. Its regional endpoints, `https://run.REGION.rep.googleapis.com/mcp`, are in Preview. To use one, set `GCP_CLOUD_RUN_MCP_URL` to it before you start Claude Code. Don't set the variable to an empty string; unset it to go back to the global endpoint.

## Requirements

- A Google Cloud project with billing enabled.
- The [Google Cloud CLI](https://docs.cloud.google.com/sdk/docs/install), to enable the API and print access tokens.
- The Cloud Run Admin API (`run.googleapis.com`) enabled. That also enables the MCP server.
- These IAM roles on the project, for the account the token belongs to:
  - MCP Tool User (`roles/mcp.toolUser`), to call any MCP tool.
  - Cloud Run Developer (`roles/run.developer`), to create Cloud Run services.
  - Service Account User (`roles/iam.serviceAccountUser`), to run operations as the service's service account.
  - Artifact Registry Reader (`roles/artifactregistry.reader`), to pull the container image.
  - Service Account Token Creator (`roles/iam.serviceAccountTokenCreator`), only to deploy with a service account from another project.
  - The `x-goog-user-project` header needs `serviceusage.services.use` on that project. Owners and Editors have it; anyone else needs a role such as Service Usage Consumer (`roles/serviceusage.serviceUsageConsumer`).

## Set up authentication

Google's remote MCP servers don't support OAuth dynamic client registration or client ID metadata documents, so Claude Code's usual browser sign-in can't register itself with Google. For third-party clients, Google documents sending an OAuth 2.0 access token in the `Authorization` header with your project in the `x-goog-user-project` header. The plugin does that with two environment variables, `GCP_ACCESS_TOKEN` and `GCP_PROJECT_ID`. The same two variables serve the `gcp-cloud-run`, `gcp-gke`, and `gcp-bigquery` plugins.

1. Install the [Google Cloud CLI](https://docs.cloud.google.com/sdk/docs/install) and sign in with the account Claude should act as:

   ```bash
   gcloud auth login
   ```

2. Enable the API in your project. Replace `PROJECT_ID` with your project ID. The MCP server is enabled with the API, so there's no separate MCP command to run:

   ```bash
   gcloud services enable run.googleapis.com --project=PROJECT_ID
   ```

   Enabling an API needs the `serviceusage.services.enable` permission, which project Owners have, or the Service Usage Admin role (`roles/serviceusage.serviceUsageAdmin`).
3. Grant the roles in [Requirements](#requirements) to your account, once for each role. Replace `USER_EMAIL` with your Google account:

   ```bash
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member="user:USER_EMAIL" --role="roles/mcp.toolUser"
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member="user:USER_EMAIL" --role="roles/run.developer"
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member="user:USER_EMAIL" --role="roles/iam.serviceAccountUser"
   gcloud projects add-iam-policy-binding PROJECT_ID \
     --member="user:USER_EMAIL" --role="roles/artifactregistry.reader"
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
claude mcp add-json --scope user gcp-cloud-run-gcloud '{"type":"http","url":"https://run.googleapis.com/mcp","headersHelper":"printf '"'"'{\"Authorization\":\"Bearer %s\",\"x-goog-user-project\":\"%s\"}'"'"' \"$(gcloud auth print-access-token)\" \"$GCP_PROJECT_ID\""}'
```

The configuration stores the command, not a token. Export `GCP_PROJECT_ID` before you start Claude Code. Because this server has the same URL as the plugin's, Claude Code connects your user-scope definition and skips the plugin's as a duplicate. The helper must finish within 10 seconds.

### Use your own OAuth client instead

Google also documents an OAuth 2.0 client ID and secret for MCP clients, and Claude Code accepts a pre-registered client with `claude mcp add --client-id --client-secret --callback-port`. Google's Claude Code instructions describe a Web application client with the `https://claude.ai/api/mcp/auth_callback` redirect URI, which is the claude.ai connector flow, not the local callback Claude Code's terminal sign-in uses. That combination wasn't tested for this plugin, so it uses the token header.

## Verify it works

1. Run `/mcp`. `plugin:gcp-cloud-run:gcp-cloud-run` shows as connected. The server connects and lists its tools even without a valid token, so a connected server doesn't prove your access works.
2. Ask Claude "List the Cloud Run services in project PROJECT_ID in region us-central1". A list, even an empty one, means the token, project, and roles work.
3. In your shell, `claude plugin details gcp-cloud-run` lists `MCP servers (1) gcp-cloud-run` in the component inventory.

## Troubleshooting

Run `/gcp-cloud-run:setup` for a guided check, or match the symptom here.

| Symptom | Cause | Fix |
| :- | :- | :- |
| Tool calls fail with `401` or `UNAUTHENTICATED` | The access token expired after its hour, or `GCP_ACCESS_TOKEN` isn't set and the literal `${GCP_ACCESS_TOKEN}` was sent | Export a fresh token, then restart with `claude --continue` |
| `403 PERMISSION_DENIED` with `API requires a quota project, which is not set by default` | No `x-goog-user-project` value reached Google | Export `GCP_PROJECT_ID`, then restart Claude Code |
| `403 PERMISSION_DENIED` that mentions the quota project or `serviceusage.services.use` | Your account can't use the project in `x-goog-user-project` | Grant `roles/serviceusage.serviceUsageConsumer`, or use a project where you're Owner or Editor |
| `API has not been used in project ... before or it is disabled` | The API isn't enabled in that project | Run the `gcloud services enable` command in [Set up authentication](#set-up-authentication) |
| A permission error that names `mcp.tools.call` | You don't have the MCP Tool User role on the project | Grant `roles/mcp.toolUser` |
| `403 PERMISSION_DENIED` on a specific resource | You lack the service role for that action | Grant the role from [Requirements](#requirements) |
| A deploy fails with a permission error on the image or service account | You lack Artifact Registry Reader or Service Account User, or Token Creator for a cross-project service account | Grant the missing role from [Requirements](#requirements) |

For more, see [Use the Cloud Run remote MCP server](https://docs.cloud.google.com/run/docs/use-cloud-run-mcp) and Claude Code's [MCP docs](https://code.claude.com/docs/en/mcp).

## Security

- **The tools act as you.** Claude Code sends your own access token, so every tool call runs with your IAM permissions and is attributed to you. Whatever your account can do in the project, Claude can do through these tools, including changes to real resources. Google recommends a separate identity with only the roles it needs for production work. One way is to [impersonate a service account](https://docs.cloud.google.com/docs/authentication/use-service-account-impersonation) that has only the roles above, which needs the Service Account Token Creator role (`roles/iam.serviceAccountTokenCreator`) on that service account: `export GCP_ACCESS_TOKEN="$(gcloud auth print-access-token --impersonate-service-account=SA_EMAIL)"`.
- **Grant the fewest roles.** To let Claude only read, grant MCP Tool User and Cloud Run Viewer (`roles/run.viewer`) instead of the deploy roles, so the deploy tools fail with a permission error.
- **Block changes at the IAM level.** Google's [deny policies for read-write MCP tools](https://docs.cloud.google.com/mcp/prevent-read-write-tool-use) can block every tool that isn't read-only, here the three deploy tools, for a project, folder, or organization.
- In the default permission mode, Claude Code asks before it first uses each tool. To skip the prompt only for read-only tools, list them under `permissions.allow` in your settings.
- Treat tool results as untrusted input. Service descriptions, environment variables, and source files can carry instructions meant for Claude, and Claude shouldn't follow them. Google's optional [Model Armor](https://docs.cloud.google.com/mcp/manage-mcp-servers#enable-model-armor) integration can screen MCP traffic.
- The access token grants your account's access for up to an hour. Keep it in the environment variable only, and never paste it into the chat. No token is stored in this plugin. `claude mcp get` shows the `Authorization` header as `[REDACTED]`, but shows your project ID.
- A deploy can create a publicly reachable service and starts billing for Cloud Run. Check the service name, project, region, image or source, and whether it allows unauthenticated access before you approve a deploy tool.

## Privacy

Claude Code sends MCP requests, with your access token, straight to Google's server at `run.googleapis.com`. Tool results, and any source files Claude deploys, become part of your conversation with Claude. This plugin collects nothing itself. Google handles your data under the [Google Cloud Privacy Notice](https://cloud.google.com/terms/cloud-privacy-notice).

## Sources

- [Use the Cloud Run remote MCP server](https://docs.cloud.google.com/run/docs/use-cloud-run-mcp), for the endpoint, roles, scopes, and the `deploy` prompt
- [Cloud Run MCP reference](https://docs.cloud.google.com/run/docs/reference/mcp)
- [Cloud Run release notes](https://docs.cloud.google.com/run/docs/release-notes), for general availability
- [Cloud Run IAM roles](https://docs.cloud.google.com/run/docs/reference/iam/roles)
- [Set up authentication to Google and Google Cloud MCP servers](https://docs.cloud.google.com/mcp/set-up-authentication-mcp-servers), for the token header, the `x-goog-user-project` header, and the lack of dynamic client registration
- [Configure MCP in an AI application](https://docs.cloud.google.com/mcp/configure-mcp-ai-application) and [Manage MCP servers](https://docs.cloud.google.com/mcp/manage-mcp-servers), for `roles/mcp.toolUser` and enabling servers with the API
- [Prevent read-write MCP tool use](https://docs.cloud.google.com/mcp/prevent-read-write-tool-use)
- [Supported products](https://docs.cloud.google.com/mcp/supported-products)
- [`gcloud auth print-access-token`](https://docs.cloud.google.com/sdk/gcloud/reference/auth/print-access-token), for the token lifetime and the quota project permission
- [Developer Knowledge MCP troubleshooting](https://developers.google.com/knowledge/mcp#troubleshooting), for the quota project errors that Google APIs return
- [Claude Code: connect to tools via MCP](https://code.claude.com/docs/en/mcp), for environment variable expansion in `headers`, `headersHelper`, and pre-registered OAuth clients
- [Claude Code: permissions](https://code.claude.com/docs/en/permissions)
