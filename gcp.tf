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
    ports    = ["22"]
  }

  source_ranges = [var.local_public_ip]
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
    ssh-keys       = "ubuntu:${tls_private_key.k3s_worker_gcp_key.public_key_openssh}"
    startup_script = "#! /bin/bash\ncurl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.public_ip}:6443 K3S_TOKEN=${data.local_file.k3s_token.content} sh -s - --debug | tee /var/log/init.log"
  }

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
    EOT
  }
}

resource "null_resource" "gcp_user_data_logs" {
  depends_on = [null_resource.aws_user_data_logs, google_compute_instance.k3s_worker_gcp, null_resource.gcp_wait_for_status]
  provisioner "local-exec" {
    when    = create
    command = "ssh -o StrictHostKeychecking=no -i ${local_file.k3s_master_key.filename} ubuntu@${aws_instance.k3s_master.public_ip} \"sudo journalctl -u google-startup-scripts.service\""
  }
}


resource "aws_vpc_security_group_ingress_rule" "k3s_master_sg_ingress_3" {
  security_group_id = aws_security_group.k3s_master_sg.id
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${google_compute_instance.k3s_worker_gcp.network_interface[0].access_config[0].nat_ip}/32"
}
