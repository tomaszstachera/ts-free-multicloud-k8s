# GCP Setup
resource "tls_private_key" "k3s_worker_gcp_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "k3s_worker_gcp_key" {
  content         = tls_private_key.k3s_worker_gcp_key.private_key_pem
  filename        = "./.ssh/k3s-worker-gcp-key.pem"
  file_permission = "0400"
}

resource "google_compute_firewall" "k3s_worker_gcp_firewall" {
  name    = "k3s-worker-gcp-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    #ports    = ["22"]
  }

  #source_ranges = [var.local_public_ip]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "k3s_worker_gcp" {
  name         = "k3s-worker-gcp"
  machine_type = "e2-micro"
  zone         = "${var.gcp_region}-f"

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20250112"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.k3s_worker_gcp_key.public_key_openssh}"
    # I wasn't able to make GPP startup script to work
    #startup_script = "curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.public_ip}:6443 K3S_TOKEN=${data.local_file.k3s_token.content} sh -s - --debug | tee /tmp/startup.log"
  }

  # I wasn't able to make GPP startup script to work
  #metadata_startup_script = "curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.public_ip}:6443 K3S_TOKEN=${data.local_file.k3s_token.content} sh -s - --debug | tee /var/log/init.log"
}

resource "null_resource" "gcp_wait_for_status" {
  depends_on = [google_compute_instance.k3s_worker_gcp]
  provisioner "local-exec" {
    command = <<EOT
      while true; do
        # Get the instance status from GCP
        instance_status=$(gcloud compute instances describe ${google_compute_instance.k3s_worker_gcp.name} \
          --zone ${google_compute_instance.k3s_worker_gcp.zone} \
          --format="value(status)")

        # Check if the status is 'RUNNING'
        if [ "$instance_status" == "RUNNING" ]; then
          echo "Instance is running!"
          break
        fi

        echo "Waiting for instance to be running: Current status=$instance_status"
        sleep 10
      done
      # Sometimes even though instance is running it won't accept SSH connection
      sleep 30
    EOT
  }
}

# I wasn't able to make GPP startup script to work
resource "null_resource" "gcp_user_data_logs" {
  depends_on = [null_resource.aws_user_data_logs, null_resource.gcp_wait_for_status]
  provisioner "local-exec" {
    when    = create
    command = "ssh -o StrictHostKeychecking=no -i ${local_file.k3s_worker_gcp_key.filename} ubuntu@${google_compute_instance.k3s_worker_gcp.network_interface[0].access_config[0].nat_ip} \"sudo journalctl -u google-startup-scripts.service\""
  }
}

resource "null_resource" "gcp_bootstrap_node" {
  depends_on = [null_resource.gcp_wait_for_status, null_resource.aws_user_data_logs]
  provisioner "local-exec" {
    when    = create
    command = "ssh -o StrictHostKeychecking=no -i ${local_file.k3s_worker_gcp_key.filename} ubuntu@${google_compute_instance.k3s_worker_gcp.network_interface[0].access_config[0].nat_ip} \"curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.public_ip}:6443 K3S_TOKEN=${chomp(data.local_file.k3s_token.content)} sh -s - --debug --node-external-ip ${google_compute_instance.k3s_worker_gcp.network_interface[0].access_config[0].nat_ip}\""
  }
}


#resource "aws_vpc_security_group_ingress_rule" "k3s_master_sg_ingress_3" {
#  security_group_id = aws_security_group.k3s_master_sg.id
#  from_port         = 6443
#  to_port           = 6443
#  ip_protocol       = "tcp"
#  cidr_ipv4         = "${google_compute_instance.k3s_worker_gcp.network_interface[0].access_config[0].nat_ip}/32"
#}
