#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# -------------------------------
# Prepare charts & images (builder mode)
# -------------------------------
MODE="${1:-}"  # default to empty string if no argument

if [ ! -d "charts" ] || [ ! -d "images" ] || [ "$MODE" == "build" ]; then
    if [ "$MODE" != "build" ]; then
        echo "⚠️  charts/ or images/ not found. Running prepare_tarbowl.sh for testing..."
    else
        echo "🛠️  Running in build mode (prepare tarbowl)..."
    fi
    chmod +x ./prepare_tarbowl.sh
    ./prepare_tarbowl.sh
else
    echo "✅ charts/ and images/ already exist. Skipping prepare_tarbowl.sh."
fi

# -------------------------------
# Helm home & config (project-local)
# -------------------------------
HELM_HOME="$SCRIPT_DIR/.helm"
export HELM_CONFIG_HOME="$HELM_HOME/config"
export HELM_DATA_HOME="$HELM_HOME/data"
export HELM_CACHE_HOME="$HELM_HOME/cache"

mkdir -p "$HELM_CONFIG_HOME/registry" \
         "$HELM_DATA_HOME" \
         "$HELM_CACHE_HOME/repository"
chmod -R 700 "$HELM_HOME"
touch "$HELM_CONFIG_HOME/registry/config.json"
touch "$HELM_CACHE_HOME/repository/repositories.lock"
echo "✅ Helm home and config set to project folder: $HELM_HOME"

# -------------------------------
# Ensure Ansible local temp is writable by become/root
# -------------------------------
ANSIBLE_LOCAL_TEMP="$SCRIPT_DIR/.ansible_tmp"
rm -rf "$ANSIBLE_LOCAL_TEMP"
mkdir -p "$ANSIBLE_LOCAL_TEMP"
chmod 777 "$ANSIBLE_LOCAL_TEMP"   # allow root and user to write
export ANSIBLE_LOCAL_TEMP

ANSIBLE_GALAXY_CACHE="$SCRIPT_DIR/.ansible_galaxy_cache"
mkdir -p "$ANSIBLE_GALAXY_CACHE"
chmod 700 "$ANSIBLE_GALAXY_CACHE"
export ANSIBLE_GALAXY_ROLE_CACHE="$ANSIBLE_GALAXY_CACHE"

export ANSIBLE_ROLES_PATH="$SCRIPT_DIR/ansible/roles"
echo "✅ Project-local Ansible directories configured."

# -------------------------------
# Load Docker images (offline)
# -------------------------------
echo "🐳 Loading Docker images from images/*.tar.gz..."
for img in images/*.tar.gz; do
    sudo docker load -i "$img"
done
echo "✅ Docker images loaded."

# -------------------------------
# Ansible Vault password
# -------------------------------
read -s -p "Enter Ansible Vault password: " VAULT_PASS
echo
VAULT_FILE="$(mktemp /tmp/.ansible_vault_pass_XXXX)"
umask 177
printf "%s" "$VAULT_PASS" > "$VAULT_FILE"
export ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_FILE"

# -------------------------------
# Run playbooks sequentially
# -------------------------------
PLAYBOOKS=(
  "ansible/playbooks/01_bootstrap_bastion.yaml"
  "ansible/playbooks/02_base_on_vms.yaml"
  "ansible/playbooks/03_rke2_install.yaml"
  "ansible/playbooks/04_fetch_kubeconfig.yaml"
  "ansible/playbooks/05_harbor_workstation.yaml"
  "ansible/playbooks/06_harbor_upload.yaml"
  "ansible/playbooks/07_cluster_tools.yaml"
  "ansible/playbooks/08_microservices.yaml"
  "ansible/playbooks/99_collect_secrets.yaml"
)

for pb in "${PLAYBOOKS[@]}"; do
    echo "=== Running playbook: $pb ==="
    ansible-playbook -i inventory.yaml "$pb"
done

# -------------------------------
# Clean up Vault password
# -------------------------------
rm -f "$VAULT_FILE"
unset ANSIBLE_VAULT_PASSWORD_FILE

echo "✅ Deployment finished!"
