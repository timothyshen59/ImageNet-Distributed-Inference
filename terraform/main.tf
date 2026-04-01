terraform { 
    required_providers { 
        aws = { 
            source = "hashicorp/aws" 
            version = " ~> 5.0" 
        }
    }
} 

provider "aws" { 
    region = "us-west-2"
}

resource "aws_iam_role" "inference" { 
    name = "inference-ec2-role" 

    assume_role_policy = jsonencode({ 
        Version = "2012-10-17" 
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow" 
            Prinicipal = {
                Service = "ec2.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "ecr" { 
    role = aws_iam_role.inference.name 
    policy_arn = "arn:aws:iam:aws:policy/AmazonEC2ContainerRegisterReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecr_full" { 
    role = aws_iam_role.inference.name 
    policy_arn = "arn:aws:iam:aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_instance_profile" "inference" { 
    name = "inference-instance-profile" 
    role = aws_iam_role.inference.name 
}

resource "aws_key_pair" "inference" { 
    key_name = "inference-key" 
    public_key = 
}

resource "aws_security_group" "inference' { 
    name = "inference-sg" 
    description  = "Distributed ImageNet Inference Service" 


    ingress {
        from_port   = 22              # SSH port
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]  
    }                               # in production you'd lock this to your IP

    ingress {
        from_port   = 8000            # FastAPI
        to_port     = 8000
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 8080            # Triton HTTP
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 8001            # Triton gRPC
        to_port     = 8001
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 9090            # Prometheus
        to_port     = 9090
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 3001            # Grafana
        to_port     = 3001
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress { 
        from_port   = 0
        to_port     = 0 
        protocol   = "-1" 
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "inference" { 
    ami = "ami-0c55b159cbfafe1f0"

    instance_type = "c5.xlarge" 

    key_name  = aws_key_pair.inference.key_name 
    vpc_security_group_ids = [aws_security_group.inference.id]
    iam_instance_profile = aws_iam_instance_profile.inference.name 

    user_data = file("${path.module}/setup.sh")

    root_block_device { 
        volume_size = 50 
        volume_type = "gp3"
    }


    tags = { 
        Name = "distributed-infernce" 
    }

    output "instance_ip" { 
        value = aws_instance.inference.public_ip 
    }

    output "ssh_command" { 
        value = "ssh ubuntu@{aws_instance.inference.public_ip }" 
    }
}