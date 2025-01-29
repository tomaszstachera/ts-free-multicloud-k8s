# Provider Configuration
provider "aws" {
  region = var.aws_region
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

provider "oci" {
  tenancy_ocid     = var.oci_tenancy_ocid
  user_ocid        = var.oci_user_ocid
  fingerprint      = var.oci_fingerprint
  private_key_path = var.oci_private_key_path
  region           = var.oci_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  default     = "eu-central-1"
}

variable "gcp_project" {
  description = "GCP project ID"
}

variable "gcp_region" {
  description = "GCP region"
  default     = "us-central1"
}

variable "oci_tenancy_ocid" {
  description = "OCI tenancy OCID"
}

variable "oci_user_ocid" {
  description = "OCI user OCID"
}

variable "oci_fingerprint" {
  description = "OCI fingerprint"
}

variable "oci_private_key_path" {
  description = "OCI private key path"
}

variable "oci_region" {
  description = "OCI region"
  default     = "eu-paris-1"
}

variable "local_public_ip" {
  description = "Public IP of the local laptop running Terraform"
}

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
  content  = tls_private_key.k3s_master_key.private_key_pem
  filename = "k3s-master-key.pem"
}

resource "aws_security_group" "k3s_master_sg" {
  name_prefix = "k3s-master-sg-"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.local_public_ip]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.local_public_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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

# GCP Setup
resource "tls_private_key" "k3s_worker_gcp_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "k3s_worker_gcp_key" {
  content  = tls_private_key.k3s_worker_gcp_key.private_key_pem
  filename = "k3s-worker-gcp-key.pem"
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
    ssh-keys = "ubuntu:${tls_private_key.k3s_worker_gcp_key.public_key_openssh}"
  }

  metadata_startup_script = <<-EOF
                            curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.public_ip}:6443 K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token) sh -s - --debug
                            EOF
}

# Oracle Cloud Setup
resource "tls_private_key" "k3s_worker_oracle_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "k3s_worker_oracle_key" {
  content  = tls_private_key.k3s_worker_oracle_key.private_key_pem
  filename = "k3s-worker-oracle-key.pem"
}

resource "oci_core_security_list" "k3s_worker_oracle_security_list" {
  compartment_id = var.oci_tenancy_ocid
  vcn_id         = oci_core_vcn.k3s_worker_oracle_vcn.id

  ingress_security_rules {
    protocol = "6"
    source   = var.local_public_ip
    tcp_options {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_instance" "k3s_worker_oracle" {
  compartment_id      = var.oci_tenancy_ocid
  availability_domain = "EU-PARIS-1-AD-1"
  shape               = "VM.Standard.E2.1.Micro"

  source_details {
    source_id   = "Canonical-Ubuntu-24.04-2024.10.09-0"
    source_type = "image"
  }

  create_vnic_details {
    subnet_id = oci_core_subnet.k3s_worker_oracle_subnet.id
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.k3s_worker_oracle_key.public_key_openssh
  }

  user_data = base64encode(<<-EOF
                            curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.public_ip}:6443 K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token) sh -s - --debug
                            EOF
  )
}

# Output KUBECONFIG
resource "local_file" "kubeconfig" {
  content = replace(
    file("/etc/rancher/k3s/k3s.yaml"),
    "127.0.0.1",
    aws_instance.k3s_master.public_ip
  )
  filename = "kubeconfig.yaml"
}
