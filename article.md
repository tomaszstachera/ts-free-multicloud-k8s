# Free fully automated multicloud multiarchitecture Kubernetes cluster (with DeepSeekAI evaluation)

We are going to build a Kubernetes cluster which will consist of master node on AWS EC2 ARM instance and worker nodes on GCP and OCI (Oracle Cloud Infrastructure) VMs. We will only use free tier of cloud resources and fully automate everything in a one-click Terraform deployment. Why are we doing this? Because we can :) We will ask DeepSeekAI for the whole code, point it's mistakes and fix them. Let's get started.

## Prerequisites

- AWS account
  - AWS CLI installed and credentials configured in a profile called `free`
- GCP account
  - gcloud CLI installed and credentials configured in a default profile
- OCI account
  - oci CLI installed and credentials configured in a default profile
- Terraform version v1.4.5
- kubectl installed

## Code preparation

## Running and testing
