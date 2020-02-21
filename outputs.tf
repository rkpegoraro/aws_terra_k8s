output "proxy_private_IP" {
  value = aws_instance.k8s_proxy.private_ip
}

output "masters_private_IPs" {
  value = {
    for instance in aws_instance.k8s_masters:
    instance.tags.Name => instance.private_ip
  }
}

output "workers_private_IPs" {
  value = {
    for instance in aws_instance.k8s_workers:
    instance.tags.Name => instance.private_ip
  }
}

output "proxy_public_IP" {
  value = aws_instance.k8s_proxy.public_ip
}

output "masters_public_IPs" {
  value = {
    for instance in aws_instance.k8s_masters:
    instance.tags.Name => instance.public_ip
  }
}
output "workers_public_IPs" {
  value = {
    for instance in aws_instance.k8s_workers:
    instance.tags.Name => instance.public_ip
  }
}

# output "hosts" {
#   value = [
#     for host in local.instance_list: 
#       "${host.private_ip} ${host.tags.Name}"
#   ]
# }

      
