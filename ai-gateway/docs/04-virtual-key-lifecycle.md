# ADR 04: Virtual Key Lifecycle

Status: accepted (2026-07).

## Context

LiteLLM requires virtual keys for data-plane requests but never
re-discloses their plaintext. Its `/key/regenerate` endpoint is available
only in Enterprise. A cache miss therefore cannot recover an existing key.

A durable subject-to-key map in DynamoDB with KMS would turn the cache into
a credential store for marginal benefit. A scheduled global sweeper would
add infrastructure even though rotation can correct stale keys per caller.

## Decision

Generate a virtual key through `/key/generate` on a cache miss. Cache it
in-memory with ElastiCache Redis as the shared layer.

After each mint, asynchronously delete older keys belonging to the caller.
Keep a grace window so concurrent mints cannot delete a newly issued key.
If LiteLLM returns 401 for a cached key, evict it, mint a replacement, and
retry the upstream request once.

Do not persist plaintext keys in a durable credential store and do not run
a scheduled global key sweeper.

## Consequences

Active callers converge on one live authorizer-issued key. Key duration is
the backstop if cleanup fails, and the next mint retries cleanup. A departed
caller's last expired key can remain as a database row, bounded by the
number of users.

Spend and budgets remain attached to LiteLLM users and teams and are
unaffected by key churn. Cache availability affects mint frequency but not
the durability of spending data.
