# EKS Upgrade Automation (Terraform)

Two Lambda functions (EKS version checker and node group version checker), SNS notifications, and EventBridge Scheduler. Only clusters that match `target_environments` (by name or tag `Environment`/`Env`) are processed.

## Features

- **Automated EKS version checking** - Monitors cluster versions and checks upgrade readiness
- **Parallel addon updates** - Updates multiple addons simultaneously (configurable concurrency)
- **CloudWatch monitoring** - Alarms for Lambda errors and throttles
- **Dry-run mode** - Test without making actual changes
- **Authentication preservation** - Maintains IRSA and Pod Identity during addon updates
- **Input validation** - Validates email format and schedule expressions
- **Batching support** - Configurable max addons per execution for large clusters

## What the two functions do

**1. EKS version checker** (first schedule, e.g. Fridays 17:00 UTC)

- Lists EKS clusters and keeps only those matching `target_environments` (cluster name or tag `Environment`/`Env`).
- For each cluster: compares control plane version to the next allowed EKS version; checks upgrade readiness insights.
- If upgrade is possible and **`enable_auto_upgrade` is true**: calls `UpdateClusterVersion` (one minor version at a time) and sends SNS.
- If **`enable_auto_upgrade` is false**: only sends SNS (up to date / upgrade available / upgrade blocked).
- Then, for that cluster's addons (vpc-cni, kube-proxy, coredns, etc.): checks for newer addon versions, preserves Pod Identity/IRSA, and updates addons when a newer version exists. Uses **parallel processing** to update multiple addons simultaneously (configurable via `max_parallel_addons`). Processes up to `max_addons_per_run` per execution. Sends one SNS summary per cluster for addons.
- **Dry-run mode** (optional): Simulates updates without making actual changes for testing.

**2. Node group version checker** (second schedule, e.g. Fridays 18:00 UTC, 1 hour after the first)

- Lists EKS clusters and keeps only those matching `target_environments`.
- For each cluster: lists managed node groups; if a node group is behind the cluster version (or has an AMI update), calls `UpdateNodegroupVersion` **without** `--force` (so Pod Disruption Budgets are respected).
- If **`enable_auto_upgrade` is true**: starts the node group update and sends SNS with the update ID.
- If **`enable_auto_upgrade` is false**: does not start updates; only reports.
- If an update fails (e.g. blocked by PDB), SNS includes the manual `aws eks update-nodegroup-version ... --force` command.

Both functions send all notifications to the SNS topic (email to `notification_email`).

## Notification results

You receive SNS emails for:

- **Cluster version**: up to date, upgrade available, upgrade blocked (insights), or upgrade initiated.
- **Addon summary** (one per cluster): total addons, counts for up-to-date / updated / failed, then a list of each updated addon with version change (e.g. `v1.12.4-eksbuild.1` -> `v1.13.2-eksbuild.1`) and authentication (IRSA, Pod Identity, or None).
- **Node group summary** (one per cluster): up-to-date, updating (with update ID), or failed (with manual `--force` command when PDB blocks the update).

## CloudWatch Alarms

The solution creates CloudWatch alarms for monitoring Lambda health:

- **EKS version checker errors** - Triggers when Lambda encounters errors
- **EKS version checker throttles** - Triggers when Lambda is throttled
- **Node group checker errors** - Triggers when Lambda encounters errors
- **Node group checker throttles** - Triggers when Lambda is throttled

All alarms trigger after 1 occurrence over a 5-minute period.

## Layout

```
.
├── main.tf              # module "iam", "sns", "lambda", "scheduler"
├── versions.tf          # required_version, required_providers
├── providers.tf         # provider aws
├── backend.tf           # S3 backend
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
├── terraform/
│   ├── env/
│   │   ├── dev/terraform.tfvars
│   │   └── prod/terraform.tfvars
│   └── modules/
│       ├── iam/
│       ├── sns/
│       ├── lambda/      # two Lambdas + Python source
│       └── scheduler/
```

Run Terraform from the **project root**. Module sources point at `./terraform/modules/...`.

## Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `notification_email` | Yes | - | Email for SNS notifications |
| `enable_auto_upgrade` | No | `false` | Set `true` to auto-upgrade in-scope clusters |
| `aws_region` | No | `us-east-1` | AWS region |
| `name_prefix` | No | `""` | Prefix for resource names (e.g. `dev-`, `prod-`) |
| `schedule_expression_version_checker` | No | `cron(0 17 ? * FRI *)` | EventBridge schedule for version checker (Fridays 17:00 UTC) |
| `schedule_expression_nodegroup` | No | `cron(0 18 ? * FRI *)` | EventBridge schedule for node group version checker (Fridays 18:00 UTC) |
| `target_environments` | No | `dev,development` | Comma-separated: only clusters whose name or tag `Environment`/`Env` contains one of these (case-insensitive). Use `""` to process all clusters. |
| `max_parallel_addons` | No | `3` | Maximum number of addons to update in parallel. Recommended: 3-5 for production, 5-10 for development. |
| `max_addons_per_run` | No | `30` | Maximum number of addons to process per Lambda execution. Remaining addons will be processed in the next scheduled run. |
| `dry_run` | No | `false` | Enable dry-run mode to simulate updates without making changes. Useful for testing without a cluster. |

## Performance Considerations

### For Small Clusters (5-15 addons)
- Use default settings: `max_parallel_addons = 3`
- Sequential or low concurrency is sufficient
- Lambda timeout: 300s is more than enough

### For Medium Clusters (15-30 addons)
- Recommended: `max_parallel_addons = 3-5`
- Parallel processing provides 3x speed improvement
- Processes all addons within Lambda timeout

### For Large Clusters (30+ addons)
- Recommended: `max_parallel_addons = 5-10`
- Configure `max_addons_per_run` to limit per execution
- Example: `max_addons_per_run = 30` with 50 addons = 2 scheduled runs
- Remaining addons processed in next scheduled run

### Performance Example

With 30 addons and default settings:
- **Sequential (old)**: 30 × 4s = 120s minimum (would timeout)
- **Parallel 3 workers**: 30 ÷ 3 = 10 batches × 5s = ~50s ✅
- **Parallel 5 workers**: 30 ÷ 5 = 6 batches × 5s = ~30s ✅

## Testing

### Dry-Run Mode (Recommended for testing)
Enable dry-run to simulate operations without making changes:

```hcl
dry_run = true
```

This will:
- List clusters and addons
- Check for available updates
- Log what **would** be updated
- NOT call actual update APIs
- Still send SNS notifications (marked as dry-run)

### Without a Cluster
If you don't have a cluster to test:
1. Use `dry_run = true` - Safest option, just enable and run
2. Create a minimal test cluster - Use AWS Free Tier (~$0.30/hour)
3. Read-only mode - Set `enable_auto_upgrade = false` to only check, not update

## Apply

From the project root:

```bash
terraform init
terraform plan -var-file=terraform/env/dev/terraform.tfvars
terraform apply -var-file=terraform/env/dev/terraform.tfvars
```

Prod: `terraform apply -var-file=terraform/env/prod/terraform.tfvars`

After the first apply, confirm the SNS subscription from the email you set in `notification_email`.

## Backend

State uses the [S3 backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3) with S3 lockfile locking (`use_lockfile = true`); no DynamoDB. Turn on **bucket versioning** for the state bucket so you can restore an older state if the object is overwritten or deleted.

Set the bucket (and region if needed) in `backend.tf`, create the S3 bucket, then run:

```bash
terraform init
```

To override without editing the file: `terraform init -backend-config="bucket=OTHER-BUCKET" -backend-config="region=eu-west-1"`. To migrate from local state, use `-migrate-state` when prompted.

## Outputs

After applying Terraform, you'll get outputs for:

- **Lambda functions**: ARNs and names for both checkers
- **SNS topic**: ARN and name for notifications
- **Schedules**: Names and expressions for both EventBridge schedules
- **IAM roles**: ARNs for all Lambda and scheduler roles
- **CloudWatch alarms**: ARNs for all four Lambda monitoring alarms

Use these outputs for:
- Integrating with other tools (e.g., dashboards, alerting systems)
- Debugging issues
- Configuring additional monitoring
- Manual Lambda invocation for testing
