# AI Gateway — User Guide

Audience: application teams calling the gateway. You need two things from the
gateway operators:

1. The **gateway URL** (looks like `https://<gateway-alb-dns>` or a friendly
   DNS name in front of it).
2. Your app registered with the company **OIDC identity provider**, issuing
   JWTs with the gateway's audience.

## Authentication

Send your IdP-issued JWT as a Bearer token. The gateway validates it, checks
your permissions, and forwards the call to the LLM backend — you never handle
provider or LiteLLM keys.

```
Authorization: Bearer <your JWT>
```

Tokens must be signed by the company IdP, unexpired, and carry the gateway
audience. If your token carries a team claim (default: `team_id`), usage is
attributed to that team and its budget; without it, usage is tracked against
you individually. Ask the operators to provision your team before sending a
team claim — unknown teams are rejected.

## API surface

The gateway exposes the OpenAI-compatible surface under `/v1/*` — chat
completions, embeddings, model listing, and every other data-plane route
LiteLLM supports. Anything else returns 404.

### curl

```bash
curl "$GATEWAY_URL/v1/chat/completions" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

Model names are the logical names configured by the operators — list them:

```bash
curl "$GATEWAY_URL/v1/models" -H "Authorization: Bearer $JWT"
```

### Streaming (SSE)

Add `"stream": true`; the gateway streams server-sent events end-to-end:

```bash
curl -N "$GATEWAY_URL/v1/chat/completions" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet", "stream": true,
       "messages": [{"role": "user", "content": "Write a haiku"}]}'
```

### OpenAI SDKs

Point any OpenAI-compatible SDK at the gateway and pass your JWT as the API
key:

```ts
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: `${process.env.GATEWAY_URL}/v1`,
  apiKey: await getJwtFromYourIdp(), // refresh before expiry
});

const completion = await client.chat.completions.create({
  model: 'claude-sonnet',
  messages: [{ role: 'user', content: 'Hello!' }],
});
```

```python
from openai import OpenAI

client = OpenAI(base_url=f"{GATEWAY_URL}/v1", api_key=get_jwt())
resp = client.chat.completions.create(
    model="claude-sonnet",
    messages=[{"role": "user", "content": "Hello!"}],
)
```

JWTs expire — construct the client with a fresh token (or a token provider)
rather than a long-lived constant.

## Errors

Errors use the OpenAI envelope: `{"error": {"message", "type", "code"}}`.

| Status | Code                   | Meaning / what to do                                                      |
| ------ | ---------------------- | ------------------------------------------------------------------------- |
| 401    | `invalid_token`        | Missing/expired/wrong-issuer JWT. Refresh your token.                     |
| 403    | `permission_denied`    | No authorization policy permits this model/action. Contact operators.     |
| 403    | `team_not_provisioned` | Your JWT names a team that doesn't exist yet. Ask operators to create it. |
| 400    | `guardrail_rejected`   | Request blocked by a gateway guardrail.                                   |
| 429    | (from backend)         | Rate limit or budget exceeded for your key/user/team.                     |
| 502    | `upstream_error`       | Gateway couldn't reach the LLM backend. Retry with backoff.               |

## Usage & budgets

Spend is metered per request and attributed to you (JWT `sub`) and, when
present, your team. Operators may set per-user and per-team budgets; when a
budget is exhausted the backend returns 429-class errors until it resets or
is raised. Ask the operators for your current spend, or for access to the
usage dashboard.
