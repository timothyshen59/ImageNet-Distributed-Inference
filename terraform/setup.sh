#!/bin/bash
set -e 
set -x 

apt-get update -y 
apt-get upgrade -y 
apt-get install -y curl wget git unzip 

#Docker + Docker Compose 
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu 
systemctl enable docker 
systemctl start docker

curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

apt-get install -y awscli 



#Pre-pull NVIDIA Triton Image
docker pull nvcr.io/nvidia/tritonserver:26.02-py3

#Setup 
cd /home/ubuntu/distributedinference
sudo -u ubuntu docker-compose up -d --build

#Done
echo "Setup complete $(date)" > /home/ubuntu/setup_done.txt


