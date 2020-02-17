provider "aws" {
    region = "us-east-2"
}

resource "aws_instance" "example" {
    ami             = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04 / Ohio USA
    instance_type   = "t2.micro"
}

