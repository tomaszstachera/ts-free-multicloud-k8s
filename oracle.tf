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

resource "oci_core_security_list" "k3s_worker_oracle_security_list" {
  compartment_id = data.oci_identity_availability_domains.ads.availability_domains[0].compartment_id
  vcn_id         = var.oci_vcn_id

  ingress_security_rules {
    protocol = "all"
    #source   = var.local_public_ip
    source = "0.0.0.0/0"
    #tcp_options {
    #  min = 22
    #  max = 22
    #}
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_instance" "k3s_worker_oracle" {
  compartment_id      = data.oci_identity_availability_domains.ads.availability_domains[0].compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = "VM.Standard.E2.1.Micro"

  source_details {
    #source_id   = "ocid1.image.oc1.eu-paris-1.aaaaaaaaxemmc2z36yddvkjkt2biu5saon7pmrrllgfigeony36w2isp6tl"
    source_id = "ocid1.image.oc1.eu-paris-1.aaaaaaaanhslz7qjbpro3ggwo6tw3waim4prbjzhzhxro4ka2vzrdo6ze6iq"
    #instance_source_image_filter_details {
    #  compartment_id           = data.oci_identity_availability_domains.ads.availability_domains[0].compartment_id
    #  operating_system         = "Canonical Ubuntu"
    #  operating_system_version = "24.04"
    #}
    source_type = "image"
  }

  create_vnic_details {
    subnet_id = var.oci_subnet_id
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.k3s_worker_oracle_key.public_key_openssh
    #user_data = base64encode(<<-EOF
    #                          curl -sfL https://get.k3s.io | K3S_URL=https://123.123.123.123:6443 K3S_TOKEN=123 sh -s - --debug
    #                          EOF
    #)
    user_data = base64encode("curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.public_ip}:6443 K3S_TOKEN=${data.local_file.k3s_token.content} sh -s - --debug --node-external-ip `curl -sSL https://ipconfig.sh`")
  }
}

resource "null_resource" "oci_wait_for_status" {
  depends_on = [oci_core_instance.k3s_worker_oracle]
  provisioner "local-exec" {
    command = <<EOT
      while true; do
        # Get the instance status from OCI
        instance_status=$(oci compute instance get --instance-id ${oci_core_instance.k3s_worker_oracle.id} --query data | jq -r '."lifecycle-state"')

        # Check if the status is 'RUNNING'
        if [ "$instance_status" == "RUNNING" ]; then
          echo "Instance is running!"
          break
        fi

        echo "Waiting for instance to be running: Current status=$instance_status"
        sleep 10
      done
    EOT
  }
}

resource "null_resource" "oci_startup_script_logs" {
  depends_on = [null_resource.aws_user_data_logs, oci_core_instance.k3s_worker_oracle, null_resource.oci_wait_for_status]
  provisioner "local-exec" {
    when    = create
    command = "ssh -o StrictHostKeychecking=no -i ${local_file.k3s_worker_oracle_key.filename} ubuntu@${oci_core_instance.k3s_worker_oracle.public_ip} \"sudo cat /var/log/cloud-init-output.log\""
  }
}

resource "null_resource" "oci_bootstrap_node" {
  depends_on = [null_resource.oci_startup_script_logs]
  provisioner "local-exec" {
    when    = create
    command = "ssh -o StrictHostKeychecking=no -i ${local_file.k3s_worker_oracle_key.filename} ubuntu@${oci_core_instance.k3s_worker_oracle.public_ip} \"curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.public_ip}:6443 K3S_TOKEN=${chomp(data.local_file.k3s_token.content)} sh -s - --debug --node-external-ip ${oci_core_instance.k3s_worker_oracle.public_ip}\""
  }
}


#resource "aws_vpc_security_group_ingress_rule" "k3s_master_sg_ingress_4" {
#  security_group_id = aws_security_group.k3s_master_sg.id
#  from_port         = 6443
#  to_port           = 6443
#  ip_protocol       = "tcp"
#  cidr_ipv4         = "${oci_core_instance.k3s_worker_oracle.public_ip}/32"
#}
