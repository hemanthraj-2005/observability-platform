# Terraform Folder Structure

Terraform files live in `infra/terraform` and provision the AWS host used by the production Docker Compose stack.

```text
infra/
├── scripts/
│   ├── bootstrap-ec2.sh      # EC2 user-data script: installs Docker and configures UFW
│   └── deploy.sh             # Server deployment script: runs production Docker Compose
└── terraform/
    ├── versions.tf           # Terraform and AWS provider version constraints
    ├── variables.tf          # Input variables for region, CIDRs, key pair, instance type, VPC, subnet
    ├── main.tf               # AWS VPC/subnet lookup, security group, Ubuntu AMI, EC2 instance
    ├── outputs.tf            # EC2 ID, public IP, SSH command, Grafana, Prometheus, and Flask URLs
    ├── terraform.tfvars.example
    │                         # Example variable values for local Terraform usage
    └── .terraform.lock.hcl   # Provider dependency lock file
```

## What Terraform Creates

| File | Responsibility |
| --- | --- |
| `versions.tf` | Pins Terraform to `>= 1.6.0` and AWS provider to `~> 5.0`. |
| `variables.tf` | Defines configurable inputs such as AWS region, EC2 key pair, CIDR allowlists, instance type, and root volume size. |
| `main.tf` | Finds the target VPC/subnet, selects the latest Ubuntu 22.04 AMI, creates the security group, and provisions the EC2 instance. |
| `outputs.tf` | Prints connection and service URLs after provisioning. |
| `terraform.tfvars.example` | Gives a safe template for local Terraform variables. |

## Interview Talking Point

The Terraform layer keeps infrastructure reproducible. Instead of manually creating an EC2 host, firewall rules, and Docker setup, the project defines them as code and runs them from GitHub Actions or locally.
