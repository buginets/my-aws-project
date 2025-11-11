#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# -------------------------------
# Helm home & config
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
# Charts & images folders
# -------------------------------
mkdir -p charts images
chmod -R 755 charts images

# -------------------------------
# Helm chart versions & images
# -------------------------------
NGINX_VER="21.0.1"
MYSQL_VER="14.0.3"
PROMETHEUS_VER="27.44.0"
GRAFANA_VER="12.1.8"
JENKINS_VER="5.8.107"
SONARQUBE_VER="2025.4.3"
INGRESS_VER="4.14.0"

NGINX_IMG="nginx:latest"
FLASK_IMG="my-flask-app:latest"
MYSQL_IMG="mysql:latest"
PROMETHEUS_IMG="prom/prometheus:latest"
GRAFANA_IMG="grafana/grafana:latest"
JENKINS_IMG="jenkins/jenkins:lts-jdk21"
SONARQUBE_IMG="sonarqube:community"
COREDNS_IMG="coredns/coredns:1.13.1"
RKE_TOOLS_IMG="rancher/rke-tools:v0.1.114"

# -------------------------------
# Build custom Flask app
# -------------------------------
echo "🚀 Building Flask app image..."
docker build -t "${FLASK_IMG}" -f Dockerfile.flask .
echo "✅ Flask image built successfully."

# -------------------------------
# Create backend Helm chart
# -------------------------------
echo "📦 Creating Helm chart for backend app..."
mkdir -p charts/backend/templates

cat > charts/backend/Chart.yaml <<EOF
apiVersion: v2
name: backend
version: 0.1.0
EOF

cat > charts/backend/values.yaml <<EOF
image:
  repository: ${FLASK_IMG}
  tag: latest
service:
  type: ClusterIP
  port: 5000
EOF

cat > charts/backend/templates/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Release.Name }}-backend
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-backend
    spec:
      containers:
      - name: backend
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        ports:
        - containerPort: 5000
EOF

cat > charts/backend/templates/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-backend
spec:
  selector:
    app: {{ .Release.Name }}-backend
  ports:
  - port: {{ .Values.service.port }}
    targetPort: 5000
EOF

helm package charts/backend -d charts && mv charts/backend-0.1.0.tgz charts/backend.tar.gz
echo "✅ Backend Helm chart packaged."

# -------------------------------
# Add repos and update
# -------------------------------
echo "🔄 Adding Helm repos..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo add jenkins https://charts.jenkins.io
helm repo update

# -------------------------------
# Download Helm charts
# -------------------------------
echo "⬇️  Downloading Helm charts..."
helm fetch bitnami/nginx --version ${NGINX_VER} -d charts && mv charts/nginx-${NGINX_VER}.tgz charts/frontend.tar.gz
helm fetch bitnami/mysql --version ${MYSQL_VER} -d charts && mv charts/mysql-${MYSQL_VER}.tgz charts/mysql.tar.gz
helm fetch prometheus-community/prometheus --version ${PROMETHEUS_VER} -d charts && mv charts/prometheus-${PROMETHEUS_VER}.tgz charts/prometheus.tar.gz
helm fetch bitnami/grafana --version ${GRAFANA_VER} -d charts && mv charts/grafana-${GRAFANA_VER}.tgz charts/grafana.tar.gz
helm fetch jenkins/jenkins --version ${JENKINS_VER} -d charts && mv charts/jenkins-${JENKINS_VER}.tgz charts/jenkins.tar.gz
helm fetch sonarqube/sonarqube --version ${SONARQUBE_VER} -d charts && mv charts/sonarqube-${SONARQUBE_VER}.tgz charts/sonarqube.tar.gz
helm fetch ingress-nginx/ingress-nginx --version ${INGRESS_VER} -d charts && mv charts/ingress-nginx-${INGRESS_VER}.tgz charts/ingress-controller.tar.gz
echo "✅ Helm charts downloaded."

# -------------------------------
# Pull and save Docker images
# -------------------------------
echo "🐳 Pulling and saving Docker images..."
pull_and_save() {
    local image="$1"
    local outfile="$2"
    docker pull "$image"
    docker save "$image" -o "$outfile"
    docker rmi "$image"
}

pull_and_save "${NGINX_IMG}" images/frontend.tar.gz
docker save "${FLASK_IMG}" -o images/backend.tar.gz && docker rmi "${FLASK_IMG}"
pull_and_save "${MYSQL_IMG}" images/mysql.tar.gz
pull_and_save "${PROMETHEUS_IMG}" images/prometheus.tar.gz
pull_and_save "${GRAFANA_IMG}" images/grafana.tar.gz
pull_and_save "${JENKINS_IMG}" images/jenkins.tar.gz
pull_and_save "${SONARQUBE_IMG}" images/sonarqube.tar.gz
pull_and_save "${COREDNS_IMG}" images/core-dns.tar.gz
pull_and_save "${RKE_TOOLS_IMG}" images/rke-tools.tar.gz

echo "✅ All Docker images pulled and saved."

# -------------------------------
# Summary
# -------------------------------
echo "🎉 Tarbowl preparation complete!"
echo "Charts saved under:   $(realpath charts)"
echo "Images saved under:   $(realpath images)"
