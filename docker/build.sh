#!/usr/bin/env bash
set -euo pipefail

action=${1:-build}
registry=${2:-}
base_registry=${3:-docker.io}
metadata_file=${4:?Supply the image metadata output path}
repo_root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)

case "$action" in
  test)
    docker buildx build --platform linux/amd64 --target encoding-tests \
      --build-arg "BASE_REGISTRY=$base_registry" \
      --output type=cacheonly --file "$repo_root/docker/Dockerfile" "$repo_root"
    exit
    ;;
  build|publish) ;;
  *) printf 'Unknown image action: %s\n' "$action" >&2; exit 64 ;;
esac

: "${registry:?Supply the hosted registry hostname}"
revision=$(git -C "$repo_root" rev-parse HEAD)
common_dir=$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir)
branch=$(git --git-dir="$common_dir" symbolic-ref --short HEAD)
branch=$(printf '%s' "$branch" | tr '/' '-' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_.-')
version=$(git -C "$repo_root" show "$revision:docker/Dockerfile" | sed -n 's/^ARG IMAGE_VERSION=//p')
image="$registry/seafile-pro-mc"
build=(docker buildx build --platform linux/amd64 --target patched \
  --build-arg "BASE_REGISTRY=$base_registry" --build-arg "GIT_SHA=$revision" \
  --metadata-file "$metadata_file" --file docker/Dockerfile \
  --tag "$image:$branch-latest" --tag "$image:$branch-$version" \
  --tag "$image:$branch-$version-${revision:0:12}")
if [[ "$action" == publish ]]; then
  build+=(--push)
else
  build+=(--load)
fi

# Publish only the named committed revision, preserving unrelated worktree edits.
git -C "$repo_root" archive "$revision" | "${build[@]}" -
printf 'Image revision: %s\nImage selection: %s:%s-%s-%s\nMetadata: %s\n' \
  "$revision" "$image" "$branch" "$version" "${revision:0:12}" "$metadata_file"
