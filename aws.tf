# AWS Setup
resource "aws_key_pair" "k3s_master_key" {
  key_name   = "k3s-master-key"
  public_key = tls_private_key.k3s_master_key.public_key_openssh
}

resource "tls_private_key" "k3s_master_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "k3s_master_key" {
  content         = tls_private_key.k3s_master_key.private_key_pem
  filename        = "./.ssh/k3s-master-key.pem"
  file_permission = "0400"
}

resource "aws_security_group" "k3s_master_sg" {
  name_prefix = "k3s-master-sg-"
}

#resource "aws_vpc_security_group_ingress_rule" "k3s_master_sg_ingress_1" {
#  security_group_id = aws_security_group.k3s_master_sg.id
#  from_port         = 22
#  to_port           = 22
#  ip_protocol       = "tcp"
#  cidr_ipv4         = var.local_public_ip
#}

resource "aws_vpc_security_group_ingress_rule" "k3s_master_sg_ingress_2" {
  security_group_id = aws_security_group.k3s_master_sg.id
  #from_port         = 6443
  #to_port           = 6443
  #ip_protocol       = "tcp"
  #cidr_ipv4         = var.local_public_ip
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "k3s_master_sg_egress_1" {
  security_group_id = aws_security_group.k3s_master_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "k3s_master" {
  ami             = "ami-000b4fe7b39432646"
  instance_type   = "t4g.small"
  key_name        = aws_key_pair.k3s_master_key.key_name
  security_groups = [aws_security_group.k3s_master_sg.name]

  tags = {
    Name = "k3s-master-aws"
  }

  user_data = <<-EOF
              #!/bin/bash
              curl -sfL https://get.k3s.io | sh -s - --node-external-ip $(curl -sSL https://ipconfig.sh) --flannel-backend=wireguard-native --flannel-external-ip --debug --write-kubeconfig-mode=644
              EOF
}

resource "null_resource" "aws_wait_for_status" {
  depends_on = [aws_instance.k3s_master]
  provisioner "local-exec" {
    command = <<EOT
      while true; do
        # Fetch both InstanceStatus and SystemStatus
        instance_status=$(aws ec2 describe-instance-status --instance-id ${aws_instance.k3s_master.id} --query 'InstanceStatuses[0].InstanceStatus.Status' --output text --profile free)
        system_status=$(aws ec2 describe-instance-status --instance-id ${aws_instance.k3s_master.id} --query 'InstanceStatuses[0].SystemStatus.Status' --output text --profile free)

        # Check if both statuses are 'ok'
        if [ "$instance_status" == "ok" ] && [ "$system_status" == "ok" ]; then
          echo "Both status checks passed: InstanceStatus=$instance_status, SystemStatus=$system_status"
          break
        fi

        echo "Waiting for both status checks to pass: InstanceStatus=$instance_status, SystemStatus=$system_status"
        sleep 10
      done
    EOT
  }
}

resource "null_resource" "aws_user_data_logs" {
  depends_on = [aws_instance.k3s_master, null_resource.aws_wait_for_status]
  provisioner "local-exec" {
    when    = create
    command = "ssh -o StrictHostKeychecking=no -i ${local_file.k3s_master_key.filename} ubuntu@${aws_instance.k3s_master.public_ip} \"cat /var/log/cloud-init-output.log\""
  }
}

resource "null_resource" "k3s_token" {
  depends_on = [aws_instance.k3s_master, null_resource.aws_wait_for_status]
  provisioner "local-exec" {
    when    = create
    command = "ssh -o StrictHostKeychecking=no -i ${local_file.k3s_master_key.filename} ubuntu@${aws_instance.k3s_master.public_ip} \"sudo cat /var/lib/rancher/k3s/server/node-token\" > .node-token"
  }
}

data "local_file" "k3s_token" {
  depends_on = [null_resource.k3s_token]
  filename   = ".node-token"
}


## Output KUBECONFIG
resource "null_resource" "kubeconfig" {
  depends_on = [aws_instance.k3s_master, null_resource.k3s_token]
  provisioner "local-exec" {
    when    = create
    command = "ssh -o StrictHostKeychecking=no -i ${local_file.k3s_master_key.filename} ubuntu@${aws_instance.k3s_master.public_ip} \"sudo cat /etc/rancher/k3s/k3s.yaml\" | sed 's/127.0.0.1/${aws_instance.k3s_master.public_ip}/g' > ~/.kube/multicloud-free"
  }
}

## Output Nodes
resource "null_resource" "nodes" {
  depends_on = [null_resource.kubeconfig, null_resource.gcp_bootstrap_node, null_resource.oci_bootstrap_node]
  provisioner "local-exec" {
    when    = create
    command = "KUBECONFIG=$HOME/.kube/multicloud-free kubectl get nodes -o wide"
  }
}

#resource "aws_vpc_security_group_ingress_rule" "k3s_master_sg_ingress_prv_ip" {
#  security_group_id = aws_security_group.k3s_master_sg.id
#  from_port         = 6443
#  to_port           = 6443
#  ip_protocol       = "tcp"
#  cidr_ipv4         = var.local_public_ip
#}
