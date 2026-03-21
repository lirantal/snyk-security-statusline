#!/bin/bash
set -e

WORKSPACE_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Starting devcontainer for: $WORKSPACE_FOLDER"
npx --yes @devcontainers/cli up --workspace-folder "$WORKSPACE_FOLDER"

echo "Dropping into container shell..."
npx --yes @devcontainers/cli exec --workspace-folder "$WORKSPACE_FOLDER" bash
