#!/usr/bin/env bash
# Main deployment script for customer
# ---------------------------
# Steps:
# 1. Ask vault password
# 2. Prepare charts & images
# 3. Set Ansible and Helm local temp directories
# 4. Install Ansible roles if needed
# 5. Run all playbooks sequentially
# 6. Collect dynamic passwords into ansible vault
# ---------------------------

set -euo pipefail

# -------------------------------
# Define project folder
# -------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# -------------------------------
# 1️⃣ Ask for Ansible Vault password
# -------------------------------
read -s -p "Enter Ansible Vault password: " VAULT_PASS
echo
VAULT_FILE="$(mktemp /tmp/.ansible_vault_pass_XXXX)"
umask 177
printf "%s" "$VAULT_PASS" > "$VAULT_FILE"
export ANSIBLE_VAULT_PASSWORD_FILE="$VAULT_FILE"

# -------------------------------
# 2️⃣ Prepare charts & Docker images
# -------------------------------
if [[ ! -f ./prepare_tarbowl.sh ]]; then
  echo "Error: prepare_tarbowl.sh not found!"
  exit 1
fi
chmod +x ./prepare_tarbowl.sh
./prepare_tarbowl.sh

# -------------------------------
# 3️⃣ Set project-local Helm & Ansible temp
# -------------------------------
HELM_HOME="$SCRIPT_DIR/.helm"
export HELM_CONFIG_HOME="$HELM_HOME/config"
export HELM_DATA_HOME="$HELM_HOME/data"
export HELM_CACHE_HOME="$HELM_HOME/cache"
mkdir -p "$HELM_CONFIG_HOME/registry" "$HELM_DATA_HOME" "$HELM_CACHE_HOME/repository"
: > "$HELM_CONFIG_HOME/registry/config.json"
: > "$HELM_CACHE_HOME/repository/repositories.lock"
chmod -R 700 "$HELM_HOME"

export ANSIBLE_LOCAL_TEMP="$SCRIPT_DIR/.ansible_tmp"
mkdir -p "$ANSIBLE_LOCAL_TEMP"
chmod 700 "$ANSIBLE_LOCAL_TEMP"

echo "✅ Helm and Ansible temp set to project folder"

# -------------------------------
# 4️⃣ Install Ansible roles
# -------------------------------
echo "Installing required Ansible roles..."
ansible-galaxy install -r ansible/requirements.yml --roles-path ansible/roles || true

# -------------------------------
# 5️⃣ Run playbooks sequentially
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
  ansible-playbook -i inventory "$pb" --ask-become-pass
done

# -------------------------------
# 6️⃣ Clean up
# -------------------------------
rm -f "$VAULT_FILE"
unset ANSIBLE_VAULT_PASSWORD_FILE

echo "✅ Deployment finished. All secrets encrypted in ansible/group_vars/all.yaml"