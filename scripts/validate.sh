#!/usr/bin/env bash
# Validate the marketplace and every plugin it lists.
#
# Usage: ./scripts/validate.sh
#
# Requires the claude CLI and jq on PATH.
# Exits non-zero if any check fails.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

marketplace=".claude-plugin/marketplace.json"
failures=0

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1" >&2; failures=$((failures + 1)); }

if ! command -v claude >/dev/null 2>&1; then
  echo "error: the claude CLI is not on PATH. Install Claude Code, then run this script again." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is not on PATH. Install jq, then run this script again. The unknown-key checks need it." >&2
  exit 1
fi

if [[ ! -f "$marketplace" ]]; then
  echo "error: $marketplace not found in $root" >&2
  exit 1
fi

echo "Validating the marketplace with claude plugin validate --strict"
if claude plugin validate ./ --strict; then
  pass "marketplace"
else
  fail "marketplace"
fi

shopt -s nullglob
plugin_dirs=(plugins/*/)
shopt -u nullglob

for dir in "${plugin_dirs[@]}"; do
  dir="${dir%/}"
  echo
  echo "Validating $dir with claude plugin validate --strict"
  if claude plugin validate "./$dir" --strict; then
    pass "$dir"
  else
    fail "$dir"
  fi
done

echo
echo "Checking JSON files, plugin names, and manifest keys with jq"
while IFS= read -r -d '' file; do
  if jq empty "$file" >/dev/null 2>&1; then
    pass "valid JSON: $file"
  else
    fail "invalid JSON: $file"
  fi
done < <(find . -path ./.git -prune -o -path ./node_modules -prune -o -type f -name '*.json' -print0)

# Every marketplace entry with a relative-path source must point at a plugin
# directory whose plugin.json has the same name as the entry.
while IFS=$'\t' read -r name source; do
  manifest="${source#./}/.claude-plugin/plugin.json"
  if [[ ! -f "$manifest" ]]; then
    fail "entry \"$name\": $manifest not found"
    continue
  fi
  manifest_name="$(jq -r '.name // empty' "$manifest")"
  if [[ "$manifest_name" == "$name" ]]; then
    pass "entry \"$name\" matches $manifest"
  else
    fail "entry \"$name\" doesn't match the name \"$manifest_name\" in $manifest"
  fi
done < <(jq -r '.plugins[] | select(.source | type == "string") | [.name, .source] | @tsv' "$marketplace")

# Unknown keys. Claude Code strips an unrecognized top-level key in
# plugin.json at load time, and the Claude app warns about it ("Plugin has
# unrecognized key in plugin.json"). claude plugin validate does not catch
# every such key: it deliberately skips the directory listing fields (icon,
# documentationUrl, supportUrl, privacyPolicyUrl, termsOfServiceUrl) in
# plugin.json, even with --strict, and it does not check the keys inside
# author or owner. So check every object against an allowlist here.
#
# Source for the allowlists: the zod schemas in the claude CLI 2.1.314 and
# 2.1.316 bundles (the plugin manifest schema that the loader strips with,
# the marketplace schema, the marketplace entry schema, and the author
# schema), cross-checked against https://code.claude.com/docs/en/plugins-reference
# and https://code.claude.com/docs/en/plugins/marketplace-reference as of
# 2026-10-30. The directory listing fields are left out on purpose, because
# Claude Code drops them at load time. When Claude Code documents a new key,
# add it to the matching list.
# shellcheck disable=SC2016 # "$schema" is a literal JSON key, not a shell variable.
plugin_keys='["$schema","name","displayName","version","description","author",
  "homepage","repository","license","keywords","defaultEnabled","dependencies",
  "metadata","hooks","commands","agents","skills","outputStyles","themes",
  "workflows","channels","mcpServers","lspServers","monitors","settings","types",
  "userConfig","binaries","experimental"]'
person_keys='["name","email","url"]'
# shellcheck disable=SC2016 # "$schema" is a literal JSON key, not a shell variable.
marketplace_keys='["$schema","name","version","description","owner","plugins",
  "forceRemoveDeletedPlugins","metadata","allowCrossMarketplaceDependenciesOn",
  "renames"]'
metadata_keys='["pluginRoot","version","description"]'
entry_keys="$(jq -cn --argjson p "$plugin_keys" \
  '$p + ["source","headers","headersHelper","category","tags","strict","relevance"]')"

# check_keys FILE LABEL ALLOWED FILTER
# FILTER selects zero or more objects as {path, value}. Fails once for each key
# of each object that is not in ALLOWED.
check_keys() {
  local file="$1" label="$2" allowed="$3" filter="$4" found=0
  # An invalid JSON file is already reported above.
  jq empty "$file" >/dev/null 2>&1 || return 0
  while IFS=$'\t' read -r path key; do
    [[ -n "$key" ]] || continue
    fail "$file: unknown key \"$key\" in $path. It isn't in the Claude Code schema, so Claude Code ignores or strips it and the Claude app can warn about it. Remove it, or move its content to the plugin's README"
    found=1
  done < <(jq -r --argjson allowed "$allowed" "$filter"'
    | select(.value | type == "object")
    | .path as $p
    | .value | keys_unsorted[]
    | select(. as $k | $allowed | index($k) | not)
    | [$p, .] | @tsv' "$file")
  if ((found == 0)); then
    pass "known keys only: $label in $file"
  fi
}

check_keys "$marketplace" "top level" "$marketplace_keys" '{path: "the top level", value: .}'
check_keys "$marketplace" "owner" "$person_keys" '{path: "owner", value: .owner}'
check_keys "$marketplace" "metadata" "$metadata_keys" '{path: "metadata", value: .metadata}'
check_keys "$marketplace" "plugin entries" "$entry_keys" \
  '.plugins | to_entries[] | {path: "plugins[\(.key)] (\(.value.name // "unnamed"))", value: .value}'
check_keys "$marketplace" "plugin entry authors" "$person_keys" \
  '.plugins | to_entries[] | {path: "plugins[\(.key)].author", value: .value.author}'

for dir in "${plugin_dirs[@]}"; do
  manifest="${dir%/}/.claude-plugin/plugin.json"
  [[ -f "$manifest" ]] || continue
  check_keys "$manifest" "top level" "$plugin_keys" '{path: "the top level", value: .}'
  check_keys "$manifest" "author" "$person_keys" '{path: "author", value: .author}'
done

# Every plugin directory must be listed in the marketplace.
for dir in "${plugin_dirs[@]}"; do
  dir="${dir%/}"
  if jq -e --arg src "./$dir" 'any(.plugins[]; .source == $src)' "$marketplace" >/dev/null; then
    pass "$dir is listed in $marketplace"
  else
    fail "$dir is not listed in $marketplace"
  fi
done

echo
if ((failures > 0)); then
  echo "Validation failed: $failures check(s) failed." >&2
  exit 1
fi
echo "All checks passed."
