# Google Developer Knowledge

Connects Claude Code to [Google's Developer Knowledge MCP server](https://developers.google.com/knowledge/mcp), so Claude can search and read official Google developer documentation, such as Google Cloud, Firebase, Android, Google Maps Platform, Flutter, and Chrome, instead of relying on web searches or older training data. Google hosts the server. It authenticates with a Google Cloud API key that you keep in an environment variable, so no key is stored in any file.

```text
/plugin marketplace add jeffrey-serrell/expo-window
/plugin install google-developer-knowledge@expo-window
```

## What it provides

| Component | Name | What it does |
| :- | :- | :- |
| MCP server | `plugin:google-developer-knowledge:google-developer-knowledge` | Google's Developer Knowledge MCP server over HTTP at `https://developerknowledge.googleapis.com/mcp`. It sends your key in the `X-Goog-Api-Key: ${DEVELOPERKNOWLEDGE_API_KEY}` header |
| Skill | `/google-developer-knowledge:setup` | Walks you through enabling the API, creating and restricting the key, and the errors in [Troubleshooting](#troubleshooting). Claude can also load it on its own when the tools fail |

The server has three tools, all read-only:

- `search_documents` returns the most relevant page excerpts and their document names.
- `get_documents` returns the full Markdown of up to 20 documents, by the names that the other tools return.
- `answer_query` returns a generated answer drawn from the documentation, with references. It has a smaller quota; if it returns `429`, use `search_documents` instead.

In Claude Code, each tool is named `mcp__plugin_google-developer-knowledge_google-developer-knowledge__<tool>`, such as `mcp__plugin_google-developer-knowledge_google-developer-knowledge__search_documents`. Use that name in permission rules. The [corpus reference](https://developers.google.com/knowledge/reference/corpus-reference) lists the indexed sites.

## Requirements

- A Google Cloud project where you can enable an API and create an API key. Enabling APIs needs the `serviceusage.services.enable` permission, which project Owners have.
- The [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) if you want to use the commands below. The Google Cloud console works too.
- Network access to `https://developerknowledge.googleapis.com`. Inside a VPC Service Controls perimeter, see Google's [known limitations](https://developers.google.com/knowledge/mcp#known-limitations).

## Set up authentication

Google recommends an API key for Claude Code. Replace `PROJECT_ID` with your project ID.

1. Enable the Developer Knowledge API:

   ```bash
   gcloud services enable developerknowledge.googleapis.com --project=PROJECT_ID
   ```

2. Create an API key:

   ```bash
   gcloud services api-keys create --project=PROJECT_ID --display-name="Developer Knowledge MCP"
   ```

   The output shows `keyString`, the key itself, and `name`, the key's resource path, such as `projects/PROJECT_ID/locations/global/keys/KEY_ID`. Copy both.
3. Restrict the key to the Developer Knowledge API, using the `name` from the previous step:

   ```bash
   gcloud services api-keys update KEY_NAME \
     --api-target=service=developerknowledge.googleapis.com
   ```

   In the console, the same steps are: open the [Developer Knowledge API page](https://console.cloud.google.com/apis/library/developerknowledge.googleapis.com), select your project, and select **Enable**. Then go to **APIs & Services > Credentials**, select **Create credentials > API key**, edit the key, and under **API restrictions** select **Restrict key** and **Developer Knowledge API**. Google also recommends an application restriction where it fits, such as allowed IP addresses.
4. Put the key in the `DEVELOPERKNOWLEDGE_API_KEY` environment variable of the shell you start Claude Code from. Google's own examples use this name. To keep the key out of your shell history, read it from a prompt:

   ```bash
   read -rs DEVELOPERKNOWLEDGE_API_KEY && export DEVELOPERKNOWLEDGE_API_KEY
   claude
   ```

   Claude Code reads the variable when it starts, so restart it after you change the key. Don't write the key into `.mcp.json`, `settings.json`, or any file you commit, and don't pass it as a URL query parameter.
5. To revoke access, delete the key or regenerate it on the **Credentials** page.

If `DEVELOPERKNOWLEDGE_API_KEY` isn't set, Claude Code sends the literal text `${DEVELOPERKNOWLEDGE_API_KEY}` as the key, and the server rejects the tool calls.

### Use Google credentials instead of a key

Google also documents an ADC bearer token or an OAuth client ID for third-party clients. The plugin uses only the API key. To use a bearer token, add a separate server rather than editing the plugin, keep the token in an environment variable, and add the quota project header:

```bash
claude mcp add-json --scope user google-developer-knowledge-adc \
  '{"type":"http","url":"https://developerknowledge.googleapis.com/mcp","headers":{"Authorization":"Bearer ${GCP_ACCESS_TOKEN}","X-Goog-User-Project":"${GCP_PROJECT_ID}"}}'
```

Single quotes keep your shell from expanding the variables, so the configuration stores their names. Before you start Claude Code, run `gcloud auth application-default login --project=PROJECT_ID`, then export `GCP_ACCESS_TOKEN="$(gcloud auth application-default print-access-token)"` and `GCP_PROJECT_ID`. The token expires after one hour. The `X-Goog-User-Project` header needs the `serviceusage.services.use` permission on the project, which Owners and Editors have; anyone else needs a role such as Service Usage Consumer (`roles/serviceusage.serviceUsageConsumer`). Turn the plugin's server off in `/mcp` so you don't have two copies.

## Verify it works

1. Run `/mcp`. `plugin:google-developer-knowledge:google-developer-knowledge` shows as connected. The server connects and lists its tools even with a missing or wrong key, so a connected server doesn't prove the key works.
2. Ask Claude something such as "How do I list Cloud Storage buckets using the Google Cloud Python SDK?" Claude should call `search_documents` or `answer_query` and cite Google documentation. An error such as `API key not valid` means the key isn't reaching the server.
3. In your shell, `claude plugin details google-developer-knowledge` lists `MCP servers (1) google-developer-knowledge` in the component inventory.

## Troubleshooting

Run `/google-developer-knowledge:setup` for a guided check, or match the symptom here.

| Symptom | Cause | Fix |
| :- | :- | :- |
| `400 Bad Request: API key not valid` | The key is missing, malformed, or the unexpanded text `${DEVELOPERKNOWLEDGE_API_KEY}` because the variable isn't set | Export the key as `DEVELOPERKNOWLEDGE_API_KEY` and restart Claude Code |
| `403 PERMISSION_DENIED: API target restriction` | The key's API restrictions don't include the Developer Knowledge API | Add **Developer Knowledge API** to the key's API restrictions |
| `403 PERMISSION_DENIED` with `Developer Knowledge API has not been used`, or `404 NOT_FOUND` on `/mcp` | The API isn't enabled in the key's project | Run `gcloud services enable developerknowledge.googleapis.com --project=PROJECT_ID` |
| `429 RESOURCE_EXHAUSTED` | The project reached its quota. `answer_query` has a smaller quota than the other tools | Use `search_documents`, or check the [Developer Knowledge API quota](https://developers.google.com/knowledge/quota) |
| `403 PERMISSION_DENIED` with Model Armor | A Model Armor prompt-injection filter in your project blocked a safe query | Set the filter's confidence to `HIGH_AND_ABOVE` |

For more, see Google's [troubleshooting tables](https://developers.google.com/knowledge/mcp#troubleshooting) and Claude Code's [MCP docs](https://code.claude.com/docs/en/mcp).

## Security

- Every tool is read-only, and the server indexes only public documentation. It can't change anything in your Google Cloud project.
- The API key is the credential. Restrict it to the Developer Knowledge API so a leaked key can't call other APIs, and rotate it if it leaks. Requests count against the quota of the key's project.
- Treat returned documentation as untrusted input, like any web content. It can carry instructions meant for Claude, and Claude shouldn't follow them.
- Full documents use many tokens. Prefer `search_documents` excerpts, and fetch whole pages with `get_documents` only when needed.
- No key is stored in this plugin.

## Privacy

Claude Code sends your queries and your API key straight to Google's server at `developerknowledge.googleapis.com`. Tool results become part of your conversation with Claude. This plugin collects nothing itself. Google handles your data under the [Google Privacy Policy](https://policies.google.com/privacy).

## Sources

- [Connect to the Developer Knowledge MCP server](https://developers.google.com/knowledge/mcp), for the tools, authentication, key creation and restriction, troubleshooting, and limitations
- [Developer Knowledge MCP reference](https://developers.google.com/knowledge/reference/mcp)
- [Connect using MCP SDKs](https://developers.google.com/knowledge/mcp-sdk), for the `DEVELOPERKNOWLEDGE_API_KEY` variable name and the header-only key
- [Set up authentication to Google and Google Cloud MCP servers](https://docs.cloud.google.com/mcp/set-up-authentication-mcp-servers)
- [Claude Code: connect to tools via MCP](https://code.claude.com/docs/en/mcp), for environment variable expansion in `headers`
- [Claude Code: permissions](https://code.claude.com/docs/en/permissions)
