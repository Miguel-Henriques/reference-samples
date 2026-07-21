# AI Gateway Initial Proposal

## 1. Intro

An AI Gateway is a must-have piece of infrastructure for companies of all sizes running more than one LLM-powered applications. Most of these apps typically have common responsibilities regarding the use of AI, e.g. the ability to easily run different models, track user spend, enforce budgets, etc. which either translates into each team building its own implementation, along duplicating the amount of work often to reach multiple incomplete solutions or, dedicate the time to build/set up a centrallised and well thought solution that is generic and expressive enough to fit all existing and future applications of your team/orgs app catalog.

This project takes the second approach, leveraging existing popular AI Gateway offerings (LiteLLM) as the baseline and then build on top of it to fill-in for any relevant, missing gaps.

## 2. Approach

There are various AI Gateway solutions out there, from SaaS to open source distributions, all of which consistently fail to capture the complete set of features your team needs. Though there is an opportunity to discover where OSS (Open Source Software) can be used as accelerators and if they provide the composability required for you to build on top to fill-in feature gaps your team depends on.

This is a smarter approach than immediately trying to reinvent the wheel and spend weeks designing and building something another couple of guys from SF with millions of funding have already done and battle tested.

## 3. Requirements

I consider the following minimum acceptance criteria for any complete AI Gateway:

- Unified LLM API Interface
- HTTP and SSE transports
- Native deployment in at least one of the 3 major hyperscalers - AWS (preferred), Azure, GCP
- Multi-tenant model for tracking usage and enforcing & cost controls with at least 1-level deep hierarchies (e.g. User -> Team)
- Built-in logs and traces

The following are nice to haves but not immediate exclusion reasons because either: a) can be built and ran in separately from the gateway or; b) is alternative to the core set of features

- Guardrails
- WebSocket transport - Popularized by OpenAI as an efficient alternative to SSE, particularly in high-volume conversations.
- JWT Authentication
- Credential Load Balancing - Smoothes distribution of traffic across available provider keys using real-time metrics, load balancing algorithms or other techniques.

## 4. High-Level Design

![High-level AI gateway architecture](assets/00-proposal-high-level-arch.png)

### 4.1. LiteLLM (Core)

LiteLLM AI Gateway is arguably the most popular open source AI Gateway solution with over 53k stars on GitHub and used by big names in tech including Netflix, Stripe and SAP.

Its recent Rust migration (mid 2026) removes previous performance concerns regarding its python-based API (FastAPI) that led to competitors such as Bifrost to market to be up to 50x faster than LiteLLM - from ~450 stable RPS, ~7.5ms overhead to ~6.7k stable RPS, ~0.05ms overhead which even superseeds Bifrost's documented 5k stable RPS, ~0.011 ms.

#### Deployment

Deployment on AWS is straigthforward as it includes a Terraform module for a full-on production deployment - EKS & ECS compatible.

#### Multi-tenancy

> **Fit:** native

It supports multi-tenant architectures spanning different tenant archetypes (organizations, teams, departments, or customers) that ensure the correct level of isolation among such tenants. Organizations are not included in the OSS version, with Team-level being the top level hierarchy - which is sufficient for most startups and scaleups anyways.

#### Authentication

> **Fit:** requires custom work

Authentication is based on virtual keys, which conceptually behave similarly to API Keys. A user can have multiple virtual keys.

JWT-based auth for OIDC identities and consequently JWT -> Virtual Key mapping is only available in Enterprise versions.

#### Load Balancing

> **Fit:** native

LiteLLM ships multi-load balancing algorithms even an experimental auto routing feature to route to different models based on request complexity

#### Authorization

> **Fit:** requires custom work

LiteLLM RBAC controls, which are available in the enterprise distro, wouldn't be sufficiently expressive for most production applications that require more flexible permissions models.

**Custom work:** Implement a custom authorizer in front of the AI gateway,

#### Deployment

> **Fit:** native

Deployment is straightforward (via Terraform modules) and provides a good level of configurability with its native AWS architecture deployment path. This is a greater offer than bundled solutions limited to Kubernetes-only deployments which many teams do not want or feel comfortable to maintain due to its inherit complexity.

#### Guardrails

> **Fit:** native

#### Client integrations

It exposes OpenAI compatible HTTP endpoints that you can derive client SDKs from based on your team's favourite programming languages (e.g. via speakeasy, stainless, fern)

### 4.2. Authorizer

The authorizer is a discrete process that validates and authorizes the request before handing it over to LiteLLM:

1. Extract Authorization request header to identify and validate the caller's identity (expects a valid JWT)
2. Runs the decoded identity + request details against Amazon Verified Permissions to verify if the caller has sufficient permissions to perform the given request
3. Pass request through the list of applicable guardrails (placeholder, will be expanded later)
4. Map caller's JWT to one or more Virtual Keys to perform authenticated requests to LiteLLM
5. Request is sent to LiteLLM with replaced virtual keys

Note: You acknowlede that the introduction of another service part of the authorization becomes fragmented between the custom authorizer (JWT, app-level checks) and LiteLLM (Virtual Keys, budgets).

## 5. Design Alternatives

### vs Bifrost

- Weighted Credential Load Balancing available out of the box
- ECS deployment though it requires a bit of custom work since there's no pre-built Terraform modules
- Uses basic auth but custom JWT auth be built on top of virtual keys
- Includes semantic caching out of the box
- Official docs describe max throughput 3,000–5,000 RPS
- Includes Prometheus metrics endpoints for telemetry data
- Implements usage and budgets at user and team level

The main downside with Bifrost is the fact its guardrails framework is only available for enterprise, therefore you need to build a custom Go plugin to implement guardrails and why we ultimately excluded it after comparison with LiteLLM.

### vs PortKey

Excluded due to missing key features in the OSS distro that only become acessible with an enterprise license:

- Multi-tenancy at any team/org level
- Observability

### vs Kong

Kong was excluded because its deployment is restricted to Kubernetes which is less ideal than other simpler container orchestration services such as ECS - though one could argue that EKS Auto Mode is as simple as ECS Fargate.

### vs SaaS

CloudFlare AI Gateway, Vercel AI Gateway and OpenRouter are appealing candidates that were excluded because open source is one of the key exclusion criteria.

---

## 6. Out of scope

The following criteria were excluded at the moment of writing this doc:

- Simple caching
- Semantic caching
- Routing rules
- Automatic fallbacks
- Automatic retries
- Prompt Management
