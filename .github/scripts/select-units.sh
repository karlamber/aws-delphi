#!/usr/bin/env bash
# Print the Terragrunt units in one account that a commit range affects.
# Stdout is one of:
#   SKIP
#   ALL
#   one unit path per line, relative to the account directory
# A path is used as a graph filter (...path), which includes that unit and
# the units that depend on it. The script avoids bash 4 features so it can
# also be run on the macOS bash that ships with a laptop.
set -euo pipefail

account_dir="${1:?account directory}"
base_sha="${2:?base sha}"
head_sha="${3:?head sha}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if printf '%s\n' "$base_sha" | grep -Eq '^0+$'; then
  echo ALL
  exit 0
fi

if ! git cat-file -e "${base_sha}^{commit}" 2>/dev/null; then
  echo "Base commit ${base_sha} is not in this clone. Fetch full history before selecting units." >&2
  exit 1
fi

files="$(git diff --name-only "$base_sha" "$head_sha")"

if printf '%s\n' "$files" | grep -Eq '^(root\.hcl$|tf-modules/)'; then
  echo ALL
  exit 0
fi

if ! printf '%s\n' "$files" | grep -q "^${account_dir}/"; then
  echo SKIP
  exit 0
fi

changed_file="$(mktemp)"
expanded_file="$(mktemp)"
trap 'rm -f "$changed_file" "$expanded_file"' EXIT

terragrunt find \
  --no-color \
  --non-interactive \
  --log-level error \
  --discovery-boundary "$account_dir" \
  --filter "[${base_sha}...${head_sha}]" \
  --filter-allow-destroy > "$changed_file"

while IFS= read -r unit; do
  [ -z "$unit" ] && continue
  case "$unit" in
    "${account_dir}/"*) rel="${unit#"${account_dir}/"}" ;;
    aws-delphi-dev/*|aws-delphi-prod/*) continue ;;
    *) rel="${unit#./}" ;;
  esac
  terragrunt find \
    --no-color \
    --non-interactive \
    --log-level error \
    --working-dir "$account_dir" \
    --filter "...${rel}" >> "$expanded_file"
done < "$changed_file"

if [ ! -s "$expanded_file" ]; then
  echo SKIP
  exit 0
fi

sort -u "$expanded_file"
