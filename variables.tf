variable "private_key" {
  default = "C:\\tools\\keys\\k8s-test.pem"
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
