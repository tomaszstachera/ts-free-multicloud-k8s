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

resource "aws_vpc_security_group_ingress_rule" "k3s_master_sg_ingress_1" {
  security_group_id = aws_security_group.k3s_master_sg.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.local_public_ip
}

resource "aws_vpc_security_group_ingress_rule" "k3s_master_sg_ingress_2" {
  security_group_id = aws_security_group.k3s_master_sg.id
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.local_public_ip
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
              curl -sfL https://get.k3s.io | sh -s - --node-external-ip $(curl -sSL https://ipconfig.sh) --debug --write-kubeconfig-mode=644
              EOF
}

resource "null_resource" "k3s_token" {
  depends_on = [aws_instance.k3s_master]
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
  depends_on = [aws_instance.k3s_master]
  provisioner "local-exec" {
    when    = create
    command = "ssh -o StrictHostKeychecking=no -i ${local_file.k3s_master_key.filename}@${aws_instance.k3s_master.public_ip} \"sudo cat /etc/rancher/k3s/k3s.yaml\" | sed 's/127.0.0.1/${aws_instance.k3s_master.public_ip}/g' > ~/.kube/multicloud-free"
  }
}
