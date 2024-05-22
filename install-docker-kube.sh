#!/bin/bash

# Đặt DEBIAN_FRONTEND thành noninteractive để tránh lỗi dpkg-preconfigure
export DEBIAN_FRONTEND=noninteractive

# 1. Install Containerd
# Install Containerd Runtime
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Enable docker repository
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

sudo apt update -y
sudo apt install -y containerd.io

# Configure containerd so that it starts using systemd as cgroup.
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

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
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y

# Install Kubernetes Tools
sudo apt-get install -y kubeadm kubelet kubectl

# Mark the packages as held back to prevent automatic installation, upgrade, or removal:
sudo apt-mark hold kubeadm kubelet kubectl

# 3. Deploy Kubernetes
# Disable all swap spaces with the swapoff command:
sudo swapoff -a

# Then use the sed command below to make the necessary adjustments to the /etc/fstab file:
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

sudo kubeadm init --control-plane-endpoint=k8s.master.pong

# Configure NetworkManager before attempting to use Calico networking