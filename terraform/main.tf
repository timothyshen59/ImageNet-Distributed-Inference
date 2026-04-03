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

# ── IAM ──────────────────────────────────────────────
resource "aws_iam_role" "inference" {
  name = "inference-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {                          # ← fixed typo: Prinicipal → Principal
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.inference.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"  # ← fixed: missing :: and typo
}

resource "aws_iam_role_policy_attachment" "ecr_full" {
  role       = aws_iam_role.inference.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"  # ← fixed: missing ::
}

resource "aws_iam_instance_profile" "inference" {
  name = "inference-instance-profile"
  role = aws_iam_role.inference.name
}

# ── NETWORKING ───────────────────────────────────────
resource "aws_key_pair" "inference" {
  key_name   = "inference-key"
  public_key = file(pathexpand("~/.ssh/inference_key.pub"))

}

resource "aws_security_group" "inference" {  # ← fixed: mixed quotes inference' → inference"
  name        = "inference-sg"
  description = "Distributed ImageNet Inference Service"

  ingress {
    from_port   = 22
    to_port     = 22
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── EC2 ──────────────────────────────────────────────
resource "aws_instance" "inference" {
  ami                    = "ami-0685c90b40d39e754"
  instance_type          = "c5.xlarge"
  key_name               = aws_key_pair.inference.key_name
  vpc_security_group_ids = [aws_security_group.inference.id]
  iam_instance_profile   = aws_iam_instance_profile.inference.name
  
  user_data = templatefile("${path.module}/setup.sh", {
    bucket_name = aws_s3_bucket.models.bucket   
  })

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "distributed-inference"
  }
}

# ── OUTPUTS ──────────────────────────────────────────
# ← fixed: outputs were inside aws_instance block, must be at top level
output "instance_ip" {
  value = aws_instance.inference.public_ip
}

output "ssh_command" {
  value = "ssh ubuntu@${aws_instance.inference.public_ip}"  # ← fixed: missing $ in interpolation
}

# ── S3 ───────────────────────────────────────────────
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "models" {
  bucket = "imagenet-distributedinference-${random_id.suffix.hex}"
  force_destroy = true 
  
  tags = {
    Name = "inference-models"
  }
}

resource "aws_s3_bucket_public_access_block" "models" {
  bucket                  = aws_s3_bucket.models.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role_policy" "s3_access" {
  name = "s3-model-access"
  role = aws_iam_role.inference.id    # ← fixed typo: infernece → inference

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.models.arn,
          "${aws_s3_bucket.models.arn}/*"
        ]
      }
    ]
  })
}

output "bucket_name" {
  value = aws_s3_bucket.models.bucket
}