#!/bin/bash

# Đặt DEBIAN_FRONTEND thành noninteractive để tránh lỗi dpkg-preconfigure
export DEBIAN_FRONTEND=noninteractive

# 1. Install Docker
# Add Docker's official GPG key:
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
# Install the Docker packages.
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $(whoami)
sudo systemctl enable docker
sudo systemctl enable containerd
sudo systemctl restart docker

# 2. Install Kubernetes
# Set up the IPV4 bridge on all nodes
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Add apt repo file for Kubernetes
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
# Add Software Repositories
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/kubernetes.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
# Ensure all packages are up to date:
sudo apt-get update -y

# Install Kubernetes Tools
sudo apt-get install -y kubeadm kubelet kubectl
sudo systemctl enable kubelet
sudo systemctl restart containerd
sudo systemctl restart kubelet

# Mark the packages as held back to prevent automatic installation, upgrade, or removal:
sudo apt-mark hold kubeadm kubelet kubectl

# 3. Deploy Kubernetes
# Disable all swap spaces with the swapoff command:
sudo swapoff -a

# Then use the sed command below to make the necessary adjustments to the /etc/fstab file:
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configure NetworkManager before attempting to use Calico networking