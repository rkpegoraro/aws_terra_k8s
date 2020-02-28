variable "private_key" {
  default = "~/.ssh/k8s-test.pem"
}

variable "ami" {
  default = "ami-0b51ab7c28f4bf5a6" //Ubuntu 18_04
}

variable "instance_type" {
  default = {
    proxy = "t2.micro"
    master = "t2.micro"
    worker = "t2.micro"
  }
}

variable "master_count" {
  default = 3
}

variable "worker_count" {
  default = 1
}

variable "remote_user" {
  default = "ubuntu"
}

variable "proxy_hostname" {
  description = "Hostname of the HAProxy server"
  type        = string
  default     = "k8s-haproxy-1"
}

variable "master_prefix" {
  description = "Prefix of the master k8s hosts"
  type        = string
  default     = "k8s-master-"
}

variable "worker_prefix" {
  description = "Prefix of the worker k8s hosts"
  type        = string
  default     = "k8s-worker-"
}
