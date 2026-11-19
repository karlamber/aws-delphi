#!/usr/bin/env bash
# Run a speculative plan, an apply of a plan created in this same job, or a
# drift plan. RECONCILE=true plans and, in apply mode, applies every unit in
# the account directory. ALLOW_DESTROY=true lets a speculative plan that
# destroys resources succeed; apply mode does not consult that flag because
# the merge and the GitHub Environment are the approval.
set -euo pipefail

mode="${1:?mode is plan, apply, or drift}"
account_dir="${2:?account directory}"
base_sha="${3:-}"
head_sha="${4:-}"

case "$mode" in
  plan|apply|drift) ;;
  *) echo "mode must be plan, apply, or drift" >&2; exit 1 ;;
esac

export TF_IN_AUTOMATION=true
export TF_INPUT=false
export TG_NON_INTERACTIVE=true

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

args=(run --all --non-interactive --no-color --working-dir "$account_dir")

if [[ "$mode" == "drift" || "${RECONCILE:-false}" == "true" ]]; then
  echo "Selecting every unit in ${account_dir}."
  args+=(--no-filters-file)
else
  if [[ -z "$base_sha" || -z "$head_sha" ]]; then
    echo "A commit range is required unless RECONCILE=true. Pass before_sha and after_sha." >&2
    exit 1
  fi
  selection="$(.github/scripts/select-units.sh "$account_dir" "$base_sha" "$head_sha")"
  first="$(printf '%s\n' "$selection" | head -n 1)"
  if [[ "$first" == "SKIP" ]]; then
    echo "No Terragrunt units selected in ${account_dir}." | tee plan.txt
    exit 0
  fi
  if [[ "$first" == "ALL" ]]; then
    args+=(--no-filters-file)
  else
    filters_file="${RUNNER_TEMP:-/tmp}/terragrunt-filters-${account_dir//\//-}.txt"
    : > "$filters_file"
    while IFS= read -r unit; do
      [ -z "$unit" ] && continue
      printf '...%s\n' "$unit" >> "$filters_file"
    done <<EOF
$selection
EOF
    args+=(--filters-file "$filters_file")
  fi
fi

set -o pipefail
if [[ "$mode" == "apply" ]]; then
  out_dir="${RUNNER_TEMP:-/tmp}/tfplan-${account_dir//\//-}"
  mkdir -p "$out_dir"
  terragrunt "${args[@]}" --out-dir "$out_dir" -- plan -input=false -no-color | tee plan.txt
  terragrunt "${args[@]}" --out-dir "$out_dir" -- apply -input=false -no-color
  exit 0
fi

terragrunt "${args[@]}" -- plan -input=false -no-color | tee plan.txt

if [[ "$mode" == "plan" && "${ALLOW_DESTROY:-false}" != "true" ]]; then
  if grep -E 'Plan: [0-9]+ to add, [0-9]+ to change, [1-9][0-9]* to destroy' plan.txt >/dev/null; then
    echo "This plan destroys infrastructure. Add the allow-destroy label to the pull request and run the plan again." | tee -a plan.txt
    exit 1
  fi
fi
