import { serve } from "@hono/node-server";
import { buildApp } from "./app.js";
import { createJwtVerifier } from "./authn/client.js";
import { createAvpAuthorizer } from "./authz/client.js";
import { buildStartupSummary, loadConfig } from "./config.js";
import type { Guardrail } from "./guardrails/types.js";
import { createGuardrailChain } from "./guardrails/utils.js";
import { createMemoryKeyCache, createRedisKeyCache } from "./keys/cache.js";
import { createKeyExchanger } from "./keys/exchange.js";
import { createLiteLlmAdminClient } from "./litellm/client.js";
import { createUpstreamProxy } from "./litellm/proxy.js";
import { createLogger } from "./logger.js";

const config = loadConfig();
const logger = createLogger(config.logLevel);

// Register custom pre-flight guardrails here. LiteLLM's native guardrails
// (configured via proxy_config in Terraform) run downstream regardless.
const guardrails: Guardrail[] = [];

const cache = config.redisUrl
  ? createRedisKeyCache(config.redisUrl)
  : createMemoryKeyCache();

const admin = createLiteLlmAdminClient(config.litellm);

const app = buildApp({
  verifier: await createJwtVerifier(config.oidc),
  authorizer: createAvpAuthorizer(config.avp),
  guardrails: createGuardrailChain(guardrails),
  keys: createKeyExchanger({
    cache,
    admin,
    logger,
    virtualKeyDuration: config.keys.virtualKeyDuration,
    cacheTtlSeconds: config.keys.cacheTtlSeconds,
    cleanupGraceSeconds: config.keys.cleanupGraceSeconds,
    ...(config.keys.defaultUserMaxBudgetUsd !== undefined
      ? { defaultUserMaxBudgetUsd: config.keys.defaultUserMaxBudgetUsd }
      : {}),
  }),
  proxy: createUpstreamProxy({ baseUrl: config.litellm.baseUrl }),
  logger,
});

const server = serve({ fetch: app.fetch, port: config.port }, () => {
  logger.info(
    buildStartupSummary(config, {
      preflightGuardrailCount: guardrails.length,
    }),
    "authorizer ready",
  );
});

for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.once(signal, () => {
    logger.info({ signal }, "shutting down");
    server.close(async () => {
      await cache.close();
      process.exit(0);
    });
  });
}
