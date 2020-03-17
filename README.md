# aws_terra_k8s
Just a test. Build a multi master kubernetes in AWS using terraform.



ansible-playbook --flush-cache -b -i ../ansible/inventory.ini -u cdtn --private-key=~/.ssh/k8s_tesouro ../ansible/kubespray/cluster.yml

git clone --branch v2.12.3 https://github.com/kubernetes-sigs/kubespray.git



export ANSIBLE_HOST_KEY_CHECKING=False;
cd ../ansible/kubespray/
ansible-playbook -b -i inventory/mycluster/inventory.ini -u ubuntu --private-key=~/.ssh/k8s-test.pem cluster.yml



Outputs:

_1_proxy_private_IP = {
  "k8s-haproxy-1" = "172.31.23.248"
  "k8s-haproxy-2" = "172.31.27.140"
}
_2_masters_private_IPs = {
  "k8s-master-1" = "172.31.37.168"
  "k8s-master-2" = "172.31.40.8"
  "k8s-master-3" = "172.31.34.2"
}
_3_workers_private_IPs = {
  "k8s-worker-1" = "172.31.47.130"
  "k8s-worker-2" = "172.31.44.174"
  "k8s-worker-3" = "172.31.43.19"
}
_4_proxy_public_IP = {
  "k8s-haproxy-1" = "3.21.122.129"
  "k8s-haproxy-2" = "3.21.134.80"
}
_5_masters_public_IPs = {
  "k8s-master-1" = "3.134.113.205"
  "k8s-master-2" = "13.58.161.72"
  "k8s-master-3" = "18.218.248.71"
}
_6_workers_public_IPs = {
  "k8s-worker-1" = "18.188.101.135"
  "k8s-worker-2" = "18.216.215.33"
  "k8s-worker-3" = "13.58.226.217"
}
_7_public_EIP = 3.20.252.67