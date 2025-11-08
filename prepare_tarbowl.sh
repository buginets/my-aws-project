#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# -------------------------------
# Helm home & config
# -------------------------------
export HELM_HOME="$SCRIPT_DIR/.helm"
export XDG_CONFIG_HOME="$HELM_HOME/config"
export XDG_DATA_HOME="$HELM_HOME/data"
export XDG_CACHE_HOME="$HELM_HOME/cache"

# Create all nested directories recursively
mkdir -p "$XDG_CONFIG_HOME/helm/registry" \
         "$XDG_DATA_HOME" \
         "$XDG_CACHE_HOME/repository"

# Ensure correct permissions
chmod -R 700 "$HELM_HOME"

# Create empty files to avoid Helm trying to write to non-existent files
touch "$XDG_CONFIG_HOME/helm/registry/config.json"
touch "$XDG_CACHE_HOME/repository/repositories.lock"

echo "✅ Helm home and config set to project folder: $HELM_HOME"


# -------------------------------
# 2️⃣ Charts & images folders
# -------------------------------
mkdir -p charts images

# -------------------------------
# 3️⃣ Helm chart versions & images
# -------------------------------
PROMETHEUS_VER="27.44.1"
GRAFANA_VER="12.1.8"
JENKINS_VER="5.8.107"
MYSQL_VER="14.0.3"
REDIS_VER="23.2.12"
INGRESS_VER="4.14.0"
WORDPRESS_VER="27.1.8"

PROMETHEUS_IMG="quay.io/prometheus/prometheus:v2.53.0"
GRAFANA_IMG="bitnamilegacy/grafana:latest"
JENKINS_IMG="jenkins/jenkins:lts-jdk21"
MYSQL_IMG="bitnamilegacy/mysql:latest"
REDIS_IMG="bitnamilegacy/redis:latest"
COREDNS_IMG="coredns/coredns:1.13.1"
RKE_TOOLS_IMG="rancher/rke-tools:v0.1.114"
WORDPRESS_IMG="bitnamilegacy/wordpress:latest"

# -------------------------------
# 4️⃣ Add repos and update
# -------------------------------
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jenkins https://charts.jenkins.io
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# -------------------------------
# 5️⃣ Download Helm charts
# -------------------------------
echo "Downloading Helm charts..."
helm fetch prometheus-community/prometheus --version ${PROMETHEUS_VER} -d charts && mv charts/prometheus-${PROMETHEUS_VER}.tgz charts/prometheus.tar.gz
helm fetch bitnami/grafana --version ${GRAFANA_VER} -d charts && mv charts/grafana-${GRAFANA_VER}.tgz charts/grafana.tar.gz
helm fetch jenkins/jenkins --version ${JENKINS_VER} -d charts && mv charts/jenkins-${JENKINS_VER}.tgz charts/jenkins.tar.gz
helm fetch bitnami/mysql --version ${MYSQL_VER} -d charts && mv charts/mysql-${MYSQL_VER}.tgz charts/mysql.tar.gz
helm fetch bitnami/redis --version ${REDIS_VER} -d charts && mv charts/redis-${REDIS_VER}.tgz charts/redis.tar.gz
helm fetch ingress-nginx/ingress-nginx --version ${INGRESS_VER} -d charts && mv charts/ingress-nginx-${INGRESS_VER}.tgz charts/ingress-controller.tar.gz
helm fetch bitnami/wordpress --version ${WORDPRESS_VER} -d charts && mv charts/wordpress-${WORDPRESS_VER}.tgz charts/booking.tar.gz

# Copy placeholders for other microservices
for svc in cars flights hotels notification payment search; do
    cp charts/booking.tar.gz charts/${svc}.tar.gz
done

# -------------------------------
# 6️⃣ Pull and save Docker images
# -------------------------------
echo "Pulling Docker images..."
docker pull ${PROMETHEUS_IMG} && docker save ${PROMETHEUS_IMG} -o images/prometheus.tar.gz
docker pull ${GRAFANA_IMG} && docker save ${GRAFANA_IMG} -o images/grafana.tar.gz
docker pull ${JENKINS_IMG} && docker save ${JENKINS_IMG} -o images/jenkins.tar.gz
docker pull ${MYSQL_IMG} && docker save ${MYSQL_IMG} -o images/mysql.tar.gz
docker pull ${REDIS_IMG} && docker save ${REDIS_IMG} -o images/redis.tar.gz
docker pull ${COREDNS_IMG} && docker save ${COREDNS_IMG} -o images/core-dns.tar.gz
docker pull ${RKE_TOOLS_IMG} && docker save ${RKE_TOOLS_IMG} -o images/rke-tools.tar.gz
docker pull ${WORDPRESS_IMG} && for svc in cars flights hotels notification payment search; do docker save ${WORDPRESS_IMG} -o images/${svc}.tar.gz; done
docker pull rancher/rancher:v2.11.7 && docker save rancher/rancher:v2.11.7 -o images/rancher.tar.gz

echo "✅ Charts and Docker images ready in tarbowl folder."