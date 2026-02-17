# Environments

Each environment has its own folder and `terraform.tfvars` under `terraform/env/` (e.g. `terraform/env/dev/`, `terraform/env/prod/`).

Run from the **project root**:

```bash
terraform plan -var-file=terraform/env/dev/terraform.tfvars
terraform apply -var-file=terraform/env/dev/terraform.tfvars
```

Prod: `terraform apply -var-file=terraform/env/prod/terraform.tfvars`

Edit `notification_email` in the env’s `terraform.tfvars` before the first apply.
