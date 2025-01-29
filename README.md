# ts-free-multicloud-k8s

Fully automated provisioning of free multicloud K3s Kubernetes cluster.

```bash
terraform init
terraform plan -var local_public_ip="$(curl -sSL https://ipconfig.sh)/32" --out local.tfplan
terraform apply -auto-approve -var local_public_ip="$(curl -sSL https://ipconfig.sh)/32"
```

```bash
terraform destroy -var local_public_ip="$(curl -sSL https://ipconfig.sh)/32"
```
