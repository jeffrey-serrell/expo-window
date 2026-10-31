#!/usr/bin/env bash
# Validate the marketplace and every plugin it lists.
#
# Usage: ./scripts/validate.sh
#
# Requires the claude CLI on PATH. Uses jq for the JSON checks when it's installed.
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
if command -v jq >/dev/null 2>&1; then
  echo "Checking JSON files and plugin names with jq"
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

  # Every plugin directory must be listed in the marketplace.
  for dir in "${plugin_dirs[@]}"; do
    dir="${dir%/}"
    if jq -e --arg src "./$dir" 'any(.plugins[]; .source == $src)' "$marketplace" >/dev/null; then
      pass "$dir is listed in $marketplace"
    else
      fail "$dir is not listed in $marketplace"
    fi
  done
else
  echo "jq not found. Skipping the JSON and name checks; claude plugin validate still checked the JSON syntax."
fi

echo
if ((failures > 0)); then
  echo "Validation failed: $failures check(s) failed." >&2
  exit 1
fi
echo "All checks passed."
