# ADR 01: Authorizer Compute

Status: accepted (2026-07). Extends
[00-PROPOSAL.md §4.2](00-PROPOSAL.md).

## Context

The authorizer sits in the data path: it forwards each request to LiteLLM
and relays the response. The proposal makes HTTP and SSE transports hard
requirements.

Three options were evaluated:

| Criterion | ALB + ECS Fargate | API Gateway + Lambda | CloudFront + Lambda@Edge |
| --- | --- | --- | --- |
| SSE streaming | Native pass-through | API Gateway buffers responses | Supported through CloudFront with auth in the control path only |
| WebSockets | Native | Requires a separate WebSocket API | Pass-through only |
| Timeouts and payload | 300 s+ idle timeout and no practical payload cap | 29–30 s and 10 MB | Function can inspect at most 1 MB of the request body |
| Warm overhead | ~15–35 ms | ~30–60 ms | ~30–80 ms with worse p99 |
| Cold starts | None | 100–400 ms | 200–800 ms per edge PoP |
| Guardrail visibility | Full request and response | Full request | Request up to 1 MB; response unavailable |
| Cost profile | Flat ~$35–50/month minimum | Pay per stream-second; expensive at steady load | Pay per request and scale to zero |
| Operations | Container and service; the cluster already exists for LiteLLM | Lowest | `us-east-1` deploys, replicated logs, and no environment variables |

## Decision

Deploy the authorizer behind an Application Load Balancer on ECS Fargate.

API Gateway with Lambda fails the SSE requirement. CloudFront with
Lambda@Edge is viable only as a control-path option: it loses response-path
guardrails, caps inspectable request bodies at 1 MB, and provides little
benefit to backend callers near the home region.

## Consequences

The gateway supports native HTTP, SSE, and potential WebSocket
pass-through without cold starts or serverless response limits. It incurs a
fixed monthly compute and load-balancer cost and requires operating an ECS
service.
