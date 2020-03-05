#====================#
# AWS Infrastructure #
#====================#

variable "private_key" {
  description = "Path and file name of the private key to be used to connect to the AWS account"
  default = "~/.ssh/k8s-test.pem"
}

variable "ami" {
  description = "AMI to be used on the new virtual machines"
  default = "ami-0b51ab7c28f4bf5a6"
}

variable "instance_type" {
  description = "AMI to be used on the new virtual machines"
  default = {
    proxy = "t2.micro"
    master = "t3a.small"
    worker = "t3a.small"
  }
}

variable "master_count" {
  description = "Number of kubernetes master nodes"
  default = 3
}

variable "worker_count" {
  description = "Number of kubernetes worker nodes"
  default = 3
}

variable "remote_user" {
  description = "Remote user to be used at the virtual machines"
  default = "ubuntu"
}

variable "proxy_hostname" {
  description = "Hostname of the HAProxy server"
  default     = "k8s-haproxy-1"
}

variable "master_prefix" {
  description = "Prefix of the master k8s hosts"
  default     = "k8s-master-"
}

variable "worker_prefix" {
  description = "Prefix of the worker k8s hosts"
  default     = "k8s-worker-"
}

#===========================#
# Kubernetes infrastructure #
#===========================#

variable "action" {
  description = "Which action have to be done on the cluster (create, add_worker, remove_worker, or upgrade)"
  default     = "create"
}

variable "worker" {
  description = "List of worker IPs to remove"
  default = [""]
}

variable "vm_distro" {
  description = "Linux distribution of the vSphere virtual machines (ubuntu/centos/debian/rhel)"
  default = "ubuntu"
}

variable "k8s_kubespray_url" {
  description = "Kubespray git repository"
  default     = "https://github.com/kubernetes-incubator/kubespray.git"
}

variable "k8s_kubespray_version" {
  description = "Kubespray version"
  default     = "2.12.2"
}

variable "k8s_version" {
  description = "Version of Kubernetes that will be deployed"
  default     = "1.16.6"
}

variable "k8s_network_plugin" {
  description = "Kubernetes network plugin (calico/canal/flannel/weave/cilium/contiv/kube-router)"
  default     = "flannel"
}

variable "k8s_dns_mode" {
  description = "Which DNS to use for the internal Kubernetes cluster name resolution (example: kubedns, coredns, etc.)"
  default     = "coredns"
}
