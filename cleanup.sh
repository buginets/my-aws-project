#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$HOME/my-aws-project"

# Remove project-local temp folders
rm -rf "$PROJECT_DIR/.ansible_tmp" \
       "$PROJECT_DIR/.ansible_galaxy_cache" \
       "$PROJECT_DIR/.helm"

# Fix project folder permissions
sudo chown -R ubuntu:ubuntu "$PROJECT_DIR"
chmod -R u+rwX "$PROJECT_DIR"

# Optional: clean global .ansible temp (if any)
rm -rf "$HOME/.ansible/tmp" "$HOME/.ansible/cp"

echo "✅ Project cleaned, ready for fresh deploy."
