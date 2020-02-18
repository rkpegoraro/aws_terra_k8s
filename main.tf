terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "aws" {
  region = "us-east-2" //Ohio

  # Allow any 2.x version of the AWS provider
  # version = "~> 2.0"
}

# resource "aws_key_pair" "k8s-test" {
#   key_name   = "k8s-test"
#   public_key = "${file("terraform-demo.pub")}"
# }

resource "aws_instance" "k8s-masters" {
  count         = "3"
  ami           = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
  instance_type = "t2.micro"
  key_name      = "k8s-test"
#   user_data     = <<-EOF
#                   #!/bin/bash
#                   echo "Hello, World" > index.html
#                   nohup busybox httpd -f -p ${var.server_port} &

#                   EOF

  tags = {
    Name  = "k8s-master-${count.index + 1}"
    Batch = "Terraform"
  }
}

# resource "aws_security_group" "k8s-multimaster" {
#   name = var.instance_security_group_name

#   ingress {
#     from_port   = var.server_port
#     to_port     = var.server_port
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# data "aws_vpc" "default" {
#   default = true
# }

# data "aws_subnet_ids" "default" {
#   vpc_id = data.aws_vpc.default.id
# }
