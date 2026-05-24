#!/usr/bin/env bash
set -euo pipefail

name="${1:?usage: rollback-function.sh <function-name> <git-sha-or-tag>}"
sha="${2:?usage: rollback-function.sh <function-name> <git-sha-or-tag>}"

repo_root="$(git rev-parse --show-toplevel)"
func_path="landing/supabase/functions/${name}"

trap 'git -C "$repo_root" checkout HEAD -- "$func_path" 2>/dev/null || true' EXIT

git -C "$repo_root" checkout "$sha" -- "$func_path"
(cd "$repo_root/landing" && npx supabase functions deploy "$name")
echo "Rolled $name back to $sha and restored working tree."
