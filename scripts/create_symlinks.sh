#!/usr/bin/env bash

set -euo pipefail

GIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$GIT_ROOT/.env"
EXAMPLE_FILE="$GIT_ROOT/.env.example"

create_env_from_example() {
    if [ ! -f "$EXAMPLE_FILE" ]; then
        echo "WARN: .env.example not found, skipping .env creation"
        return
    fi

    if [ ! -f "$ENV_FILE" ]; then
        cp "$EXAMPLE_FILE" "$ENV_FILE"
        echo "INFO: Created .env from .env.example"
    fi
}

create_symlink() {
    local target_dir="$1"
    local link_path="$target_dir/.env"

    if [ -L "$link_path" ]; then
        rm "$link_path"
    elif [ -f "$link_path" ]; then
        echo "WARN: $link_path is a regular file, skipping symlink"
        return
    fi

    # Targets are one level below GIT_ROOT, so relative path is always ../.env.
    ln -s "../.env" "$link_path"
    echo "INFO: Created symlink $link_path -> ../.env"
}

create_env_from_example

echo "INFO: Creating .env symlinks in subdirectories..."

SKIP_DIRS=("node_modules" "nginx" "terraform")

for top_dir in "$GIT_ROOT"/*/; do
    dir_name="$(basename "$top_dir")"
    for skip in "${SKIP_DIRS[@]}"; do
        [[ "$dir_name" == "$skip" ]] && continue 2
    done
    create_symlink "${top_dir%/}"
done

echo "INFO: .env symlink setup complete"
