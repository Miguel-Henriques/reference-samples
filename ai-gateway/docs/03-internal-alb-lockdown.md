# ADR 03: Internal ALB Lockdown

Status: accepted (2026-07), not yet implemented. This is a production
security requirement, not an optimization.

## Context

The interior ALB exposes the LiteLLM admin plane, including the UI and
management API, to the internet behind static credentials. The OSS login
has no MFA, lockout, or rate limiting. The hostname is discoverable through
ALB DNS scanning and Certificate Transparency after an ACM certificate is
attached. A leaked master key would provide remote control of the gateway.

Forking the module and replacing its infrastructure were evaluated:

| Criterion | Fork and minimal patch | Replace the infrastructure |
| --- | --- | --- |
| Baseline effort | ~1 day; standing diff of ~40–60 lines against ~2,480 | ~1.5–2 weeks to reach parity |
| Service Connect single hop | +1.5–2.5 days; diff grows to ~150–200 lines in high-churn `ecs.tf` | Natural shape of the replacement |
| Ongoing maintenance | Occasionally rebase a small patch; upgrade LiteLLM through image variables | Permanently track LiteLLM route allowlists, environment and secret contracts, health checks, and migrations |
| Exit path | Upstream the internal-ALB, CIDR, and output variables so the fork can disappear | Infrastructure ownership is permanent |

The module captures upstream operational knowledge, including a route
allowlist mirrored from LiteLLM, Aurora IAM-auth bootstrapping, and
migration sequencing. Replacing it would require re-deriving and
continually tracking that behavior.

## Decision

Vendor `terraform-aws-litellm` with a minimal patch:

1. Place it in `infra/modules/litellm`.
2. Add `internal = var.internal` in `alb.tf`.
3. Add an ingress CIDR variable in `network.tf`.
4. Export VPC, subnet, and security-group identifiers from `outputs.tf`.
5. Consume those outputs from the authorizer and remove tag-based
   discovery and the two-phase first apply.
6. Add a `t4g.nano` SSM-managed jump instance with no public IP or inbound
   access.
7. Open an upstream pull request for the internal-ALB, ingress-CIDR, and
   output additions.

Access the admin UI through SSM port forwarding:

```bash
aws ssm start-session \
	--document-name AWS-StartPortForwardingSessionToRemoteHost \
	--parameters host=<interior-alb-dns>,portNumber=443,localPortNumber=8443
```

## Consequences

The LiteLLM admin and data planes become privately reachable. The internal
ALB resolves to private IPs, removing the NAT gateway hairpin and its
approximately $0.045/GB processing fee from authorizer-to-LiteLLM traffic.
Maintainers assume responsibility for rebasing a small module patch until
the changes are accepted upstream.

If deployment must precede the fork, associate a WAF Web ACL with the
module ALB from outside the module. Default to blocking traffic and allow
the NAT EIP used by the authorizer plus approved admin CIDRs. This costs
approximately $5–7/month and can remain in place after the fork.

Current credential mitigations and UI credential procedures are documented
in [MAINTAINERS.md](MAINTAINERS.md).
