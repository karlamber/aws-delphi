#!/usr/bin/env bash
# Print dev=run|skip and prod=run|skip for a commit range.
# root.hcl and tf-modules changes select both accounts. A range whose base
# is all zeros, which GitHub uses for the first push of a branch, selects both.
set -euo pipefail

base_sha="${1:?base sha}"
head_sha="${2:?head sha}"

dev=skip
prod=skip

if printf '%s\n' "$base_sha" | grep -Eq '^0+$'; then
  echo "dev=run"
  echo "prod=run"
  exit 0
fi

files="$(git diff --name-only "$base_sha" "$head_sha")"

if printf '%s\n' "$files" | grep -Eq '^(root\.hcl$|tf-modules/)'; then
  dev=run
  prod=run
fi
if printf '%s\n' "$files" | grep -q '^aws-delphi-dev/'; then
  dev=run
fi
if printf '%s\n' "$files" | grep -q '^aws-delphi-prod/'; then
  prod=run
fi

echo "dev=$dev"
echo "prod=$prod"
