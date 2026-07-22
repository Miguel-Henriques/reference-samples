# AI Gateway Initial Proposal

## 1. Intro

An AI gateway is essential infrastructure component for companies of all sizes that run multiple LLM-powered applications. These applications typically have common non-functional requirements such as the ability to run different models, track user spending and enforcing budgets. Without a common gateway, each team must either build its own implementation—duplicating effort and often producing several incomplete solutions—or invest in a centralized, well-designed solution that is generic and expressive enough to support every current and future application in the team's or organization's catalog.

This project takes the second approach, using LiteLLM, a popular AI gateway,
as baseline and extends it to fill key gaps.

## 2. Approach

There are various AI Gateway solutions out there, from SaaS to open-source distributions, all of which consistently fail to capture the complete set of features your team needs. Nevertheless, open-source solutions often provide a strong foundation that teams can extend to address critical feature gaps. This approach avoids spending weeks reinventing a solution that other teams with millions in VC funding have already built and battle-tested.

## 3. Requirements

I consider the following minimum acceptance criteria for a complete AI Gateway:

- Unified LLM API Interface
- HTTP and SSE transports
- Native deployment on at least one of the three major hyperscalers: AWS
  (preferred), Azure, or GCP
- A multi-tenant model that tracks usage and enforces cost controls with
  hierarchies at least one level deep (e.g., User -> Team)
- Built-in logs and traces

The following are nice-to-have capabilities but not grounds for immediate exclusion, either because they (a) can be built and run separately from the gateway or (b) provide alternatives to the core feature set.

- Guardrails
- WebSocket transport - OpenAI popularized it as an efficient alternative to
  SSE, particularly for high-volume conversations.
- JWT authentication
- Credential load balancing - Distributes traffic across available
  provider keys using real-time metrics, load-balancing algorithms and other
  techniques.

## 4. High-Level Design

![High-level AI gateway architecture](assets/00-proposal-high-level-arch.png)

### 4.1. LiteLLM (Core)

With more than 53,000 GitHub stars, LiteLLM is arguably the most popular open-source AI gateway with major tech companies including Netflix, Stripe, and SAP, as references.

Its recent Rust migration (mid-2026) addresses previous performance concerns about its Python-based implementation (FastAPI). Those concerns led competitors such as Bifrost to claim performance up to 50 times faster than LiteLLM.

Post-migration, LiteLLM reported metrics describe a stable throughput increased by 15x (450 -> 6,700 RPS) while cutting request overhead by 99%, from 7.5ms to 0.05ms. This throughput surpasses Bifrost's documented 5,000 stable RPS, although Bifrost reports an overall lower request overhead of approximately 0.011 ms.

#### Deployment

LiteLLM makes AWS deployment straightforward by providing a Terraform module
for production deployments on EKS and ECS.

#### Multi-tenancy

> **Fit:** native

LiteLLM supports multi-tenant architectures across organizations, teams, departments, and customers while maintaining appropriate isolation between tenants. The OSS version does not support organizations, so teams form its highest hierarchy level, though this shouldn't be a problem for most startups and medium-size scale-ups.

#### Authentication

> **Fit:** requires custom work

Authentication is based on virtual keys, which conceptually behave similarly to API Keys. A user can have multiple virtual keys.

JWT-based auth for OIDC identities, and consequently JWT -> Virtual Key mapping, is only available in Enterprise versions.

#### Load Balancing

> **Fit:** native

LiteLLM provides multiple load-balancing algorithms and an experimental
automatic-routing feature that selects models based on request complexity.

#### Authorization

> **Fit:** requires custom work

Although LiteLLM offers RBAC controls in its Enterprise distribution, but they lack the
expressiveness that most production applications need for flexible permission
models.

#### Deployment

> **Fit:** native

LiteLLM provides pre-built Terraform modules that simplify deployment, breaking with the long-standing OSS convention of supporting Kubernetes deployments only. Its native AWS, Azure, and GCP deployment options are a welcome alternative for teams that want to avoid Kubernetes and its inherent complexity.

#### Guardrails

> **Fit:** native

#### Client integrations

LiteLLM exposes OpenAI-compatible HTTP endpoints from which teams can generate client SDKs in their preferred programming languages by using tools such as Speakeasy, Stainless, or Fern.

### 4.2. Authorizer

The authorizer runs as a discrete process that validates and authorizes each request before passing it to LiteLLM:

1. Extracts the `Authorization` request header to identify and validate the caller (expects a valid JWT)
2. Checks the decoded identity and request details against Amazon Verified Permissions to determine whether the caller can perform the request
3. Passes the request through applicable guardrails (placeholder, to be expanded later)
4. Maps the caller's JWT to one or more virtual keys for authenticated LiteLLM requests
5. Sends the request to LiteLLM with the mapped virtual keys

**Note:** Introducing another service fragments authorization responsibilities
between the custom authorizer (JWTs and application-level checks) and LiteLLM
(virtual keys and budgets).

## 5. Design Alternatives

### vs Bifrost

- Provides weighted credential load balancing out of the box
- Supports ECS deployment, although it requires hand-rolling the infrastructure code since Bifrost does not provide any prebuilt Terraform modules
- Uses basic authentication but supports custom JWT authentication on top of
  virtual keys
- Includes semantic caching out of the box
- Its official documentation reports a maximum throughput of 3,000–5,000 RPS
- Includes Prometheus metrics endpoints for telemetry data
- Implements usage and budgets at user and team level

Despite this, Bifrost's guardrails framework is only available to the Enterprise version, therefore teams using the OSS version must craft a Go plugin to implement custom guardrails. This became a deciding factor and why we I've ultimately excluded Bifrost in favour of LiteLLM.

### vs PortKey

Excluded Portkey because its OSS distribution lacks key features that
require an Enterprise license:

- Multi-tenancy at any team/org level
- Observability

### vs Kong

Excluded Kong because it restricts deployment to Kubernetes, which offers
less flexibility than simpler container orchestration services such as ECS - EKS Auto Mode wasn't evaluated as a possible alternative.

### vs SaaS

Excluded Cloudflare AI Gateway, Vercel AI Gateway, and OpenRouter because
they do not meet the open-source requirement.

---

## 6. Out of scope

At the time of writing, we excluded the following capabilities from the
project's scope:

- Simple caching
- Semantic caching
- Routing rules
- Automatic fallbacks
- Automatic retries
- Prompt management
