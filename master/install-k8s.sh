# Step 1: Update and more Ubuntu (all nodes)
sudo apt -y update
DEBIAN_FRONTEND=noninteractive sudo apt install ca-certificates curl telnet net-tools -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Step 2: Disable Swap (all nodes)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Step 3: Add Kernel Parameters (all nodes)
# Load the required kernel modules on all nodes:
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
# Configure the critical kernel parameters for Kubernetes using the following:
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Step 4: Install Containerd Runtime (all nodes)
# We are using the containerd runtime. Install containerd and its dependencies with the following commands:
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y curl gnupg2 software-properties-common apt-transport-https
# Enable the Docker repository:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Update the package list and install containerd:
sudo apt -y update
sudo apt install -y containerd.io
# Configure containerd to start using systemd as cgroup:
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
# Restart and enable the containerd service:
sudo systemctl restart containerd
sudo systemctl enable containerd

# Step 5: Add Apt Repository for Kubernetes (all nodes)
# Kubernetes packages are not available in the default Ubuntu 22.04 repositories. Add the Kubernetes repositories with the following commands:
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Step 6: Install Kubectl, Kubeadm, and Kubelet (all nodes)
# After adding the repositories, install essential Kubernetes components, including kubectl, kubelet, and kubeadm, on all nodes with the following commands:
sudo apt -y update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Step 7: Initialize Kubernetes Cluster with Kubeadm (master node)
# With all the prerequisites in place, initialize the Kubernetes cluster on the master node using the following Kubeadm command:
sudo kubeadm init k8s-master-pong
# After the initialization is complete make a note of the kubeadm join command for future reference.
# Run the following commands on the master node:
# Kiểm tra kết quả của lệnh khởi tạo
if [ $? -eq 0 ]; then
    echo "Kubernetes master initialization completed successfully."
    echo "Make a note of the 'kubeadm join' command for future reference."

    # Thực hiện các bước cấu hình kubectl trên master node
    sudo mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
else
    echo "Kubernetes master initialization failed. Please check the logs for more details."
    exit 1
fi

# Step 8: Install Kubernetes Network Plugin (master node)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
# Next, use kubectl commands to check the cluster and node status:
kubectl get pods -n kube-system
kubectl get nodes