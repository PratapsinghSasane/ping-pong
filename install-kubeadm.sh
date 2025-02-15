#!/bin/sh

set -e  # Exit immediately if a command exits with a non-zero status

# Define Kubernetes version
K8S_VERSION="1.29.0"
CRI_VERSION="1.29.0"

# Update Alpine packages
apk update && apk upgrade
apk add --no-cache curl bash openrc iptables

# Enable kernel modules
modprobe overlay
modprobe br_netfilter
echo "overlay" >> /etc/modules
echo "br_netfilter" >> /etc/modules

# Configure sysctl settings for Kubernetes networking
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# Install containerd (required container runtime)
apk add containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
rc-service containerd restart
rc-update add containerd default

# Download Kubernetes binaries
cd /usr/local/bin
curl -LO "https://dl.k8s.io/release/v${K8S_VERSION}/bin/linux/amd64/kubeadm"
curl -LO "https://dl.k8s.io/release/v${K8S_VERSION}/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/v${K8S_VERSION}/bin/linux/amd64/kubelet"
chmod +x kubeadm kubectl kubelet

# Install crictl (Container Runtime Interface tool)
curl -LO "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRI_VERSION}/crictl-v${CRI_VERSION}-linux-amd64.tar.gz"
tar -xzf crictl-v${CRI_VERSION}-linux-amd64.tar.gz -C /usr/local/bin
rm crictl-v${CRI_VERSION}-linux-amd64.tar.gz

# Start kubelet service
rc-service kubelet start
rc-update add kubelet default

# Initialize Kubernetes cluster
kubeadm init --pod-network-cidr=192.168.0.0/16

# Configure kubectl for the root user
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Install a network plugin (Flannel)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Print success message
echo "Kubeadm installation completed! Run 'kubectl get nodes' to verify."
