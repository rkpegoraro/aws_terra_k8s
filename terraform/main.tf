terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "aws" {
  region = "us-east-2" //Ohio

  # # Locks AWS provider version
  # version = "~> 2.49"
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
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
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

  ami                    = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
  instance_type          = "t2.micro"
  key_name               = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s_multimaster.id]
  user_data              = <<-EOF
                  #!/bin/bash
                  sudo hostname "${var.proxy_hostname}"
                  sudo echo "${var.proxy_hostname}" > /etc/hostname
                  sudo apt-get update
                  sudo apt-get -qq install python -y

                  # sudo apt-get install -y haproxy
                  # #TODO look for a more elagant way to copy the haproxy.cfg
                  # # I was not able to copy a local file to /etc/haproxy/haproxy.cfg using the file provisioner
                  # # I had to copy the file to /tmp them opem another connection with remote-exec to copy the file to the prper place
                  # # That was too messy
                  # echo "" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "frontend kubernetes" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "    mode tcp" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "    bind k8s-haproxy-1:6443" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "    option tcplog" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "    default_backend k8s-masters" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "backend k8s-masters" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "    mode tcp" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "    balance roundrobin" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "    option tcp-check" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "    server k8s-master-1 k8s-master-1:6443 check fall 3 rise 2" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "    server k8s-master-2 k8s-master-2:6443 check fall 3 rise 2" | sudo tee -a /etc/haproxy/haproxy.cfg
                  # echo "    server k8s-master-3 k8s-master-3:6443 check fall 3 rise 2" | sudo tee -a /etc/haproxy/haproxy.cfg
                  EOF

  tags = {
    Name = var.proxy_hostname
  }

}

# K8s Master Instances
resource "aws_instance" "k8s_masters" {
  count                  = "1"
  ami                    = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
  instance_type          = "t2.micro"
  key_name               = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s_multimaster.id]
  user_data              = <<-EOF
                  #!/bin/bash
                  sudo hostname "${var.master_prefix}${count.index + 1}"
                  sudo echo "${var.master_prefix}${count.index + 1}" > /etc/hostname
                  sudo apt-get update
                  curl -fsSL https://get.docker.com | sh
                  EOF

  tags = {
    Name = "${var.master_prefix}${count.index + 1}"
  }

}

# K8s Worker Instances
resource "aws_instance" "k8s_workers" {
  count                  = "1"
  ami                    = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
  instance_type          = "t2.micro"
  key_name               = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s_multimaster.id]
  user_data              = <<-EOF
                  #!/bin/bash
                  sudo hostname "${var.worker_prefix}${count.index + 1}"
                  sudo echo "${var.worker_prefix}${count.index + 1}" > /etc/hostname
                  sudo apt-get update
                  curl -fsSL https://get.docker.com | sh
                  EOF

  tags = {
    Name = "${var.worker_prefix}${count.index + 1}"
  }
}

locals {
  # A list of all instances created
  instance_list = concat([aws_instance.k8s_proxy], aws_instance.k8s_masters, aws_instance.k8s_workers)
}

# # Edit hosts file on all created instances
# resource "null_resource" "edit_hosts" {
#   # # Changes to any instance of the cluster requires re-provisioning
#   # triggers = {
#   #   cluster_instance_ids = "${join(",", aws_instance.cluster.*.id)}"
#   # }

#   count = length(local.instance_list)

#   depends_on = [
#     aws_instance.k8s_proxy,
#     aws_instance.k8s_masters,
#     aws_instance.k8s_workers,
#   ]

#   connection {
#     type        = "ssh"
#     user        = "ubuntu"
#     private_key = "${file(var.private_key)}"
#     host        = element(local.instance_list.*.public_ip, count.index)
#   }

#   provisioner "remote-exec" {
#     # Change /etc/host file
#     inline = [
#       for host in local.instance_list :
#       "echo ${host.private_ip} ${host.tags.Name} | sudo tee -a /etc/hosts"
#     ]
#   }
# }

variable "names" {
  description = "A list of names"
  type        = list(string)
  default     = ["neo", "trinity", "morpheus"]
}

# Create local inventory
resource "null_resource" "ansible_inventory" {
  
  depends_on = [
    aws_instance.k8s_proxy,
    aws_instance.k8s_masters,
    aws_instance.k8s_workers,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      touch inventory.ini
      echo "[haproxy]" | tee -a inventory.ini
      echo "${aws_instance.k8s_proxy.public_ip} | tee -a inventory.ini
      echo "[k8s_masters]" | tee -a inventory.ini
      %{ for node in aws_instance.k8s_masters }
        echo ${node.public_ip} | tee -a inventory.ini
      %{ endfor ~}
      echo "[k8s_workers]" | tee -a inventory.ini
      %{ for node in aws_instance.k8s_workers }
        echo ${node.public_ip} | tee -a inventory.ini
      %{ endfor ~}
      export ANSIBLE_HOST_KEY_CHECKING=False;
	    #ansible-playbook -u ${var.remote_user} --private-key ${var.private_key} -i inventory.ini ../playbooks/install_haproxy.yml
    EOT  
  }
}

