terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "aws" {
  region = "us-east-2" //Ohio

  # Locks AWS provider version
  version = "~> 2.50"
}

provider "null" {
  # Locks Null provider version
  version = "~> 2.1"
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

  # ICMP (ping) from anywhere
  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


// Lookup latest Ubuntu 18.04 AMI
data "aws_ami" "ubuntu18" {
  most_recent = true
  owners = ["099720109477"] //Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}

# Proxy Instance
resource "aws_instance" "k8s_proxies" {
  count                  = var.proxy_count
  # ami                    = var.ami
  ami                    = data.aws_ami.ubuntu18.id
  instance_type          = var.instance_type["proxy"]
  key_name               = "k8s-test"
  iam_instance_profile   = "k8s-ec2-iam"
  vpc_security_group_ids = [aws_security_group.k8s_multimaster.id]
  user_data              = <<-EOF
                  #!/bin/bash
                  sudo hostname "${var.proxy_prefix}${count.index + 1}"
                  sudo echo "${var.proxy_prefix}${count.index + 1}" > /etc/hostname
                  sudo apt-get update
                  sudo apt-get install -y unzip
                  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                  unzip awscliv2.zip
                  sudo ./aws/install
                  rm -rf ~/aws*
                  EOF

  tags = {
    Name = "${var.proxy_prefix}${count.index + 1}"
  }

}

# K8s Master Instances
resource "aws_instance" "k8s_masters" {
  count                  = var.master_count
  # ami                    = var.ami
  ami                    = data.aws_ami.ubuntu18.id
  instance_type          = var.instance_type["master"]
  key_name               = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s_multimaster.id]
  user_data              = <<-EOF
                  #!/bin/bash
                  sudo hostname "${var.master_prefix}${count.index + 1}"
                  sudo echo "${var.master_prefix}${count.index + 1}" > /etc/hostname
                  sudo apt-get update
                  # docker install
                  curl -fsSL https://get.docker.com | sh
                  EOF

  tags = {
    Name = "${var.master_prefix}${count.index + 1}"
  }

}

# K8s Worker Instances
resource "aws_instance" "k8s_workers" {
  count                  = var.worker_count
  # ami                    = var.ami
  ami                    = data.aws_ami.ubuntu18.id
  instance_type          = var.instance_type["worker"]
  key_name               = "k8s-test"
  vpc_security_group_ids = [aws_security_group.k8s_multimaster.id]
  user_data              = <<-EOF
                  #!/bin/bash
                  sudo hostname "${var.worker_prefix}${count.index + 1}"
                  sudo echo "${var.worker_prefix}${count.index + 1}" > /etc/hostname
                  sudo apt-get update
                  # docker install
                  curl -fsSL https://get.docker.com | sh
                  EOF

  tags = {
    Name = "${var.worker_prefix}${count.index + 1}"
  }
}

# Consolidate all instances on a single list
locals {
  # A list of all instances created
  instance_list = concat(aws_instance.k8s_proxies, aws_instance.k8s_masters, aws_instance.k8s_workers)
}

# Edit hosts file on all created instances
# It is possible to do this with ansible, but I choose to left this as an example
resource "null_resource" "edit_hosts" {
  count = length(local.instance_list)

  depends_on = [
    aws_instance.k8s_proxies,
    aws_instance.k8s_masters,
    aws_instance.k8s_workers,
  ]

  connection { //default ssh
    #type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key)
    host        = element(local.instance_list.*.public_ip, count.index)
  }

  provisioner "remote-exec" {
    # Change /etc/host file
    inline = [
      for host in local.instance_list :
      "echo ${host.private_ip} ${host.tags.Name} | sudo tee -a /etc/hosts"
    ]
  }
}

resource "aws_eip" "proxy_eip" {
  instance = aws_instance.k8s_proxies.0.id
  vpc      = true

  depends_on = [
    null_resource.edit_hosts,
  ]
}

###############################################################################
# Create configuration files
###############################################################################

# Create Keepalived master configuration from Terraform templates #
resource "local_file" "keepalived_master" {
  content  = templatefile("./templates/keepalived_master.tlp", {
    ip_master = aws_instance.k8s_proxies.0.private_ip
    ip_slave  = aws_instance.k8s_proxies.1.private_ip
  })
  filename = "config/keepalived-master.cfg"
}

# Create Keepalived slave configuration from Terraform templates #
resource "local_file" "keepalived_slave" {
  content  = templatefile("./templates/keepalived_slave.tlp", {
    ip_master = aws_instance.k8s_proxies.0.private_ip
    ip_slave  = aws_instance.k8s_proxies.1.private_ip
  })
  filename = "config/keepalived-slave.cfg"
}

# Create Keepalived script on master from Terraform templates #
resource "local_file" "keepalived_master_script" {
  content  = templatefile("./templates/keepalived_failover.tlp", {
    elastic_ip  = aws_eip.proxy_eip.public_ip
    instance_id = aws_instance.k8s_proxies.0.id
  })
  filename = "config/failover_master.sh"
}

# Create Keepalived script on slave from Terraform templates #
resource "local_file" "keepalived_slave_script" {
  content  = templatefile("./templates/keepalived_failover.tlp", {
    elastic_ip  = aws_eip.proxy_eip.public_ip
    instance_id = aws_instance.k8s_proxies.1.id
  })
  filename = "config/failover_slave.sh"
}

# Create HAProxy configuration file from Terraform templates #
resource "local_file" "haproxy_config" {
  content  = templatefile("./templates/haproxy.tlp", {
    masters = aws_instance.k8s_masters.*.tags.Name
  })
  filename = "config/haproxy.cfg"
}

# Create local inventory
resource "null_resource" "ansible_inventory" {
  
  depends_on = [
    aws_eip.proxy_eip,
    aws_instance.k8s_masters,
    aws_instance.k8s_workers,
  ]  

  # Note 1  The sleep command is to wait a bit so the instances are reachable
  # Note 2: The proxy instances are not in a loop because the elastic_ip overwrites the public ip of the first proxy instance, but 
  # seems that the terraform aws_instance is unable to recognized that new public ip
  provisioner "local-exec" {
    command = <<-EOT
      sleep 20s
      > ../ansible/inventory.ini
      echo "[haproxy]" | tee -a ../ansible/inventory.ini
      echo "${aws_instance.k8s_proxies.0.tags.Name} ansible_host=${aws_eip.proxy_eip.public_ip} private_ip=${aws_instance.k8s_proxies.0.private_ip}" | tee -a ../ansible/inventory.ini
      echo "${aws_instance.k8s_proxies.1.tags.Name} ansible_host=${aws_instance.k8s_proxies.1.public_ip} private_ip=${aws_instance.k8s_proxies.1.private_ip}" | tee -a ../ansible/inventory.ini
      echo "[k8s_masters]" | tee -a ../ansible/inventory.ini
      %{ for node in aws_instance.k8s_masters }
        echo "${node.tags.Name} ansible_host=${node.public_ip} private_ip=${node.private_ip}" | tee -a ../ansible/inventory.ini
      %{ endfor ~}
      echo "[k8s_workers]" | tee -a ../ansible/inventory.ini
      %{ for node in aws_instance.k8s_workers }
        echo "${node.tags.Name} ansible_host=${node.public_ip} private_ip=${node.private_ip}" | tee -a ../ansible/inventory.ini
      %{ endfor ~}
      export ANSIBLE_HOST_KEY_CHECKING=False;
      ansible-playbook -i ../ansible/inventory.ini -u ${var.remote_user} --private-key=${var.private_key} ../ansible/playbooks/install_haproxy.yml
    EOT  
  }
}

