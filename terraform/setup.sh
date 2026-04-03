#!/bin/bash
set -e 
set -x 

# Run upload_model_s3.sh before 
# terraform/setup.sh


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


# Pull Code Over 
git clone https://github.com/timothyshen59/ImageNet-Distributed-Inference.git /home/ubuntu/distributedinference
chown -R ubuntu:ubuntu /home/ubuntu/distributedinference

#Model Download from S3 
BUCKET="${bucket_name}" 

mkdir -p /home/ubuntu/distributedinference/triton_models/vit_int8/1
mkdir -p /home/ubuntu/distributedinference/model

aws s3 cp s3://$BUCKET/triton_models/vit_int8/1/model.onnx \
  /home/ubuntu/distributedinference/triton_models/vit_int8/1/model.onnx

aws s3 cp s3://$BUCKET/model/vit_legacy.onnx \
  /home/ubuntu/distributedinference/model/vit_legacy.onnx
  
#Pre-pull NVIDIA Triton Image
docker pull nvcr.io/nvidia/tritonserver:26.02-py3

#Setup 
cd /home/ubuntu/distributedinference
sudo -u ubuntu docker-compose up -d --build

#Done
echo "Setup complete $(date)" > /home/ubuntu/setup_done.txt


