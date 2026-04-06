terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "inference" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "inference-vpc" }
}

resource "aws_subnet" "inference" {
  vpc_id                  = aws_vpc.inference.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true
  tags = { Name = "inference-subnet" }
}

resource "aws_internet_gateway" "inference" {
  vpc_id = aws_vpc.inference.id
  tags   = { Name = "inference-igw" }
}

resource "aws_route_table" "inference" {
  vpc_id = aws_vpc.inference.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.inference.id
  }
  tags = { Name = "inference-rt" }
}

resource "aws_route_table_association" "inference" {
  subnet_id      = aws_subnet.inference.id
  route_table_id = aws_route_table.inference.id
}

resource "aws_security_group" "inference" {
  name        = "inference-sg"
  description = "Distributed inference service"
  vpc_id      = aws_vpc.inference.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "inference-sg" }
}

resource "aws_iam_role" "inference" {
  name = "inference-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_full" {
  role       = aws_iam_role.inference.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role_policy" "s3_access" {
  name = "s3-model-access"
  role = aws_iam_role.inference.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.models.arn,
          "${aws_s3_bucket.models.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_describe" {
  name = "ec2-describe-access"
  role = aws_iam_role.inference.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:DescribeImages", "ec2:DescribeInstances", "ec2:DescribeInstanceStatus"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "inference" {
  name = "inference-instance-profile"
  role = aws_iam_role.inference.name
}

resource "aws_key_pair" "inference" {
  key_name   = "inference-key"
  public_key = file(pathexpand("~/.ssh/inference_key.pub"))
}

locals {
  ubuntu_ami = "ami-0685c90b40d39e754"
}

resource "aws_instance" "master" {
  ami                    = local.ubuntu_ami
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.inference.key_name
  vpc_security_group_ids = [aws_security_group.inference.id]
  iam_instance_profile   = aws_iam_instance_profile.inference.name
  subnet_id              = aws_subnet.inference.id
  user_data              = file("${path.module}/setup_master.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "inference-master" }
}

resource "aws_instance" "worker" {
  count                  = 2
  ami                    = local.ubuntu_ami
  instance_type          = "c6i.xlarge"
  key_name               = aws_key_pair.inference.key_name
  vpc_security_group_ids = [aws_security_group.inference.id]
  iam_instance_profile   = aws_iam_instance_profile.inference.name
  subnet_id              = aws_subnet.inference.id
  user_data              = file("${path.module}/setup_worker.sh")

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = { Name = "inference-worker-${count.index + 1}" }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "models" {
  bucket        = "imagenet-distributedinference-${random_id.suffix.hex}"
  force_destroy = true
  tags          = { Name = "inference-models" }
}

resource "aws_s3_bucket_public_access_block" "models" {
  bucket                  = aws_s3_bucket.models.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "master_ip" {
  value = aws_instance.master.public_ip
}

output "master_private_ip" {
  value = aws_instance.master.private_ip
}

output "worker_ips" {
  value = aws_instance.worker[*].public_ip
}

output "worker_private_ips" {
  value = aws_instance.worker[*].private_ip
}

output "bucket_name" {
  value = aws_s3_bucket.models.bucket
}

output "ssh_master" {
  value = "ssh -i ~/.ssh/inference_key ubuntu@${aws_instance.master.public_ip}"
}

output "ssh_worker1" {
  value = "ssh -i ~/.ssh/inference_key ubuntu@${aws_instance.worker[0].public_ip}"
}

output "ssh_worker2" {
  value = "ssh -i ~/.ssh/inference_key ubuntu@${aws_instance.worker[1].public_ip}"
}