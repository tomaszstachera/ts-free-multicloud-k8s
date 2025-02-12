# Free fully automated multicloud multiarchitecture Kubernetes cluster (with DeepSeekAI evaluation)

We are going to build a Kubernetes cluster which will consist of master node on AWS EC2 ARM instance and worker nodes on GCP and OCI (Oracle Cloud Infrastructure) x86/64 VMs. We will only use free tier of cloud resources and fully automate everything in a one-click Terraform deployment. Why are we doing this? Because we can :) We will ask DeepSeekAI for the whole code, point it's mistakes and fix them. Let's get started.

## Prerequisites

- AWS account
  - AWS CLI [installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and credentials [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) in a profile called `free`
- GCP account
  - gcloud CLI [installed](https://cloud.google.com/sdk/docs/install) and credentials [configured](https://cloud.google.com/sdk/docs/initializing) in a default profile
- OCI account
  - oci CLI [installed](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm) and credentials [configured](https://docs.public.oneportal.content.oci.oraclecloud.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm#two) in a default profile
- Terraform version v1.4.5 (for example using [tfenv](https://github.com/tfutils/tfenv) )
- kubectl [installed](https://kubernetes.io/docs/tasks/tools/)

## Which clouds to choose?

![Azure issue](img/azure-issue.png "Azure issue")
![AWS Graviton2](img/graviton.png "AWS Graviton2")

## Manual tests

![Cannot join without Graviton2](img/cannot-join-on-free.png "Cannot join without Graviton2")
![Worked with Graviton2](img/worked-manually.png "Worked with Graviton2")
![htop - manual](img/htop.png "htop - manual")
![AWS metrics - manual](img/aws-metr.png "AWS metrics - manual")
![GCP metrics - manual](img/gcp-metr.png "GCP metrics - manual")
![OCI metrics - manual](img/oracle-metr.png "OCI metrics - manual")
![OCI ARM](img/working-arm-24hrs.png "OCI ARM")

## Code preparation

![Deepseek](img/deepseek.png "Deepseek")
![NVIM - OCI user_data](img/nvim-user-data.png "NVIM - OCI user_data") # not works should be under metadata for OCI
![NVIM - KUBECONFIG](img/neovim-kubeconfig.png "NVIM - KUBECONFIG") # replaces local with local instead of local with remote
![NVIM - missing AWS SG CIDRs](img/neovim-missing-sg-cidrs.png "NVIM - missing AWS SG CIDRs")
![NVIM - cycle code](img/neovim-cycle-code.png "NVIM - cycle code")

## Running and testing

![OCI - 404](img/404.png "OCI - 404")
![OCI - 400](img/400.png "OCI - 400")
![OCI - 500](img/oci-500.png "OCI - 500")
![2 NGINX simple test](img/2-nginx-results.png "2 NGINX simple test")
![ab tests 1](img/ab-tests.png "ab tests 1")
![ab summary 1](img/ab-summary.png "ab summary 1")
![ab tests 2](img/ab-2-nodes.png "ab tests 2")
![ab summary 2](img/ab-2-nodes-final.png "ab summary 2")
![locust 1](img/locust-1.png "locust 1")
![locust 2](img/locust-2.png "locust 2")
![locust 3](img/locust-3.png "locust 3")
![locust 4](img/locust-4.png "locust 4")
![locust 5](img/locust-5.png "locust 5")
