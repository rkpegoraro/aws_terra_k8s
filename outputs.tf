output "proxy_private_IP" {
  value = aws_instance.k8s-proxy.private_ip
}

output "masters_private_IPs" {
  value = {
    for instance in aws_instance.k8s-masters:
    instance.tags.Name => instance.private_ip
  }
}

output "workers_private_IPs" {
  value = {
    for instance in aws_instance.k8s-workers:
    instance.tags.Name => instance.private_ip
  }
}

output "proxy_public_IP" {
  value = aws_instance.k8s-proxy.public_ip
}

output "masters_public_IPs" {
  value = {
    for instance in aws_instance.k8s-masters:
    instance.tags.Name => instance.public_ip
  }
}
output "workers_public_IPs" {
  value = {
    for instance in aws_instance.k8s-workers:
    instance.tags.Name => instance.public_ip
  }
}
