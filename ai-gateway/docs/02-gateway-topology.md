# ADR 02: Gateway Topology

Status: accepted (2026-07).

## Context

The LiteLLM core is deployed with the official
[BerriAI/litellm/aws](https://registry.terraform.io/modules/BerriAI/litellm/aws)
Terraform module. The module creates its own VPC and internet-facing ALB. It
offers no internal-ALB flag, bring-your-own VPC support, ECS Service
Connect or Cloud Map registration, or sidecar hook, and exports no VPC,
subnet, or security-group outputs.

Three topologies were considered:

- **A — two ALBs.** Public gateway ALB → authorizer service → module ALB →
  LiteLLM. Deploy the authorizer into the module VPC by discovering its
  deterministic `litellm:stack = <tenant>-litellm-<env>` tag. Reuse the
  interior ALB routing from data-plane requests to the gateway on port 4000
  and management requests to the backend on port 4001.
- **B — single shared ALB.** Add listener rules to the module ALB, with a
  catch-all route to the authorizer and a header-matched bypass to LiteLLM.
  This saves one ALB but depends on internal rule priorities and resource
  names that the module does not expose as a stable interface. Traffic
  still traverses the ALB twice.
- **C — true single hop.** Proxy directly to LiteLLM tasks through ECS
  Service Connect or Cloud Map, or run the authorizer as a sidecar. This is
  the cleanest data path and removes public exposure of the interior ALB,
  but requires forking the module or replacing its infrastructure.

## Decision

Use option A, with two ALBs. Revisit option C if the extra hop or the
interior ALB exposure warrants it.

The additional ALB costs about $20/month and adds roughly 1–2 ms per
request. That is negligible compared with the authorizer's ~15–35 ms of
work and LLM response times measured in seconds.

## Consequences

The deployment can reuse the upstream module without modification and can
preserve its existing data-plane and management-plane routing. It remains
coupled to deterministic tags for VPC discovery and retains an extra
network hop.

The module ALB remains internet-reachable because its security group
hardcodes `0.0.0.0/0` ingress on ports 80 and 443. Every LiteLLM endpoint
still requires a virtual key or master key, neither of which is disclosed
to clients, but a leaked key could bypass the authorizer's AVP and custom
guardrail controls. Treat all LiteLLM keys as high-value secrets, keep
virtual-key durations short, and set a dedicated UI password.

The production remediation is defined separately in
[ADR 03](03-internal-alb-lockdown.md).

To move later to option C:

1. Add ECS Service Connect registration for the gateway and backend
   services to the vendored module.
2. Point the authorizer at the `gateway:4000` and `backend:4001` Service
   Connect names. Split its data-plane and management base URLs when the
   ALB path routing is removed.
3. Replace tag-based discovery in `infra/modules/authorizer/data.tf` with
   explicit module outputs.
