#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Setting up prerequisites..."

# 1️⃣ Ensure ubuntu user is in Docker group
sudo usermod -aG docker ubuntu
#newgrp docker || true

# 2️⃣ Clean disk space and old images
docker system prune -a -f --volumes || true
sudo apt clean
rm -rf charts images .helm .ansible_tmp

# 3️⃣ Install system dependencies
sudo apt update
sudo apt install -y \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    apt-transport-https \
    ca-certificates \
    software-properties-common

# 4️⃣ Install Docker (if not already installed)
if ! command -v docker &>/dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
fi

# 5️⃣ Install Helm
if ! command -v helm &>/dev/null; then
    echo "⛵ Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# 6️⃣ Install kubectl
if ! command -v kubectl &>/dev/null; then
    echo "☸️ Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

# 7️⃣ Install Ansible
sudo apt install -y ansible
pip3 install --user kubernetes jinja2 pyyaml

# 8️⃣ Fix permissions for the project
sudo chown -R ubuntu:ubuntu .
chmod -R u+rw .

echo "✅ Prerequisites are fully installed and ready!"
