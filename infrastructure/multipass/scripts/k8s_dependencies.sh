#!/bin/bash

set -e

# Setting colors
YELLOW="\033[1;33m"
NC="\033[0m"

# Disable swap (K8s requirement)
echo -e "${YELLOW}Disabling Swap...${NC}"
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Install containerd
echo -e "${YELLOW}Installing Containerd...${NC}"
# Uninstall all conflicting packages
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release containerd

# Configure Containerd (Critical: Use Systemd Cgroup)
# Kubernetes requires the container runtime to use systemd for cgroups management
# Kubeadm will automatically install and setup kubernetes-cni (The standard one) later, so no need to install CNI plugin for containerd
# CNI Provider will be using are one of those (Flannel, Calico)
echo -e "${YELLOW}Configuring Containerd...${NC}"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd

# Install Kubeadm, Kubelet and Kubectl
echo -e "${YELLOW}Installing Kubernetes tools...${NC}"
sudo apt-get update
# apt-transport-https may be a dummy package; if so, we can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Download the public signing key for the Kubernetes package repositories
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the appropriate Kubernetes apt repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl