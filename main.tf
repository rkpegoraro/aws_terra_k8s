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
# resource "aws_subnet" "k8s_subnet" {
#   cidr_block = cidrsubnet(aws_vpc.k8s-vpc.cidr_block, 3, 1)
#   vpc_id = aws_vpc.k8s_vpc.id
#   availability_zone = "us-east-2a"
# }

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Security Group
resource "aws_security_group" "k8s_multimaster" {
  
  name = "k8s_multimaster"

  # ssh access
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  
  # full permission among hosts in this security group
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = true
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
resource "aws_instance" "k8s_proxy" {

  ami           = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
  instance_type = "t2.micro"
  key_name      = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s_multimaster.id]
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
resource "aws_instance" "k8s_masters" {
  count         = "1"
  ami           = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
  instance_type = "t2.micro"
  key_name      = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s_multimaster.id]
  user_data     = <<-EOF
                  #!/bin/bash
                  sudo hostname "${var.master_prefix}${count.index + 1}"
                  sudo echo "${var.master_prefix}${count.index + 1}" > /etc/hostname
                  sudo apt-get update
                  curl -fsSL https://get.docker.com | sh
                  EOF

  tags = {
    Name  = "${var.master_prefix}${count.index + 1}"
  }

}

# K8s Worker Instances
resource "aws_instance" "k8s_workers" {
  count         = "1"
  ami           = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
  instance_type = "t2.micro"
  key_name      = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s_multimaster.id]
  user_data     = <<-EOF
                  #!/bin/bash
                  sudo hostname "${var.worker_prefix}${count.index + 1}"
                  sudo echo "${var.worker_prefix}${count.index + 1}" > /etc/hostname
                  sudo apt-get update
                  curl -fsSL https://get.docker.com | sh
                  EOF

  tags = {
    Name  = "${var.worker_prefix}${count.index + 1}"
  }
}

locals {
  # A list of all instances created
  instance_list = concat([aws_instance.k8s_proxy], aws_instance.k8s_masters, aws_instance.k8s_workers)
}

# Create hosts file on proxy server
resource "null_resource" "proxy_hosts" {
  # # Changes to any instance of the cluster requires re-provisioning
  # triggers = {
  #   cluster_instance_ids = "${join(",", aws_instance.cluster.*.id)}"
  # }

  count = length(local.instance_list)

  depends_on = [
    aws_instance.k8s_proxy,
    aws_instance.k8s_masters,
    aws_instance.k8s_workers,
  ]

  connection {
    private_key = "${file(var.private_key)}"
    user        = "ubuntu"
    host = element(local.instance_list.*.public_ip, count.index)
  }

  provisioner "remote-exec" {
    # Change /etc/host file
    inline = [
      for host in local.instance_list: 
        "echo ${host.private_ip} ${host.tags.Name} | sudo tee -a /etc/hosts"
    ]
  }
}