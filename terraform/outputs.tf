output "_1_proxy_private_IP" {
  value = aws_instance.k8s_proxy.private_ip
}

output "_2_masters_private_IPs" {
  value = {
    for instance in aws_instance.k8s_masters:
    instance.tags.Name => instance.private_ip
  }
}

output "_3_workers_private_IPs" {
  value = {
    for instance in aws_instance.k8s_workers:
    instance.tags.Name => instance.private_ip
  }
}

output "_4_proxy_public_IP" {
  value = aws_instance.k8s_proxy.public_ip
}

output "_5_masters_public_IPs" {
  value = {
    for instance in aws_instance.k8s_masters:
    instance.tags.Name => instance.public_ip
  }
}
output "_6_workers_public_IPs" {
  value = {
    for instance in aws_instance.k8s_workers:
    instance.tags.Name => instance.public_ip
  }
}

# output "instances_info" {
#   value = {
#     for instance in concat([aws_instance.k8s_proxy], aws_instance.k8s_masters, aws_instance.k8s_workers) :
#       format("%13s", instance.tags.Name) => format("%15s %15s", instance.private_ip, instance.public_ip)
#   }
# }
