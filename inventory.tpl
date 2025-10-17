[worker_node]
%{ for ip in workerips ~}
${ip} ansible_host=${ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/tf-key.pem
%{ endfor ~}