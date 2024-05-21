# 1. Install Docker
# Add Docker's official GPG key:
sudo apt-get update -y
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings -y
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
# Install the Docker packages.
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
usermod -aG docker $(whoami)
sudo systemctl enable docker
sudo systemctl enable containerd
sudo systemctl restart docker


# Verify that the Docker Engine installation is successful by running the hello-world image
# sudo docker run hello-world

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
# Add yum repo file for Kubernetes
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
# Add Software Repositories
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/kubernetes.gpg] http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list
# Ensure all packages are up to date:
sudo apt update -y

# Install Kubernetes Tools
# Kubeadm. A tool that initializes a Kubernetes cluster by fast-tracking the setup using community-sourced best practices.
# Kubelet. The work package that runs on every node and starts containers. The tool gives you command-line access to clusters.
# Kubectl. The command-line interface for interacting with clusters.
# Run the install command:
sudo apt install kubeadm kubelet kubectl -y
sudo systemctl enable kubelet
sudo systemctl restart containerd
sudo systemctl restart kubelet


# Mark the packages as held back to prevent automatic installation, upgrade, or removal:
sudo apt-mark hold kubeadm kubelet kubectl

# 3. Deploy Kubernetes
# Disable all swap spaces with the swapoff command:
sudo swapoff -a

#Then use the sed command below to make the necessary adjustments to the /etc/fstab file:
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configure NetworkManager before attempting to use Calico networki