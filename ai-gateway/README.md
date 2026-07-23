# AI Gateway

> ⚠️ **Before any production deployment**:
>
> Complete the production-ready [security checklist](MAINTAINERS.md#production-ready-security-checklist).
> In particular, the LiteLLM API and the Admin UI are currently internet-reachable behind static credentials only.
> The planned remediation is documented as a must-do in [ADR 03](docs/03-internal-alb-lockdown.md) and is not yet implemented.

A production-shaped AI gateway based on [LiteLLM](https://github.com/BerriAI/litellm) with a custom TypeScript **authorizer** in front of it. It gives every LLM-powered application in the organization one OpenAI-compatible endpoint with:

- **Unified LLM API** (HTTP + SSE streaming) across providers
- **JWT authentication** against your existing OIDC identity provider
- **Fine-grained authorization** via Amazon Verified Permissions (Cedar policies)
- **Multi-tenant usage tracking and budgets** (user and team level; solo users supported)
- **Guardrails** — LiteLLM OSS custom/Presidio guardrails, plus an pluggable pre-flight hook
- **Logs and traces** out of the box (CloudWatch, optional OTEL)

## Deployment

This project includes a Terraform module to deploy the solution to AWS.

See [`MAINTAINERS.md`](MAINTAINERS.md) for the full first-deploy runbook.

## Additional documentation

See [`00-PROPOSAL.md`](./docs/00-PROPOSAL.md) for the insights about what motivated this project plus early stage decisions, such as why I chose LiteLLM over other open source alternatives. Furthermore, I keep up to date records of all key architectural decisions under the `/docs` folder.
