#!/bin/bash
# scripts/setup_k8s.sh
set -e

PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

echo "=== Initializing K8s master ==="
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$PRIVATE_IP

echo "=== Setting up kubeconfig ==="
mkdir -p /home/ubuntu/.kube
sudo cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo "=== Installing Flannel ==="
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "=== Waiting for master node to be Ready ==="
until kubectl get nodes | grep -q "Ready"; do
    echo "Waiting..."
    sleep 5
done

echo "=== Join command for workers ==="
echo "Run this on each worker node:"
kubeadm token create --print-join-command

echo "=== Master setup complete ==="
kubectl get nodes