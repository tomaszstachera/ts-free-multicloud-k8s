# Oracle Cloud Setup
resource "tls_private_key" "k3s_worker_oracle_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "k3s_worker_oracle_key" {
  content         = tls_private_key.k3s_worker_oracle_key.private_key_pem
  filename        = "./.ssh/k3s-worker-oracle-key.pem"
  file_permission = "0400"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_tenancy_ocid
}

output "all-availability-domains-in-your-tenancy" {
  value = data.oci_identity_availability_domains.ads.availability_domains
}

#resource "oci_core_security_list" "k3s_worker_oracle_security_list" {
#  compartment_id = var.oci_tenancy_ocid
#  vcn_id         = var.oci_vcn_id
#
#  ingress_security_rules {
#    protocol = "6"
#    source   = var.local_public_ip
#    tcp_options {
#      min = 22
#      max = 22
#    }
#  }
#}
#
#resource "oci_core_instance" "k3s_worker_oracle" {
#  compartment_id = var.oci_tenancy_ocid
#  #availability_domain = "EU-PARIS-1-AD-1"
#  availability_domain = "ocid1.domain.oc1..aaaaaaaa2nqzdbkcib2n6yhgkxqynkvyjxkc4shl763gyn6nftdqairj7rda"
#  shape               = "VM.Standard.E2.1.Micro"
#
#  source_details {
#    source_id   = "ocid1.image.oc1.eu-paris-1.aaaaaaaaxemmc2z36yddvkjkt2biu5saon7pmrrllgfigeony36w2isp6tl"
#    source_type = "image"
#  }
#
#  create_vnic_details {
#    subnet_id = var.oci_subnet_id
#  }
#
#  metadata = {
#    ssh_authorized_keys = tls_private_key.k3s_worker_oracle_key.public_key_openssh
#    user_data = base64encode(<<-EOF
#                              curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.public_ip}:6443 K3S_TOKEN=${data.local_file.k3s_token.content} sh -s - --debug
#                              EOF
#    )
#  }
#}
#
#resource "aws_vpc_security_group_ingress_rule" "k3s_master_sg_ingress_4" {
#  security_group_id = aws_security_group.k3s_master_sg.id
#  from_port         = 6443
#  to_port           = 6443
#  ip_protocol       = "tcp"
#  cidr_ipv4         = "${oci_core_instance.k3s_worker_oracle.public_ip}/32"
#}
