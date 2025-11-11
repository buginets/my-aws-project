#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Setting up prerequisites for the project..."

# -------------------------------
# Update system
# -------------------------------
sudo apt update && sudo apt upgrade -y

# -------------------------------
# Install core tools
# -------------------------------
sudo apt install -y \
    curl \
    wget \
    git \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    python3-pip \
    sshpass

# -------------------------------
# Docker install
# -------------------------------
if ! command -v docker &>/dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh

    sudo usermod -aG docker $USER
    newgrp docker || true
else
    echo "🐳 Docker already installed"
fi

# -------------------------------
# Helm install
# -------------------------------
if ! command -v helm &>/dev/null; then
    echo "⛵ Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "⛵ Helm already installed"
fi

# -------------------------------
# Kubectl install
# -------------------------------
if ! command -v kubectl &>/dev/null; then
    echo "☸️ Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
else
    echo "☸️ kubectl already installed"
fi

# -------------------------------
# Ansible install
# -------------------------------
if ! command -v ansible &>/dev/null; then
    echo "📦 Installing Ansible..."
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt update
    sudo apt install -y ansible
else
    echo "📦 Ansible already installed"
fi

# -------------------------------
# Python Kubernetes module
# -------------------------------
pip3 install --user kubernetes
