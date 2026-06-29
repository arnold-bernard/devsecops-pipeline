#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------
# Jenkins + Docker + Trivy installer for Ubuntu
# ------------------------------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Root check
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root. Use sudo."
fi

# Update & install base packages
log_info "Updating package lists..."
apt update -y

log_info "Installing essential packages (wget, curl, gnupg, python3, pip, etc.)..."
apt install -y wget curl gnupg fontconfig openjdk-21-jre python3 python3-pip

# --------------------------------------------------------------------
# 1. JENKINS
# --------------------------------------------------------------------
log_info "Setting up Jenkins repository..."
mkdir -p /etc/apt/keyrings
wget -q -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | \
  tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt update -y
apt install -y jenkins

systemctl daemon-reload
systemctl enable --now jenkins

# --------------------------------------------------------------------
# 2. DOCKER
# --------------------------------------------------------------------
log_info "Removing conflicting Docker packages (if any)..."
apt remove -y docker.io docker-compose docker-compose-v2 \
  docker-doc podman-docker containerd runc 2>/dev/null || true

log_info "Installing Docker..."
apt install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update -y
apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

if systemctl is-active --quiet docker; then
    log_info "Docker is running."
else
    log_warn "Docker failed to start. Check with: systemctl status docker"
fi

# --------------------------------------------------------------------
# 3. ADD USERS TO DOCKER GROUP
# --------------------------------------------------------------------
log_info "Adding 'ubuntu' and 'jenkins' users to the docker group..."
groupadd -f docker

for user in ubuntu jenkins; do
    if id "$user" &>/dev/null; then
        usermod -aG docker "$user"
        log_info "User '$user' added to docker group."
    else
        log_warn "User '$user' does not exist. Skipping."
    fi
done

# --------------------------------------------------------------------
# 4. TRIVY (using the exact commands you provided)
# --------------------------------------------------------------------
log_info "Installing Trivy..."
# Ensure wget and gnupg are present (already installed, but safe)
apt install -y wget gnupg

mkdir -p /usr/share/keyrings
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
    gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | \
    tee /etc/apt/sources.list.d/trivy.list

apt update -y
apt install -y trivy

if command -v trivy &>/dev/null; then
    log_info "Trivy installed successfully: $(trivy --version | head -n1)"
else
    log_warn "Trivy not found in PATH."
fi

# --------------------------------------------------------------------
# 5. JENKINS INITIAL ADMIN PASSWORD
# --------------------------------------------------------------------
sleep 3
if [[ -f /var/lib/jenkins/secrets/initialAdminPassword ]]; then
    PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
    log_info "=================================================="
    log_info "Jenkins installation complete!"
    log_info "Access Jenkins at: http://$(hostname -I | awk '{print $1}'):8080"
    log_info "Initial Admin Password: ${PASSWORD}"
    log_info "=================================================="
else
    log_warn "Initial admin password not yet available. Check /var/lib/jenkins/secrets/initialAdminPassword later."
fi

log_info "All components installed."
log_info "NOTE: Users added to docker group must log out and back in (or run 'newgrp docker') for group changes to take effect."