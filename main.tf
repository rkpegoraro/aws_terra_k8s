terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "aws" {
  region = "us-east-2" //Ohio
  
  # Locks AWS provider version
  version = "~> 2.49"
}

# # VPC
# resource "aws_vpc" "k8s-vpc" {
#   cidr_block = "10.0.0.0/16"
#   enable_dns_hostnames = true
#   enable_dns_support = true
#   tags = {
#     Name = "k8s-vpc"
#   }
# }

# // Subnet
# resource "aws_subnet" "k8s-subnet" {
#   cidr_block = cidrsubnet(aws_vpc.k8s-vpc.cidr_block, 3, 1)
#   vpc_id = aws_vpc.k8s-vpc.id
#   availability_zone = "us-east-2a"
# }

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Security Group
resource "aws_security_group" "k8s-multimaster" {
  
  name = "k8s-multimaster"

  # ssh access
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  
  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Proxy Instance
resource "aws_instance" "k8s-proxy" {

  ami           = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
  instance_type = "t2.micro"
  key_name      = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s-multimaster.id]
  user_data     = <<-EOF
                  #!/bin/bash
                  sudo hostname "${var.proxy_hostname}"
                  sudo echo "${var.proxy_hostname}" > /etc/hostname
                  sudo apt-get update
                  sudo apt-get install -y haproxy
                  EOF

  tags = {
    Name  = var.proxy_hostname
  }

}

# K8s Master Instances
resource "aws_instance" "k8s-masters" {
  count         = "3"
  ami           = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
  instance_type = "t2.micro"
  key_name      = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s-multimaster.id]
  user_data     = <<-EOF
                  #!/bin/bash
                  sudo hostname "k8s-master-0${count.index + 1}"
                  sudo echo "k8s-master-0${count.index + 1}" > /etc/hostname
                  sudo apt-get update
                  curl -fsSL https://get.docker.com | sh
                  EOF

  tags = {
    Name  = "k8s-master-0${count.index + 1}"
  }

}

# K8s Worker Instances
resource "aws_instance" "k8s-workers" {
  count         = "3"
  ami           = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
  instance_type = "t2.micro"
  key_name      = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s-multimaster.id]
  user_data     = <<-EOF
                  #!/bin/bash
                  sudo hostname "k8s-worker-0${count.index + 1}"
                  sudo echo "k8s-worker-0${count.index + 1}" > /etc/hostname
                  sudo apt-get update
                  curl -fsSL https://get.docker.com | sh
                  EOF

  tags = {
    Name  = "k8s-worker-0${count.index + 1}"
  }

}
