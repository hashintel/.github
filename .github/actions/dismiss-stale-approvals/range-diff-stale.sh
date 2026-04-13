#!/usr/bin/env bash
set -euo pipefail

run_range_diff_stale() {
  local range_diff
  range_diff="$(cat)"

  if printf '%s\n' "$range_diff" | awk 'NF >= 3 { print $3 }' | grep -vq '^=$'; then
    printf 'stale=true\n'
  else
    printf 'stale=false\n'
  fi
}

# Runs the full range-diff staleness check for a repository.
# Handles the case where HEAD hasn't changed (base-branch-only advance).
#
# Arguments:
#   --repository-path  Path to a git repo (bare or non-bare)
#   --prev-base-sha    Previous base branch SHA
#   --prev-head-sha    Previous PR head SHA
#   --base-sha         Current base branch SHA
#   --head-sha         Current PR head SHA
#   --fetch-depth      (optional) Depth for git fetch (only for remote repos)
run_check_range_diff_stale() {
  local repository_path="" prev_base_sha="" prev_head_sha="" base_sha="" head_sha=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repository-path) repository_path="$2"; shift 2 ;;
      --prev-base-sha)   prev_base_sha="$2"; shift 2 ;;
      --prev-head-sha)   prev_head_sha="$2"; shift 2 ;;
      --base-sha)        base_sha="$2"; shift 2 ;;
      --head-sha)        head_sha="$2"; shift 2 ;;
      *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
  done

  # If the PR branch head hasn't changed, the reviewed code hasn't changed.
  # This prevents false positives when only the base branch advances
  # (e.g., squash-merge of a stacked PR shifting the merge-base).
  if [[ "$head_sha" == "$prev_head_sha" ]]; then
    printf 'stale=false\n'
    return
  fi

  local prev_merge_base merge_base range_diff
  prev_merge_base="$(git -C "$repository_path" merge-base "$prev_base_sha" "$prev_head_sha")"
  merge_base="$(git -C "$repository_path" merge-base "$base_sha" "$head_sha")"
  range_diff="$(git -C "$repository_path" range-diff "$prev_merge_base..$prev_head_sha" "$merge_base..$head_sha")"

  printf '%s\n' "$range_diff" | run_range_diff_stale
}

main() {
  run_range_diff_stale
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
