# payhook-infra

Terraform for running [payhook](https://github.com/unsound-mint/payhook) (a Go payments and webhooks service) on AWS.

![terraform](https://github.com/unsound-mint/payhook-infra/actions/workflows/terraform.yml/badge.svg)

```mermaid
flowchart LR
    U[Merchants and payment providers] -->|HTTP/HTTPS| ALB
    subgraph VPC 10.20.0.0/16
      subgraph public subnets, 2 AZs
        ALB[Application Load Balancer]
        ASG["Auto Scaling group (EC2, AL2023)<br/>api, relay, worker, NATS JetStream"]
      end
      subgraph private subnets, 2 AZs
        RDS[(RDS PostgreSQL 17)]
      end
    end
    ALB -->|":8080, /readyz health checks"| ASG
    ASG -->|5432, TLS| RDS
    ASG -.->|logs| CW[CloudWatch Logs + alarms -> SNS]
    ASG -.->|secrets at boot| SM[Secrets Manager / SSM]
    ALB -.->|access logs| S3[(S3)]
```

## Layout

```
bootstrap/              one-time: S3 state bucket, GitHub OIDC provider, deploy role
modules/network         VPC, public + private subnets in 2 AZs, routing
modules/database        RDS PostgreSQL: private, encrypted, managed master password, forced TLS
modules/app             ALB, Auto Scaling group, launch template, IAM, secrets, ALB log bucket
modules/observability   CloudWatch alarms (5xx, unhealthy targets, p95 latency, DB CPU/storage, app errors) -> SNS
envs/dev                the environment that wires the modules together
```

## Decisions

- **State:** S3 with versioning, KMS encryption and TLS-only access, locked with Terraform's native S3 lockfile (`use_lockfile`, no DynamoDB table).
- **CI has no AWS keys, and two roles.** GitHub Actions assumes an IAM role through OIDC. The plan role (`AWS_PLAN_ROLE_ARN`) trusts this repository's pull requests and `main` and only has ReadOnlyAccess plus the state lock file, because anyone who can open a pull request can edit the workflow. The apply role (`AWS_ROLE_ARN`) trusts only the `production` environment, so every apply passes the required-reviewers gate. It has PowerUserAccess plus IAM rights limited to roles under the `/payhook/` path, and it can attach only the managed policies on an allowlist (currently just `AmazonSSMManagedInstanceCore`), not `AdministratorAccess`. It can still write inline policies on `/payhook/` roles; a permissions boundary would close that and is not set up yet.
- **Secrets never touch Terraform state or user data.** RDS generates the database password into Secrets Manager (`manage_master_user_password`). Webhook signing secrets go into SSM SecureString parameters. Instances read both at boot using a narrowly scoped instance role.
- **No SSH.** Instances are reached through SSM Session Manager. IMDSv2 is required, and root volumes are encrypted.
- **Network:** the database lives in private subnets with no internet route and accepts traffic only from the app security group. App instances accept traffic only from the ALB. Outbound traffic is limited to HTTPS anywhere (image pulls, AWS APIs, merchant callbacks) and PostgreSQL inside the VPC.
- **Deploys:** changing `image_tag` creates a new launch template version, and the Auto Scaling group rolls instances one at a time (`instance_refresh`, at least 50% healthy). The ALB's deregistration delay matches the app's graceful shutdown.
- **Scaling:** target tracking at 60% average CPU, 1–3 instances in dev.

### Trade-offs (and what production would change)

| Here (dev, cheap) | Production |
|---|---|
| No NAT gateway: instances in public subnets, locked down by security groups | Private app subnets behind NAT, or VPC endpoints |
| NATS JetStream runs on each instance (each instance's relay and worker share it; dedupe lives in Postgres) | A NATS cluster (or Synadia Cloud / EKS), so unconsumed messages survive losing an instance |
| HTTP unless `certificate_arn` is set | ACM certificate, HTTP → HTTPS redirect (already supported) |
| Single-AZ `db.t4g.micro`, 1-day backups, no deletion protection | Multi-AZ, longer retention, deletion protection (module defaults) |
| AWS-managed KMS keys | Customer-managed keys where policy requires it |

Accepted security-scanner findings are listed with reasons in [`.trivyignore`](.trivyignore).

## Checks (run in CI on every push, no AWS account needed)

- `terraform fmt`, `terraform validate` for both root modules
- `terraform test` with a mocked AWS provider. It checks that the database isn't public, that storage is encrypted, that only the app can reach the database, that IMDSv2 is required, that secrets are fetched at boot rather than rendered into user data, the HTTP/HTTPS listener behaviour, and that a single-AZ setup is rejected
- `tflint` with the AWS ruleset
- Trivy misconfiguration scan (HIGH/CRITICAL fail the build)

When the AWS variables are configured, pull requests also get a `terraform plan`. Applying is a manual workflow run behind the `production` environment's approval.

## Deploying

```sh
# 1. one-time bootstrap with admin credentials (local state)
cd bootstrap && terraform init && terraform apply
#    -> set repository variables AWS_PLAN_ROLE_ARN, AWS_ROLE_ARN and TF_STATE_BUCKET from the outputs
#       (github_plan_role_arn, github_role_arn, state_bucket)

# 2. the environment
cd ../envs/dev
terraform init -backend-config="bucket=$(terraform -chdir=../../bootstrap output -raw state_bucket)"
terraform apply
curl "$(terraform output -raw api_url)/healthz"

# 3. tear down when done
terraform destroy
```

The app image comes from `ghcr.io/unsound-mint/payhook` (built by payhook's CI). Dev runs about $0.06 an hour: ALB, a t3.small and a db.t4g.micro.
