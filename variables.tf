variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "gcp_project" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "oci_tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
}

variable "oci_vcn_id" {
  description = "OCI VCN ID"
  type        = string
}

variable "oci_subnet_id" {
  description = "OCI VCN subnet ID"
  type        = string
}

variable "oci_private_key_path" {
  description = "OCI private key path"
  type        = string
}

variable "oci_fingerprint" {
  description = "OCI fingerprint"
  type        = string
}

variable "oci_user_ocid" {
  description = "OCI user OCID"
  type        = string
}

variable "oci_region" {
  description = "OCI region"
  type        = string
}

variable "local_public_ip" {
  description = "Public IP of the local laptop running Terraform"
  type        = string
}
