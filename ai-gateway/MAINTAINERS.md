# AI Gateway — Maintainer Guide

Audience: engineers who develop, deploy, and operate the gateway.
Client-facing usage lives in [USERS.md](USERS.md). Architecture and design
rationale live in [00-PROPOSAL.md](00-PROPOSAL.md) and
[ADR 01](01-authorizer-compute.md) through
[ADR 04](04-virtual-key-lifecycle.md).

## Contents

- [Quick reference](#quick-reference)
- [Repository layout](#repository-layout)
- [Prerequisites and local development](#prerequisites-and-local-development)
- [Configuration](#configuration)
- [First deployment](#first-deployment)
- [Authorizer releases](#authorizer-releases)
- [Day-two operations](#day-two-operations)
- [Model management](#model-management)
- [Security and credentials](#security-and-credentials)
- [Production-ready Security Checklist](#production-ready-security-checklist)
- [Troubleshooting](#troubleshooting)
- [Upgrades](#upgrades)

## Quick reference

The request flow and component boundaries are documented in the
[initial proposal](00-PROPOSAL.md#4-high-level-design). See
[ADR 02](02-gateway-topology.md) for the deployed topology,
[ADR 03](03-internal-alb-lockdown.md) for the production security blocker,
and [ADR 04](04-virtual-key-lifecycle.md) for virtual-key behavior.

Resource names use the `<tenant>-litellm-<env>` prefix.

| Terraform output | Use |
| --- | --- |
| `gateway_url` | Public endpoint provided to clients |
| `authorizer_ecr_repository_url` | Authorizer image repository |
| `avp_policy_store_id` | Verified Permissions policy store |
| `litellm_admin_url` | LiteLLM UI and management API |
| `litellm_master_key_secret_arn` | Master-key secret |
| `litellm_db_bootstrap_sql` | One-time database user bootstrap |
| `litellm_migration_run_command` | LiteLLM migration command |

## Repository layout

| Path | Contents |
| --- | --- |
| `authorizer/` | TypeScript authorizer service |
| `infra/` | Root Terraform stack |
| `infra/modules/authorizer/` | ALB, ECS, ECR, IAM, AVP, and Redis |
| `docs/` | Proposal, ADRs, and operating guides |

## Prerequisites and local development

- Terraform 1.6 or later and AWS credentials for the target account
- Node.js 24 or later, pnpm 11, and Docker
- An external OIDC issuer, audience, and test JWT
- Two ACM certificates for non-development deployments
- Network access to Aurora for the one-time database bootstrap

Use the [README quick start](../README.md#quick-start) for authorizer checks.
All scripts are defined in
[`authorizer/package.json`](../authorizer/package.json). Running `pnpm dev`
also requires the environment variables validated by
[`authorizer/src/config.ts`](../authorizer/src/config.ts).

## Configuration

Copy `infra/terraform.tfvars.example` to the ignored
`infra/terraform.tfvars`. Do not commit credentials or real environment
values.

| Input group | Root variables |
| --- | --- |
| Location and naming | `region`, `azs`, `tenant`, `env` |
| TLS | `litellm_acm_certificate_arn`, `authorizer_acm_certificate_arn`, `allow_plaintext_alb` |
| LiteLLM | `proxy_config`, `ui_password` |
| OIDC | `oidc_issuer_url`, `oidc_audience`, `oidc_jwks_url`, `oidc_team_claim` |
| Authorizer release | `authorizer_image_tag`, `authorizer_cpu`, `authorizer_memory`, `authorizer_desired_count` |
| Network | `authorizer_allowed_ingress_cidrs` |
| Virtual keys | `virtual_key_duration`, `key_cache_ttl_seconds`, `authorizer_enable_redis_cache` |
| Cost controls | `default_user_max_budget_usd` |

Set `allow_plaintext_alb = true` only for a development sandbox. Production
requires certificates for both ALBs and restricted
`authorizer_allowed_ingress_cidrs`.

`proxy_config` becomes LiteLLM's optional `config.yaml`. Use it for routing,
native guardrails, and an initial or immutable base model set. Runtime model
management is enabled by default, so `proxy_config` can remain empty. See
[Model management](#model-management) for the production workflow.

Provider keys in a static `proxy_config` must come from Secrets Manager,
never from `terraform.tfvars`. The root stack does not currently expose the
upstream module's `gateway_extra_secrets` input; wire an explicit root
variable and module argument in `infra/main.tf` before using environment
references such as `os.environ/ANTHROPIC_API_KEY`.

The root stack also does not expose the LiteLLM module's OTEL inputs. Add
explicit root variables and module arguments before configuring an external
collector.

The authorizer module sets its container environment from these root inputs.
`KEY_CLEANUP_GRACE_SECONDS`, `autoscaling_max_capacity`,
`log_retention_days`, and `redis_node_type` currently retain their local
module defaults because the root stack does not expose them.

Keep `key_cache_ttl_seconds` shorter than `virtual_key_duration`. Disabling
Redis uses independent in-memory caches in each authorizer task and causes
additional key minting when more than one task is running.

## First deployment

Initialize the stack and create the LiteLLM core first. The authorizer's
data sources cannot resolve the shared VPC until that core exists.

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform apply -target=module.litellm
```

Run `litellm_db_bootstrap_sql` once as the Aurora master user from a host
with VPC database access. Then run the module-provided migrations.

```bash
terraform output -raw litellm_db_bootstrap_sql
terraform output -raw litellm_migration_run_command | bash
```

Apply the remaining resources, then push the first authorizer image. The
ECS service may report image-pull failures until this push completes.

```bash
terraform apply

REPO=$(terraform output -raw authorizer_ecr_repository_url)
aws ecr get-login-password |
	docker login --username AWS --password-stdin "${REPO%%/*}"
docker build --platform linux/amd64 -t "$REPO:latest" ../authorizer
docker push "$REPO:latest"
```

Confirm `terraform output -raw gateway_url` and call `/healthz` before
onboarding clients. The health endpoint checks only the authorizer process;
it does not validate OIDC, AVP, Redis, or LiteLLM connectivity.

## Authorizer releases

Use immutable image tags. Build and push the image, update
`authorizer_image_tag`, and apply Terraform so ECS receives a new task
definition.

If reusing a tag during development, force a deployment:

```bash
aws ecs update-service \
	--cluster <tenant>-litellm-<env> \
	--service <tenant>-litellm-<env>-authorizer \
	--force-new-deployment
```

## Day-two operations

### Models and guardrails

Manage production models and provider credentials at runtime through the
LiteLLM Admin UI or management API. Reserve `proxy_config` for static base
models, routing, and LiteLLM-native guardrails. For a check that must run
before LiteLLM, implement the
[`Guardrail`](../authorizer/src/guardrails/index.ts) interface and register it
in `authorizer/src/index.ts`.

### Users, teams, and budgets

Users are created on first request. Set their budgets through the LiteLLM UI
or `/user/update`. Create teams and their model allowlists through the UI or
`/team/new`; team identifiers must match the configured JWT team claim.
Resolve `403 team_not_provisioned` by provisioning the team or correcting
the claim.

Blocking a user is the revocation mechanism. Deleting a virtual key is only
temporary because the next valid request mints a replacement. See
[ADR 04](04-virtual-key-lifecycle.md) for rotation and cleanup behavior.

## Model management

The upstream AWS module enables `STORE_MODEL_IN_DB=true` by default. Models
created through the LiteLLM Admin UI or management API are therefore stored
in Aurora and survive task replacements, restarts, and scaling events.

Start with `proxy_config.model_list` when a fixed bootstrap set is useful,
then move day-two model operations to the database. Database-backed models
can be added, edited, tested, or removed without a Terraform apply or
LiteLLM task restart. Provider credentials can also be created once and
reused across models.

Static and database-backed models can coexist. Static models remain owned by
`config.yaml`: change them through `proxy_config` and apply Terraform, which
creates a new task definition and rolling deployment. They cannot be edited
or deleted through the Admin UI. For production, prefer database-backed
models unless a model must remain coupled to infrastructure deployment.

Use these management API endpoints with the LiteLLM master key:

- `POST /model/new`
- `GET /model/info`
- `POST /model/update`
- `POST /model/delete`

See the
[LiteLLM model management guide](https://docs.litellm.ai/docs/proxy/model_management)
for request bodies, reusable credentials, and Admin UI operations.

Database-stored provider credentials are encrypted using
`LITELLM_SALT_KEY`, or `LITELLM_MASTER_KEY` when no salt key is configured.
Do not change the encryption key after credentials have been stored, because
LiteLLM cannot decrypt them with a different value. The root stack does not
currently expose a dedicated salt-key secret, so account for this before
adopting database-managed provider credentials in production.

### Authorization policies

The policy store begins with a permissive starter policy in
[`avp.tf`](../infra/modules/authorizer/avp.tf). Replace it with
`aws_verifiedpermissions_policy` resources managed by Terraform. The Cedar
schema and `authorizer/src/auth/avp.ts` mirror each other and must change
together.

### Logs and scaling

Authorizer logs are JSON in
`/ecs/<tenant>-litellm-<env>-authorizer`. Forwarded-request entries include
`sub`, `teamId`, `model`, `status`, and `authorizerMs`.

The authorizer scales at 70% average CPU. Its minimum is
`authorizer_desired_count`; its local-module maximum defaults to 10.
LiteLLM scaling is managed by the upstream module.

## Security and credentials

Do not deploy to production until the interior ALB remediation in
[ADR 03](03-internal-alb-lockdown.md) is implemented. That ADR also
documents the interim WAF option.

Restrict `authorizer_allowed_ingress_cidrs` whenever callers use known
networks. The authorizer exposes only `/v1/*` and `/healthz`; use the
interior ALB for the LiteLLM UI and management APIs.

Set a dedicated `ui_password`. If it is empty, LiteLLM uses the master key
as the UI password. The default username is `admin`; the root stack does not
currently expose a username override.

Retrieve the configured UI password:

```bash
aws secretsmanager get-secret-value \
	--secret-id "<tenant>-litellm-<env>-ui-password" \
	--query SecretString \
	--output text
```

Retrieve the master key:

```bash
aws secretsmanager get-secret-value \
	--secret-id "$(terraform output -raw litellm_master_key_secret_arn)" \
	--query SecretString \
	--output text
```

After changing `ui_password` and applying Terraform, replace the LiteLLM
backend tasks because running tasks retain the previous secret value:

```bash
aws ecs update-service \
	--cluster <tenant>-litellm-<env> \
	--service <tenant>-litellm-<env>-backend \
	--force-new-deployment
```

After rotating the master-key secret, replace the LiteLLM gateway and
backend tasks and the authorizer tasks so every container receives the new
value.

## Production-ready Security Checklist

Complete every applicable item before exposing the gateway to production.
Record any exception with an owner, compensating control, and expiry date.

### Network and transport

- [ ] Provision or import valid ACM certificates whose names match every
  internet-accessible hostname. Attach them to the public ALB HTTPS
  listeners so HTTP API and SSE traffic uses `https://` and WebSocket
  traffic uses `wss://`.
- [ ] Set `allow_plaintext_alb = false`, use the TLS 1.2/1.3 listener policy,
  and verify that no public listener serves application traffic over HTTP.
- [ ] Implement [ADR 03](docs/03-internal-alb-lockdown.md): make the LiteLLM
  ALB internal and limit its security group to the authorizer and approved
  administrative paths.
- [ ] Keep ECS tasks, Aurora, Redis, and the jump instance in private
  subnets without public IP addresses or direct internet ingress.
- [ ] Access the LiteLLM Admin UI and management APIs only through the
  SSM-managed jump instance. Give it no public IP, inbound security-group
  rules, or SSH key, and restrict `ssm:StartSession` with least-privilege
  IAM.
- [ ] Record Session Manager API activity in CloudTrail and review access
  regularly. Port-forwarded session content cannot be logged, so treat
  `ssm:StartSession` permission as privileged access.
- [ ] Restrict `authorizer_allowed_ingress_cidrs` where callers have known
  egress ranges. Otherwise, protect the public ALB with AWS WAF rate limits
  and managed rules.
- [ ] Review and limit outbound access where practical. Use VPC endpoints
  for supported AWS services and a controlled egress path if
  provider-domain restrictions are required.

### Identity, authorization, and secrets

- [ ] Validate OIDC issuer, audience, signature, and expiry for every request.
  Use short-lived JWTs and test key rotation and invalid-token rejection.
- [ ] Replace the permissive starter Verified Permissions policy with
  least-privilege Cedar policies managed by Terraform. Test cross-user,
  cross-team, model, method, and path denial cases.
- [ ] Store the LiteLLM master key, UI password, and provider credentials in
  Secrets Manager. Never place plaintext credentials in Terraform variables,
  state, container images, source control, or logs.
- [ ] Set a dedicated, unique LiteLLM UI password; do not fall back to the
  master key. Rotate both credentials on a defined schedule and redeploy all
  tasks that consume them.
- [ ] Keep virtual-key lifetimes short, keep the cache TTL shorter than the
  key lifetime, and verify revocation by blocking a user.
- [ ] Apply least-privilege IAM to ECS task, execution, deployment, and
  operator roles. Require MFA for privileged human access.

### Data protection and abuse controls

- [ ] Verify encryption at rest for Aurora, Redis, Secrets Manager, log
  groups, and backups with approved KMS keys where required.
- [ ] Configure per-user and per-team budgets, model allowlists, request rate
  limits, token limits, and concurrency limits. Alert before hard limits are
  reached.
- [ ] Configure guardrails for sensitive-data handling and prohibited
  content. Confirm prompts, completions, authorization headers, and keys are
  not logged unless explicitly approved under the data-retention policy.
- [ ] Define Aurora backup retention and point-in-time recovery, then test a
  restore. Document recovery objectives and deletion-protection exceptions.

### Detection, response, and software supply chain

- [ ] Enable ALB access logs, application audit logs, CloudTrail, GuardDuty,
  and Security Hub or approved equivalents. Centralize logs with retention,
  encryption, restricted access, and alerts for authentication failures,
  unusual spend, elevated error rates, and administrative changes.
- [ ] Use immutable authorizer image tags, scan container images and
  dependencies, patch critical vulnerabilities, and review the full
  Terraform plan before each production release.
- [ ] Run production smoke tests covering TLS, OIDC, authorization denials,
  LiteLLM isolation, guardrails, budgets, streaming, dependency failure, and
  secret rotation.
- [ ] Maintain an incident-response runbook for credential compromise,
  unauthorized model use, data exposure, and spend anomalies. Test key
  rotation, user blocking, traffic containment, and rollback procedures.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Authorizer tasks cannot start | Confirm the configured image tag exists in `authorizer_ecr_repository_url` |
| `401 invalid_token` | Check issuer, audience, token expiry, discovery, and the optional JWKS override |
| `403 permission_denied` | Inspect the AVP policy and the request's user, team, model, method, and path |
| `403 team_not_provisioned` | Create the LiteLLM team or correct the JWT team claim |
| `400 guardrail_rejected` | Inspect the named pre-flight guardrail and request payload |
| `502 upstream_error` | Check interior ALB reachability, LiteLLM health, and the injected master key |
| Healthy `/healthz` but requests fail | Check OIDC, AVP, Redis, and LiteLLM separately |
| First plan cannot resolve VPC data | Apply `module.litellm` first |

Start with the authorizer CloudWatch log group and the LiteLLM ECS service
logs. Do not infer dependency health from `/healthz`.

## Upgrades

The LiteLLM Terraform module is pinned to `~> 1.89` in `infra/main.tf`.
Review upstream release notes and ADR 03's vendoring implications before
changing the constraint. Run `terraform init -upgrade`, inspect the complete
plan, and test database migrations in a non-production environment first.

For authorizer dependency upgrades, use the checks in the
[README quick start](../README.md#quick-start) before publishing an image.
